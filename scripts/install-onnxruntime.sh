#!/usr/bin/env bash
# Installs ONNX Runtime 1.20 static libs for ort 2.0.0-rc.9 / ort-sys linking.
#
# Usage:
#   source scripts/install-onnxruntime.sh
#   # or: scripts/install-onnxruntime.sh && export ORT_LIB_LOCATION=...
#
# Sets ORT_LIB_LOCATION when sourced. Does not use ort's download-binaries feature
# (avoids edition2024 transitive deps on older Rust toolchains).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ORT_VERSION="1.20.0"
ORT_HASH="F88A8C1E4B4813A1CFA79AF3F35B23ADDF2F0F36E66C5CD7C88103CB9B30509D"
ORT_URL="https://parcel.pyke.io/v2/delivery/ortrs/packages/msort-binary/${ORT_VERSION}/ortrs_static-v${ORT_VERSION}-x86_64-unknown-linux-gnu.tgz"

case "$(uname -s)-$(uname -m)" in
  Linux-x86_64) TARGET_DIR="${HOME}/.airo/onnxruntime/${ORT_VERSION}/linux-x64" ;;
  Linux-aarch64)
    ORT_HASH="76F8BAD14294874115F687DF7C09FB4EF0800ED928096F504AE666298E31A136"
    ORT_URL="https://parcel.pyke.io/v2/delivery/ortrs/packages/msort-binary/${ORT_VERSION}/ortrs_static-v${ORT_VERSION}-aarch64-unknown-linux-gnu.tgz"
    TARGET_DIR="${HOME}/.airo/onnxruntime/${ORT_VERSION}/linux-arm64"
    ;;
  Darwin-arm64)
    ORT_HASH="5EAFA0AF54D630C4D4D9F459CB95E3CFF442993F0FFA50402695186F9B1A38A5"
    ORT_URL="https://parcel.pyke.io/v2/delivery/ortrs/packages/msort-binary/${ORT_VERSION}/ortrs_static-v${ORT_VERSION}-aarch64-apple-darwin.tgz"
    TARGET_DIR="${HOME}/.airo/onnxruntime/${ORT_VERSION}/macos-arm64"
    ;;
  Darwin-x86_64)
    ORT_HASH="876174AEC9DC8422E9A757A0D1C5F0DF4F0A32B2FED6E4C7E4183DFD80F65AEF"
    ORT_URL="https://parcel.pyke.io/v2/delivery/ortrs/packages/msort-binary/${ORT_VERSION}/ortrs_static-v${ORT_VERSION}-x86_64-apple-darwin.tgz"
    TARGET_DIR="${HOME}/.airo/onnxruntime/${ORT_VERSION}/macos-x64"
    ;;
  *)
    echo "install-onnxruntime.sh: unsupported platform $(uname -s)-$(uname -m)" >&2
    exit 1
    ;;
esac

MARKER="${TARGET_DIR}/.installed"
if [[ -f "${MARKER}" ]]; then
  echo "ONNX Runtime ${ORT_VERSION} already installed at ${TARGET_DIR}"
else
  TMP="$(mktemp -d)"
  echo "Downloading ONNX Runtime ${ORT_VERSION} static libs..."
  curl -fsSL "${ORT_URL}" -o "${TMP}/ort.tgz"
  ACTUAL_HASH="$(sha256sum "${TMP}/ort.tgz" | awk '{print $1}')"
  if [[ "${ACTUAL_HASH}" != "$(echo "${ORT_HASH}" | tr '[:upper:]' '[:lower:]')" ]]; then
    echo "ORT archive hash mismatch: expected ${ORT_HASH}, got ${ACTUAL_HASH}" >&2
    exit 1
  fi
  rm -rf "${TARGET_DIR}"
  mkdir -p "${TARGET_DIR}"
  tar -xzf "${TMP}/ort.tgz" -C "${TARGET_DIR}" --strip-components=1
  touch "${MARKER}"
  rm -rf "${TMP}"
  echo "Installed ONNX Runtime ${ORT_VERSION} to ${TARGET_DIR}"
fi

export ORT_LIB_LOCATION="${TARGET_DIR}"

case "$(uname -s)" in
  Darwin)
    # whisper-rs-sys links -lstdc++; macOS SDK only ships libc++. Homebrew gcc
    # provides libstdc++ for Apple Silicon / modern Xcode toolchains.
    export CXX="${CXX:-clang++}"
    export ORT_CXX_STDLIB="${ORT_CXX_STDLIB:-c++}"
    if command -v brew >/dev/null 2>&1; then
      _gcc_prefix="$(brew --prefix gcc 2>/dev/null || true)"
      if [[ -n "${_gcc_prefix}" ]]; then
        for _libdir in "${_gcc_prefix}/lib/gcc/current" "${_gcc_prefix}"/lib/gcc/*; do
          if [[ -f "${_libdir}/libstdc++.a" || -f "${_libdir}/libstdc++.dylib" ]]; then
            export LIBRARY_PATH="${_libdir}${LIBRARY_PATH:+:${LIBRARY_PATH}}"
            export DYLD_LIBRARY_PATH="${_libdir}${DYLD_LIBRARY_PATH:+:${DYLD_LIBRARY_PATH}}"
            break
          fi
        done
      fi
    fi
    ;;
  *)
    export ORT_CXX_STDLIB="${ORT_CXX_STDLIB:-stdc++}"
    # Static ORT links libstdc++; rustc invokes `cc` by default, so point at g++'s
    # lib search path (same fix as product whisper builds with ecapa-ort).
    export CXX="${CXX:-g++}"
    _gcc_libdir="$(gcc -print-file-name=libstdc++.a 2>/dev/null | xargs dirname 2>/dev/null || true)"
    if [[ -n "${_gcc_libdir}" && -d "${_gcc_libdir}" && "${_gcc_libdir}" != "." ]]; then
      export LIBRARY_PATH="${_gcc_libdir}${LIBRARY_PATH:+:${LIBRARY_PATH}}"
    fi
    ;;
esac

if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  : # sourced — ORT_LIB_LOCATION is now set in the caller shell
else
  echo "ORT_LIB_LOCATION=${ORT_LIB_LOCATION}"
  echo "Export before building: export ORT_LIB_LOCATION=\"${ORT_LIB_LOCATION}\""
fi
