#!/usr/bin/env bash
# Builds and runs Airo Mind on macOS.
#
# Everything here is what the Flutter build does NOT do for us yet. There is no
# cargokit in this workspace, so the Rust library is not compiled, copied or
# signed as part of `flutter build` -- see #1401's follow-ups.
#
# Usage:  app/tool/run_mind_macos.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

echo "==> Building the runtime (whisper.cpp + llama.cpp; slow on a cold cache)"
cargo build --manifest-path rust/Cargo.toml -p airo_mind_runtime --features app --release

echo "==> Building the Flutter app"
cp app/pubspec_mind.yaml app/pubspec.yaml
trap 'git -C "$ROOT" checkout app/pubspec.yaml' EXIT
(cd app && flutter pub get && flutter build macos --debug -t lib/main_mind.dart)

APP="$ROOT/app/build/macos/Build/Products/Debug/Airo TV.app"
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist")"

echo "==> Bundling the runtime into $APP"
mkdir -p "$APP/Contents/Frameworks"
cp rust/target/release/libairo_mind_runtime.dylib "$APP/Contents/Frameworks/"
# Ad-hoc signing, and the app has to be re-signed AFTER the dylib lands or the
# bundle's signature no longer covers its contents and macOS refuses to launch.
codesign --force --sign - "$APP/Contents/Frameworks/libairo_mind_runtime.dylib"
codesign --force --deep --sign - \
  --entitlements app/macos/Runner/DebugProfile.entitlements "$APP"

# Standing in for ADR-0018's Model Manager, which does not exist yet. The app
# is sandboxed, so its "application support" is inside its container.
SUPPORT="$HOME/Library/Containers/$BUNDLE_ID/Data/Library/Application Support/$BUNDLE_ID/airo_mind"
mkdir -p "$SUPPORT"
for model in ggml-tiny.en.bin qwen2.5-0.5b-instruct-q4_k_m.gguf; do
  if [ ! -f "$SUPPORT/$model" ]; then
    echo "==> Installing $model"
    cp "rust/airo_mind_runtime/models/$model" "$SUPPORT/"
  fi
done

echo "==> Launching"
open "$APP"
