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

"$ROOT/app/tool/fetch_mind_models.sh"

# feature_mind's *.freezed.dart is generated, and gitignored. On a fresh clone
# it does not exist, and the shell fails to compile with a misleading
# "Couldn't find constructor ProcessingEvent_*" pointing inside the package.
echo "==> Generating feature_mind code"
(cd "$ROOT/packages/feature_mind" && flutter pub get && dart run build_runner build)

echo "==> Building (cargokit compiles the Rust as part of this)"
# Flavors are separate pubspecs in this repo, so selecting one means swapping
# the file. Restored on exit, including on failure.
cp app/pubspec_mind.yaml app/pubspec.yaml
trap 'git -C "$ROOT" checkout app/pubspec.yaml app/pubspec.lock' EXIT
cd app
flutter pub get
flutter run -d macos -t lib/main_mind.dart
