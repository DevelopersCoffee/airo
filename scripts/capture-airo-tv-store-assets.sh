#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/app"
E2E_DIR="$ROOT_DIR/e2e"
WEB_PORT="${AIRO_TV_WEB_PORT:-8790}"
ARTIFACT_DIR="${AIRO_STORE_ASSET_DIR:-$ROOT_DIR/artifacts/store-listing}"
OUTPUT_DIR="$ARTIFACT_DIR/processed"
PLAYLIST_URL="http://127.0.0.1:${WEB_PORT}/fixtures/airo-tv-viewport.m3u"
USE_SYSTEM_CHROME="${AIRO_TV_USE_SYSTEM_CHROME:-}"
if [[ -z "$USE_SYSTEM_CHROME" ]]; then
  if [[ -x "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" ]]; then
    USE_SYSTEM_CHROME=1
  else
    USE_SYSTEM_CHROME=0
  fi
fi

mkdir -p "$ARTIFACT_DIR" "$OUTPUT_DIR"
RAW_DIR="$(mktemp -d "$ARTIFACT_DIR/raw-run.XXXXXX")"

cd "$APP_DIR"
flutter build web --profile --no-wasm-dry-run \
  --target=lib/main_tv.dart \
  --dart-define=APP_VARIANT=tv \
  --dart-define=APP_PLATFORM=androidTv \
  --dart-define=DEBUG_IPTV_PLAYLIST_URL="$PLAYLIST_URL"

mkdir -p "$APP_DIR/build/web/fixtures"
sed "s|__BASE_URL__|http://127.0.0.1:${WEB_PORT}|g" \
  "$E2E_DIR/fixtures/airo-tv-viewport.m3u" \
  > "$APP_DIR/build/web/fixtures/airo-tv-viewport.m3u"
cp "$E2E_DIR/fixtures/airo-demo.mp4" "$APP_DIR/build/web/fixtures/airo-demo.mp4"

cd "$E2E_DIR"
AIRO_TV_WEB_PORT="$WEB_PORT" \
AIRO_STORE_SCREENSHOT_RAW_DIR="$RAW_DIR" \
AIRO_TV_USE_SYSTEM_CHROME="$USE_SYSTEM_CHROME" \
npx playwright test \
  --config=playwright.airo-tv.config.ts \
  tests/airo-tv/store-screenshots.spec.ts

cd "$ROOT_DIR"
python3 scripts/process-store-screenshots.py \
  --input-dir "$RAW_DIR" \
  --output-dir "$OUTPUT_DIR" \
  --feature-source docs/store-assets/airo-tv/source/feature-graphic-background.png \
  --feature-output "$OUTPUT_DIR/feature-graphic-1024x500.png" \
  --manifest "$OUTPUT_DIR/store-assets.json"

echo "Airo TV raw captures: $RAW_DIR"
echo "Airo TV store assets written to $OUTPUT_DIR"
