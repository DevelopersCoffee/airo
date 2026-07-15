#!/usr/bin/env bash
# Build the v2 Airo TV macOS app with the TV pubspec profile.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/app"
BUILD_NAME="${BUILD_NAME:-2.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-200}"
GENERATED_FILES=(
  "$APP_DIR/macos/Flutter/GeneratedPluginRegistrant.swift"
  "$APP_DIR/linux/flutter/generated_plugin_registrant.cc"
  "$APP_DIR/linux/flutter/generated_plugin_registrant.h"
  "$APP_DIR/linux/flutter/generated_plugins.cmake"
  "$APP_DIR/windows/flutter/generated_plugin_registrant.cc"
  "$APP_DIR/windows/flutter/generated_plugin_registrant.h"
  "$APP_DIR/windows/flutter/generated_plugins.cmake"
)

cleanup() {
  if [[ -f "$APP_DIR/pubspec.yaml.backup" ]]; then
    cp "$APP_DIR/pubspec.yaml.backup" "$APP_DIR/pubspec.yaml"
    rm "$APP_DIR/pubspec.yaml.backup"
  fi
  if [[ -f "$APP_DIR/pubspec.lock.backup" ]]; then
    cp "$APP_DIR/pubspec.lock.backup" "$APP_DIR/pubspec.lock"
    rm "$APP_DIR/pubspec.lock.backup"
  fi
  for generated_file in "${GENERATED_FILES[@]}"; do
    if [[ -f "$generated_file.backup" ]]; then
      cp "$generated_file.backup" "$generated_file"
      rm "$generated_file.backup"
    fi
  done
}
trap cleanup EXIT

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "macOS builds require a macOS host with Xcode."
  exit 1
fi

cp "$APP_DIR/pubspec.yaml" "$APP_DIR/pubspec.yaml.backup"
cp "$APP_DIR/pubspec.lock" "$APP_DIR/pubspec.lock.backup"
for generated_file in "${GENERATED_FILES[@]}"; do
  if [[ -f "$generated_file" ]]; then
    cp "$generated_file" "$generated_file.backup"
  fi
done
cp "$APP_DIR/pubspec_tv.yaml" "$APP_DIR/pubspec.yaml"

cd "$APP_DIR"
flutter pub get
flutter build macos --release \
  --target=lib/main_tv.dart \
  --dart-define=APP_VARIANT=tv \
  --dart-define=APP_PLATFORM=androidTv \
  --dart-define=APP_VERSION="$BUILD_NAME" \
  --build-name="$BUILD_NAME" \
  --build-number="$BUILD_NUMBER" \
  --tree-shake-icons

echo "Built $APP_DIR/build/macos/Build/Products/Release/Airo TV.app"
