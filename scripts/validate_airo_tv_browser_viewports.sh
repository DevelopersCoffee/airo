#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/app"
E2E_DIR="$ROOT_DIR/e2e"
WEB_PORT="${AIRO_TV_WEB_PORT:-8790}"
ARTIFACT_DIR="${AIRO_TV_VIEWPORT_ARTIFACT_DIR:-$ROOT_DIR/artifacts/airo-tv-browser-viewports}"
PLAYLIST_URL="http://127.0.0.1:${WEB_PORT}/fixtures/airo-tv-viewport.m3u"

echo "Building Airo TV web profile bundle for viewport validation..."
cd "$APP_DIR"
flutter build web --profile --no-wasm-dry-run \
  --target=lib/main_tv.dart \
  --dart-define=APP_VARIANT=tv \
  --dart-define=APP_PLATFORM=androidTv \
  --dart-define=DEBUG_IPTV_PLAYLIST_URL="$PLAYLIST_URL"

mkdir -p "$APP_DIR/build/web/fixtures" "$ARTIFACT_DIR"
cp "$E2E_DIR/fixtures/airo-tv-viewport.m3u" \
  "$APP_DIR/build/web/fixtures/airo-tv-viewport.m3u"

echo "Running Airo TV browser viewport validation..."
cd "$E2E_DIR"
AIRO_TV_WEB_PORT="$WEB_PORT" \
AIRO_TV_VIEWPORT_ARTIFACT_DIR="$ARTIFACT_DIR" \
AIRO_TV_USE_SYSTEM_CHROME="${AIRO_TV_USE_SYSTEM_CHROME:-0}" \
npx playwright test --config=playwright.airo-tv.config.ts "$@"

echo "Airo TV browser viewport evidence written to $ARTIFACT_DIR"
