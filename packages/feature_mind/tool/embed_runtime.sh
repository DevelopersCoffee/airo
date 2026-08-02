#!/bin/sh
# Puts libairo_mind_runtime.dylib inside feature_mind.framework.
#
# CocoaPods embeds pod frameworks into the app bundle, so a dylib carried in the
# framework's Resources ships with the app and needs no separate copy step. That
# is what library_loader.dart looks for on macOS.
#
# The install name has to be rewritten. Cargo stamps an absolute path from the
# build machine, and a bundle that refers to a path on the machine that built it
# is a bundle that works exactly once, here.
set -e

SOURCE="$BUILT_PRODUCTS_DIR/libairo_mind_runtime.dylib"
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
cp "$SOURCE" "$DEST/libairo_mind_runtime.dylib"
install_name_tool -id "@rpath/libairo_mind_runtime.dylib" \
  "$DEST/libairo_mind_runtime.dylib"

# Re-signed because changing the install name invalidates whatever signature
# cargo's linker left, and macOS refuses to load a dylib whose signature does
# not match its contents.
codesign --force --sign - "$DEST/libairo_mind_runtime.dylib" 2>/dev/null || true

echo "==> Embedded $(basename "$SOURCE") in feature_mind.framework"
