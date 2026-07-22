#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/check-apk-size.sh"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

make_file() {
  local path="$1"
  local bytes="$2"
  dd if=/dev/zero of="$path" bs=1 count="$bytes" status=none
}

run_case() {
  local name="$1"
  local expected_status="$2"
  shift 2

  set +e
  "$@" >"$TMP_DIR/$name.out" 2>&1
  local actual_status=$?
  set -e

  if [ "$expected_status" -ne "$actual_status" ]; then
    echo "FAIL: $name expected exit $expected_status, got $actual_status"
    cat "$TMP_DIR/$name.out"
    exit 1
  fi
}

baseline_file="$TMP_DIR/baselines.tsv"
cat >"$baseline_file" <<'EOF'
component	artifact	baseline_bytes	budget_mb
demo	ok.apk	1000	1
demo	growth.apk	1000	1
demo	over-cap.apk	1000	1
EOF

ok_apk="$TMP_DIR/ok.apk"
growth_apk="$TMP_DIR/growth.apk"
over_cap_apk="$TMP_DIR/over-cap.apk"
missing_apk="$TMP_DIR/missing.apk"
make_file "$ok_apk" 1040
make_file "$growth_apk" 1060
make_file "$over_cap_apk" 1200
make_file "$missing_apk" 1000

run_case "passes-under-baseline-growth" 0 \
  env APK_SIZE_APK_GLOB="$ok_apk" \
    APK_SIZE_COMPONENT=demo \
    APK_SIZE_BASELINE_FILE="$baseline_file" \
    APK_SIZE_REPORT_FILE="$TMP_DIR/ok-report.md" \
    APK_SIZE_MAX_BYTES=2000 \
    APK_SIZE_MAX_INCREASE_PERCENT=5 \
    "$SCRIPT"

real_baseline_apk="$TMP_DIR/app-arm64-v8a-release.apk"
make_file "$real_baseline_apk" 1024
run_case "parses-committed-baseline" 0 \
  env APK_SIZE_APK_GLOB="$real_baseline_apk" \
    APK_SIZE_COMPONENT=full \
    APK_SIZE_BASELINE_FILE="$ROOT_DIR/.github/apk-size-baselines.tsv" \
    APK_SIZE_REPORT_FILE="$TMP_DIR/real-baseline-report.md" \
    APK_SIZE_MAX_BYTES=2000 \
    APK_SIZE_MAX_INCREASE_PERCENT=5 \
    "$SCRIPT"

run_case "fails-over-absolute-cap" 1 \
  env APK_SIZE_APK_GLOB="$over_cap_apk" \
    APK_SIZE_COMPONENT=demo \
    APK_SIZE_BASELINE_FILE="$baseline_file" \
    APK_SIZE_REPORT_FILE="$TMP_DIR/over-cap-report.md" \
    APK_SIZE_MAX_BYTES=1100 \
    APK_SIZE_MAX_INCREASE_PERCENT=5 \
    "$SCRIPT"
grep -q "exceeds max APK size" "$TMP_DIR/fails-over-absolute-cap.out"

run_case "fails-over-baseline-growth" 1 \
  env APK_SIZE_APK_GLOB="$growth_apk" \
    APK_SIZE_COMPONENT=demo \
    APK_SIZE_BASELINE_FILE="$baseline_file" \
    APK_SIZE_REPORT_FILE="$TMP_DIR/growth-report.md" \
    APK_SIZE_MAX_BYTES=2000 \
    APK_SIZE_MAX_INCREASE_PERCENT=5 \
    "$SCRIPT"
grep -q "exceeds 5% baseline increase" "$TMP_DIR/fails-over-baseline-growth.out"

run_case "fails-missing-baseline" 1 \
  env APK_SIZE_APK_GLOB="$missing_apk" \
    APK_SIZE_COMPONENT=demo \
    APK_SIZE_BASELINE_FILE="$baseline_file" \
    APK_SIZE_REPORT_FILE="$TMP_DIR/missing-report.md" \
    APK_SIZE_MAX_BYTES=2000 \
    APK_SIZE_MAX_INCREASE_PERCENT=5 \
    "$SCRIPT"
grep -q "No APK size baseline" "$TMP_DIR/fails-missing-baseline.out"

if command -v zip >/dev/null 2>&1; then
  zip_root="$TMP_DIR/zip-root"
  mkdir -p "$zip_root/lib/arm64-v8a" "$zip_root/assets"
  make_file "$zip_root/lib/arm64-v8a/liblitertlm_jni.so" 2048
  make_file "$zip_root/assets/flutter_assets.bin" 1024
  zip_apk="$TMP_DIR/zipped.apk"
  (cd "$zip_root" && zip -qr "$zip_apk" .)

  zip_size="$(wc -c < "$zip_apk" | tr -d ' ')"
  cat >>"$baseline_file" <<EOF
demo	zipped.apk	$zip_size	1
EOF

  run_case "reports-largest-apk-entries" 0 \
    env APK_SIZE_APK_GLOB="$zip_apk" \
      APK_SIZE_COMPONENT=demo \
      APK_SIZE_BASELINE_FILE="$baseline_file" \
      APK_SIZE_REPORT_FILE="$TMP_DIR/zip-report.md" \
      APK_SIZE_MAX_BYTES=200000 \
      APK_SIZE_MAX_INCREASE_PERCENT=5 \
      APK_SIZE_TOP_ENTRIES=2 \
      "$SCRIPT"
  grep -q "Largest APK entries" "$TMP_DIR/zip-report.md"
  grep -q "liblitertlm_jni.so" "$TMP_DIR/zip-report.md"
fi

echo "check-apk-size tests passed"
