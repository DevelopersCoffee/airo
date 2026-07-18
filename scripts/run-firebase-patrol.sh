#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${AIRO_RELEASE_QUALIFICATION_DIR:-$ROOT_DIR/artifacts/release-qualification/firebase-$(date -u +%Y%m%dT%H%M%SZ)}"
APP_APK="${AIRO_FIREBASE_APP_APK:-}"
TEST_APK="${AIRO_FIREBASE_TEST_APK:-}"
RESULTS_BUCKET="${AIRO_FIREBASE_RESULTS_BUCKET:-}"
DEVICE_MODEL="${AIRO_FIREBASE_DEVICE_MODEL:-oriole}"
DEVICE_VERSION="${AIRO_FIREBASE_DEVICE_VERSION:-35}"
DEVICE_LOCALE="${AIRO_FIREBASE_DEVICE_LOCALE:-en}"
DEVICE_ORIENTATION="${AIRO_FIREBASE_DEVICE_ORIENTATION:-portrait}"

usage() {
  cat <<EOF
Usage: $0 --app APK --test-suite APK [--output-dir DIR]

Runs Android Patrol instrumentation artifacts on Firebase Test Lab.

Required tools:
  gcloud

Optional environment:
  AIRO_FIREBASE_RESULTS_BUCKET
  AIRO_FIREBASE_DEVICE_MODEL
  AIRO_FIREBASE_DEVICE_VERSION
  AIRO_FIREBASE_DEVICE_LOCALE
  AIRO_FIREBASE_DEVICE_ORIENTATION
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app)
      APP_APK="$2"
      shift 2
      ;;
    --test-suite)
      TEST_APK="$2"
      shift 2
      ;;
    --output-dir)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

mkdir -p "$OUTPUT_DIR"
[[ -s "$APP_APK" ]] || { echo "::error::App APK not found: $APP_APK"; exit 1; }
[[ -s "$TEST_APK" ]] || { echo "::error::Test APK not found: $TEST_APK"; exit 1; }
command -v gcloud >/dev/null 2>&1 || { echo "::error::gcloud is required for Firebase Test Lab."; exit 1; }

args=(
  firebase test android run
  --type instrumentation
  --app "$APP_APK"
  --test "$TEST_APK"
  --device "model=${DEVICE_MODEL},version=${DEVICE_VERSION},locale=${DEVICE_LOCALE},orientation=${DEVICE_ORIENTATION}"
  --timeout 30m
)

if [[ -n "$RESULTS_BUCKET" ]]; then
  args+=(--results-bucket "$RESULTS_BUCKET")
fi

gcloud "${args[@]}" | tee "$OUTPUT_DIR/firebase-test-lab.log"

cat > "$OUTPUT_DIR/firebase-summary.md" <<EOF
# Firebase Test Lab Patrol Qualification

Device: ${DEVICE_MODEL} / Android ${DEVICE_VERSION} / ${DEVICE_ORIENTATION}
App APK: $(basename "$APP_APK")
Test APK: $(basename "$TEST_APK")

See firebase-test-lab.log and the Firebase Test Lab console for device details.
EOF
