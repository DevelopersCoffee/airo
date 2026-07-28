#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MERGER="$ROOT_DIR/scripts/merge-apk-size-baselines.py"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

mkdir -p "$TMP_DIR/updates"

cat >"$TMP_DIR/baseline.tsv" <<'EOF'
# APK size guardrail baselines.
component	artifact	baseline_bytes	budget_mb
full	app-arm64-v8a-release.apk	100	35
tv	app-arm64-v8a-release.apk	200	35
coins	app-arm64-v8a-release.apk	300	25
EOF

cat >"$TMP_DIR/updates/full.tsv" <<'EOF'
full	app-arm64-v8a-release.apk	110	35
EOF

cat >"$TMP_DIR/updates/tv.tsv" <<'EOF'
tv	app-arm64-v8a-release.apk	220	35
EOF

python3 "$MERGER" \
  --baseline "$TMP_DIR/baseline.tsv" \
  --updates-dir "$TMP_DIR/updates" \
  --output "$TMP_DIR/merged.tsv"

cat >"$TMP_DIR/expected.tsv" <<'EOF'
# APK size guardrail baselines.
#
# Columns:
# component: CI build component that produced the APK.
# artifact: APK file name produced by Flutter.
# baseline_bytes: approved baseline size in bytes.
# budget_mb: absolute artifact budget in MiB.
#
# This file is updated automatically after successful main builds.
component	artifact	baseline_bytes	budget_mb
coins	app-arm64-v8a-release.apk	300	25
full	app-arm64-v8a-release.apk	110	35
tv	app-arm64-v8a-release.apk	220	35
EOF

diff -u "$TMP_DIR/expected.tsv" "$TMP_DIR/merged.tsv"

cat >"$TMP_DIR/updates/malformed.tsv" <<'EOF'
broken	too-few-columns
EOF

if python3 "$MERGER" \
  --baseline "$TMP_DIR/baseline.tsv" \
  --updates-dir "$TMP_DIR/updates" \
  --output "$TMP_DIR/invalid.tsv"; then
  echo "FAIL: malformed update unexpectedly succeeded" >&2
  exit 1
fi
rm "$TMP_DIR/updates/malformed.tsv"

cat >"$TMP_DIR/updates/duplicate.tsv" <<'EOF'
full	app-arm64-v8a-release.apk	115	35
EOF

if python3 "$MERGER" \
  --baseline "$TMP_DIR/baseline.tsv" \
  --updates-dir "$TMP_DIR/updates" \
  --output "$TMP_DIR/duplicate.tsv"; then
  echo "FAIL: duplicate update key unexpectedly succeeded" >&2
  exit 1
fi

echo "merge APK size baseline tests passed"
