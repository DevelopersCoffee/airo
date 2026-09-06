#!/usr/bin/env bash
# =============================================================================
# AAB pre-upload size budget check (shift-left)
# =============================================================================
# Run this locally against a freshly built AAB *before* uploading anything to
# Play Console, so a size/shrink regression is caught on your machine instead
# of discovered afterward in the App Bundle Explorer.
#
# With `bundletool` available (https://github.com/google/bundletool releases,
# or `brew install bundletool`), this computes the real universal-device
# install size the same way Play Console's own "Download size" figure is
# derived: `bundletool build-apks --mode=universal` then
# `bundletool get-size total`. Without bundletool, it falls back to the raw
# .aab file size, which is a looser upper bound (an AAB isn't installed as-is,
# so this overstates true download size) but still catches a gross size
# regression when bundletool isn't installed.
#
# Budget mirrors the existing TV universal-APK gate in
# .github/workflows/aika-stream-release.yml (80 MB) so both artifacts are
# judged against the same store ceiling. Override with AIRO_AAB_SIZE_BUDGET_MB.
#
# Usage: ./scripts/check-aab-size-budget.sh <path-to-app-release.aab>
# Exit 0 when within budget, 1 when over budget or the AAB is missing.
# =============================================================================
set -euo pipefail

BUDGET_MB="${AIRO_AAB_SIZE_BUDGET_MB:-80}"
AAB_PATH="${1:-}"

fail() {
  echo "::error::$1" >&2
  exit 1
}

[[ -n "$AAB_PATH" ]] || fail "Usage: $0 <path-to-app-release.aab>"
[[ -f "$AAB_PATH" ]] || fail "AAB not found: $AAB_PATH"

file_size_bytes() {
  stat -c%s "$1" 2>/dev/null || stat -f%z "$1"
}

BUNDLETOOL_CMD=""
if [[ -n "${BUNDLETOOL_JAR:-}" ]]; then
  BUNDLETOOL_CMD="java -jar $BUNDLETOOL_JAR"
elif command -v bundletool >/dev/null 2>&1; then
  BUNDLETOOL_CMD="bundletool"
fi

if [[ -n "$BUNDLETOOL_CMD" ]]; then
  workdir="$(mktemp -d)"
  trap 'rm -rf "$workdir"' EXIT

  apks_path="$workdir/universal.apks"
  # --mode=universal skips signing config validation and produces one APK
  # covering every device config, matching what a real device install pulls
  # for the worst case (no per-ABI/density split).
  $BUNDLETOOL_CMD build-apks \
    --bundle="$AAB_PATH" \
    --output="$apks_path" \
    --mode=universal \
    --overwrite >/dev/null

  size_bytes="$($BUNDLETOOL_CMD get-size total --apks="$apks_path" | tail -1)"
  size_mb=$(( size_bytes / 1000000 ))
  echo "bundletool universal install size: ${size_mb} MB (source of truth, matches Play Console)"
else
  echo "bundletool not found (set BUNDLETOOL_JAR or install the 'bundletool' CLI for an exact figure)." >&2
  echo "Falling back to raw .aab file size -- this OVERSTATES real download size." >&2
  size_bytes="$(file_size_bytes "$AAB_PATH")"
  size_mb=$(( size_bytes / 1000000 ))
  echo "raw .aab file size: ${size_mb} MB (upper-bound estimate, not the real per-device download size)"
fi

echo "budget: ${BUDGET_MB} MB"

if [[ "$size_mb" -gt "$BUDGET_MB" ]]; then
  fail "$AAB_PATH is ${size_mb} MB, over the ${BUDGET_MB} MB store budget. Do not upload -- investigate what grew (check R8/shrink output, new native libs, new blanket -keep) before retrying."
fi

echo "AAB size budget check passed."
