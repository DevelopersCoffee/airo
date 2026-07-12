#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GRADLE_FILE="$ROOT_DIR/app/android/app/build.gradle.kts"
TV_MANIFEST="$ROOT_DIR/app/android/app/src/tv/AndroidManifest.xml"
MIN_TARGET_SDK="${AIRO_TV_MIN_TARGET_SDK:-34}"

fail() {
  echo "::error::$1" >&2
  exit 1
}

target_sdk="$(sed -nE 's/^[[:space:]]*targetSdk[[:space:]]*=[[:space:]]*([0-9]+).*$/\1/p' "$GRADLE_FILE" | head -1)"
compile_sdk="$(sed -nE 's/^[[:space:]]*compileSdk[[:space:]]*=[[:space:]]*([0-9]+).*$/\1/p' "$GRADLE_FILE" | head -1)"

[ -n "$target_sdk" ] || fail "Unable to read targetSdk from $GRADLE_FILE"
[ -n "$compile_sdk" ] || fail "Unable to read compileSdk from $GRADLE_FILE"

if [ "$target_sdk" -lt "$MIN_TARGET_SDK" ]; then
  fail "Android TV targetSdk $target_sdk is below Google Play minimum $MIN_TARGET_SDK"
fi

if [ "$compile_sdk" -lt "$target_sdk" ]; then
  fail "compileSdk $compile_sdk is below targetSdk $target_sdk"
fi

grep -q 'android.software.leanback' "$TV_MANIFEST" || fail "TV manifest missing android.software.leanback feature"
grep -q 'android.hardware.touchscreen" android:required="false"' "$TV_MANIFEST" || fail "TV manifest must mark touchscreen optional"
grep -q 'android.intent.category.LEANBACK_LAUNCHER' "$TV_MANIFEST" || fail "TV manifest missing LEANBACK_LAUNCHER"
grep -q 'android:banner="@drawable/tv_banner"' "$TV_MANIFEST" || fail "TV manifest missing TV banner"

if [ -n "${AIRO_TV_RELEASE_APK:-}" ]; then
  [ -s "$AIRO_TV_RELEASE_APK" ] || fail "Release APK not found or empty: $AIRO_TV_RELEASE_APK"
fi

if [ -n "${AIRO_TV_RELEASE_AAB:-}" ]; then
  [ -s "$AIRO_TV_RELEASE_AAB" ] || fail "Release AAB not found or empty: $AIRO_TV_RELEASE_AAB"
fi

echo "Airo TV release checks passed: compileSdk=$compile_sdk targetSdk=$target_sdk minRequired=$MIN_TARGET_SDK"
