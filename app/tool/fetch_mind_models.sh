#!/usr/bin/env bash
# Seeds a local dev cache of Airo Mind's models. NOT part of the normal build
# any more -- both apps default to `DownloadModelProvider`, which fetches
# through Airo's existing download pipeline at first run instead of shipping
# weights in the APK (docs/superpowers/specs/2026-08-07-airo-mind-abstraction-layer.md).
#
# What this script is still for:
#   * Seeding `ModelInstaller`'s bundled path (`ADR-0018 §2`), for anyone
#     building a flavour that intentionally bundles -- that also needs
#     `packages/feature_mind/pubspec.yaml`'s `assets:` block restored.
#     `DownloadModelProvider` does NOT consult this directory; it always
#     fetches from `mindModelDownloadUrl`.
#   * A fast way to get verified weights on disk for manual testing without
#     waiting on a real download.
#
# `ADR-0018 §1` still holds either way: the runtime never acquires models.
# llama-cpp-2 is built with `default-features = false` precisely so llama.cpp's
# HuggingFace client is not compiled in; this script and
# `DownloadModelProvider` are both Dart-side.
#
# The digests below are the same values pinned in
# rust/airo_mind_core/src/models.rs, and the same URLs
# `app/lib/core/mind/mind_model_source.dart` uses for the real download path.
# They are the contract: the upstream refs are branch names and can move, so a
# changed file fails here loudly rather than shipping weights nobody reviewed.
# If a digest mismatches, that is a decision for a human, not a reason to pass
# --force.
#
# Usage:  app/tool/fetch_mind_models.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ASSETS="$ROOT/packages/feature_mind/assets/models"
mkdir -p "$ASSETS"

# name | sha256 | url
MODELS=(
  "ggml-tiny.en.bin|921e4cf8686fdd993dcd081a5da5b6c365bfde1162e72b08d75ac75289920b1f|https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.en.bin"
  "ggml-tiny.bin|be07e048e1e599ad46341c8d2a135645097a538221678b7acdd1b1919c6e1b21|https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin"
  "qwen2.5-0.5b-instruct-q4_k_m.gguf|74a4da8c9fdbcd15bd1f6d01d621410d31c6fc00986f5eb687824e7b93d7a9db|https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf"
)

digest_of() {
  shasum -a 256 "$1" 2>/dev/null | cut -d' ' -f1
}

for entry in "${MODELS[@]}"; do
  IFS='|' read -r name sha url <<<"$entry"
  target="$ASSETS/$name"

  if [ -f "$target" ] && [ "$(digest_of "$target")" = "$sha" ]; then
    echo "==> $name already present and verified"
    continue
  fi

  # A local copy is preferred over the network -- a developer who already has
  # the weights should not re-download half a gigabyte, and CI can seed this
  # directory from a cache.
  cache="$ROOT/rust/airo_mind_core/models/$name"
  if [ -f "$cache" ] && [ "$(digest_of "$cache")" = "$sha" ]; then
    echo "==> $name from local cache"
    cp "$cache" "$target"
    continue
  fi

  echo "==> Fetching $name"
  # Downloaded to a temporary name so an interrupted fetch cannot leave a
  # partial file that a later run treats as a corrupt model rather than an
  # incomplete one.
  curl --fail --location --progress-bar --output "$target.partial" "$url"

  found="$(digest_of "$target.partial")"
  if [ "$found" != "$sha" ]; then
    rm -f "$target.partial"
    echo "error: $name does not match its pinned digest." >&2
    echo "       expected $sha" >&2
    echo "       found    $found" >&2
    echo "       The upstream file changed. That is a review, not a retry." >&2
    exit 1
  fi
  mv "$target.partial" "$target"
  echo "==> $name verified"
done

echo "==> Models staged in $ASSETS"
