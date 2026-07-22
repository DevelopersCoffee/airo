#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

AIRO_BUILD_PROFILE_REPORT_FILE="$TMP_DIR/airo-build-profile-report.md" \
  "$ROOT_DIR/scripts/check-build-profiles.py" >"$TMP_DIR/airo-build-profile-test.out"

grep -q "Airo Build Profile Contract" "$TMP_DIR/airo-build-profile-test.out"
grep -q "\`full\`" "$TMP_DIR/airo-build-profile-test.out"
grep -q "\`ios-spm\`" "$TMP_DIR/airo-build-profile-test.out"
grep -q "\`tv\`" "$TMP_DIR/airo-build-profile-test.out"
grep -q "5 KGP-risk deps guarded" "$TMP_DIR/airo-build-profile-test.out"

python3 - "$ROOT_DIR/.github/airo-build-profiles.json" "$TMP_DIR/kgp-regression.json" <<'PY'
import json
import sys
from pathlib import Path

source = Path(sys.argv[1])
target = Path(sys.argv[2])
data = json.loads(source.read_text(encoding="utf-8"))
profiles = [profile for profile in data["profiles"] if profile["id"] == "tv"]
profiles[0]["requiredDependencyOverrides"].pop("wakelock_plus", None)
data["profiles"] = profiles
target.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
PY

if AIRO_BUILD_PROFILE_FILE="$TMP_DIR/kgp-regression.json" \
  AIRO_BUILD_PROFILE_REPORT_FILE="$TMP_DIR/kgp-regression-report.md" \
  "$ROOT_DIR/scripts/check-build-profiles.py" >"$TMP_DIR/kgp-regression.out" 2>&1; then
  echo "expected missing KGP-risk override to fail" >&2
  exit 1
fi

grep -q "KGP-risk package wakelock_plus must be listed in requiredDependencyOverrides" \
  "$TMP_DIR/kgp-regression.out"

echo "check-build-profiles tests passed"
