#!/usr/bin/env bash
# Regenerates feature_mind llama FRB bindings from rust/airo_mind_llama.
#
# Requires Rust >= 1.88 and cargo-expand (for flutter_rust_bridge_codegen 2.11.1).
# On older toolchains, install explicitly:
#   rustup toolchain install 1.88.0
#   cargo +1.88.0 install cargo-expand --version 1.0.118 --locked

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FRB_TOOLCHAIN="${FRB_TOOLCHAIN:-1.88.0}"
CONFIG="${ROOT}/flutter_rust_bridge_mind_llama.yaml"

if ! rustup toolchain list | grep -q "${FRB_TOOLCHAIN}"; then
  echo "Installing Rust ${FRB_TOOLCHAIN} for FRB codegen..."
  rustup toolchain install "${FRB_TOOLCHAIN}" --profile minimal
fi

rustup component add --toolchain "${FRB_TOOLCHAIN}" rustfmt 2>/dev/null || true

# Homebrew cargo does not understand `+toolchain`. Prefer rustup's cargo.
CARGO="$(rustup which cargo --toolchain "${FRB_TOOLCHAIN}")"
TOOLCHAIN_BIN="$(dirname "${CARGO}")"
export PATH="${TOOLCHAIN_BIN}:${HOME}/.cargo/bin:${PATH}"

if ! "${CARGO}" expand --version >/dev/null 2>&1; then
  echo "Installing cargo-expand for ${FRB_TOOLCHAIN}..."
  "${CARGO}" install cargo-expand --version 1.0.118 --locked --force
fi

echo "Regenerating llama FRB (Rust ${FRB_TOOLCHAIN})..."
cd "${ROOT}"
RUSTUP_TOOLCHAIN="${FRB_TOOLCHAIN}" flutter_rust_bridge_codegen generate --config-file "${CONFIG}"

echo "Done. Review diffs in:"
echo "  packages/feature_mind/lib/src/llama/"
echo "  rust/airo_mind_llama/src/frb_generated.rs"
