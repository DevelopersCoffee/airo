#!/usr/bin/env bash
# Builds and runs Airo Mind on macOS.
#
# Cargokit compiles, links and signs the Airo Mind engines as part of the Flutter
# build, so this script does not touch the Rust. It fetches the bundled model
# weights -- which are not in git -- and then builds.
#
# A reviewer runs this one command on a fresh clone. No code edits, no manual
# copying.
#
# Usage:  app/tool/run_mind_macos.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
export AIRO_ROOT="$ROOT"

APP_INFO_XCCONFIG="$ROOT/app/macos/Runner/Configs/AppInfo.xcconfig"
APP_INFO_BACKUP="$APP_INFO_XCCONFIG.mind-run.bak"

restore_app_info() {
  if [ -f "$APP_INFO_BACKUP" ]; then
    mv -f "$APP_INFO_BACKUP" "$APP_INFO_XCCONFIG"
  fi
}

# macOS window/menu title still reads from PRODUCT_NAME in AppInfo.xcconfig,
# which defaults to the TV shell name because flavors share one Runner target.
cp "$APP_INFO_XCCONFIG" "$APP_INFO_BACKUP"
sed -i '' 's/^PRODUCT_NAME = .*/PRODUCT_NAME = Airo Mind/' "$APP_INFO_XCCONFIG"

"$ROOT/app/tool/fetch_mind_models.sh"

# macOS sandbox: copy staged weights into Application Support so first launch
# does not depend on platform_downloads (mobile-only) or a hot restart.
MIND_SUPPORT="$HOME/Library/Containers/com.developerscoffee.airo.tv/Data/Library/Application Support/com.developerscoffee.airo.tv/airo_mind"
mkdir -p "$MIND_SUPPORT"
for model in ggml-tiny.en.bin ggml-tiny.bin qwen2.5-0.5b-instruct-q4_k_m.gguf; do
  src="$ROOT/packages/feature_mind/assets/models/$model"
  if [ -f "$src" ]; then
    cp -f "$src" "$MIND_SUPPORT/$model"
  fi
done

echo "==> Generating feature_mind code"
(cd "$ROOT/packages/feature_mind" && flutter pub get && dart run build_runner build)

echo "==> Building (cargokit compiles the Rust as part of this)"
# Optional preflight (Rust vault/notes/replay + macOS compile):
#   scripts/verify-mind-macos-e2e.sh
# Flavors are separate pubspecs in this repo, so selecting one means swapping
# the file. Restored on exit, including on failure.
cp app/pubspec_mind.yaml app/pubspec.yaml
trap 'git -C "$ROOT" checkout app/pubspec.yaml app/pubspec.lock; restore_app_info' EXIT
cd app
flutter pub get
flutter run -d macos -t lib/main_mind.dart
