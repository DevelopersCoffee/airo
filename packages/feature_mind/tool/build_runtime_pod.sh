#!/bin/sh
# Builds one Airo Mind engine for an Apple target and checks the artefact the pod
# actually ships.
#
# macOS consumes the DYLIB. whisper.cpp and llama.cpp each vendor their own ggml
# with identical symbol names, and linking the merged static archive produces
# 591 duplicate symbols -- a real one-definition-rule conflict between two
# upstream projects. rustc resolves it when it links the cdylib, so we take that
# artefact instead of fighting the linker.
#
# `ADR-0018 §1`: the runtime never acquires models. `default-features = false`
# on llama-cpp-2 drops its `common` feature and is NOT sufficient -- llama-cpp-2
# depends on llama-cpp-sys-2 without disabling its defaults, and sys's default
# is `["common"]`. Cargo features are a union, so a dependent cannot subtract
# one. The check below is therefore on the shipped binary rather than on the
# feature flags, because the flags do not tell the truth here.
set -e

BASEDIR=$(cd "$(dirname "$0")" && pwd)

sh "$BASEDIR/../cargokit/build_pod.sh" "$@"

# Cargokit stages only the static archive into BUILT_PRODUCTS_DIR; the cdylib
# stays in the cargo target directory it built in. Found rather than
# constructed, because the path carries a rust target triple and a profile name
# that this script has no business hardcoding.
# $2 is the library name, already passed by the podspec.
LIBNAME="${2:?usage: build_runtime_pod.sh <manifestDir> <libname>}"
DYLIB="$BUILT_PRODUCTS_DIR/lib$LIBNAME.dylib"
slices=$(find "$TARGET_TEMP_DIR" -name "lib$LIBNAME.dylib" -not -path "*/deps/*" 2>/dev/null)

if [ -z "$slices" ]; then
  echo "error: cargokit produced no lib$LIBNAME.dylib under" >&2
  echo "       $TARGET_TEMP_DIR" >&2
  echo "       The crate must declare crate-type = [\"cdylib\", ...]." >&2
  exit 1
fi

count=$(echo "$slices" | wc -l | tr -d ' ')
if [ "$count" -eq 1 ]; then
  cp "$slices" "$DYLIB"
else
  # A universal build: one dylib per architecture, combined here.
  # shellcheck disable=SC2086
  lipo -create $slices -output "$DYLIB"
fi

# 1. The bridge has to be there, or the app fails at RustLib.init with nothing
#    to explain it.
exports=$(nm -gU "$DYLIB" 2>/dev/null | grep -c ' T _frb_' || true)
if [ "$exports" -lt 10 ]; then
  echo "error: only $exports frb entry points exported by $DYLIB (expected 10+)." >&2
  exit 1
fi

# 2. No model downloader may be reachable in the shipped library. This is the
#    ADR-0018 §1 obligation, checked where it can actually be observed.
if nm -u "$DYLIB" 2>/dev/null | grep -qi httplib; then
  echo "error: $DYLIB references an HTTP client." >&2
  echo "       llama.cpp's downloader has been linked in. Do not re-enable" >&2
  echo "       \`common\`; find what pulled it." >&2
  exit 1
fi
if nm -gU "$DYLIB" 2>/dev/null | grep -q "common_download"; then
  echo "error: $DYLIB exports llama.cpp's model downloader." >&2
  exit 1
fi

echo "==> $DYLIB: $exports bridge entry points, no downloader"
