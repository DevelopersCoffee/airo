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
assert apk["profileId"] == "tv"
assert apk["packageId"] == "io.airo.app.tv"
assert apk["artifactType"] == "apk"
assert apk["distributionChannel"] == "direct-apk"
assert apk["abi"] == "android-arm64"
assert len(apk["sha256"]) == 64
assert aab["artifactType"] == "aab"
assert aab["distributionChannel"] == "play-store"
assert len(aab["sha256"]) == 64
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
