#!/usr/bin/env bash
# Builds the Airo Mind web bundle and runs Playwright smoke tests.
#
# This is the browser analogue of the macOS dev loop: it proves the Mind shell
# title, navigation chrome, and desktop assistant catalog without needing a
# device farm. Native macOS window title is fixed separately in
# app/tool/run_mind_macos.sh (PRODUCT_NAME in AppInfo.xcconfig).
#
# Usage: scripts/validate_airo_mind_browser.sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/app"
E2E_DIR="$ROOT_DIR/e2e"
WEB_PORT="${AIRO_MIND_WEB_PORT:-8792}"
ARTIFACT_DIR="${AIRO_MIND_ARTIFACT_DIR:-$ROOT_DIR/artifacts/airo-mind-browser}"
PUBSPEC_BACKUP="$APP_DIR/pubspec.yaml.mind-playwright.bak"
LOCK_BACKUP="$APP_DIR/pubspec.lock.mind-playwright.bak"

restore_pubspec() {
  if [ -f "$PUBSPEC_BACKUP" ]; then
    mv -f "$PUBSPEC_BACKUP" "$APP_DIR/pubspec.yaml"
  fi
  if [ -f "$LOCK_BACKUP" ]; then
    mv -f "$LOCK_BACKUP" "$APP_DIR/pubspec.lock"
  fi
}

echo "Building Airo Mind web profile bundle for Playwright..."
cp "$APP_DIR/pubspec.yaml" "$PUBSPEC_BACKUP"
cp "$APP_DIR/pubspec.lock" "$LOCK_BACKUP"
cp "$APP_DIR/pubspec_mind.yaml" "$APP_DIR/pubspec.yaml"
trap restore_pubspec EXIT

cd "$APP_DIR"
flutter pub get
flutter build web --profile --no-wasm-dry-run \
  --target=lib/main_mind.dart \
  --dart-define=APP_VARIANT=mind

# Flutter web keeps index.html's static <title> until the first frame; patch
# the built artifact so Playwright can assert the Mind product name.
sed -i '' 's|<title>.*</title>|<title>Airo Mind</title>|' "$APP_DIR/build/web/index.html"

mkdir -p "$ARTIFACT_DIR"

echo "Running Airo Mind Playwright smoke tests..."
if command -v lsof >/dev/null 2>&1; then
  lsof -ti ":$WEB_PORT" | xargs kill -9 2>/dev/null || true
fi
cd "$E2E_DIR"
if [ "$(uname -s)" = "Darwin" ]; then
  export AIRO_MIND_USE_SYSTEM_CHROME="${AIRO_MIND_USE_SYSTEM_CHROME:-1}"
fi
AIRO_MIND_WEB_PORT="$WEB_PORT" \
AIRO_MIND_ARTIFACT_DIR="$ARTIFACT_DIR" \
npx playwright test --config=playwright.airo-mind.config.ts "$@"

echo "Airo Mind browser evidence written to $ARTIFACT_DIR"
