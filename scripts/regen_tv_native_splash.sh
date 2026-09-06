#!/usr/bin/env bash
# Regenerate Aika Stream's Android 12+ native splash and clean up the parts
# flutter_native_splash always regenerates that this repo cannot use.
#
# Why the cleanup: app/android's TV source set (`src/tv/res`) is merged
# additively into the *same* "main" Android sourceSet (see
# app/android/app/build.gradle.kts), not a real Gradle product flavor. Value
# resources (styles.xml) and XML drawables with the same name in two res
# dirs on one sourceSet are a hard "Duplicate resources" build failure, not
# a silent override -- confirmed by an actual build. flutter_native_splash
# --flavor=tv still generates a full legacy (pre-Android-12) splash
# (drawable/launch_background.xml, drawable-v21/launch_background.xml,
# values/styles.xml, values-night/styles.xml) that collides with the
# phone app's own equivalents in src/main/res. This repo doesn't need that
# legacy path replaced -- main's existing dark-navy launch_background.xml
# is already reasonably branded for pre-12 devices, and the actual reported
# bug (a default white icon-background circle behind the launcher icon) is
# Android-12-specific. So: generate, then delete exactly the legacy-path
# output, keeping only the non-colliding values-v31/values-night-v31 styles
# and their android12splash.png assets.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT/app"

dart run flutter_native_splash:create --path=flutter_native_splash_tv.yaml --flavor=tv

rm -f android/app/src/tv/res/drawable/launch_background.xml
rm -f android/app/src/tv/res/drawable-v21/launch_background.xml
rm -f android/app/src/tv/res/values/styles.xml
rm -f android/app/src/tv/res/values-night/styles.xml
rm -f android/app/src/tv/res/drawable/background.png
for f in android/app/src/tv/res/drawable-*/background.png android/app/src/tv/res/drawable-*/splash.png; do
  [ -f "$f" ] && rm "$f"
done
find android/app/src/tv/res -type d -empty -delete

echo "Kept (Android 12+ only, no collision with src/main/res):"
find android/app/src/tv/res -iname "*android12splash*" -o -iname "styles.xml" | sort
