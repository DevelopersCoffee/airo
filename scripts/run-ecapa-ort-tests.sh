#!/usr/bin/env bash
# Runs airo_mind_diarize tests with ecapa-ort linked against system ONNX Runtime.
#
# CI and local dev: avoids ort's download-binaries (edition2024 deps on Rust 1.83).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if command -v apt-get >/dev/null 2>&1; then
  if ! command -v g++ >/dev/null 2>&1; then
    echo "Installing C++ toolchain for ort static link..."
    if command -v sudo >/dev/null 2>&1; then
      sudo apt-get update -qq
      sudo apt-get install -y -qq build-essential g++ libstdc++-13-dev
    else
      apt-get update -qq
      apt-get install -y -qq build-essential g++ libstdc++-13-dev
    fi
  fi
fi

# shellcheck source=/dev/null
source "${ROOT}/scripts/install-onnxruntime.sh"

cd "${ROOT}/rust"

echo "Running airo_mind_diarize tests with ecapa-ort (ORT_LIB_LOCATION=${ORT_LIB_LOCATION})..."
cargo test -p airo_mind_diarize --features ecapa-ort

if [[ "${AIRO_ECAPA_E2E:-}" == "1" ]]; then
  echo "Running ECAPA e2e tests (ignored by default)..."
  # shellcheck source=/dev/null
  source "${ROOT}/scripts/download-ecapa-model.sh"
  cargo test -p airo_mind_diarize --features ecapa-ort --test ecapa_onnx_e2e -- --ignored --test-threads=1
fi
