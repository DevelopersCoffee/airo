#!/usr/bin/env bash
set -euo pipefail

PUB_CACHE_DIR="${PUB_CACHE:-$HOME/.pub-cache}"
STOCKFISH_GRADLE="$PUB_CACHE_DIR/hosted/pub.dev/stockfish-1.8.1/android/build.gradle"

if [[ ! -f "$STOCKFISH_GRADLE" ]]; then
  echo "stockfish Android Gradle file not found; skipping patch"
elif grep -q 'jcenter()' "$STOCKFISH_GRADLE"; then
  sed -i.bak 's/jcenter()/mavenCentral()/g' "$STOCKFISH_GRADLE"
  rm -f "$STOCKFISH_GRADLE.bak"
  echo "Patched stockfish Android Gradle repositories from jcenter() to mavenCentral()"
else
  echo "stockfish Android Gradle repositories already patched"
fi

for FILE_PICKER_GRADLE in "$PUB_CACHE_DIR"/hosted/pub.dev/file_picker-*/android/build.gradle; do
  [[ -f "$FILE_PICKER_GRADLE" ]] || continue

  if grep -q "^    apply plugin: 'org.jetbrains.kotlin.android'" "$FILE_PICKER_GRADLE"; then
    perl -0pi.bak -e "s/if \\(!isAgp9OrAbove\\) \\{\\n    apply plugin: 'org\\.jetbrains\\.kotlin\\.android'\\n\\}/apply plugin: 'org.jetbrains.kotlin.android'/g" "$FILE_PICKER_GRADLE"
    rm -f "$FILE_PICKER_GRADLE.bak"
    echo "Patched file_picker Android Gradle to apply Kotlin plugin with AGP 9 compatibility flags"
  else
    echo "file_picker Android Gradle Kotlin plugin patch already applied"
  fi
done
