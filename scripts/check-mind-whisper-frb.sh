#!/usr/bin/env bash
# CI gate: regenerated whisper FRB bindings must match committed output.
#
# Requires Rust >= 1.88 and cargo-expand (see regenerate-mind-whisper-frb.sh).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v dart >/dev/null 2>&1 && ! command -v flutter >/dev/null 2>&1; then
  echo "Skipping Mind whisper FRB bindings check: Dart/Flutter toolchain not available."
  exit 0
fi

"${ROOT}/scripts/regenerate-mind-whisper-frb.sh"

cd "${ROOT}"
if git diff --quiet -- packages/feature_mind/lib/src/whisper rust/airo_mind_whisper/src/frb_generated.rs; then
  echo "Mind whisper FRB bindings are up to date."
else
  echo "Mind whisper FRB bindings are stale. Run scripts/regenerate-mind-whisper-frb.sh and commit." >&2
  git diff --stat -- packages/feature_mind/lib/src/whisper rust/airo_mind_whisper/src/frb_generated.rs >&2
  exit 1
fi
