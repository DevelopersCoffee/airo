#!/usr/bin/env bash
# feature_mind's *.freezed.dart is gitignored; the app depends on feature_mind
# since SSOT Phase 3, so that package must generate first.
# The default app profile no longer declares build_runner — skip app codegen
# unless the active pubspec lists it.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

(
  cd "$ROOT/packages/feature_mind"
  flutter pub get
  dart run build_runner build
)

cd "$ROOT/app"
if grep -qE '^[[:space:]]*build_runner:' pubspec.yaml; then
  dart run build_runner build
else
  echo "Skipping app codegen: this profile does not declare build_runner."
fi
