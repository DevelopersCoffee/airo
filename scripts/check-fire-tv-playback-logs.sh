#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE_NAME="${AIRO_ANDROID_TV_PACKAGE:-io.airo.app.tv}"
DURATION_SECONDS="${AIRO_FIRE_TV_LOG_DURATION_SECONDS:-5}"
OUTPUT_FILE="${AIRO_FIRE_TV_LOG_REPORT:-$ROOT_DIR/artifacts/release-qualification/fire-tv-playback-log-report.md}"
INPUT_FILE=""

usage() {
  cat <<EOF
Usage: $0 [--input FILE] [--output FILE] [--duration SECONDS]

Classifies a bounded, app-PID-scoped Fire TV error-log sample. With --input,
classifies an existing sanitized sample instead of connecting to a device.
Raw device logcat is held in a temporary file and is never copied to the report.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --input)
      INPUT_FILE="$2"
      shift 2
      ;;
    --output)
      OUTPUT_FILE="$2"
      shift 2
      ;;
    --duration)
      DURATION_SECONDS="$2"
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

if [[ ! "$DURATION_SECONDS" =~ ^[1-9][0-9]*$ ]] ||
  [[ "$DURATION_SECONDS" -gt 60 ]]; then
  echo "Duration must be an integer from 1 to 60 seconds" >&2
  exit 2
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
sample="$tmp_dir/fire-tv-errors.log"

if [[ -n "$INPUT_FILE" ]]; then
  cp "$INPUT_FILE" "$sample"
else
  device="$("$ROOT_DIR/scripts/select_rig_device.sh" tv)"
  adb -s "$device" shell am force-stop "$PACKAGE_NAME" >/dev/null
  adb -s "$device" shell monkey \
    -p "$PACKAGE_NAME" \
    -c android.intent.category.LEANBACK_LAUNCHER \
    1 >/dev/null
  pid="$(adb -s "$device" shell pidof "$PACKAGE_NAME" | tr -d '\r')"
  if [[ -z "$pid" ]]; then
    echo "Airo TV process is not running after launcher start" >&2
    exit 1
  fi
  adb -s "$device" logcat -c
  sleep "$DURATION_SECONDS"
  adb -s "$device" logcat -d --pid="$pid" '*:E' > "$sample"
fi

log_enable_count="$(grep -cF 'vendor.dpframework.log.enable' "$sample" || true)"
checksum_count="$(grep -cF 'vendor.dpframework.dumpbuffer.checksum' "$sample" || true)"
dumpbuffer_count="$(grep -cF 'vendor.dpframework.dumpbuffer.enable' "$sample" || true)"
known_count=$((log_enable_count + checksum_count + dumpbuffer_count))
total_count="$(grep -c . "$sample" || true)"

grep -vF \
  -e 'vendor.dpframework.log.enable' \
  -e 'vendor.dpframework.dumpbuffer.checksum' \
  -e 'vendor.dpframework.dumpbuffer.enable' \
  "$sample" > "$tmp_dir/actionable.log" || true
actionable_count="$(grep -c . "$tmp_dir/actionable.log" || true)"
fatal_count="$(grep -Ec 'FATAL EXCEPTION|AndroidRuntime|Process: io\.airo\.app\.tv' "$tmp_dir/actionable.log" || true)"

status="PASS"
if [[ "$actionable_count" -gt 0 ]]; then
  status="FAIL_ACTIONABLE_ERRORS"
elif [[ "$known_count" -gt 0 ]]; then
  status="PASS_WITH_KNOWN_PLATFORM_NOISE"
fi

mkdir -p "$(dirname "$OUTPUT_FILE")"
cat > "$OUTPUT_FILE" <<EOF
# Fire TV playback log classification

- Status: \`$status\`
- Sample window: ${DURATION_SECONDS}s
- Package: \`$PACKAGE_NAME\`
- Total app-scoped error lines: $total_count
- Known Fire OS/MediaTek property denials: $known_count
- Other actionable error lines: $actionable_count
- Fatal signatures among actionable lines: $fatal_count

| Known signature | Count |
| --- | ---: |
| \`vendor.dpframework.log.enable\` | $log_enable_count |
| \`vendor.dpframework.dumpbuffer.checksum\` | $checksum_count |
| \`vendor.dpframework.dumpbuffer.enable\` | $dumpbuffer_count |

Raw logcat is intentionally excluded because it can contain stream URLs,
network identifiers, or device identifiers. Known property denials are
aggregated only; every other error remains an actionable qualification failure.
EOF

echo "Fire TV playback log report: $OUTPUT_FILE"
if [[ "$actionable_count" -gt 0 ]]; then
  exit 1
fi
