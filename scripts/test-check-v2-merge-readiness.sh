#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

"$ROOT_DIR/scripts/check-v2-merge-readiness.sh" --help >"$TMP_DIR/help.out"
grep -q "Locally dry-merge" "$TMP_DIR/help.out"

"$ROOT_DIR/scripts/check-v2-merge-readiness.sh" \
  --skip-fetch \
  --base HEAD \
  --next HEAD \
  --worktree "$TMP_DIR/self-merge" \
  >"$TMP_DIR/self-merge.out"

grep -q "Airo mainline merge-readiness dry run" "$TMP_DIR/self-merge.out"
grep -q "YAML parse: ok" "$TMP_DIR/self-merge.out"
grep -q "Whitespace check: ok" "$TMP_DIR/self-merge.out"
grep -Eq "V2 readiness preflight: (publicReady=true|unresolved gates remain)" \
  "$TMP_DIR/self-merge.out"

echo "check-v2-merge-readiness tests passed"
