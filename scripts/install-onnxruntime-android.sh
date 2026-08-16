#!/usr/bin/env bash
# Installs ONNX Runtime 1.20 static libs for Android arm64-v8a (ort 2.0.0-rc.9).
#
# Source: csukuangfj/onnxruntime-libs (community static builds matching ORT 1.20).
# Product Mind Android builds pick this up automatically when present — see
# packages/feature_mind/cargokit/build_tool/lib/src/builder.dart.
#
# Usage:
#   source scripts/install-onnxruntime-android.sh
#   # or: scripts/install-onnxruntime-android.sh && export ORT_LIB_LOCATION=...

set -euo pipefail

ORT_VERSION="1.20.0"
ORT_ZIP="onnxruntime-android-arm64-v8a-static_lib-${ORT_VERSION}.zip"
ORT_URL="https://huggingface.co/csukuangfj/onnxruntime-libs/resolve/main/${ORT_ZIP}"
ORT_HASH="e97c30611318aaf9fb25b8782f6744e5f29f3f18caf8bf4eb0ca564afc50e77e"
TARGET_DIR="${HOME}/.airo/onnxruntime/${ORT_VERSION}/android-arm64"
EXTRACT_ROOT="${TARGET_DIR}/${ORT_ZIP%.zip}"
MARKER="${TARGET_DIR}/.installed"

if [[ -f "${MARKER}" && -f "${EXTRACT_ROOT}/lib/libonnxruntime.a" ]]; then
  echo "ONNX Runtime Android ${ORT_VERSION} already installed at ${EXTRACT_ROOT}"
else
  TMP="$(mktemp -d)"
  echo "Downloading ONNX Runtime Android ${ORT_VERSION} static libs (~170 MB)..."
  curl -fsSL "${ORT_URL}" -o "${TMP}/ort.zip"
  ACTUAL_HASH="$(sha256sum "${TMP}/ort.zip" | awk '{print $1}')"
  if [[ "${ACTUAL_HASH}" != "${ORT_HASH}" ]]; then
    echo "ORT archive hash mismatch: expected ${ORT_HASH}, got ${ACTUAL_HASH}" >&2
    exit 1
  fi
  rm -rf "${TARGET_DIR}"
  mkdir -p "${TARGET_DIR}"
  unzip -q "${TMP}/ort.zip" -d "${TARGET_DIR}"
  touch "${MARKER}"
  rm -rf "${TMP}"
  echo "Installed ONNX Runtime Android ${ORT_VERSION} to ${EXTRACT_ROOT}"
fi

export ORT_LIB_LOCATION="${EXTRACT_ROOT}"
export ORT_CXX_STDLIB="c++_shared"

if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  : # sourced
else
  echo "ORT_LIB_LOCATION=${ORT_LIB_LOCATION}"
  echo "Export before building: export ORT_LIB_LOCATION=\"${ORT_LIB_LOCATION}\""
fi
