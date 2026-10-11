# Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
# This product includes software developed at Datadog (https://www.datadoghq.com/).
# Copyright 2026-Present Datadog, Inc.

import importlib
import io
import json
import sys
import tempfile
import unittest
from contextlib import redirect_stderr
from pathlib import Path
from unittest.mock import patch


sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
latest = importlib.import_module("test-latest-sdk-compatibility")
compatibility = latest.compatibility


def version_range(lower: str, upper: str) -> dict:
    return {"range": [{"lowerBound": lower, "upperBound": upper}]}


class LatestVersionTests(unittest.TestCase):
    tags = "\n".join(
        f"abcdef refs/tags/{version}"
        for version in ["3.9.0", "3.13.0", "3.16.0", "3.17.0", "3.18.0-beta.1", "4.0.0", "develop"]
    )

    def test_original_range_selects_platform_breaking_sdk(self):
        self.assertEqual(
            latest.latest_allowed_version(self.tags, version_range("3.13.0", "4.0.0")), "3.17.0"
        )

    def test_maintenance_range_excludes_platform_breaking_sdk(self):
        self.assertEqual(
            latest.latest_allowed_version(self.tags, version_range("3.13.0", "3.17.0")), "3.16.0"
        )

    def test_raised_minimum_accepts_new_sdk(self):
        self.assertEqual(
            latest.latest_allowed_version(self.tags, version_range("3.17.0", "4.0.0")), "3.17.0"
        )

    def test_exact_version_and_numeric_ordering(self):
        self.assertEqual(latest.latest_allowed_version(self.tags, {"exact": ["3.13.0"]}), "3.13.0")
        self.assertEqual(latest.latest_allowed_version(self.tags, {"exact": "3.13.0"}), "3.13.0")
        self.assertEqual(
            latest.latest_allowed_version(self.tags, version_range("3.0.0", "3.17.0")), "3.16.0"
        )

    def test_no_candidate_and_unversioned_requirements_fail(self):
        for requirement in (version_range("5.0.0", "6.0.0"), {"branch": "develop"}):
            with self.subTest(requirement=requirement), self.assertRaises(ValueError):
                latest.latest_allowed_version(self.tags, requirement)

    def test_resolved_version_cannot_silently_fall_back(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            resolved = {"pins": [{
                "identity": "dd-sdk-ios", "state": {"version": "3.16.0", "revision": "abc"}
            }]}
            (root / "Package.resolved").write_text(json.dumps(resolved))
            with self.assertRaisesRegex(ValueError, "refusing an older-SDK fallback"):
                latest.assert_sdk_version(root, "3.17.0")
            latest.assert_sdk_version(root, "3.16.0")
            (root / "Package.resolved").write_text('{"pins": []}')
            with self.assertRaises(ValueError):
                latest.assert_sdk_version(root, "3.17.0")


class IsolationTests(unittest.TestCase):
    def test_fresh_workspace_is_resolved_before_sdk_override(self):
        provider = Path("provider")
        with patch.object(latest, "run") as run, patch.object(latest, "assert_sdk_version") as verify:
            latest.resolve_sdk(provider, "3.17.0")
            self.assertEqual(run.call_args_list, [
                unittest.mock.call(["swift", "package", "resolve"], provider),
                unittest.mock.call(["swift", "package", "resolve", "dd-sdk-ios", "--version", "3.17.0"], provider),
            ])
            verify.assert_called_once_with(provider, "3.17.0")

    def test_copy_uses_current_package_files_without_mutating_original(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "source"
            source.mkdir()
            for name in ("Package.swift", "Package.resolved"):
                (source / name).write_text("original")
            for name in ("Sources", "Tests", "xcconfigs", ".build", ".git"):
                (source / name).mkdir()
            destination = Path(directory) / "provider"
            latest.copy_provider(source, destination)
            (destination / "Package.resolved").write_text("updated")
            self.assertEqual((source / "Package.resolved").read_text(), "original")
            self.assertFalse((destination / ".build").exists())
            self.assertFalse((destination / ".git").exists())

    def test_consumer_uses_provider_minimums_and_exact_sdk(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "consumer"
            platforms = {"ios": "14.0", "macos": "12.6", "tvos": "14.0", "watchos": "8.0"}
            latest.create_consumer(root, platforms, "3.17.0")
            manifest = (root / "Package.swift").read_text()
            for declaration in ('.iOS("14.0")', '.macOS("12.6")', '.tvOS("14.0")', '.watchOS("8.0")'):
                self.assertIn(declaration, manifest)
            self.assertIn('exact: "3.17.0"', manifest)
            self.assertIn('.package(path: "../provider")', manifest)


class PlatformRegressionTests(unittest.TestCase):
    def test_new_sdk_floor_is_rejected_until_provider_minimum_is_raised(self):
        cases = (("14.0", "12.0", False), ("14.0", "15.0", True), ("15.0", "15.0", False))
        for provider_ios, sdk_ios, expected_failure in cases:
            with self.subTest(provider_ios=provider_ios, sdk_ios=sdk_ios):
                self.validate_platforms(provider_ios, sdk_ios, expected_failure)

    def validate_platforms(self, provider_ios, sdk_ios, expected_failure):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "xcconfigs").mkdir()
            platforms = {"ios": provider_ios, "macos": "12.6", "tvos": "15.0", "watchos": "9.0"}
            (root / "xcconfigs" / "Base.xcconfig").write_text("\n".join(
                f"{key}={platforms[name]}" for name, key in compatibility.PLATFORM_XCCONFIG_KEYS.items()
            ))
            pins = [
                {"identity": name, "state": {"version": version, "revision": "abc"}}
                for name, version in (("dd-sdk-ios", "3.17.0"), ("swift-sdk", "0.3.1"))
            ]
            (root / "Package.resolved").write_text(json.dumps({"pins": pins}))
            for name in compatibility.DIRECT_DEPENDENCIES:
                (root / ".build" / "checkouts" / name).mkdir(parents=True)

            def package(path):
                values = dict(platforms)
                if path.name == "dd-sdk-ios":
                    values["ios"] = sdk_ios
                return {
                    "platforms": [{"platformName": name, "version": version} for name, version in values.items()],
                    "dependencies": [{"identity": "swift-sdk", "requirement": version_range("0.3.1", "0.4.0")}],
                }

            with patch.object(compatibility, "dump_package", side_effect=package), patch.object(
                compatibility, "run", return_value="abc"
            ):
                if expected_failure:
                    diagnostic = io.StringIO()
                    with redirect_stderr(diagnostic), self.assertRaises(SystemExit) as error:
                        compatibility.main(root)
                    self.assertEqual(error.exception.code, 1)
                    self.assertIn("dd-sdk-ios requires ios 15.0, above the provider's 14.0 floor", diagnostic.getvalue())
                else:
                    compatibility.main(root)


if __name__ == "__main__":
    unittest.main()
