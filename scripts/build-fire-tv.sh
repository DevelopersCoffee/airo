#!/bin/bash
# Build Aika Stream for Fire OS (Amazon Appstore line).
# Same Dart entrypoint and pubspec_tv.yaml as Play TV; APP_VARIANT=fireTv
# selects the Fire manifest and GMS-free native gates in build.gradle.kts.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$SCRIPT_DIR/../app"
ANDROID_DIR="$APP_DIR/android"
BUILD_AAB=true
BUILD_APK=true
SIGNING_CREATED=false
VERSION_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    --apk-only) BUILD_AAB=false; shift ;;
    --aab-only) BUILD_APK=false; shift ;;
    --build-name) VERSION_ARGS+=(--build-name="$2"); shift 2 ;;
    --build-number) VERSION_ARGS+=(--build-number="$2"); shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Fire builds intentionally omit Pro/SLM dart-defines. Rule-based voice/intent
# is the default when AIRO_EDGE_INTELLIGENCE_BACKEND and AIRO_MEDIA_PACK* are unset.
PRO_DEFINES=()

resolve_keytool() {
  if command -v keytool >/dev/null 2>&1; then
    command -v keytool
    return 0
  fi
  local flutter_jdk
  flutter_jdk="$(flutter config --list 2>/dev/null | sed -nE 's/^[[:space:]]*jdk-dir: (.+)$/\1/p' | head -1)"
  if [[ -n "$flutter_jdk" && -x "$flutter_jdk/bin/keytool" ]]; then
    printf '%s\n' "$flutter_jdk/bin/keytool"
    return 0
  fi
  return 1
}

echo -e "\033[0;34mBuilding Aika Stream for Fire OS...\033[0m"
cd "$APP_DIR"

if [[ ! -f "$ANDROID_DIR/key.properties" ]]; then
  echo -e "\033[0;33mNo Android signing config; creating local validation keystore...\033[0m"
  KEYTOOL_BIN="$(resolve_keytool)" || {
    echo -e "\033[0;31mERROR: keytool not found.\033[0m"
    exit 1
  }
  "$KEYTOOL_BIN" -genkeypair \
    -v \
    -keystore "$ANDROID_DIR/fire-tv-validation.keystore" \
    -storepass fire-tv-validation-password \
    -keypass fire-tv-validation-password \
    -alias fire-tv-validation \
    -keyalg RSA \
    -keysize 2048 \
    -validity 10000 \
    -dname "CN=Aika Stream Fire TV Validation,O=DevelopersCoffee,C=US" >/dev/null 2>&1
  {
    echo "storeFile=fire-tv-validation.keystore"
    echo "storePassword=fire-tv-validation-password"
    echo "keyAlias=fire-tv-validation"
    echo "keyPassword=fire-tv-validation-password"
  } > "$ANDROID_DIR/key.properties"
  chmod 600 "$ANDROID_DIR/fire-tv-validation.keystore" "$ANDROID_DIR/key.properties"
  SIGNING_CREATED=true
fi

cleanup() {
  if [[ -f pubspec_backup.yaml ]]; then
    cp pubspec_backup.yaml pubspec.yaml
    rm -f pubspec_backup.yaml pubspec_backup.lock
    flutter pub get >/dev/null 2>&1 || true
  fi
  if [[ "$SIGNING_CREATED" == true ]]; then
    rm -f "$ANDROID_DIR/key.properties" "$ANDROID_DIR/fire-tv-validation.keystore"
  fi
}
trap cleanup EXIT

cp pubspec.yaml pubspec_backup.yaml
cp pubspec_tv.yaml pubspec.yaml
flutter pub get

FIRE_DEFINES=(
  --dart-define=APP_VARIANT=fireTv
  --dart-define=APP_PLATFORM=androidTv
)

if [[ "$BUILD_APK" == true ]]; then
  flutter build apk --release \
    --target=lib/main_tv.dart \
    "${FIRE_DEFINES[@]}" \
    --target-platform=android-arm,android-arm64 \
    --tree-shake-icons \
    --split-debug-info=build/debug-info-fire-tv \
    --obfuscate \
    "${VERSION_ARGS[@]}"
  mkdir -p build
  cp build/app/outputs/flutter-apk/app-release.apk build/aika-stream-fire-universal.apk
  cp build/app/outputs/flutter-apk/app-arm64-v8a-release.apk build/aika-stream-fire-arm64.apk 2>/dev/null || true
fi

if [[ "$BUILD_AAB" == true ]]; then
  flutter build appbundle --release \
    --target=lib/main_tv.dart \
    "${FIRE_DEFINES[@]}" \
    --tree-shake-icons \
    --split-debug-info=build/debug-info-fire-tv \
    --obfuscate \
    "${VERSION_ARGS[@]}"
  mkdir -p build
  cp build/app/outputs/bundle/release/app-release.aab build/aika-stream-fire-amazon.aab
fi

echo -e "\033[0;32m✓ Fire TV artifacts ready under app/build/\033[0m"
ls -lh build/aika-stream-fire-* 2>/dev/null || ls -lh build/app/outputs/flutter-apk/ build/app/outputs/bundle/release/ 2>/dev/null || true
