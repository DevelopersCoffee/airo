#!/usr/bin/env bash
# Product desktop build: whisper + ECAPA diarization with bundled ORT dylibs.
#
# Requires: source scripts/install-onnxruntime.sh (sets ORT_LIB_LOCATION, CXX, LIBRARY_PATH)
#
# Usage:
#   source scripts/install-onnxruntime.sh
#   scripts/build-whisper-ecapa-desktop.sh [extra cargo args...]

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "${ROOT}/scripts/install-onnxruntime.sh"

if [[ -z "${ORT_LIB_LOCATION:-}" ]]; then
  echo "ORT_LIB_LOCATION is not set — run: source scripts/install-onnxruntime.sh" >&2
  exit 1
fi

cd "${ROOT}/rust"
echo "Building airo_mind_whisper with whisper,ecapa,ecapa-bundle (ORT_LIB_LOCATION=${ORT_LIB_LOCATION})..."
cargo build -p airo_mind_whisper --release --features whisper,ecapa,ecapa-bundle "$@"
