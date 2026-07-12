#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

PROFILE_FILE="${AIRO_BUILD_PROFILE_FILE:-$ROOT_DIR/.github/airo-build-profiles.json}"

PUBSPECS_FILE="$TMP_DIR/pubspecs.txt"
python3 - "$PROFILE_FILE" >"$PUBSPECS_FILE" <<'PY'
import json
import sys
from pathlib import Path

data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
for pubspec in sorted({profile["pubspec"] for profile in data["profiles"]}):
    print(pubspec)
PY

rewrite_pubspec_paths() {
  local source_pubspec="$1"
  local target_pubspec="$2"
  python3 - "$ROOT_DIR" "$source_pubspec" "$target_pubspec" <<'PY'
import re
import sys
from pathlib import Path

root = Path(sys.argv[1]).resolve()
source = (root / sys.argv[2]).resolve()
target = Path(sys.argv[3]).resolve()
source_dir = source.parent

path_line = re.compile(r"^(\s*path:\s*)([^#\n]+)(.*)$")
output = []
for line in source.read_text(encoding="utf-8").splitlines():
    match = path_line.match(line)
    if match:
        raw_path = match.group(2).strip().strip("'\"")
        if raw_path.startswith("."):
            resolved = (source_dir / raw_path).resolve()
            line = f"{match.group(1)}{resolved}{match.group(3)}"
    output.append(line)

target.write_text("\n".join(output) + "\n", encoding="utf-8")
PY
}

while IFS= read -r pubspec; do
  [ -n "$pubspec" ] || continue
  profile_name="$(basename "$pubspec" .yaml)"
  work_dir="$TMP_DIR/$profile_name"
  mkdir -p "$work_dir"
  rewrite_pubspec_paths "$pubspec" "$work_dir/pubspec.yaml"
  echo "Resolving $pubspec"
  flutter pub get --directory "$work_dir"
done <"$PUBSPECS_FILE"

echo "variant pubspec dependency resolution passed"
