#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

ARTIFACT_DIR="$TMP_DIR/artifacts"
OUTPUT_DIR="$TMP_DIR/report"
APP_DIR="$TMP_DIR/Airo TV.app/Contents"

mkdir -p "$ARTIFACT_DIR" "$APP_DIR/MacOS"
printf '%s\n' 'Airo TV' > "$APP_DIR/MacOS/Airo TV"
printf '%s\n' '<plist version="1.0"><dict/></plist>' > "$APP_DIR/Info.plist"
(cd "$TMP_DIR" && zip -qr "$ARTIFACT_DIR/Airo-TV-v2.0.0-macOS.zip" 'Airo TV.app')

AIRO_RELEASE_ARTIFACT_DIR="$ARTIFACT_DIR" \
AIRO_RELEASE_QUALIFICATION_DIR="$OUTPUT_DIR" \
"$ROOT_DIR/scripts/release-artifact-smoke.sh" --require-artifacts

grep -q '"kind": "macos_zip"' "$OUTPUT_DIR/artifact-inventory.jsonl"
grep -q 'macOS ZIP integrity and app bundle presence verified' \
  "$OUTPUT_DIR/artifact-inventory.jsonl"

INVALID_ARTIFACT_DIR="$TMP_DIR/invalid-artifacts"
INVALID_OUTPUT_DIR="$TMP_DIR/invalid-report"
mkdir -p "$INVALID_ARTIFACT_DIR"
printf 'not a zip archive' > "$INVALID_ARTIFACT_DIR/Airo-TV-v2.0.0-macOS.zip"

set +e
AIRO_RELEASE_ARTIFACT_DIR="$INVALID_ARTIFACT_DIR" \
  AIRO_RELEASE_QUALIFICATION_DIR="$INVALID_OUTPUT_DIR" \
  "$ROOT_DIR/scripts/release-artifact-smoke.sh" --require-artifacts
status=$?
set -e

if [ "$status" -eq 0 ]; then
  echo 'expected invalid macOS ZIP smoke check to fail' >&2
  exit 1
fi

grep -q '"kind": "macos_zip"' "$INVALID_OUTPUT_DIR/artifact-inventory.jsonl"
grep -q 'macOS ZIP integrity failed' "$INVALID_OUTPUT_DIR/artifact-inventory.jsonl"

echo 'release-artifact-smoke tests passed'
