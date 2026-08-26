#!/usr/bin/env python3

# Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
# This product includes software developed at Datadog (https://www.datadoghq.com/).
# Copyright 2026-Present Datadog, Inc.

import json
import re
import subprocess
import sys
from pathlib import Path
from typing import Optional


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
PACKAGE_RESOLVED = REPOSITORY_ROOT / "Package.resolved"
BASE_XCCONFIG = REPOSITORY_ROOT / "xcconfigs" / "Base.xcconfig"
CHECKOUTS = REPOSITORY_ROOT / ".build" / "checkouts"

# These are the Apple platforms the provider publicly supports and exercises in CI.
PLATFORM_XCCONFIG_KEYS = {
    "ios": "IPHONEOS_DEPLOYMENT_TARGET",
    "macos": "MACOSX_DEPLOYMENT_TARGET",
    "watchos": "WATCHOS_DEPLOYMENT_TARGET",
    "tvos": "TVOS_DEPLOYMENT_TARGET",
}

# Both direct dependencies must explicitly advertise every public platform.
DIRECT_DEPENDENCIES = ("dd-sdk-ios", "swift-sdk")
OPENFEATURE_IDENTITY = "swift-sdk"


def run(command: list[str]) -> str:
    result = subprocess.run(
        command,
        cwd=REPOSITORY_ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    return result.stdout


def dump_package(package_path: Path) -> dict:
    output = run(["swift", "package", "--package-path", str(package_path), "dump-package"])
    return json.loads(output)


def package_platforms(package: dict) -> dict[str, str]:
    return {
        platform["platformName"].lower(): platform["version"]
        for platform in package.get("platforms", [])
    }


def parse_xcconfig(path: Path) -> dict[str, str]:
    settings = {}
    assignment = re.compile(r"^\s*([A-Z0-9_]+)\s*=\s*([^\s/]+)\s*$")
    for line in path.read_text().splitlines():
        match = assignment.match(line)
        if match:
            settings[match.group(1)] = match.group(2)
    return settings


def version_tuple(version: str) -> tuple[int, ...]:
    parts = tuple(int(part) for part in version.split("."))
    return parts + (0,) * (3 - len(parts))


def find_dependency_requirement(node: object, identity: str) -> Optional[dict]:
    if isinstance(node, dict):
        if node.get("identity") == identity and isinstance(node.get("requirement"), dict):
            return node["requirement"]
        for value in node.values():
            requirement = find_dependency_requirement(value, identity)
            if requirement is not None:
                return requirement
    elif isinstance(node, list):
        for value in node:
            requirement = find_dependency_requirement(value, identity)
            if requirement is not None:
                return requirement
    return None


def lower_bound(requirement: dict) -> Optional[str]:
    range_requirement = requirement.get("range")
    if isinstance(range_requirement, list) and range_requirement:
        first_range = range_requirement[0]
        if isinstance(first_range, dict):
            return first_range.get("lowerBound")
    if isinstance(range_requirement, dict):
        return range_requirement.get("lowerBound")

    exact_requirement = requirement.get("exact")
    if isinstance(exact_requirement, str):
        return exact_requirement
    return None


def fail(errors: list[str]) -> None:
    print("Platform compatibility validation failed:", file=sys.stderr)
    for error in errors:
        print(f"- {error}", file=sys.stderr)
    raise SystemExit(1)


def main() -> None:
    errors = []
    root_package = dump_package(REPOSITORY_ROOT)
    root_platforms = package_platforms(root_package)
    xcconfig = parse_xcconfig(BASE_XCCONFIG)

    for platform, setting in PLATFORM_XCCONFIG_KEYS.items():
        package_version = root_platforms.get(platform)
        xcconfig_version = xcconfig.get(setting)
        if package_version is None:
            errors.append(f"Package.swift does not declare {platform}")
        elif xcconfig_version is None:
            errors.append(f"{BASE_XCCONFIG.relative_to(REPOSITORY_ROOT)} does not declare {setting}")
        elif version_tuple(package_version) != version_tuple(xcconfig_version):
            errors.append(
                f"{platform} is {package_version} in Package.swift but {xcconfig_version} in {setting}"
            )

    resolved = json.loads(PACKAGE_RESOLVED.read_text())
    pins = {pin["identity"]: pin for pin in resolved.get("pins", [])}

    openfeature_pin = pins.get(OPENFEATURE_IDENTITY)
    openfeature_requirement = find_dependency_requirement(root_package, OPENFEATURE_IDENTITY)
    if openfeature_pin is None:
        errors.append(f"Package.resolved does not pin {OPENFEATURE_IDENTITY}")
    elif openfeature_requirement is None:
        errors.append(f"Package.swift does not constrain {OPENFEATURE_IDENTITY}")
    else:
        minimum_version = lower_bound(openfeature_requirement)
        resolved_version = openfeature_pin.get("state", {}).get("version")
        if minimum_version is None:
            errors.append(f"Could not determine the {OPENFEATURE_IDENTITY} minimum version")
        elif resolved_version is None:
            errors.append(f"Package.resolved does not record a {OPENFEATURE_IDENTITY} version")
        elif version_tuple(minimum_version) != version_tuple(resolved_version):
            errors.append(
                f"{OPENFEATURE_IDENTITY} allows {minimum_version} but Package.resolved validates "
                f"{resolved_version}; consumers could resolve an older, unvalidated release"
            )

    for identity in DIRECT_DEPENDENCIES:
        pin = pins.get(identity)
        checkout = CHECKOUTS / identity
        if pin is None:
            errors.append(f"Package.resolved does not pin direct dependency {identity}")
            continue
        if not checkout.is_dir():
            errors.append(f"Missing resolved checkout {checkout.relative_to(REPOSITORY_ROOT)}")
            continue

        expected_revision = pin.get("state", {}).get("revision")
        actual_revision = run(["git", "-C", str(checkout), "rev-parse", "HEAD"]).strip()
        if actual_revision != expected_revision:
            errors.append(
                f"{identity} checkout is {actual_revision}, expected Package.resolved revision {expected_revision}"
            )

        dependency_platforms = package_platforms(dump_package(checkout))
        for platform in PLATFORM_XCCONFIG_KEYS:
            root_version = root_platforms.get(platform)
            dependency_version = dependency_platforms.get(platform)
            if dependency_version is None:
                errors.append(f"{identity} does not explicitly declare {platform} support")
            elif root_version is not None and version_tuple(dependency_version) > version_tuple(root_version):
                errors.append(
                    f"{identity} requires {platform} {dependency_version}, above the provider's {root_version} floor"
                )

    if errors:
        fail(errors)

    platforms = ", ".join(f"{name} {version}" for name, version in root_platforms.items())
    print(f"Platform compatibility validated: {platforms}")
    print("Direct dependencies explicitly support every advertised CI platform.")
    print("The OpenFeature consumer minimum matches the release pinned and validated by CI.")


if __name__ == "__main__":
    main()
