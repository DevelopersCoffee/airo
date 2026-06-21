#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/app"
PLATFORM="${AIRO_JOURNEY_PLATFORM:-android}"
TARGET="${AIRO_JOURNEY_TARGET:-patrol_test/agent_skills_journey_test.dart}"
PROMPT="${AIRO_AGENT_SKILLS_PROMPT:-}"
ANDROID_SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-/opt/homebrew/share/android-commandlinetools}}"
ANDROID_DEVICE="${AIRO_JOURNEY_ANDROID_DEVICE:-emulator-5554}"
IOS_DEVICE="${AIRO_JOURNEY_IOS_DEVICE:-iPhone 17 Pro Max iOS 26.5}"
STAMP="$(date -u +"%Y%m%dT%H%M%SZ")"
OUTPUT_DIR="${AIRO_JOURNEY_OUTPUT_DIR:-$ROOT_DIR/artifacts/agent-skills-journey/$STAMP}"
LOG_FILE="$OUTPUT_DIR/patrol.log"
SUMMARY_FILE="$OUTPUT_DIR/summary.json"

mkdir -p "$OUTPUT_DIR"
export PATH="$HOME/.pub-cache/bin:$ANDROID_SDK/platform-tools:$PATH"

if ! command -v patrol >/dev/null 2>&1; then
  echo "patrol is required. Run: dart pub global activate patrol_cli" >&2
  exit 127
fi

case "$PLATFORM" in
  android)
    (cd "$ROOT_DIR" && make boot-pixel9)
    DEVICE="$ANDROID_DEVICE"
    ;;
  ios)
    (cd "$ROOT_DIR" && make boot-iphone17)
    DEVICE="$IOS_DEVICE"
    ;;
  *)
    echo "Unsupported AIRO_JOURNEY_PLATFORM=$PLATFORM. Use android or ios." >&2
    exit 2
    ;;
esac

START_EPOCH="$(date +%s)"
STATUS="passed"
set +e
(
  cd "$APP_DIR"
  if [ -n "$PROMPT" ]; then
    patrol test -t "$TARGET" -d "$DEVICE" --dart-define="AIRO_AGENT_SKILLS_PROMPT=$PROMPT"
  else
    patrol test -t "$TARGET" -d "$DEVICE"
  fi
) 2>&1 | tee "$LOG_FILE"
EXIT_CODE="${PIPESTATUS[0]}"
set -e
END_EPOCH="$(date +%s)"
DURATION_SECONDS="$((END_EPOCH - START_EPOCH))"

if [ "$EXIT_CODE" -ne 0 ]; then
  STATUS="failed"
fi

cat > "$SUMMARY_FILE" <<JSON
{
  "journey": "agent_skills_calendar_schedule",
  "platform": "$PLATFORM",
  "device": "$DEVICE",
  "target": "$TARGET",
  "prompt": $(python3 -c 'import json, os; print(json.dumps(os.environ.get("AIRO_AGENT_SKILLS_PROMPT", "Check my schedule for today")))' ),
  "status": "$STATUS",
  "exit_code": $EXIT_CODE,
  "duration_seconds": $DURATION_SECONDS,
  "log_file": "$LOG_FILE"
}
JSON

echo "Agent Skills journey summary: $SUMMARY_FILE"
exit "$EXIT_CODE"
