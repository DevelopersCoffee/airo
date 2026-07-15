#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/generate-release-manifest.py"
TMP_DIR="$(mktemp -d "$ROOT_DIR/.tmp-release-manifest.XXXXXX")"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

mkdir -p "$TMP_DIR/artifacts"
printf 'apk-content' > "$TMP_DIR/artifacts/Airo-TV-v2.0.0.apk"
printf 'aab-content' > "$TMP_DIR/artifacts/Airo-TV-v2.0.0-Play-Store.aab"
printf 'zip-content' > "$TMP_DIR/artifacts/Airo-TV-v2.0.0-macOS.zip"
printf 'dmg-content' > "$TMP_DIR/artifacts/Airo-TV-v2.0.0-macOS.dmg"

python3 "$SCRIPT" \
  --artifacts-dir "$TMP_DIR/artifacts" \
  --profile-id tv \
  --version v2.0.0 \
  --build-number 200 \
  --source-ref v2 \
  --source-sha abc123 \
  --workflow-name "Release Test" \
  --workflow-run 42 \
  --workflow-run-attempt 1 \
  --repository DevelopersCoffee/airo \
  > "$TMP_DIR/generate.out"

grep -q "Airo-TV-v2.0.0.apk" "$TMP_DIR/artifacts/SHA256SUMS"
grep -q "Airo-TV-v2.0.0-Play-Store.aab" "$TMP_DIR/artifacts/SHA256SUMS"
grep -q "Airo-TV-v2.0.0-macOS.zip" "$TMP_DIR/artifacts/SHA256SUMS"
grep -q "Airo-TV-v2.0.0-macOS.dmg" "$TMP_DIR/artifacts/SHA256SUMS"

python3 - "$TMP_DIR/artifacts/Release-Manifest.json" <<'PY'
import json
import sys

manifest = json.load(open(sys.argv[1], encoding="utf-8"))
assert manifest["schemaVersion"] == 1
assert manifest["release"]["version"] == "v2.0.0"
assert manifest["release"]["buildNumber"] == "200"
assert manifest["release"]["sourceRef"] == "v2"
assert manifest["release"]["sourceSha"] == "abc123"
assert manifest["release"]["workflowRunUrl"].endswith("/actions/runs/42")

artifacts = {artifact["filename"]: artifact for artifact in manifest["artifacts"]}
apk = artifacts["Airo-TV-v2.0.0.apk"]
aab = artifacts["Airo-TV-v2.0.0-Play-Store.aab"]
macos_zip = artifacts["Airo-TV-v2.0.0-macOS.zip"]
macos_dmg = artifacts["Airo-TV-v2.0.0-macOS.dmg"]
assert apk["profileId"] == "tv"
assert apk["packageId"] == "io.airo.app.tv"
assert apk["artifactType"] == "apk"
assert apk["distributionChannel"] == "direct-apk"
assert apk["abi"] == "android-arm64"
assert len(apk["sha256"]) == 64
assert aab["artifactType"] == "aab"
assert aab["distributionChannel"] == "play-store"
assert len(aab["sha256"]) == 64
assert macos_zip["profileId"] == "tv"
assert macos_zip["packageId"] == "com.developerscoffee.airo.tv"
assert macos_zip["artifactType"] == "macos_zip"
assert macos_zip["distributionChannel"] == "direct-macos"
assert macos_zip["abi"] == "macos-universal"
assert macos_zip["macos"]["signingStatus"] == "unsigned"
assert macos_zip["macos"]["notarizationStatus"] == "not_notarized"
assert len(macos_zip["sha256"]) == 64
assert macos_dmg["artifactType"] == "macos_dmg"
assert macos_dmg["distributionChannel"] == "direct-macos"
assert len(macos_dmg["sha256"]) == 64
PY

mkdir -p "$TMP_DIR/macos"
printf 'zip-content' > "$TMP_DIR/macos/Airo-TV-v2.0.0-macOS.zip"
python3 "$SCRIPT" \
  --artifacts-dir "$TMP_DIR/macos" \
  --profile-id tv \
  --version v2.0.0 \
  --build-number 200 \
  --macos-signing-status signed \
  --macos-notarization-status notarized \
  > "$TMP_DIR/macos.out"

python3 - "$TMP_DIR/macos/Release-Manifest.json" <<'PY'
import json
import sys

manifest = json.load(open(sys.argv[1], encoding="utf-8"))
artifact = manifest["artifacts"][0]
assert artifact["filename"] == "Airo-TV-v2.0.0-macOS.zip"
assert artifact["profileId"] == "tv"
assert artifact["packageId"] == "com.developerscoffee.airo.tv"
assert artifact["artifactType"] == "macos_zip"
assert artifact["distributionChannel"] == "direct-macos"
assert artifact["macos"]["signingStatus"] == "signed"
assert artifact["macos"]["notarizationStatus"] == "notarized"
PY

mkdir -p "$TMP_DIR/empty"
if python3 "$SCRIPT" \
  --artifacts-dir "$TMP_DIR/empty" \
  --profile-id tv \
  > "$TMP_DIR/empty.out" 2>&1; then
  echo "Expected empty artifact directory to fail"
  exit 1
fi
grep -q "No APK or AAB artifacts found" "$TMP_DIR/empty.out"

echo "generate-release-manifest tests passed"
