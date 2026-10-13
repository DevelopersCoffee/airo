#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIRE_MANIFEST="$ROOT_DIR/app/android/app/src/fireTv/AndroidManifest.xml"
GRADLE_FILE="$ROOT_DIR/app/android/app/build.gradle.kts"

fail() {
  echo "::error::$1" >&2
  exit 1
}

[[ -f "$FIRE_MANIFEST" ]] || fail "Fire TV manifest missing: $FIRE_MANIFEST"

grep -q 'android.software.leanback' "$FIRE_MANIFEST" ||
  fail "Fire TV manifest missing android.software.leanback"
grep -q 'amazon.hardware.fire_tv' "$FIRE_MANIFEST" ||
  fail "Fire TV manifest missing amazon.hardware.fire_tv (optional)"
grep -q 'android.hardware.touchscreen" android:required="false"' "$FIRE_MANIFEST" ||
  fail "Fire TV manifest must mark touchscreen optional"
grep -q 'android.intent.category.LEANBACK_LAUNCHER' "$FIRE_MANIFEST" ||
  fail "Fire TV manifest missing LEANBACK_LAUNCHER"
grep -q 'com.google.android.gms.cast.tv' "$FIRE_MANIFEST" &&
  fail "Fire TV manifest must not declare Cast Connect receiver metadata"
grep -q 'com.google.android.gms.ads.APPLICATION_ID' "$FIRE_MANIFEST" &&
  fail "Fire TV manifest must not declare AdMob APPLICATION_ID"
grep -q 'com.google.android.gms.car.application' "$FIRE_MANIFEST" &&
  fail "Fire TV manifest must not declare Android Auto metadata"
if grep -q 'com.google.android.gms.permission.AD_ID' "$FIRE_MANIFEST"; then
  grep -A1 'com.google.android.gms.permission.AD_ID' "$FIRE_MANIFEST" |
    grep -q 'tools:node="remove"' ||
    fail "Fire TV manifest must not request AD_ID (only tools:node=remove stubs allowed)"
fi

grep -q '"fireTv" -> "com.developerscoffee.tv.midas"' "$GRADLE_FILE" ||
  fail "Gradle must map fireTv variant to com.developerscoffee.tv.midas"
grep -q 'isFireTvVariant' "$GRADLE_FILE" ||
  fail "Gradle must define isFireTvVariant for Fire-specific gates"
grep -q 'play-services-cast-tv' "$GRADLE_FILE" ||
  fail "Gradle file missing cast-tv gate (expected Play-only dependency)"
grep -q 'if (isTvVariant)' "$GRADLE_FILE" ||
  fail "play-services-cast-tv must stay gated to Play TV (isTvVariant)"

# Shared TV pubspec / SDK / resource checks (Play TV uses the same IPTV graph).
AIRO_TV_MANIFEST="$FIRE_MANIFEST" \
  AIRO_TV_PACKAGE_NAME="com.developerscoffee.tv.midas" \
  bash "$ROOT_DIR/scripts/check-android-tv-release.sh"

echo "Fire TV release checks passed."
