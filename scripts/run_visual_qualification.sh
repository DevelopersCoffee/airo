#!/usr/bin/env bash
set -euo pipefail

# Visual Device Qualification Script for connected iPad Air 4
DEVICE_ID="00008101-000940CC2690001E"
CWD="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="$CWD/artifacts/visual_qualification"
LOG_FILE="$OUTPUT_DIR/run_logs.txt"

mkdir -p "$OUTPUT_DIR"
echo "📷 Starting automated visual device qualification on iPad Air 4..."
echo "Output Directory: $OUTPUT_DIR"

# Step 1: Clean up any active runs
echo "🧹 Cleaning up previous flutter processes..."
pkill -f "flutter_tools.snapshot.*main_qualification.dart" || true

# Step 2: Start flutter run in background
echo "🚀 Launching Airo TV QA Qualification app on iPad Air..."
cd "$CWD/app"
flutter run --device-id="$DEVICE_ID" --target=lib/main_qualification.dart > "$LOG_FILE" 2>&1 &
FLUTTER_PID=$!

# Step 3: Wait for VM Service to become available (app launch)
echo "⏳ Waiting for app launch and VM Service connection..."
LAUNCHED=false
for i in {1..90}; do
  if grep -q "A Dart VM Service" "$LOG_FILE"; then
    echo "✅ VM Service connected! App launched successfully."
    LAUNCHED=true
    break
  fi
  if grep -q "Error:" "$LOG_FILE" || grep -q "Exception:" "$LOG_FILE"; then
    echo "❌ Launch Error detected in logs!"
    cat "$LOG_FILE"
    exit 1
  fi
  sleep 2
done

if [ "$LAUNCHED" = false ]; then
  echo "❌ Launch timed out after 180 seconds. Check logs at $LOG_FILE"
  cat "$LOG_FILE" || true
  kill $FLUTTER_PID || true
  exit 1
fi

# Step 4: Wait additional 10 seconds for initial IPTV playlist channels to load
echo "📡 Seeding and loading IPTV channels (https://iptv-org.github.io/iptv/index.m3u)..."
sleep 10

# The overlay auto-cycles every 8 seconds and this script waits 10 seconds for
# playlist warmup before the first screenshot. Labels start at the first
# post-warmup profile, then follow the SimulatedDevice enum cycle.
# 1. Native
# 2. Mobile Browser Fallback
# 3. Android TV Compact Browser
# 4. Android TV 720p
# 5. Android TV 1080p
# 6. Fire TV Stick
# 7. Google TV 4K
# 8. Shield TV 4K
# 9. Tablet Landscape
# 10. Foldable Portrait
# 11. Foldable Landscape
DEVICES=(
  "01_mobile_browser_fallback_390x844"
  "02_android_tv_compact_browser_1024x576"
  "03_android_tv_720p"
  "04_android_tv_1080p"
  "05_fire_tv_stick"
  "06_google_tv_4k"
  "07_shield_tv_4k"
  "08_tablet_landscape"
  "09_foldable_portrait"
  "10_foldable_landscape"
  "11_native_ipad_air"
)

# Step 5: Loop to take screenshots at each layout cycle
for dev in "${DEVICES[@]}"; do
  echo "📸 Capturing screenshot for simulated profile: $dev..."
  flutter screenshot --device-id="$DEVICE_ID" --out="$OUTPUT_DIR/screenshot_$dev.png" || true
  echo "⏳ Waiting for next layout cycle..."
  sleep 8
done

# Step 6: Shutdown the app
echo "🛑 Terminating qualification app on iPad..."
kill $FLUTTER_PID || true
pkill -f "flutter_tools.snapshot.*main_qualification.dart" || true

echo "🎉 Visual qualification screenshots saved under $OUTPUT_DIR!"
ls -la "$OUTPUT_DIR"
