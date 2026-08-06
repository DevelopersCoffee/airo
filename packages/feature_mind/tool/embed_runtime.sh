#!/bin/sh
# Puts an Airo Mind engine dylib inside feature_mind.framework.
#
# Usage: embed_runtime.sh <libname>
#
# There are two engines -- whisper.cpp and llama.cpp vendor incompatible
# copies of ggml and cannot share a linked image (#1546) -- so the name is
# an argument rather than baked in.
#
# CocoaPods embeds pod frameworks into the app bundle, so a dylib carried in the
# framework's Resources ships with the app and needs no separate copy step. That
# is what library_loader.dart looks for on macOS.
#
# The install name has to be rewritten. Cargo stamps an absolute path from the
# build machine, and a bundle that refers to a path on the machine that built it
# is a bundle that works exactly once, here.
set -e

LIBNAME="${1:?usage: embed_runtime.sh <libname>}"

SOURCE="$BUILT_PRODUCTS_DIR/lib$LIBNAME.dylib"
FRAMEWORK="$BUILT_PRODUCTS_DIR/feature_mind.framework"
DEST="$FRAMEWORK/Resources"

if [ ! -f "$SOURCE" ]; then
  echo "error: $SOURCE is missing; the build phase did not produce it." >&2
  exit 1
fi
if [ ! -d "$FRAMEWORK" ]; then
  echo "error: $FRAMEWORK does not exist yet." >&2
  echo "       This phase must run AFTER compile." >&2
  exit 1
fi

mkdir -p "$DEST"
cp "$SOURCE" "$DEST/lib$LIBNAME.dylib"
install_name_tool -id "@rpath/lib$LIBNAME.dylib" \
  "$DEST/lib$LIBNAME.dylib"

# Re-signed because changing the install name invalidates whatever signature
# cargo's linker left, and macOS refuses to load a dylib whose signature does
# not match its contents.
codesign --force --sign - "$DEST/lib$LIBNAME.dylib" 2>/dev/null || true

echo "==> Embedded $(basename "$SOURCE") in feature_mind.framework"
