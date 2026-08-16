#!/usr/bin/env bash
# Regenerates feature_mind whisper FRB bindings from rust/airo_mind_whisper.
#
# Requires Rust >= 1.88 and cargo-expand (for flutter_rust_bridge_codegen 2.11.1).
# On older toolchains, install explicitly:
#   rustup toolchain install 1.88.0
#   cargo +1.88.0 install cargo-expand --version 1.0.118 --locked

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FRB_TOOLCHAIN="${FRB_TOOLCHAIN:-1.88.0}"
CONFIG="${ROOT}/flutter_rust_bridge_mind_whisper.yaml"

if ! rustup toolchain list | grep -q "${FRB_TOOLCHAIN}"; then
  echo "Installing Rust ${FRB_TOOLCHAIN} for FRB codegen..."
  rustup toolchain install "${FRB_TOOLCHAIN}" --profile minimal
fi

rustup component add --toolchain "${FRB_TOOLCHAIN}" rustfmt 2>/dev/null || true

if ! cargo "+${FRB_TOOLCHAIN}" expand --version >/dev/null 2>&1; then
  echo "Installing cargo-expand for ${FRB_TOOLCHAIN}..."
  cargo "+${FRB_TOOLCHAIN}" install cargo-expand --version 1.0.118 --locked --force
fi

if ! command -v flutter_rust_bridge_codegen >/dev/null 2>&1; then
  echo "Installing flutter_rust_bridge_codegen 2.11.1..."
  cargo install flutter_rust_bridge_codegen --version 2.11.1 --locked --force
fi

export PATH="${HOME}/.cargo/bin:${PATH}"

echo "Regenerating whisper FRB (Rust ${FRB_TOOLCHAIN})..."
cd "${ROOT}"
RUSTUP_TOOLCHAIN="${FRB_TOOLCHAIN}" flutter_rust_bridge_codegen generate --config-file "${CONFIG}"

echo "Done. Review diffs in:"
echo "  packages/feature_mind/lib/src/whisper/"
echo "  rust/airo_mind_whisper/src/frb_generated.rs"
