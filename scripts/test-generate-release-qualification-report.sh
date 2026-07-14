#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/generate-release-qualification-report.py"
TMP_DIR="$(mktemp -d "$ROOT_DIR/.tmp-release-qualification.XXXXXX")"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

manifest="$TMP_DIR/manifest.json"
evidence="$TMP_DIR/evidence.json"
report="$TMP_DIR/Release-Qualification-Report.md"

cat >"$manifest" <<'JSON'
{
  "schemaVersion": 1,
  "release": {
    "version": "v2.0.0",
    "buildNumber": "200"
  },
  "artifacts": [
    {
      "filename": "Airo-TV-v2.0.0.apk",
      "profileId": "tv",
      "packageId": "io.airo.app.tv",
      "artifactType": "apk",
      "sha256": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    }
  ]
}
JSON

cat >"$evidence" <<'JSON'
{
  "schemaVersion": 1,
  "checks": [
    {
      "profileId": "tv",
      "filename": "Airo-TV-v2.0.0.apk",
      "deviceClass": "android-tv",
      "checkType": "physical-device",
      "deviceModel": "Chromecast with Google TV",
      "osVersion": "Android 12",
      "result": "passed",
      "notes": "Installed release APK and launched Leanback entrypoint."
    }
  ],
  "waivers": [
    {
      "profileId": "tv",
      "filename": "Airo-TV-v2.0.0.apk",
      "deviceClass": "fire-tv",
      "reason": "Fire TV remains compatible/experimental for this release.",
      "approvedBy": "release-manager"
    }
  ]
}
JSON

python3 "$SCRIPT" \
  --manifest "$manifest" \
  --evidence "$evidence" \
  --mode public \
  > "$TMP_DIR/pass.out"

grep -q "Airo-TV-v2.0.0.apk" "$report"
grep -q "aaaaaaaaaaaa" "$report"
grep -q "Chromecast with Google TV" "$report"
grep -q "Android 12" "$report"
grep -q "passed" "$report"
grep -q "waived" "$report"

cat >"$evidence" <<'JSON'
{
  "schemaVersion": 1,
  "checks": []
}
JSON

if python3 "$SCRIPT" \
  --manifest "$manifest" \
  --evidence "$evidence" \
  --mode public \
  > "$TMP_DIR/fail.out" 2>&1; then
  echo "Expected public mode to fail without required evidence"
  exit 1
fi
grep -q "missing 2 required evidence" "$TMP_DIR/fail.out"

cat >"$evidence" <<'JSON'
{
  "schemaVersion": 1,
  "checks": [
    {
      "profileId": "tv",
      "filename": "Airo-TV-v2.0.0.apk",
      "deviceClass": "android-tv",
      "checkType": "smoke-test",
      "deviceModel": "Chromecast with Google TV",
      "osVersion": "Android 12",
      "result": "passed",
      "notes": "Wrong evidence type for release qualification."
    }
  ]
}
JSON

if python3 "$SCRIPT" \
  --manifest "$manifest" \
  --evidence "$evidence" \
  --mode public \
  > "$TMP_DIR/wrong-type.out" 2>&1; then
  echo "Expected public mode to fail when evidence checkType does not match"
  exit 1
fi
grep -q "missing 2 required evidence" "$TMP_DIR/wrong-type.out"

python3 "$SCRIPT" \
  --manifest "$manifest" \
  --evidence "$evidence" \
  --mode internal \
  > "$TMP_DIR/internal.out"
grep -q "missing" "$report"

echo "generate-release-qualification-report tests passed"
