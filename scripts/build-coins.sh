#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/app"
BUILD_MODE="${AIRO_COINS_BUILD_MODE:-release}"
BUILD_NAME="${AIRO_COINS_BUILD_NAME:-}"
BUILD_NUMBER="${AIRO_COINS_BUILD_NUMBER:-}"
PROFILE_PUBSPEC="$APP_DIR/pubspec_coins.yaml"
ACTIVE_PUBSPEC="$APP_DIR/pubspec.yaml"
ACTIVE_LOCK="$APP_DIR/pubspec.lock"

if [[ "$BUILD_MODE" != "debug" && "$BUILD_MODE" != "release" ]]; then
  echo "AIRO_COINS_BUILD_MODE must be debug or release" >&2
  exit 2
fi

if [[ -n "$BUILD_NUMBER" && ! "$BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]]; then
  echo "AIRO_COINS_BUILD_NUMBER must be a positive integer" >&2
  exit 2
fi

if [[ ! -f "$PROFILE_PUBSPEC" ]]; then
  echo "Airo Coins profile not found: $PROFILE_PUBSPEC" >&2
  exit 1
fi

backup_dir="$(mktemp -d)"
cp "$ACTIVE_PUBSPEC" "$backup_dir/pubspec.yaml"
cp "$ACTIVE_LOCK" "$backup_dir/pubspec.lock"

restore_profile() {
  cp "$backup_dir/pubspec.yaml" "$ACTIVE_PUBSPEC"
  cp "$backup_dir/pubspec.lock" "$ACTIVE_LOCK"
  # Recreate the full-profile plugin registrants. A profile swap changes
  # generated desktop/native registration files even though pubspec.yaml and
  # pubspec.lock themselves are restored.
  (cd "$APP_DIR" && flutter pub get >/dev/null)
  rm -rf "$backup_dir"
}
trap restore_profile EXIT

cp "$PROFILE_PUBSPEC" "$ACTIVE_PUBSPEC"

cd "$APP_DIR"
flutter pub get

build_args=(
  build apk
  "--$BUILD_MODE"
  --target=lib/main_coins.dart
  --dart-define=APP_VARIANT=coins
)
if [[ -n "$BUILD_NAME" ]]; then
  build_args+=("--build-name=$BUILD_NAME")
fi
if [[ -n "$BUILD_NUMBER" ]]; then
  build_args+=("--build-number=$BUILD_NUMBER")
fi
if [[ "$BUILD_MODE" == "release" ]]; then
  build_args+=(--split-per-abi)
fi

flutter "${build_args[@]}"

if [[ "$BUILD_MODE" == "debug" ]]; then
  manifest_task="processDebugManifest"
else
  manifest_task="processReleaseManifest"
fi
merged_manifest="$APP_DIR/build/app/intermediates/merged_manifests/$BUILD_MODE/$manifest_task/AndroidManifest.xml"
if [[ ! -f "$merged_manifest" ]]; then
  echo "Airo Coins merged manifest missing: $merged_manifest" >&2
  exit 1
fi
if ! grep -q 'android:name="io.airo.app.CoinsActivity"' "$merged_manifest"; then
  echo "Airo Coins merged manifest does not declare CoinsActivity" >&2
  exit 1
fi
if grep -q 'android:name="io.airo.app.MainActivity"' "$merged_manifest"; then
  echo "Airo Coins merged manifest still exposes the full-app MainActivity" >&2
  exit 1
fi
launcher_count="$(grep -c 'android.intent.category.LAUNCHER' "$merged_manifest")"
if [[ "$launcher_count" -ne 1 ]]; then
  echo "Airo Coins merged manifest must expose exactly one launcher activity" >&2
  exit 1
fi

if [[ "$BUILD_MODE" == "release" ]]; then
  artifact="$APP_DIR/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk"
else
  artifact="$APP_DIR/build/app/outputs/flutter-apk/app-debug.apk"
fi

if [[ ! -s "$artifact" ]]; then
  echo "Airo Coins build artifact missing: $artifact" >&2
  exit 1
fi

echo "Airo Coins artifact: $artifact"
ls -lh "$artifact"
