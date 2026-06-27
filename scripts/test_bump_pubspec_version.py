from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from bump_pubspec_version import (
    bump_version,
    parse_version,
    update_pubspec,
    validate_pubspec_path,
)


class ParseVersionTest(unittest.TestCase):
    def test_parse_version_extracts_core_and_build(self) -> None:
        self.assertEqual(parse_version("1.2.3+4"), (1, 2, 3, 4))

    def test_parse_version_rejects_unsupported_format(self) -> None:
        with self.assertRaises(ValueError):
            parse_version("1.2.3")


class BumpVersionTest(unittest.TestCase):
    def test_patch_bump_increments_patch_and_build(self) -> None:
        self.assertEqual(bump_version("1.2.3+4", "patch"), "1.2.4+5")

    def test_minor_bump_resets_patch_and_increments_build(self) -> None:
        self.assertEqual(bump_version("1.2.3+4", "minor"), "1.3.0+5")

    def test_major_bump_resets_minor_and_patch_and_increments_build(self) -> None:
        self.assertEqual(bump_version("1.2.3+4", "major"), "2.0.0+5")


class UpdatePubspecTest(unittest.TestCase):
    def test_update_pubspec_rewrites_version_line(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            pubspec = Path(tmpdir) / "pubspec.yaml"
            pubspec.write_text("name: demo\nversion: 1.0.0+1\ndescription: sample\n")

            new_version = update_pubspec(pubspec, "patch", Path(tmpdir))

            self.assertEqual(new_version, "1.0.1+2")
            self.assertIn("version: 1.0.1+2", pubspec.read_text())


class ValidatePubspecPathTest(unittest.TestCase):
    def test_validate_pubspec_path_allows_pubspec_inside_repo(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            app_dir = root / "app"
            app_dir.mkdir()
            pubspec = app_dir / "pubspec.yaml"
            pubspec.write_text("name: demo\nversion: 1.0.0+1\n")

            self.assertEqual(validate_pubspec_path(pubspec, root), pubspec.resolve())

    def test_validate_pubspec_path_rejects_non_pubspec_file(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            other = root / "version.txt"
            other.write_text("1.0.0+1\n")

            with self.assertRaises(ValueError):
                validate_pubspec_path(other, root)

    def test_validate_pubspec_path_rejects_file_outside_repo(self) -> None:
        with tempfile.TemporaryDirectory() as root_dir:
            with tempfile.TemporaryDirectory() as outside_dir:
                outside = Path(outside_dir) / "pubspec.yaml"
                outside.write_text("name: outside\nversion: 1.0.0+1\n")

                with self.assertRaises(ValueError):
                    validate_pubspec_path(outside, Path(root_dir))


if __name__ == "__main__":
    unittest.main()
