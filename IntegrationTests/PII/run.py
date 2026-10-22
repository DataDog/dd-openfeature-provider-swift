#!/usr/bin/env python3
# Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
# This product includes software developed at Datadog (https://www.datadoghq.com/).
# Copyright 2026-Present Datadog, Inc.

"""Build local SDK/provider artifacts and assert their actual loopback HTTP payloads on macOS."""
import argparse
import copy
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import tempfile
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HERE = Path(__file__).resolve().parent
PROVIDER = HERE.parents[1]
HASH = "sha256_b4698f9b6d186781fa8dc59e533578fa2d8379a46b1cf6db85cda6aa9c99e51b"
RAW = "jane.doe@datadoghq.com"


class Intake(BaseHTTPRequestHandler):
    state = "absent"
    offline = False
    attempts = []
    accepted = []
    assignments = []
    lock = threading.Lock()

    def log_message(self, *_args):
        pass

    def do_GET(self):
        cls = type(self)
        with cls.lock:
            count = sum(event["evaluation_count"] for batch in cls.accepted for event in batch["flagEvaluations"])
        encoded = json.dumps({"evaluation_count": count}).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)

    def do_POST(self):
        body = json.loads(self.rfile.read(int(self.headers.get("Content-Length", 0))))
        cls = type(self)
        with cls.lock:
            status, response = 200, {}
            if self.path.startswith("/control"):
                cls.state, cls.offline = body["state"], body["offline"]
            elif self.path.startswith("/assignments"):
                cls.assignments.append(body)
                if cls.offline:
                    status = 503
                else:
                    flags = {}
                    for key, kind, value in [("bool", "boolean", True), ("string", "string", "ok"),
                                             ("int", "integer", 42), ("double", "float", 1.5),
                                             ("object", "object", {"ok": True})]:
                        flags[f"{key}-{cls.state}"] = dict(allocationKey="a", variationKey="v", variationType=kind,
                                                          variationValue=value, reason="TARGETING_MATCH", doLog=False)
                    attributes = {"flags": flags}
                    if cls.state != "absent":
                        attributes["observeFullEvaluationData"] = {"true": True, "false": False, "null": None,
                                                                   "wrong": "true", "disabled": True}[cls.state]
                    response = {"data": {"type": "precomputed-assignments", "attributes": attributes}}
            elif self.path.startswith("/evaluations"):
                cls.attempts.append(body)
                if len(cls.attempts) == 1:
                    status = 500
                else:
                    cls.accepted.append(body)
            else:
                status = 404
            encoded = json.dumps(response).encode()
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(encoded)))
            self.end_headers()
            self.wfile.write(encoded)


def reset_intake():
    with Intake.lock:
        Intake.state, Intake.offline = "absent", False
        Intake.attempts, Intake.accepted, Intake.assignments = [], [], []


def captured_wire():
    with Intake.lock:
        return copy.deepcopy({"attempts": Intake.attempts, "accepted": Intake.accepted,
                              "assignments": Intake.assignments})


def ios_test_source(base_url):
    source = (HERE / "Probe.swift").read_text()
    assert source.count("@main\n") == 1
    source = source.replace("@main\n", "", 1)
    variable = 'ProcessInfo.processInfo.environment["FFL_PII_URL"]!'
    assert source.count(variable) == 1
    source = source.replace(variable, json.dumps(base_url), 1)
    return source + "\n" + (HERE / "IOSAppTests.swift").read_text()


def verify_wire(accepted, assignments, attempts=None):
    events = [event for batch in accepted for event in batch["flagEvaluations"]]
    counts = {}
    for event in events + [event for batch in (attempts or []) for event in batch["flagEvaluations"]]:
        key = event["flag"]["key"]
        state = key.rsplit("-", 1)[1]
        assert state in ["absent", "false", "null", "wrong", "true"], event
        full = state == "true"
        assert event["targeting_key"] == (RAW if full else HASH), event
        if full:
            assert event["context"]["evaluation"]["private"] == "CONTEXT_CANARY", event
        else:
            assert "evaluation" not in event.get("context", {}), event
            assert "CONTEXT_CANARY" not in json.dumps(event) and RAW not in json.dumps(event), event
        code = event.get("error", {}).get("message")
        assert code in (None, "FLAG_NOT_FOUND", "TYPE_MISMATCH"), event
        assert (code == "FLAG_NOT_FOUND") == key.startswith("missing-"), event
        if code:
            assert event["runtime_default_used"] is True, event
    for event in events:
        key = event["flag"]["key"]
        code = event.get("error", {}).get("message")
        counts[(key, code)] = counts.get((key, code), 0) + event["evaluation_count"]
    expected = {}
    for state in ["absent", "false", "null", "wrong", "true"]:
        for key in ["bool", "string", "int", "double", "object"]:
            expected[(f"{key}-{state}", None)] = 4 if key == "bool" and state == "false" else 2
        expected[(f"missing-{state}", "FLAG_NOT_FOUND")] = 2
        expected[(f"bool-{state}", "TYPE_MISMATCH")] = 2
    assert counts == expected, (counts, expected)
    assert assignments, "No real assignment requests captured"
    for body in assignments:
        subject = body["data"]["attributes"]["subject"]
        assert subject["targeting_key"] == RAW, subject
        assert subject["targeting_attributes"]["private"] == "CONTEXT_CANARY", subject
    return {"evaluation_count": sum(counts.values()), "buckets": len(counts), "assignment_requests": len(assignments)}


def identity(path):
    def git(*args):
        return subprocess.check_output(["git", "-C", str(path), *args])
    return {"path": str(path), "commit": git("rev-parse", "HEAD").decode().strip(),
            "diff_sha256": hashlib.sha256(git("diff", "HEAD", "--")).hexdigest(),
            "status": git("status", "--short").decode()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sdk", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--cocoapods-destination", help="Run the wire probe inside both CocoaPods iOS apps at this xcodebuild destination")
    args = parser.parse_args()
    if platform.system() != "Darwin":
        parser.error("Requires macOS and Xcode/Swift 6.2; Linux cannot build the Apple SDK artifacts")
    sdk, output = args.sdk.resolve(), args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    evidence = {"sdk": identity(sdk), "provider": identity(PROVIDER), "commands": []}
    server = ThreadingHTTPServer(("127.0.0.1", 0), Intake)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    active_run = "macos"

    def save_wire():
        wire = captured_wire()
        (output / ("wire-" + active_run + ".json")).write_text(json.dumps(wire, indent=2))
        return wire

    def verify_run():
        wire = save_wire()
        assert len(wire["attempts"]) >= 2, "Retry was not exercised"
        return verify_wire(wire["accepted"], wire["assignments"], wire["attempts"])

    try:
        with tempfile.TemporaryDirectory(prefix="ffl-3433-") as temp:
            root = Path(temp)
            provider = root / "dd-openfeature-provider-swift"
            shutil.copytree(PROVIDER, provider, ignore=shutil.ignore_patterns(".git", ".build", ".pii-sdk", "pii-evidence", "Pods"))
            manifest = provider / "Package.swift"
            source, changed = re.subn(r'\.package\(url: "https://github.com/DataDog/dd-sdk-ios.git", [^\n]+\),',
                                     '.package(path: ' + json.dumps(str(sdk)) + '),', manifest.read_text())
            assert changed == 1, "Expected one native SDK dependency override"
            manifest.write_text(source)
            (provider / "Package.resolved").unlink(missing_ok=True)
            probe = root / "probe"
            (probe / "Sources" / "Probe").mkdir(parents=True)
            shutil.copy2(HERE / "Probe.swift", probe / "Sources" / "Probe" / "Probe.swift")
            (probe / "Package.swift").write_text('''// swift-tools-version: 6.2
import PackageDescription
let package = Package(name: "PrivacyProbe", platforms: [.macOS("12.6")], dependencies: [
    .package(path: %s), .package(path: %s),
    .package(url: "https://github.com/open-feature/swift-sdk.git", exact: "0.3.1")
], targets: [.executableTarget(name: "Probe", dependencies: [
    .product(name: "DatadogCore", package: "dd-sdk-ios"),
    .product(name: "DatadogFlags", package: "dd-sdk-ios"),
    .product(name: "DatadogOpenFeatureProvider", package: "dd-openfeature-provider-swift"),
    .product(name: "OpenFeature", package: "swift-sdk")
])], swiftLanguageModes: [.v5])
''' % (json.dumps(str(sdk)), json.dumps(str(provider))))
            env = dict(os.environ, FFL_PII_URL=f"http://127.0.0.1:{server.server_port}")
            with (output / "build-and-run.log").open("w") as log:
                def run(command, cwd=None):
                    evidence["commands"].append(command)
                    print("Running:", command, flush=True)
                    subprocess.run(command, check=True, stdout=log, stderr=subprocess.STDOUT, env=env, cwd=cwd, timeout=1800)
                run(["xcodebuild", "-version"])
                run(["swift", "test", "--package-path", str(provider)])
                run(["swift", "build", "--package-path", str(probe)])
                binary = probe / ".build" / "debug" / "Probe"
                evidence["binary_sha256"] = hashlib.sha256(binary.read_bytes()).hexdigest()
                shutil.copy2(probe / "Package.resolved", output / "Package.resolved")
                run([str(binary)])
                evidence["assertions"] = verify_run()
                evidence["cocoapods"] = "not run"
                if args.cocoapods_destination:
                    smoke = provider / "SmokeTests" / "cocoapods"
                    podfile = (smoke / "Podfile.src").read_text()
                    podfile = re.sub(r"  pod 'DatadogFlags', [^\n]+", "\n".join(
                        "  pod '%s', :path => %s" % (name, json.dumps(str(sdk)))
                        for name in ["DatadogFlags", "DatadogInternal", "DatadogCore"]), podfile)
                    podfile = re.sub(r"  pod 'DatadogOpenFeatureProvider', [^\n]+",
                                     "  pod 'DatadogOpenFeatureProvider', :path => " + json.dumps(str(provider)), podfile)
                    (smoke / "Podfile").write_text(podfile)
                    env["BUNDLE_GEMFILE"] = str(provider / "Gemfile")
                    run(["bundle", "exec", "pod", "install"], cwd=smoke)
                    shutil.copy2(smoke / "Podfile.lock", output / "Podfile.lock")
                    # These targets have TEST_HOST=App.app/App: the shared probe executes
                    # inside the existing UIKit app, linked to the real local pod artifacts.
                    (smoke / "AppTests" / "CPProjectTests.swift").write_text(ios_test_source(env["FFL_PII_URL"]))
                    evidence["ios_apps"] = {}
                    for linkage in ["dynamic", "static"]:
                        active_run = "ios-" + linkage
                        reset_intake()
                        scheme = "App " + linkage.title() + " iOS"
                        derived = root / ("derived-" + linkage)
                        result_bundle = output / (active_run + ".xcresult")
                        run(["xcodebuild", "test", "-workspace", str(smoke / "CPProject.xcworkspace"),
                             "-scheme", scheme, "-destination", args.cocoapods_destination,
                             "-derivedDataPath", str(derived), "-resultBundlePath", str(result_bundle)], cwd=smoke)
                        assertions = verify_run()
                        app = derived / "Build" / "Products" / "Debug-iphonesimulator" / "App.app"
                        binaries = [app / "App"]
                        binaries += [p / p.stem for p in app.rglob("*.framework") if (p / p.stem).is_file()]
                        binaries += [p / p.stem for p in app.rglob("*.xctest") if (p / p.stem).is_file()]
                        evidence["ios_apps"][linkage] = {
                            "result": "passed", "assertions": assertions, "destination": args.cocoapods_destination,
                            "binary_sha256": {str(p.relative_to(app)): hashlib.sha256(p.read_bytes()).hexdigest() for p in binaries}
                        }
                    evidence["cocoapods"] = "passed: OpenFeature 0.3.0, local native/provider, static and dynamic iOS app wire probes"
            evidence["result"] = "passed"
    finally:
        server.shutdown()
        save_wire()
        (output / "evidence.json").write_text(json.dumps(evidence, indent=2))
    print(json.dumps(evidence["assertions"], indent=2))


if __name__ == "__main__":
    main()
