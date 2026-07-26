#!/usr/bin/env python3
"""Enforce the Edge Intelligence / Media Engine dependency boundary."""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path

INTELLIGENCE_PACKAGES = frozenset({"core_ai", "core_edge_intelligence"})
MEDIA_PACKAGES = frozenset(
    {"core_media_routing", "platform_player", "platform_streams"}
)
PACKAGE_IMPORT = re.compile(
    r"""^\s*(?:import|export|part)\s+['"]package:([^/'"]+)/""",
    re.MULTILINE,
)


@dataclass(frozen=True)
class Violation:
    path: Path
    source_package: str
    imported_package: str
    line: int

    def diagnostic(self, root: Path) -> str:
        path = self.path.relative_to(root)
        return (
            f"::error file={path},line={self.line}::"
            f"{self.source_package} must not import {self.imported_package}; "
            "use an application-owned IntentExecutor adapter"
        )


def scan(root: Path) -> list[Violation]:
    packages_dir = root / "packages"
    violations: list[Violation] = []
    for source_group, forbidden_group in (
        (INTELLIGENCE_PACKAGES, MEDIA_PACKAGES),
        (MEDIA_PACKAGES, INTELLIGENCE_PACKAGES),
    ):
        for package_name in sorted(source_group):
            package_dir = packages_dir / package_name
            if not package_dir.is_dir():
                continue
            for path in sorted(package_dir.rglob("*.dart")):
                if any(
                    segment in {".dart_tool", "build"}
                    for segment in path.parts
                ):
                    continue
                text = path.read_text(encoding="utf-8")
                for match in PACKAGE_IMPORT.finditer(text):
                    imported_package = match.group(1)
                    if imported_package not in forbidden_group:
                        continue
                    violations.append(
                        Violation(
                            path=path,
                            source_package=package_name,
                            imported_package=imported_package,
                            line=text.count("\n", 0, match.start()) + 1,
                        )
                    )
    return violations


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--root",
        type=Path,
        default=Path(__file__).resolve().parents[1],
        help="repository root containing packages/",
    )
    args = parser.parse_args()
    root = args.root.resolve()
    violations = scan(root)
    if violations:
        for violation in violations:
            print(violation.diagnostic(root))
        print(f"edge import boundary failed: {len(violations)} violation(s)")
        return 1
    print("edge import boundary valid")
    return 0


if __name__ == "__main__":
    sys.exit(main())
