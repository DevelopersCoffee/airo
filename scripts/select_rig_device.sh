#!/usr/bin/env bash
# Resolve one rig surface to exactly one device id, or fail loudly.
#
# Usage: scripts/select_rig_device.sh phone|tablet|tv
#
# The rig is three physical devices, one per surface. Each surface resolves on
# its own -- a Fire TV Stick is never a phone, an iPhone is never the tablet.
# Nothing here ever falls back to a simulator or emulator; those live behind
# AIRO_ALLOW_ANDROID_EMULATOR / AIRO_ALLOW_IOS_SIMULATOR in the journey script.
#
# Override per surface when the rig changes:
#   AIRO_PHONE_DEVICE, AIRO_TABLET_DEVICE, AIRO_TV_DEVICE
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ANDROID_SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-/opt/homebrew/share/android-commandlinetools}}"
ADB="${ADB:-$ANDROID_SDK/platform-tools/adb}"
command -v "$ADB" >/dev/null 2>&1 || ADB="adb"

SURFACE="${1:-}"

# Fire TV hardware reports model:AFT*. That is the only thing separating the
# Stick from a phone in `adb devices` output.
android_devices() {
  local want_firetv="$1"
  "$ADB" devices -l 2>/dev/null | awk -v want="$want_firetv" '
    NR > 1 && $2 == "device" && $1 !~ /^emulator-/ {
      is_firetv = ($0 ~ /model:AFT/) ? 1 : 0
      if (is_firetv == want) {
        model = "unknown"
        for (i = 3; i <= NF; i++) if ($i ~ /^model:/) model = substr($i, 7)
        print $1 "\t" model
      }
    }
  '
}

ipad_devices() {
  flutter devices --machine 2>/dev/null | python3 -c '
import json, sys
try:
    devices = json.load(sys.stdin)
except ValueError:
    sys.exit(0)
for d in devices:
    if not str(d.get("targetPlatform", "")).startswith("ios"):
        continue
    if d.get("emulator", True):
        continue
    name = str(d.get("name", ""))
    if "ipad" in name.lower():
        print("{}\t{}".format(d.get("id", ""), name))
'
}

resolve() {
  local label="$1" hint="$2" override="$3"
  shift 3
  local matches count

  if [ -n "$override" ]; then
    printf '%s\n' "$override"
    return 0
  fi

  matches="$("$@" || true)"
  count="$(printf '%s' "$matches" | grep -c . || true)"

  if [ "$count" -eq 1 ]; then
    printf '%s\n' "$matches" | cut -f1
    return 0
  fi

  if [ "$count" -eq 0 ]; then
    echo "No $label connected. $hint" >&2
    return 1
  fi

  {
    echo "More than one $label connected; refusing to guess:"
    printf '%s\n' "$matches" | sed 's/^/  /'
  } >&2
  return 1
}

case "$SURFACE" in
  phone)
    resolve "phone (Pixel 9)" \
      "Connect it over USB, or set AIRO_PHONE_DEVICE=<adb-serial>." \
      "${AIRO_PHONE_DEVICE:-}" android_devices 0
    ;;
  tablet)
    resolve "iPad" \
      "Connect it and trust this host, or set AIRO_TABLET_DEVICE=<device-id>. An iPhone is not a substitute." \
      "${AIRO_TABLET_DEVICE:-}" ipad_devices
    ;;
  tv)
    resolve "Fire TV Stick" \
      "Attach it first: adb connect <stick-ip>:5555, or set AIRO_TV_DEVICE=<adb-serial>." \
      "${AIRO_TV_DEVICE:-}" android_devices 1
    ;;
  *)
    echo "Usage: ${BASH_SOURCE[0]##*/} phone|tablet|tv" >&2
    exit 2
    ;;
esac
