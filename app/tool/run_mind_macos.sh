#!/usr/bin/env bash
# Builds and runs Airo Mind on macOS.
#
# Cargokit compiles, links and signs airo_mind_runtime as part of the Flutter
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

"$ROOT/app/tool/fetch_mind_models.sh"

echo "==> Building (cargokit compiles the Rust as part of this)"
# Flavors are separate pubspecs in this repo, so selecting one means swapping
# the file. Restored on exit, including on failure.
cp app/pubspec_mind.yaml app/pubspec.yaml
trap 'git -C "$ROOT" checkout app/pubspec.yaml' EXIT
cd app
flutter pub get
flutter run -d macos -t lib/main_mind.dart
