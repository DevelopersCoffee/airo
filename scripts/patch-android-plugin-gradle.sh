#!/usr/bin/env bash
set -euo pipefail

PUB_CACHE_DIR="${PUB_CACHE:-$HOME/.pub-cache}"
STOCKFISH_GRADLE="$PUB_CACHE_DIR/hosted/pub.dev/stockfish-1.8.1/android/build.gradle"

if [[ ! -f "$STOCKFISH_GRADLE" ]]; then
  echo "stockfish Android Gradle file not found; skipping patch"
  exit 0
fi

if grep -q 'jcenter()' "$STOCKFISH_GRADLE"; then
  sed -i.bak 's/jcenter()/mavenCentral()/g' "$STOCKFISH_GRADLE"
  rm -f "$STOCKFISH_GRADLE.bak"
  echo "Patched stockfish Android Gradle repositories from jcenter() to mavenCentral()"
else
  echo "stockfish Android Gradle repositories already patched"
fi
