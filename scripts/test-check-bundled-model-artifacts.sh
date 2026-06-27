#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/check-bundled-model-artifacts.sh"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

make_file() {
  local path="$1"
  local bytes="$2"
  mkdir -p "$(dirname "$path")"
  dd if=/dev/zero of="$path" bs=1 count="$bytes" status=none
}

run_case() {
  local name="$1"
  local expected_status="$2"
  shift 2

  set +e
  "$@" > "$TMP_DIR/$name.out" 2>&1
  local actual_status=$?
  set -e

  if [ "$expected_status" -ne "$actual_status" ]; then
    echo "FAIL: $name expected exit $expected_status, got $actual_status"
    cat "$TMP_DIR/$name.out"
    exit 1
  fi
}

clean_app="$TMP_DIR/clean/app"
mkdir -p "$clean_app/lib"
run_case "passes-without-model-artifacts" 0 \
  env AIRO_MODEL_ARTIFACT_SCAN_PATHS="$clean_app" \
    AIRO_MODEL_ARTIFACT_REPORT_FILE="$TMP_DIR/clean-report.md" \
    "$SCRIPT"
grep -q "No bundled model artifacts" "$TMP_DIR/passes-without-model-artifacts.out"

small_model="$TMP_DIR/small/app/assets/classifier.tflite"
make_file "$small_model" 1024
run_case "warns-for-small-pinned-model" 0 \
  env AIRO_MODEL_ARTIFACT_SCAN_PATHS="$TMP_DIR/small/app" \
    AIRO_MAX_BUNDLED_MODEL_BYTES=2048 \
    AIRO_MODEL_ARTIFACT_REPORT_FILE="$TMP_DIR/small-report.md" \
    "$SCRIPT"
grep -q "below small pinned-model cap" "$TMP_DIR/warns-for-small-pinned-model.out"

large_model="$TMP_DIR/large/app/assets/offline.gguf"
make_file "$large_model" 4096
run_case "fails-for-large-bundled-model" 1 \
  env AIRO_MODEL_ARTIFACT_SCAN_PATHS="$TMP_DIR/large/app" \
    AIRO_MAX_BUNDLED_MODEL_BYTES=2048 \
    AIRO_MODEL_ARTIFACT_REPORT_FILE="$TMP_DIR/large-report.md" \
    "$SCRIPT"
grep -q "models larger than" "$TMP_DIR/fails-for-large-bundled-model.out"

run_case "passes-allowlisted-large-model" 0 \
  env AIRO_MODEL_ARTIFACT_SCAN_PATHS="$TMP_DIR/large/app" \
    AIRO_MAX_BUNDLED_MODEL_BYTES=2048 \
    AIRO_MODEL_ARTIFACT_ALLOWLIST="$large_model" \
    AIRO_MODEL_ARTIFACT_REPORT_FILE="$TMP_DIR/allowlist-report.md" \
    "$SCRIPT"
grep -q "allowlisted" "$TMP_DIR/passes-allowlisted-large-model.out"

echo "check-bundled-model-artifacts tests passed"
