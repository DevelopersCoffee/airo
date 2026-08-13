#!/usr/bin/env python3
"""Report Riverpod providers whose name occurs exactly once repo-wide (#1681).

Best-effort and heuristic, deliberately NOT a CI gate: a name occurring once
means "declared, never referenced by that identifier" — it can't tell
liveness from a provider consumed only via `ref.watch(provider)` in a file
this scan can't attribute, or a legitimately-unused-yet provider mid-build.
Report-only; feeds future #1669-style dead-provider pruning passes, the way
that issue's own audit started.

Usage: python3 scripts/report-dead-providers.py [--json]
"""
import argparse
import re
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCAN_DIRS = [ROOT / "app", ROOT / "packages"]
SKIP_DIR_SEGMENTS = {".dart_tool", "build", "cargokit"}

DECL_RE = re.compile(
    r"""^(?:final|late\s+final)\s+(\w+Provider)\b""",
    re.MULTILINE,
)
IDENT_RE_TEMPLATE = r"\b{name}\b"


def dart_files():
    for base in SCAN_DIRS:
        for path in sorted(base.rglob("*.dart")):
            if any(part in SKIP_DIR_SEGMENTS for part in path.parts):
                continue
            if path.name.endswith((".g.dart", ".freezed.dart")):
                continue
            yield path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    declarations = {}  # name -> (path, line)
    file_texts = {}
    for path in dart_files():
        text = path.read_text(encoding="utf-8", errors="ignore")
        file_texts[path] = text
        for match in DECL_RE.finditer(text):
            name = match.group(1)
            if name in declarations:
                continue  # first declaration wins; duplicates are rare and not this script's concern
            line = text.count("\n", 0, match.start()) + 1
            declarations[name] = (path.relative_to(ROOT), line)

    counts = defaultdict(int)
    for text in file_texts.values():
        for name in declarations:
            counts[name] += len(re.findall(IDENT_RE_TEMPLATE.format(name=re.escape(name)), text))

    dead = sorted(
        (name, path, line)
        for name, (path, line) in declarations.items()
        if counts[name] <= 1
    )

    if args.json:
        import json

        print(
            json.dumps(
                [{"name": n, "file": str(p), "line": l} for n, p, l in dead],
                indent=2,
            )
        )
    else:
        print(f"{len(declarations)} provider(s) scanned, {len(dead)} referenced exactly once:\n")
        for name, path, line in dead:
            print(f"  {path}:{line}  {name}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
