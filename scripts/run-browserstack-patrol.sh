#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MATRIX="${AIRO_RELEASE_DEVICE_MATRIX:-$ROOT_DIR/config/release_device_matrix.yaml}"
OUTPUT_DIR="${AIRO_RELEASE_QUALIFICATION_DIR:-$ROOT_DIR/artifacts/release-qualification/browserstack-$(date -u +%Y%m%dT%H%M%SZ)}"
TIER="${AIRO_QUALIFICATION_TIER:-tier1}"
APP_APK="${AIRO_BROWSERSTACK_APP_APK:-}"
TEST_APK="${AIRO_BROWSERSTACK_TEST_APK:-}"
WAIT_FOR_COMPLETION="${AIRO_BROWSERSTACK_WAIT_FOR_COMPLETION:-true}"
POLL_SECONDS="${AIRO_BROWSERSTACK_POLL_SECONDS:-60}"
TIMEOUT_SECONDS="${AIRO_BROWSERSTACK_TIMEOUT_SECONDS:-1800}"

usage() {
  cat <<EOF
Usage: $0 --app APK --test-suite APK [--output-dir DIR] [--tier tier1|full]

Schedules Android Patrol instrumentation artifacts on BrowserStack App Automate
using the tier 1 Android entries from config/release_device_matrix.yaml.

Required secrets:
  BROWSERSTACK_USERNAME
  BROWSERSTACK_ACCESS_KEY
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
    --tier)
      TIER="$2"
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

if [[ -z "${BROWSERSTACK_USERNAME:-}" || -z "${BROWSERSTACK_ACCESS_KEY:-}" ]]; then
  echo "::error::BROWSERSTACK_USERNAME and BROWSERSTACK_ACCESS_KEY are required."
  exit 1
fi

[[ -s "$APP_APK" ]] || { echo "::error::App APK not found: $APP_APK"; exit 1; }
[[ -s "$TEST_APK" ]] || { echo "::error::Test APK not found: $TEST_APK"; exit 1; }

auth="${BROWSERSTACK_USERNAME}:${BROWSERSTACK_ACCESS_KEY}"
app_response="$OUTPUT_DIR/browserstack-app-upload.json"
test_response="$OUTPUT_DIR/browserstack-test-upload.json"
build_response="$OUTPUT_DIR/browserstack-build.json"

curl --fail-with-body -u "$auth" \
  -X POST "https://api-cloud.browserstack.com/app-automate/espresso/v2/app" \
  -F "file=@${APP_APK}" \
  -o "$app_response"

curl --fail-with-body -u "$auth" \
  -X POST "https://api-cloud.browserstack.com/app-automate/espresso/v2/test-suite" \
  -F "file=@${TEST_APK}" \
  -o "$test_response"

python3 - "$MATRIX" "$TIER" "$app_response" "$test_response" "$build_response" <<'PY'
import json
import re
import sys
from pathlib import Path

matrix_path, tier, app_response, test_response, build_response = sys.argv[1:6]
text = Path(matrix_path).read_text(encoding="utf-8")

devices = []
current = {}
for line in text.splitlines():
    if re.match(r"\s+- id:", line):
        current = {"id": line.split(":", 1)[1].strip()}
    elif "tier:" in line and current is not None:
        current["tier"] = line.split(":", 1)[1].strip()
    elif "browserstack:" in line and current is not None:
        value = line.split(":", 1)[1].strip().strip('"')
        current["browserstack"] = value
        if tier == "full" or current.get("tier") == tier:
            devices.append(value)

android_devices = [
    d for d in devices
    if any(marker in d.lower() for marker in ["pixel", "samsung", "galaxy"])
]
if not android_devices:
    raise SystemExit("No BrowserStack Android devices found in matrix")

app_url = json.loads(Path(app_response).read_text(encoding="utf-8")).get("app_url")
test_url = json.loads(Path(test_response).read_text(encoding="utf-8")).get("test_suite_url")
if not app_url or not test_url:
    raise SystemExit("BrowserStack upload response missing app_url or test_suite_url")

payload = {
    "app": app_url,
    "testSuite": test_url,
    "devices": android_devices,
    "project": "Airo",
    "build": "release-device-qualification",
    "networkLogs": True,
    "deviceLogs": True,
    "video": True,
}
Path(build_response + ".payload.json").write_text(json.dumps(payload, indent=2), encoding="utf-8")
print(json.dumps(payload))
PY

curl --fail-with-body -u "$auth" \
  -X POST "https://api-cloud.browserstack.com/app-automate/espresso/v2/build" \
  -H "Content-Type: application/json" \
  -d @"$build_response.payload.json" \
  -o "$build_response"

cat > "$OUTPUT_DIR/browserstack-summary.md" <<EOF
# BrowserStack Patrol Qualification

Provider: BrowserStack App Automate Espresso
Tier: $TIER
Matrix: $MATRIX

Responses:
- App upload: $(basename "$app_response")
- Test upload: $(basename "$test_response")
- Build schedule: $(basename "$build_response")

Check the BrowserStack dashboard for live status, videos, and device logs.
EOF

if [[ "$WAIT_FOR_COMPLETION" == "true" ]]; then
  build_id="$(python3 - "$build_response" <<'PY'
import json
import sys
from pathlib import Path

data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
for key in ("build_id", "id", "buildId"):
    value = data.get(key)
    if value:
        print(value)
        break
else:
    print("")
PY
)"

  if [[ -z "$build_id" ]]; then
    echo "::error::BrowserStack build response did not include a build id."
    cat "$build_response"
    exit 1
  fi

  status_file="$OUTPUT_DIR/browserstack-build-status.json"
  elapsed=0
  while [[ "$elapsed" -le "$TIMEOUT_SECONDS" ]]; do
    curl --fail-with-body -u "$auth" \
      "https://api-cloud.browserstack.com/app-automate/espresso/v2/builds/${build_id}" \
      -o "$status_file"

    status="$(python3 - "$status_file" <<'PY'
import json
import sys
from pathlib import Path

data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
text = json.dumps(data).lower()
for key in ("status", "state", "build_status"):
    value = data.get(key)
    if isinstance(value, str):
        print(value.lower())
        break
else:
    if any(word in text for word in ("failed", "error", "timed out")):
        print("failed")
    elif any(word in text for word in ("passed", "success", "completed", "done")):
        print("completed")
    else:
        print("running")
PY
)"

    case "$status" in
      passed|success|completed|done)
        if grep -Eiq '"(failed|error|timed out)"' "$status_file"; then
          echo "::error::BrowserStack build completed with failing session details."
          cat "$status_file"
          exit 1
        fi
        echo "BrowserStack build completed with status: $status"
        break
        ;;
      failed|error|timedout|timed_out|timeout)
        echo "::error::BrowserStack build failed with status: $status"
        cat "$status_file"
        exit 1
        ;;
      *)
        echo "BrowserStack build status: $status (${elapsed}s elapsed)"
        sleep "$POLL_SECONDS"
        elapsed=$((elapsed + POLL_SECONDS))
        ;;
    esac
  done

  if [[ "$elapsed" -gt "$TIMEOUT_SECONDS" ]]; then
    echo "::error::Timed out waiting for BrowserStack build $build_id."
    exit 1
  fi
fi

echo "BrowserStack build scheduled. Summary: $OUTPUT_DIR/browserstack-summary.md"
