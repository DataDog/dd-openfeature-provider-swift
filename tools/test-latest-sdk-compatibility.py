#!/usr/bin/env python3

# Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
# This product includes software developed at Datadog (https://www.datadoghq.com/).
# Copyright 2026-Present Datadog, Inc.

import argparse
import importlib
import json
import re
import shutil
import subprocess
import tempfile
from pathlib import Path


compatibility = importlib.import_module("validate-platform-compatibility")
SDK_IDENTITY = "dd-sdk-ios"
SDK_URL = "https://github.com/DataDog/dd-sdk-ios.git"
REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
PLATFORMS = {
    "ios": ("iOS", "generic/platform=iOS Simulator"),
    "macos": ("macOS", "platform=macOS,arch=arm64"),
    "tvos": ("tvOS", "generic/platform=tvOS"),
    "watchos": ("watchOS", "generic/platform=watchOS"),
}


def run(command: list[str], cwd: Path, capture: bool = False) -> str:
    print(f"[{cwd.name}] {' '.join(command)}", flush=True)
    result = subprocess.run(
        command, cwd=cwd, check=True, text=True,
        stdout=subprocess.PIPE if capture else None,
    )
    return result.stdout or ""


def latest_allowed_version(tags: str, requirement: dict) -> str:
    ranges = requirement.get("range", [])
    if isinstance(ranges, dict):
        ranges = [ranges]
    exact = requirement.get("exact")
    if isinstance(exact, list) and len(exact) == 1:
        exact = exact[0]
    if not ranges and not isinstance(exact, str):
        raise ValueError("The Datadog SDK dependency must use a version range or exact version")

    versions = []
    # SDK release tags are bare semantic versions; pre-release tags are not candidates.
    for line in tags.splitlines():
        match = re.fullmatch(r"[0-9a-f]+\s+refs/tags/(\d+\.\d+\.\d+)", line)
        if not match:
            continue
        version = match.group(1)
        number = compatibility.version_tuple(version)
        if version == exact or any(
            compatibility.version_tuple(bounds["lowerBound"]) <= number
            < compatibility.version_tuple(bounds["upperBound"])
            for bounds in ranges
        ):
            versions.append(version)

    if not versions:
        raise ValueError(f"No stable SDK release tag satisfies {requirement}")
    return max(versions, key=compatibility.version_tuple)


def assert_sdk_version(package_root: Path, expected: str) -> None:
    resolved = json.loads((package_root / "Package.resolved").read_text())
    pin = next((pin for pin in resolved["pins"] if pin["identity"] == SDK_IDENTITY), None)
    actual = pin["state"].get("version") if pin else None
    if actual != expected:
        raise ValueError(f"Expected SDK {expected}, resolved {actual}; refusing an older-SDK fallback")
    print(f"Verified SDK {actual} at {pin['state']['revision']}", flush=True)


def copy_provider(source: Path, destination: Path) -> None:
    destination.mkdir()
    # Copy the package inputs, not dependency checkouts, build products, or Git metadata.
    for name in ("Package.swift", "Package.resolved", "Sources", "Tests", "xcconfigs"):
        item = source / name
        if item.is_dir():
            shutil.copytree(item, destination / name)
        else:
            shutil.copy2(item, destination / name)


def resolve_sdk(provider: Path, version: str) -> None:
    # SwiftPM needs managed dependency state before a package-specific version override.
    run(["swift", "package", "resolve"], provider)
    run(["swift", "package", "resolve", SDK_IDENTITY, "--version", version], provider)
    assert_sdk_version(provider, version)


def create_consumer(root: Path, platforms: dict[str, str], sdk_version: str) -> None:
    source = root / "Sources" / "CompatibilitySmoke"
    source.mkdir(parents=True)
    declarations = ",\n        ".join(
        f'.{name}("{platforms[platform]}")' for platform, (name, _) in PLATFORMS.items()
    )
    (root / "Package.swift").write_text(
        f'''// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CompatibilitySmoke",
    platforms: [
        {declarations}
    ],
    products: [.library(name: "CompatibilitySmoke", targets: ["CompatibilitySmoke"])],
    dependencies: [
        .package(path: "../provider"),
        .package(url: "{SDK_URL}", exact: "{sdk_version}")
    ],
    targets: [.target(name: "CompatibilitySmoke", dependencies: [
        .product(name: "DatadogOpenFeatureProvider", package: "provider"),
        .product(name: "DatadogFlags", package: "dd-sdk-ios")
    ])]
)
'''
    )
    (source / "Smoke.swift").write_text(
        "import DatadogFlags\nimport DatadogOpenFeatureProvider\n\n"
        "public func makeProvider() -> DatadogProvider { DatadogProvider() }\n"
    )


def main() -> None:
    parser = argparse.ArgumentParser(description="Test the newest SDK allowed by the provider")
    parser.add_argument("--repository-root", type=Path, default=REPOSITORY_ROOT)
    parser.add_argument("--check-only", action="store_true", help="Resolve and validate without builds")
    args = parser.parse_args()
    repository_root = args.repository_root.resolve()

    with tempfile.TemporaryDirectory(prefix="provider-latest-sdk-") as directory:
        workspace = Path(directory)
        provider = workspace / "provider"
        copy_provider(repository_root, provider)
        package = compatibility.dump_package(provider)
        requirement = compatibility.find_dependency_requirement(package, SDK_IDENTITY)
        if requirement is None:
            raise ValueError("Package.swift does not declare a Datadog SDK dependency")
        tags = run(["git", "ls-remote", "--tags", "--refs", SDK_URL], provider, capture=True)
        version = latest_allowed_version(tags, requirement)
        print(f"Newest allowed Datadog SDK: {version}; requirement: {requirement}", flush=True)

        # Override only the SDK pin; preserve unrelated locked dependencies where possible.
        resolve_sdk(provider, version)
        compatibility.main(provider)
        if args.check_only:
            return

        run(["swift", "test"], provider)
        consumer = workspace / "consumer"
        create_consumer(consumer, compatibility.package_platforms(package), version)
        run(["swift", "package", "resolve"], consumer)
        assert_sdk_version(consumer, version)
        for _, destination in PLATFORMS.values():
            run([
                "xcodebuild", "-scheme", "CompatibilitySmoke",
                "-destination", destination,
                "-derivedDataPath", str(workspace / "DerivedData"),
                "-disableAutomaticPackageResolution", "CODE_SIGNING_ALLOWED=NO", "build",
            ], consumer)
        assert_sdk_version(consumer, version)


if __name__ == "__main__":
    main()
