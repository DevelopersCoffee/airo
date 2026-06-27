#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/app"
PLATFORM="${AIRO_JOURNEY_PLATFORM:-ios}"
TARGET="${AIRO_JOURNEY_TARGET:-patrol_test/agent_skills_journey_test.dart}"
PROMPT="${AIRO_AGENT_SKILLS_PROMPT:-}"
ANDROID_SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-/opt/homebrew/share/android-commandlinetools}}"
ADB="${ADB:-$ANDROID_SDK/platform-tools/adb}"
ANDROID_DEVICE="${AIRO_JOURNEY_ANDROID_DEVICE:-}"
ALLOW_ANDROID_EMULATOR="${AIRO_ALLOW_ANDROID_EMULATOR:-false}"
IOS_DEVICE="${AIRO_JOURNEY_IOS_DEVICE:-iPhone 17 Pro Max iOS 26.5}"
TIMEOUT_SECONDS="${AIRO_JOURNEY_TIMEOUT_SECONDS:-900}"
STAMP="$(date -u +"%Y%m%dT%H%M%SZ")"
OUTPUT_DIR="${AIRO_JOURNEY_OUTPUT_DIR:-$ROOT_DIR/artifacts/agent-skills-journey/$STAMP}"
LOG_FILE="$OUTPUT_DIR/patrol.log"
SUMMARY_FILE="$OUTPUT_DIR/summary.json"
TIMEOUT_MARKER="$OUTPUT_DIR/.timed_out"

mkdir -p "$OUTPUT_DIR"
export PATH="$HOME/.pub-cache/bin:$ANDROID_SDK/platform-tools:$PATH"

find_physical_android_device() {
  if [ ! -x "$ADB" ]; then
    return 1
  fi

  "$ADB" devices | awk '
    NR > 1 && $2 == "device" && $1 !~ /^emulator-/ {
      print $1
      exit
    }
  '
}

android_device_is_emulator() {
  [ "$1" = "android" ] || [[ "$1" == emulator-* ]]
}

require_android_emulator_opt_in() {
  if [ "$ALLOW_ANDROID_EMULATOR" != "true" ]; then
    cat >&2 <<'EOF'
Android emulator journey tests are disabled by default for agent runs.

The Android Emulator/qemu process can crash the macOS host runtime and lose test
state. Use host checks or a connected physical Android device for routine agent
verification.

Allowed paths:
- Physical Android: set AIRO_JOURNEY_ANDROID_DEVICE=<adb-serial>
- iOS simulator: set AIRO_JOURNEY_PLATFORM=ios
- Explicit emulator opt-in: set AIRO_ALLOW_ANDROID_EMULATOR=true
EOF
    exit 78
  fi
}

case "$PLATFORM" in
  android)
    if [ -z "$ANDROID_DEVICE" ]; then
      ANDROID_DEVICE="$(find_physical_android_device || true)"
    fi

    if [ -z "$ANDROID_DEVICE" ]; then
      require_android_emulator_opt_in
      ANDROID_DEVICE="emulator-5554"
    fi

    if android_device_is_emulator "$ANDROID_DEVICE"; then
      require_android_emulator_opt_in
      (cd "$ROOT_DIR" && make boot-pixel9)
    fi

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

if ! command -v patrol >/dev/null 2>&1; then
  echo "patrol is required. Run: dart pub global activate patrol_cli" >&2
  exit 127
fi

START_EPOCH="$(date +%s)"
STATUS="passed"

kill_process_tree() {
  local pid="$1"
  local child

  for child in $(pgrep -P "$pid" 2>/dev/null || true); do
    kill_process_tree "$child"
  done

  kill -TERM "$pid" 2>/dev/null || true
}

set +e
(
  cd "$APP_DIR"
  patrol_args=(test -t "$TARGET" -d "$DEVICE")
  if [ -n "$PROMPT" ]; then
    patrol_args+=(--dart-define="AIRO_AGENT_SKILLS_PROMPT=$PROMPT")
  fi

  patrol "${patrol_args[@]}" &
  patrol_pid="$!"

  (
    sleep "$TIMEOUT_SECONDS"
    if kill -0 "$patrol_pid" 2>/dev/null; then
      echo "Agent Skills journey timed out after ${TIMEOUT_SECONDS}s; stopping Patrol." >&2
      touch "$TIMEOUT_MARKER"
      kill_process_tree "$patrol_pid"
      sleep 5
      for child in $(pgrep -P "$patrol_pid" 2>/dev/null || true); do
        kill -KILL "$child" 2>/dev/null || true
      done
      kill -KILL "$patrol_pid" 2>/dev/null || true
    fi
  ) &
  watchdog_pid="$!"

  wait "$patrol_pid"
  patrol_exit="$?"
  kill_process_tree "$watchdog_pid"
  wait "$watchdog_pid" 2>/dev/null || true
  exit "$patrol_exit"
) 2>&1 | tee "$LOG_FILE"
EXIT_CODE="${PIPESTATUS[0]}"
set -e
END_EPOCH="$(date +%s)"
DURATION_SECONDS="$((END_EPOCH - START_EPOCH))"

if [ -f "$TIMEOUT_MARKER" ]; then
  EXIT_CODE=124
fi

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
