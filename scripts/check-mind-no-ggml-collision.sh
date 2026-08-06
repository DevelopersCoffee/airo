#!/usr/bin/env bash
#
# The mutation test for the Airo Mind runtime split (#1546).
#
# whisper.cpp and llama.cpp each statically vendor their own copy of ggml, with
# the same symbol names and 348 files of difference between the trees. Putting
# both in one linked image is a one-definition-rule conflict between two
# upstream projects, and every linker handles it differently and badly:
#
#   * Android's lld refuses          -- 20+ duplicate symbols
#   * a merged static archive fails  -- 592 duplicate symbols (this is iOS)
#   * Apple's linker "succeeds"      -- 339 duplicate-symbol warnings, and the
#                                       implementation is chosen per symbol by
#                                       link order
#
# The last one is why this check exists. Recombining the engines does not
# reliably break the build; on Apple it produces a binary that links, ships, and
# runs one engine against the other's ggml. So the property is asserted here
# rather than left to a linker to notice.
#
# Two things are checked per library:
#   1. ggml is not exported. Each image keeps its own copy private, which is
#      what lets both be loaded into one process.
#   2. only one engine is present. A library holding both whisper and llama is
#      the merge this split exists to prevent.
#
# Usage: scripts/check-mind-no-ggml-collision.sh [lib ...]
# With no arguments it checks whatever has been built under rust/target.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# `nm` is present on both hosts; readelf is not on macOS and otool is not on
# Linux. Prefer llvm-nm from the NDK when it is around, because a GNU nm cannot
# always read an ELF file produced by lld for another architecture.
pick_nm() {
  if [[ -n "${ANDROID_NDK_ROOT:-}" ]]; then
    local candidate
    for candidate in "$ANDROID_NDK_ROOT"/toolchains/llvm/prebuilt/*/bin/llvm-nm; do
      [[ -x "$candidate" ]] && { echo "$candidate"; return; }
    done
  fi
  command -v llvm-nm || command -v nm
}
NM="$(pick_nm)"

libs=("$@")
if [[ ${#libs[@]} -eq 0 ]]; then
  # Only what exists. A build that produced nothing is caught by the positive
  # control below, not by silently checking an empty list.
  #
  # `deps/` is excluded: cargo leaves hash-suffixed copies there, so including
  # it reports the same library several times. Sorted and de-duplicated for the
  # same reason.
  while IFS= read -r found; do
    libs+=("$found")
  done < <(find "$ROOT_DIR/rust/target" \
    -type f -not -path '*/deps/*' \
    \( -name 'libairo_mind_whisper.so' -o -name 'libairo_mind_whisper.dylib' \
       -o -name 'airo_mind_whisper.dll' \
       -o -name 'libairo_mind_llama.so' -o -name 'libairo_mind_llama.dylib' \
       -o -name 'airo_mind_llama.dll' \) 2>/dev/null | sort -u || true)
fi

if [[ ${#libs[@]} -eq 0 ]]; then
  echo "No Airo Mind engine libraries found under rust/target." >&2
  echo "Build one first, e.g. cargo build --features whisper --target <triple>." >&2
  exit 1
fi

status=0
symbols="$(mktemp)"
exported="$(mktemp)"
trap 'rm -f "$symbols" "$exported"' EXIT

for lib in "${libs[@]}"; do
  name="$(basename "$lib")"
  lib_ok=1

  # Read the symbol tables once. Three separate `nm | grep` pipelines over a
  # 79 MB library is both slow and easy to get subtly wrong.
  "$NM" -a "$lib" >"$symbols" 2>/dev/null || true
  { "$NM" -D --defined-only "$lib" 2>/dev/null || "$NM" -g "$lib" 2>/dev/null; } >"$exported" || true

  # Positive control, first and non-negotiable.
  #
  # Every assertion below is of the form "this symbol is absent", and absence is
  # exactly what a broken symbol reader, a wrong path, or a stripped file also
  # produces. `command -v nm` does not catch any of those. So the gate must
  # first prove it can see a symbol that MUST be there -- the bridge entry
  # points, without which the library is useless to Dart anyway -- and refuse to
  # run if it cannot.
  if ! grep -q 'frb_' "$exported"; then
    echo "FAIL $name: no frb_ entry points found." >&2
    echo "     Either the library exports no bridge (cargokit built it without" >&2
    echo "     its feature -- see cargokit.yaml), or $NM cannot read it. Either" >&2
    echo "     way the checks below would pass by finding nothing." >&2
    status=1
    continue
  fi

  exported_ggml="$(grep -c 'ggml_' "$exported" || true)"
  if [[ "$exported_ggml" -ne 0 ]]; then
    echo "FAIL $name: exports $exported_ggml ggml symbols." >&2
    echo "     Two libraries exporting ggml can bind to each other at load time," >&2
    echo "     which is the collision in a slower form." >&2
    status=1
    lib_ok=0
  fi

  # Presence, not export: the engines' own entry points are internal.
  has_whisper=0
  has_llama=0
  grep -q 'whisper_full' "$symbols" && has_whisper=1
  grep -q 'llama_decode' "$symbols" && has_llama=1
  if [[ "$has_whisper" -eq 1 && "$has_llama" -eq 1 ]]; then
    echo "FAIL $name: contains BOTH whisper.cpp and llama.cpp." >&2
    echo "     This is the merge the split exists to prevent. On Apple it will" >&2
    echo "     link anyway and run one engine against the other's ggml." >&2
    status=1
    lib_ok=0
  fi
  if [[ "$has_whisper" -eq 0 && "$has_llama" -eq 0 ]]; then
    echo "FAIL $name: contains neither engine." >&2
    echo "     It exports a bridge, so it is not an unbuilt stub -- the engine" >&2
    echo "     was compiled out and every call would fail at run time." >&2
    status=1
    lib_ok=0
  fi

  if [[ "$lib_ok" -eq 1 ]]; then
    engine="whisper"
    [[ "$has_llama" -eq 1 ]] && engine="llama"
    echo "ok   $name: $engine only, ggml not exported"
  fi
done

exit "$status"
