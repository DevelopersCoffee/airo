#!/usr/bin/env python3
"""Reject cross-package `package:<pkg>/src/...` imports/exports (#1681).

A package's `src/` is its own implementation detail; anything another
package needs is supposed to come through its public barrel
(`lib/<pkg>.dart`). Importing across the `src/` boundary means a caller can
break silently on an internal rename/move that owes it no compatibility.

This is a RATCHET gate, not a hard ban: `check-private-src-imports.baseline`
lists every violation that predates this gate (mostly app/features/coins ->
feature_coins_core/src — real architecture debt, not something this
milestone is scoped to fix wholesale). New violations outside that baseline
fail CI; baseline entries that get fixed should be deleted from the
baseline file in the same commit, not left stale.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BASELINE_FILE = ROOT / "scripts" / "check-private-src-imports.baseline"
SCAN_ROOTS = [
    ("packages", ROOT / "packages"),
    ("app", ROOT / "app"),
]
IMPORT_RE = re.compile(
    r"""^\s*(?:import|export)\s+['"]package:([a-zA-Z0-9_]+)/src/""",
    re.MULTILINE,
)
SKIP_DIR_SEGMENTS = {".dart_tool", "build", "cargokit"}


def owning_package(dart_file, packages_dir, app_dir):
    try:
        rel = dart_file.relative_to(packages_dir)
        return rel.parts[0]
    except ValueError:
        pass
    try:
        dart_file.relative_to(app_dir)
        return "app"
    except ValueError:
        return None


def scan():
    packages_dir = ROOT / "packages"
    app_dir = ROOT / "app"
    violations = set()
    for _label, base in SCAN_ROOTS:
        for dart_file in sorted(base.rglob("*.dart")):
            if any(part in SKIP_DIR_SEGMENTS for part in dart_file.parts):
                continue
            owner = owning_package(dart_file, packages_dir, app_dir)
            if owner is None:
                continue
            text = dart_file.read_text(encoding="utf-8", errors="ignore")
            for match in IMPORT_RE.finditer(text):
                imported_pkg = match.group(1)
                if imported_pkg == owner:
                    continue  # a package importing its own src/ is fine
                line = text.count("\n", 0, match.start()) + 1
                rel_path = dart_file.relative_to(ROOT)
                violations.add((str(rel_path), line, owner, imported_pkg))
    return violations


def load_baseline():
    if not BASELINE_FILE.exists():
        return set()
    entries = set()
    for raw in BASELINE_FILE.read_text(encoding="utf-8").splitlines():
        raw = raw.strip()
        if not raw or raw.startswith("#"):
            continue
        path, line, owner, imported = raw.split("\t")
        entries.add((path, int(line), owner, imported))
    return entries


def main():
    found = scan()
    baseline = load_baseline()

    new_violations = found - baseline
    stale_baseline = baseline - found

    failed = False
    for path, line, owner, imported in sorted(new_violations):
        failed = True
        print(
            f"::error file={path},line={line}::"
            f"{owner} imports package:{imported}/src/... — cross the public "
            f"barrel instead, or add this to "
            f"scripts/check-private-src-imports.baseline with a reason if "
            f"it's an intentional pre-existing exception."
        )

    if stale_baseline:
        print(
            f"note: {len(stale_baseline)} baseline entr{'y is' if len(stale_baseline) == 1 else 'ies are'} "
            "no longer violations — delete from "
            "scripts/check-private-src-imports.baseline to shrink the ratchet:"
        )
        for path, line, owner, imported in sorted(stale_baseline):
            print(f"  {path}:{line} ({owner} -> {imported})")

    if failed:
        return 1

    print(
        f"{len(found)} pre-existing private-src import(s) within baseline, "
        "0 new violations"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
