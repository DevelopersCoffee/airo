#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# Positive case: real manifests in the repo must pass.
"$ROOT_DIR/scripts/check-module-manifests.py" >"$TMP_DIR/pass.out"
grep -q "module.yaml manifest(s) valid" "$TMP_DIR/pass.out"
grep -q "ok: packages/platform_epg/module.yaml" "$TMP_DIR/pass.out"

# Negative case: build a throwaway packages/ tree with a broken manifest and
# confirm each failure mode is caught.
FAKE_ROOT="$TMP_DIR/fake-repo"
mkdir -p "$FAKE_ROOT/packages/broken_pkg" "$FAKE_ROOT/.github"
cp "$ROOT_DIR/.github/council-roles.json" "$FAKE_ROOT/.github/council-roles.json"

cat > "$FAKE_ROOT/packages/broken_pkg/pubspec.yaml" << 'EOF'
name: broken_pkg
dependencies:
  core_ui:
    path: ../core_ui
  flutter:
    sdk: flutter
EOF

cat > "$FAKE_ROOT/packages/broken_pkg/module.yaml" << 'EOF'
name: wrong_name
owner: Nonexistent Role
reviewers:
  - Also Nonexistent
allowed_dependencies: []
forbidden_dependencies:
  - core_ui
EOF

# Run the real script against the fake tree: Path(__file__).resolve().parents[1]
# resolves to FAKE_ROOT because the script is copied under FAKE_ROOT/scripts/.
mkdir -p "$FAKE_ROOT/scripts"
cp "$ROOT_DIR/scripts/check-module-manifests.py" "$FAKE_ROOT/scripts/check-module-manifests.py"

set +e
(cd "$FAKE_ROOT" && python3 scripts/check-module-manifests.py) > "$TMP_DIR/fail.out" 2>&1
status=$?
set -e

if [ "$status" -eq 0 ]; then
  echo "expected broken manifest to fail validation" >&2
  cat "$TMP_DIR/fail.out" >&2
  exit 1
fi

grep -q "does not match pubspec.yaml name" "$TMP_DIR/fail.out"
grep -q "is not a known council role" "$TMP_DIR/fail.out"
grep -q "missing real path dependencies: core_ui" "$TMP_DIR/fail.out"
grep -q "forbidden_dependencies are actually depended on: core_ui" "$TMP_DIR/fail.out"

echo "check-module-manifests tests passed"
