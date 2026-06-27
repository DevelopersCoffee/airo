#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$TMP_DIR/scripts"
cp "$ROOT_DIR/scripts/check-module-sizes.sh" "$TMP_DIR/scripts/check-module-sizes.sh"
chmod +x "$TMP_DIR/scripts/check-module-sizes.sh"
mkdir -p "$TMP_DIR/packages/small/lib" "$TMP_DIR/packages/large/lib" "$TMP_DIR/packages/plugins/large_plugin/lib"

cat >"$TMP_DIR/packages/small/pubspec.yaml" <<'YAML'
name: small
YAML
printf 'small' >"$TMP_DIR/packages/small/lib/small.dart"

cat >"$TMP_DIR/packages/large/pubspec.yaml" <<'YAML'
name: large
YAML
python3 - <<'PY' >"$TMP_DIR/packages/large/lib/blob.bin"
import sys
sys.stdout.buffer.write(b'x' * (4 * 1024 * 1024))
PY

cat >"$TMP_DIR/packages/plugins/large_plugin/pubspec.yaml" <<'YAML'
name: large_plugin
airo_plugin: true
YAML
python3 - <<'PY' >"$TMP_DIR/packages/plugins/large_plugin/lib/blob.bin"
import sys
sys.stdout.buffer.write(b'x' * (4 * 1024 * 1024))
PY

(
  cd "$TMP_DIR"
  git init -q
  git config user.email test@example.com
  git config user.name test
  git add .
  git commit -qm initial
)

set +e
(
  cd "$TMP_DIR"
  MODULE_SIZE_CHANGED_ONLY=false MODULE_SIZE_REPORT_FILE=report.md scripts/check-module-sizes.sh >/tmp/check-module-sizes-large.out 2>&1
)
status=$?
set -e
if [ "$status" -eq 0 ]; then
  echo "Expected large bundled module to fail"
  cat /tmp/check-module-sizes-large.out
  exit 1
fi
grep -q 'packages/large' /tmp/check-module-sizes-large.out
grep -q 'exceeds 3 MB bundled-module limit' /tmp/check-module-sizes-large.out
grep -q 'packages/plugins/large_plugin' /tmp/check-module-sizes-large.out

rm -rf "$TMP_DIR/packages/large"
(
  cd "$TMP_DIR"
  MODULE_SIZE_CHANGED_ONLY=false MODULE_SIZE_REPORT_FILE=report.md scripts/check-module-sizes.sh >/tmp/check-module-sizes-plugin.out 2>&1
)
grep -q 'Plugin Module Size Gate' /tmp/check-module-sizes-plugin.out
grep -q 'packages/plugins/large_plugin' /tmp/check-module-sizes-plugin.out

echo "check-module-sizes tests passed"
