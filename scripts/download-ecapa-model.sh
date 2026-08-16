#!/usr/bin/env bash
# Downloads pinned ECAPA ONNX weights for local e2e / CI (vedk00 HF mirror).
#
# Usage:
#   source scripts/download-ecapa-model.sh
#   # sets AIRO_ECAPA_MODEL_PATH to $HOME/.airo/models/ecapa_tdnn_tiny_int8.onnx

set -euo pipefail

MODEL_DIR="${AIRO_MODELS_DIR:-${HOME}/.airo/models}"
MODEL_FILE="ecapa_tdnn_tiny_int8.onnx"
MODEL_PATH="${MODEL_DIR}/${MODEL_FILE}"
EXPECTED_SHA="f46380bbaeddb929fb3a10ab63a4b1877a50e3d1e5fdd55a1b618d5651d3f64e"
EXPECTED_BYTES=83476039
URL="https://huggingface.co/vedk00/ecapa-voxceleb-speaker-embedding-onnx/resolve/main/model/ecapa-speaker-v1.onnx"

verify_model() {
  local path="$1"
  [[ -f "${path}" ]] || return 1
  local size
  size="$(stat -c%s "${path}" 2>/dev/null || stat -f%z "${path}")"
  [[ "${size}" -eq "${EXPECTED_BYTES}" ]] || return 1
  local actual
  actual="$(sha256sum "${path}" | awk '{print $1}')"
  [[ "${actual}" == "${EXPECTED_SHA}" ]]
}

if verify_model "${MODEL_PATH}"; then
  echo "ECAPA model already present at ${MODEL_PATH}"
else
  mkdir -p "${MODEL_DIR}"
  TMP="$(mktemp)"
  echo "Downloading ECAPA ONNX (${EXPECTED_BYTES} bytes)..."
  curl -fsSL "${URL}" -o "${TMP}"
  actual_sha="$(sha256sum "${TMP}" | awk '{print $1}')"
  if [[ "${actual_sha}" != "${EXPECTED_SHA}" ]]; then
    echo "ECAPA hash mismatch: expected ${EXPECTED_SHA}, got ${actual_sha}" >&2
    rm -f "${TMP}"
    exit 1
  fi
  mv "${TMP}" "${MODEL_PATH}"
  echo "Installed ECAPA model to ${MODEL_PATH}"
fi

export AIRO_ECAPA_MODEL_PATH="${MODEL_PATH}"

if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  : # sourced
else
  echo "AIRO_ECAPA_MODEL_PATH=${AIRO_ECAPA_MODEL_PATH}"
fi
