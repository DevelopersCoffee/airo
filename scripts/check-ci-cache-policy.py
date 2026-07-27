#!/usr/bin/env python3
"""Reject generated Dart project metadata in GitHub Actions caches."""

from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[1]
WORKFLOWS = ROOT / ".github" / "workflows"
FORBIDDEN = (".dart_tool",)


def main() -> int:
    violations: list[str] = []
    for workflow in sorted(WORKFLOWS.glob("*.yml")):
        for line_number, line in enumerate(
            workflow.read_text(encoding="utf-8").splitlines(), start=1
        ):
            if any(entry in line for entry in FORBIDDEN):
                violations.append(
                    f"{workflow.relative_to(ROOT)}:{line_number}: "
                    "cache only immutable package downloads; regenerate .dart_tool"
                )

    if violations:
        print("\n".join(violations), file=sys.stderr)
        return 1

    print("CI cache policy valid: no generated .dart_tool metadata is cached")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
