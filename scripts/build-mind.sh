#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/app"
BUILD_MODE="${AIRO_MIND_BUILD_MODE:-release}"
BUILD_NAME="${AIRO_MIND_BUILD_NAME:-}"
BUILD_NUMBER="${AIRO_MIND_BUILD_NUMBER:-}"
PROFILE_PUBSPEC="$APP_DIR/pubspec_mind.yaml"
ACTIVE_PUBSPEC="$APP_DIR/pubspec.yaml"
ACTIVE_LOCK="$APP_DIR/pubspec.lock"

if [[ "$BUILD_MODE" != "debug" && "$BUILD_MODE" != "release" ]]; then
  echo "AIRO_MIND_BUILD_MODE must be debug or release" >&2
  exit 2
fi

if [[ -n "$BUILD_NUMBER" && ! "$BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]]; then
  echo "AIRO_MIND_BUILD_NUMBER must be a positive integer" >&2
  exit 2
fi

if [[ ! -f "$PROFILE_PUBSPEC" ]]; then
  echo "Airo Mind profile not found: $PROFILE_PUBSPEC" >&2
  exit 1
fi

# feature_mind builds a Rust runtime through cargokit, and two of its native
# dependencies (llama-cpp-sys-2, whisper-rs-sys) locate the Android NDK through
# the environment rather than through cargokit's own variables. Cargokit does
# not export it, so derive it here from the SDK Gradle already resolved.
if [[ -z "${ANDROID_NDK_ROOT:-}" ]]; then
  sdk_dir="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
  if [[ -z "$sdk_dir" && -f "$APP_DIR/android/local.properties" ]]; then
    sdk_dir="$(sed -n 's/^sdk\.dir=//p' "$APP_DIR/android/local.properties" | tail -1)"
  fi
  if [[ -n "$sdk_dir" && -d "$sdk_dir/ndk" ]]; then
    ANDROID_NDK_ROOT="$sdk_dir/ndk/$(ls "$sdk_dir/ndk" | sort -V | tail -1)"
    export ANDROID_NDK_ROOT
    echo "Using ANDROID_NDK_ROOT=$ANDROID_NDK_ROOT"
  else
    echo "ANDROID_NDK_ROOT is not set and no NDK was found under the Android SDK." >&2
    echo "The feature_mind Rust runtime cannot cross-compile without it." >&2
    exit 1
  fi
fi
# llama-cpp-sys-2 and whisper-rs-sys read these two spellings instead.
export ANDROID_NDK="${ANDROID_NDK:-$ANDROID_NDK_ROOT}"
export NDK_ROOT="${NDK_ROOT:-$ANDROID_NDK_ROOT}"

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
  --target=lib/main_mind.dart
  --dart-define=APP_VARIANT=mind
  # arm64 only. The Rust runtime pulls llama-cpp-sys-2, whose build script
  # panics on `armv7-linux-androideabi` ("Env var CARGO_CFG_TARGET_FEATURE not
  # found") because rustc reports no target features for that triple. Airo Mind
  # therefore ships 64-bit ARM only until that upstream bug is fixed.
  --target-platform=android-arm64
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
  echo "Airo Mind merged manifest missing: $merged_manifest" >&2
  exit 1
fi
# Mind reuses the product MainActivity; the assertion that matters is that the
# variant manifest replaced the full-app one, so exactly one launcher survives
# and none of the IPTV deep links come along.
if ! grep -q 'android:name="io.airo.app.MainActivity"' "$merged_manifest"; then
  echo "Airo Mind merged manifest does not declare MainActivity" >&2
  exit 1
fi
launcher_count="$(grep -c 'android.intent.category.LAUNCHER' "$merged_manifest")"
if [[ "$launcher_count" -ne 1 ]]; then
  echo "Airo Mind merged manifest must expose exactly one launcher activity" >&2
  exit 1
fi
if grep -q 'android:scheme="airo"' "$merged_manifest"; then
  echo "Airo Mind merged manifest still claims the airo:// deep link scheme" >&2
  exit 1
fi
if ! grep -q 'package="io.airo.app.mind"' "$merged_manifest"; then
  echo "Airo Mind merged manifest does not carry applicationId io.airo.app.mind" >&2
  exit 1
fi
if ! grep -q 'android.permission.RECORD_AUDIO' "$merged_manifest"; then
  echo "Airo Mind merged manifest is missing RECORD_AUDIO (scribe capture)" >&2
  exit 1
fi

if [[ "$BUILD_MODE" == "release" ]]; then
  artifact="$APP_DIR/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk"
else
  artifact="$APP_DIR/build/app/outputs/flutter-apk/app-debug.apk"
fi

if [[ ! -s "$artifact" ]]; then
  echo "Airo Mind build artifact missing: $artifact" >&2
  exit 1
fi

echo "Airo Mind artifact: $artifact"
ls -lh "$artifact"
