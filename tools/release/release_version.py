#!/usr/bin/env python3

# Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
#
# This product includes software developed at Datadog (https://www.datadoghq.com/).
# Copyright 2026 Datadog, Inc.

"""Prepare and validate release versions and extract release notes."""

from __future__ import annotations

import argparse
import datetime as dt
import re
import sys
from pathlib import Path


SEMVER = re.compile(r"(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)")
SDK_VERSION = re.compile(r'(internal let __sdkVersion = ")[^"]+(")')
PODSPEC_VERSION = re.compile(r'(?m)^(\s*s\.version\s*=\s*")[^"]+(".*)$')


class ReleaseError(RuntimeError):
    """Raised when a release invariant is not satisfied."""


def require_semver(version: str) -> None:
    if SEMVER.fullmatch(version) is None:
        raise ReleaseError(
            f"Invalid release version {version!r}; expected MAJOR.MINOR.PATCH without a v prefix"
        )


def replace_version(text: str, pattern: re.Pattern[str], version: str, path: Path) -> str:
    updated, count = pattern.subn(lambda match: f"{match.group(1)}{version}{match.group(2)}", text)
    if count != 1:
        raise ReleaseError(f"Expected exactly one version declaration in {path}, found {count}")
    return updated


def declared_version(text: str, pattern: re.Pattern[str], path: Path) -> str:
    matches = list(pattern.finditer(text))
    if len(matches) != 1:
        raise ReleaseError(f"Expected exactly one version declaration in {path}, found {len(matches)}")
    declaration = matches[0].group(0)
    match = re.search(r'"([^"]+)"', declaration)
    if match is None:
        raise ReleaseError(f"Could not parse the version declaration in {path}")
    return match.group(1)


def release_header_index(lines: list[str], version: str) -> int:
    header = re.compile(rf"^# {re.escape(version)} / (\d{{4}}-\d{{2}}-\d{{2}})$")
    matches = [index for index, line in enumerate(lines) if header.fullmatch(line)]
    if len(matches) != 1:
        raise ReleaseError(
            f"Expected exactly one '# {version} / YYYY-MM-DD' CHANGELOG heading, found {len(matches)}"
        )
    date_text = header.fullmatch(lines[matches[0]]).group(1)  # type: ignore[union-attr]
    try:
        dt.date.fromisoformat(date_text)
    except ValueError as error:
        raise ReleaseError(f"Invalid CHANGELOG release date {date_text!r}") from error
    return matches[0]


def prepare_changelog(text: str, version: str, release_date: str) -> str:
    try:
        dt.date.fromisoformat(release_date)
    except ValueError as error:
        raise ReleaseError(f"Invalid release date {release_date!r}; expected YYYY-MM-DD") from error

    lines = text.splitlines()
    if not lines or lines[0] != "# Unreleased":
        raise ReleaseError("CHANGELOG.md must begin with '# Unreleased'")
    if any(line.startswith(f"# {version} /") for line in lines):
        raise ReleaseError(f"CHANGELOG.md already contains a {version} release heading")

    next_heading = next(
        (index for index, line in enumerate(lines[1:], start=1) if line.startswith("# ")),
        len(lines),
    )
    unreleased = lines[1:next_heading]
    while unreleased and not unreleased[0].strip():
        unreleased.pop(0)
    while unreleased and not unreleased[-1].strip():
        unreleased.pop()
    if not unreleased:
        raise ReleaseError("The Unreleased CHANGELOG section is empty")

    previous_releases = lines[next_heading:]
    result = ["# Unreleased", "", f"# {version} / {release_date}", "", *unreleased]
    if previous_releases:
        result.extend(["", *previous_releases])
    return "\n".join(result) + "\n"


def release_notes(text: str, version: str) -> str:
    lines = text.splitlines()
    start = release_header_index(lines, version) + 1
    end = next(
        (index for index, line in enumerate(lines[start:], start=start) if line.startswith("# ")),
        len(lines),
    )
    notes = lines[start:end]
    while notes and not notes[0].strip():
        notes.pop(0)
    while notes and not notes[-1].strip():
        notes.pop()
    if not notes:
        raise ReleaseError(f"CHANGELOG.md has no release notes for {version}")
    return "\n".join(notes) + "\n"


def paths(root: Path) -> tuple[Path, Path, Path]:
    return (
        root / "Sources/DatadogOpenFeatureProvider/Versioning.swift",
        root / "DatadogOpenFeatureProvider.podspec",
        root / "CHANGELOG.md",
    )


def prepare(root: Path, version: str, release_date: str) -> None:
    require_semver(version)
    sdk_path, podspec_path, changelog_path = paths(root)
    sdk = replace_version(sdk_path.read_text(), SDK_VERSION, version, sdk_path)
    podspec = replace_version(podspec_path.read_text(), PODSPEC_VERSION, version, podspec_path)
    changelog = prepare_changelog(changelog_path.read_text(), version, release_date)

    sdk_path.write_text(sdk)
    podspec_path.write_text(podspec)
    changelog_path.write_text(changelog)


def validate(root: Path, version: str) -> None:
    require_semver(version)
    sdk_path, podspec_path, changelog_path = paths(root)
    sdk_version = declared_version(sdk_path.read_text(), SDK_VERSION, sdk_path)
    podspec_version = declared_version(podspec_path.read_text(), PODSPEC_VERSION, podspec_path)
    if sdk_version != version:
        raise ReleaseError(f"{sdk_path} declares {sdk_version}, expected {version}")
    if podspec_version != version:
        raise ReleaseError(f"{podspec_path} declares {podspec_version}, expected {version}")
    release_header_index(changelog_path.read_text().splitlines(), version)


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description=__doc__)
    subparsers = result.add_subparsers(dest="command", required=True)

    prepare_parser = subparsers.add_parser("prepare", help="Update release version files and CHANGELOG")
    prepare_parser.add_argument("--version", required=True)
    prepare_parser.add_argument("--date", default=dt.date.today().isoformat())
    prepare_parser.add_argument("--root", type=Path, default=Path.cwd())

    validate_parser = subparsers.add_parser("validate", help="Validate release version files and CHANGELOG")
    validate_parser.add_argument("--version", required=True)
    validate_parser.add_argument("--root", type=Path, default=Path.cwd())

    notes_parser = subparsers.add_parser("notes", help="Extract one release's CHANGELOG notes")
    notes_parser.add_argument("--version", required=True)
    notes_parser.add_argument("--root", type=Path, default=Path.cwd())
    notes_parser.add_argument("--output", type=Path, required=True)
    return result


def main() -> int:
    arguments = parser().parse_args()
    root = arguments.root.resolve()
    try:
        if arguments.command == "prepare":
            prepare(root, arguments.version, arguments.date)
            validate(root, arguments.version)
            print(f"Prepared release {arguments.version} in {root}")
        elif arguments.command == "validate":
            validate(root, arguments.version)
            print(f"Release version {arguments.version} is consistent in {root}")
        else:
            require_semver(arguments.version)
            changelog_path = root / "CHANGELOG.md"
            arguments.output.write_text(release_notes(changelog_path.read_text(), arguments.version))
            print(f"Wrote release notes for {arguments.version} to {arguments.output}")
    except (OSError, ReleaseError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
