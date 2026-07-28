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
grep -q "\`coins\`" "$TMP_DIR/airo-build-profile-test.out"
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

python3 - "$ROOT_DIR/.github/airo-build-profiles.json" "$TMP_DIR/ship-policy-regression.json" <<'PY'
import json
import sys
from pathlib import Path

source = Path(sys.argv[1])
target = Path(sys.argv[2])
data = json.loads(source.read_text(encoding="utf-8"))
profiles = [profile for profile in data["profiles"] if profile["id"] == "tv"]
profiles[0]["featureModules"].append("feature_coin")
data["profiles"] = profiles
target.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
PY

if AIRO_BUILD_PROFILE_FILE="$TMP_DIR/ship-policy-regression.json" \
  AIRO_BUILD_PROFILE_REPORT_FILE="$TMP_DIR/ship-policy-regression-report.md" \
  "$ROOT_DIR/scripts/check-build-profiles.py" >"$TMP_DIR/ship-policy-regression.out" 2>&1; then
  echo "expected Never Ship module assignment to fail" >&2
  exit 1
fi

grep -q "feature module feature_coin is marked Never Ship for device class tv" \
  "$TMP_DIR/ship-policy-regression.out"

python3 - \
  "$ROOT_DIR/.github/airo-build-profiles.json" \
  "$ROOT_DIR/app/pubspec_tv.yaml" \
  "$TMP_DIR/excluded-package-regression.json" \
  "$TMP_DIR/pubspec_tv_with_meeting.yaml" <<'PY'
import json
import sys
from pathlib import Path

profile_source = Path(sys.argv[1])
pubspec_source = Path(sys.argv[2])
profile_target = Path(sys.argv[3])
pubspec_target = Path(sys.argv[4])

data = json.loads(profile_source.read_text(encoding="utf-8"))
profiles = [profile for profile in data["profiles"] if profile["id"] == "tv"]
profiles[0]["excludedPackages"] = ["feature_meeting_intelligence"]
profiles[0]["pubspec"] = str(pubspec_target)
data["profiles"] = profiles
profile_target.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")

pubspec = pubspec_source.read_text(encoding="utf-8")
pubspec = pubspec.replace(
    "\ndev_dependencies:",
    "\n  feature_meeting_intelligence:\n"
    "    path: ../packages/feature_meeting_intelligence\n\n"
    "dev_dependencies:",
    1,
)
pubspec_target.write_text(pubspec, encoding="utf-8")
PY

if AIRO_BUILD_PROFILE_FILE="$TMP_DIR/excluded-package-regression.json" \
  AIRO_BUILD_PROFILE_REPORT_FILE="$TMP_DIR/excluded-package-regression-report.md" \
  "$ROOT_DIR/scripts/check-build-profiles.py" \
  >"$TMP_DIR/excluded-package-regression.out" 2>&1; then
  echo "expected excluded profile package to fail" >&2
  exit 1
fi

grep -q "tv: excluded package feature_meeting_intelligence is present" \
  "$TMP_DIR/excluded-package-regression.out"

echo "check-build-profiles tests passed"
