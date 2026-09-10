#!/usr/bin/env bash
# packages/../scripts/regenerate-m3u-parser-frb.sh
# Regenerates m3u_parser's FRB bindings from packages/m3u_parser/rust.
#
# Requires flutter_rust_bridge_codegen 2.11.1 (pinned to match the crate's
# `flutter_rust_bridge = "=2.11.1"` dependency).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="${ROOT}/flutter_rust_bridge_m3u_parser.yaml"

if ! command -v flutter_rust_bridge_codegen >/dev/null 2>&1; then
  echo "Installing flutter_rust_bridge_codegen 2.11.1..."
  cargo install flutter_rust_bridge_codegen --version 2.11.1 --locked --force
fi

export PATH="${HOME}/.cargo/bin:${PATH}"

echo "Regenerating m3u_parser FRB bindings..."
cd "${ROOT}"
flutter_rust_bridge_codegen generate --config-file "${CONFIG}"

echo "Done. Review diffs in:"
echo "  packages/m3u_parser/lib/src/"
echo "  packages/m3u_parser/rust/src/frb_generated.rs"
