#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

AIRO_BUILD_PROFILE_REPORT_FILE=/tmp/airo-build-profile-report.md \
  "$ROOT_DIR/scripts/check-build-profiles.py" >/tmp/airo-build-profile-test.out

grep -q "Airo Build Profile Contract" /tmp/airo-build-profile-test.out
grep -q "\`iptv-standalone\`" /tmp/airo-build-profile-test.out
grep -q "\`tv\`" /tmp/airo-build-profile-test.out

echo "check-build-profiles tests passed"
