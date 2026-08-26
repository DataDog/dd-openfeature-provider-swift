# Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
#
# This product includes software developed at Datadog (https://www.datadoghq.com/).
# Copyright 2026 Datadog, Inc.

import sys
import tempfile
import unittest
from pathlib import Path


sys.path.insert(0, str(Path(__file__).parents[1]))

import release_version  # noqa: E402


class ReleaseVersionTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary_directory.name)
        (self.root / "Sources/DatadogOpenFeatureProvider").mkdir(parents=True)
        (self.root / "Sources/DatadogOpenFeatureProvider/Versioning.swift").write_text(
            '// GENERATED FILE: Do not edit directly\n\ninternal let __sdkVersion = "0.2.0"\n'
        )
        (self.root / "DatadogOpenFeatureProvider.podspec").write_text(
            'Pod::Spec.new do |s|\n  s.version = "0.2.0"\nend\n'
        )
        (self.root / "CHANGELOG.md").write_text(
            "# Unreleased\n\n- [FIXED] Restore watchOS support.\n\n# 0.2.0 / 2026-07-02\n\n- Previous.\n"
        )

    def tearDown(self) -> None:
        self.temporary_directory.cleanup()

    def test_prepare_validate_and_extract_notes(self) -> None:
        release_version.prepare(self.root, "0.2.1", "2026-08-26")
        release_version.validate(self.root, "0.2.1")

        self.assertIn(
            'internal let __sdkVersion = "0.2.1"',
            (self.root / "Sources/DatadogOpenFeatureProvider/Versioning.swift").read_text(),
        )
        self.assertIn(
            's.version = "0.2.1"',
            (self.root / "DatadogOpenFeatureProvider.podspec").read_text(),
        )
        changelog = (self.root / "CHANGELOG.md").read_text()
        self.assertTrue(changelog.startswith("# Unreleased\n\n# 0.2.1 / 2026-08-26\n"))
        self.assertEqual(
            release_version.release_notes(changelog, "0.2.1"),
            "- [FIXED] Restore watchOS support.\n",
        )

    def test_prepare_rejects_invalid_version_without_writing(self) -> None:
        before = (self.root / "CHANGELOG.md").read_text()

        with self.assertRaises(release_version.ReleaseError):
            release_version.prepare(self.root, "v0.2.1", "2026-08-26")

        self.assertEqual((self.root / "CHANGELOG.md").read_text(), before)

    def test_prepare_rejects_empty_unreleased_section(self) -> None:
        (self.root / "CHANGELOG.md").write_text("# Unreleased\n\n# 0.2.0 / 2026-07-02\n")

        with self.assertRaisesRegex(release_version.ReleaseError, "Unreleased CHANGELOG section is empty"):
            release_version.prepare(self.root, "0.2.1", "2026-08-26")

    def test_prepare_rejects_duplicate_release(self) -> None:
        (self.root / "CHANGELOG.md").write_text(
            "# Unreleased\n\n- New.\n\n# 0.2.1 / 2026-08-25\n\n- Existing.\n"
        )

        with self.assertRaisesRegex(release_version.ReleaseError, "already contains"):
            release_version.prepare(self.root, "0.2.1", "2026-08-26")

    def test_validate_rejects_mismatched_version(self) -> None:
        with self.assertRaisesRegex(release_version.ReleaseError, "declares 0.2.0, expected 0.2.1"):
            release_version.validate(self.root, "0.2.1")


if __name__ == "__main__":
    unittest.main()
