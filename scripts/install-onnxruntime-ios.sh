#!/usr/bin/env bash
# Installs ONNX Runtime 1.20 XCFramework for ort iOS static linking.
#
# Usage:
#   source scripts/install-onnxruntime-ios.sh
#   # or: scripts/install-onnxruntime-ios.sh && export ORT_IOS_XCFWK_LOCATION=...
#
# Sets ORT_IOS_XCFWK_LOCATION when sourced. ort-sys expects:
#   ${ORT_IOS_XCFWK_LOCATION}/ios-arm64/onnxruntime.framework
#   ${ORT_IOS_XCFWK_LOCATION}/ios-arm64_x86_64-simulator/onnxruntime.framework

set -euo pipefail

ORT_VERSION="1.20.0"
TARGET_DIR="${HOME}/.airo/onnxruntime/${ORT_VERSION}/ios-xcframework"
ZIP_URL="https://download.onnxruntime.ai/pod-archive-onnxruntime-c-${ORT_VERSION}.zip"
MARKER="${TARGET_DIR}/.installed"

if [[ -f "${MARKER}" ]]; then
  echo "ONNX Runtime iOS ${ORT_VERSION} already installed at ${TARGET_DIR}"
else
  TMP="$(mktemp -d)"
  echo "Downloading ONNX Runtime iOS ${ORT_VERSION} pod archive..."
  curl -fsSL "${ZIP_URL}" -o "${TMP}/ort-ios.zip"
  unzip -q "${TMP}/ort-ios.zip" -d "${TMP}/extract"
  XCFWK="$(find "${TMP}/extract" -name 'onnxruntime.xcframework' -type d | head -1)"
  if [[ -z "${XCFWK}" ]]; then
    echo "install-onnxruntime-ios.sh: onnxruntime.xcframework not found in archive" >&2
    rm -rf "${TMP}"
    exit 1
  fi
  rm -rf "${TARGET_DIR}"
  mkdir -p "${TARGET_DIR}"
  for slice in ios-arm64 ios-arm64_x86_64-simulator; do
    if [[ -d "${XCFWK}/${slice}/onnxruntime.framework" ]]; then
      mkdir -p "${TARGET_DIR}/${slice}"
      cp -R "${XCFWK}/${slice}/onnxruntime.framework" "${TARGET_DIR}/${slice}/"
    fi
  done
  touch "${MARKER}"
  rm -rf "${TMP}"
  echo "Installed ONNX Runtime iOS ${ORT_VERSION} to ${TARGET_DIR}"
fi

export ORT_IOS_XCFWK_LOCATION="${TARGET_DIR}"

if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  :
else
  echo "ORT_IOS_XCFWK_LOCATION=${ORT_IOS_XCFWK_LOCATION}"
  echo "Export before building: export ORT_IOS_XCFWK_LOCATION=\"${ORT_IOS_XCFWK_LOCATION}\""
fi
