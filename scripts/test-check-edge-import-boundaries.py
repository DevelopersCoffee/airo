#!/usr/bin/env python3
"""Deterministic positive and negative tests for the edge import gate."""

from __future__ import annotations

import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).with_name("check-edge-import-boundaries.py")
SPEC = importlib.util.spec_from_file_location("edge_boundary", SCRIPT)
assert SPEC is not None and SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = MODULE
SPEC.loader.exec_module(MODULE)


class EdgeImportBoundaryTest(unittest.TestCase):
    def test_repository_passes(self) -> None:
        self.assertEqual(MODULE.scan(SCRIPT.parents[1]), [])

    def test_intelligence_cannot_import_media(self) -> None:
        with fixture_repo() as root:
            write_dart(
                root,
                "core_ai",
                "import 'package:platform_player/platform_player.dart';",
            )
            violations = MODULE.scan(root)

            self.assertEqual(len(violations), 1)
            self.assertEqual(violations[0].source_package, "core_ai")
            self.assertEqual(violations[0].imported_package, "platform_player")

    def test_media_cannot_import_intelligence(self) -> None:
        with fixture_repo() as root:
            write_dart(
                root,
                "platform_streams",
                "export 'package:core_edge_intelligence/core_edge_intelligence.dart';",
            )
            violations = MODULE.scan(root)

            self.assertEqual(len(violations), 1)
            self.assertEqual(
                violations[0].source_package,
                "platform_streams",
            )
            self.assertEqual(
                violations[0].imported_package,
                "core_edge_intelligence",
            )

    def test_unrelated_imports_pass(self) -> None:
        with fixture_repo() as root:
            write_dart(
                root,
                "core_ai",
                "import 'package:core_domain/core_domain.dart';",
            )
            write_dart(
                root,
                "platform_player",
                "import 'package:platform_media/platform_media.dart';",
            )

            self.assertEqual(MODULE.scan(root), [])


def fixture_repo():
    temporary = tempfile.TemporaryDirectory()

    class Fixture:
        def __enter__(self) -> Path:
            self.root = Path(temporary.name)
            (self.root / "packages").mkdir()
            return self.root

        def __exit__(self, *args: object) -> None:
            temporary.cleanup()

    return Fixture()


def write_dart(root: Path, package: str, source: str) -> None:
    path = root / "packages" / package / "lib" / "source.dart"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(f"{source}\n", encoding="utf-8")


if __name__ == "__main__":
    unittest.main()
