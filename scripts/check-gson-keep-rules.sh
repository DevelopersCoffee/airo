#!/usr/bin/env bash
# Guard the R8 keep rules that scheduled notifications depend on.
#
# flutter_local_notifications persists each scheduled notification as JSON and
# reads it back with Gson when the alarm fires. Gson maps JSON keys onto field
# names, so R8 renaming the fields of NotificationDetails turns every persisted
# notification into null fields. The plugin ships no consumer ProGuard rules, so
# the app's own proguard-rules.pro is the only thing holding this together.
#
# Nothing else can catch a regression here: debug builds have no R8, widget
# tests never reach the Android receiver, and `show()` bypasses Gson entirely,
# so immediate notifications keep working while scheduled ones silently die.
# That makes these rules easy to "tidy up" and impossible to notice losing.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RULES="$ROOT_DIR/app/android/app/proguard-rules.pro"

if [ ! -f "$RULES" ]; then
  echo "::error::ProGuard rules not found: $RULES"
  exit 1
fi

# Every Android flavour builds from this one ProGuard file but declares its own
# dependencies, so the plugin has to be looked for across all of them. Checking
# only app/pubspec.yaml would let the guard fall silent if the phone flavour
# dropped the plugin while Airo TV -- which schedules EPG reminders -- kept it.
users=()
for pubspec in "$ROOT_DIR"/app/pubspec*.yaml; do
  [ -f "$pubspec" ] || continue
  if grep -q "flutter_local_notifications" "$pubspec"; then
    users+=("$(basename "$pubspec")")
  fi
done

if [ ${#users[@]} -eq 0 ]; then
  echo "No flavour depends on flutter_local_notifications; Gson keep rules not required."
  exit 0
fi

echo "Flavours scheduling notifications: ${users[*]}"

missing=()
require() {
  grep -qF -- "$1" "$RULES" || missing+=("$1")
}

# The Gson-serialized models and their fields. Both rules are checked in full
# rather than by shared substring: the class-level and member-level rules share
# the `...models.` prefix, so a prefix match would still pass with one of them
# deleted -- which a mutation test caught.
require "-keep class com.dexterous.flutterlocalnotifications.models.** { *; }"
require "-keepclassmembers class com.dexterous.flutterlocalnotifications.models.** { <fields>; }"
# Polymorphic style types (BigTextStyleInformation and friends) resolve by name.
require "com.dexterous.flutterlocalnotifications.RuntimeTypeAdapterFactory"
# Anonymous TypeToken subclasses carry the generic signature Gson needs.
require "com.google.gson.reflect.TypeToken"
# TypeToken cannot resolve generics without the Signature attribute.
require "-keepattributes Signature"

if [ ${#missing[@]} -gt 0 ]; then
  for m in "${missing[@]}"; do
    echo "::error file=app/android/app/proguard-rules.pro::Missing R8 keep rule: $m"
  done
  echo "::error::Scheduled notifications deserialize through Gson and will silently"
  echo "::error::produce empty notifications in release builds without these rules."
  exit 1
fi

echo "Gson keep rules for scheduled notifications are present."
