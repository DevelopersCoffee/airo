#!/usr/bin/env bash
# feature_mind's *.freezed.dart is gitignored; the app depends on feature_mind
# since SSOT Phase 3, so that package must generate first.
#
# Do not run app build_runner here. The phone profile's only tracked generated
# part is app/lib/core/database/app_database_native.g.dart. riverpod_generator
# 4.0.8 (the first release that solves with riverpod 3.4.2 + riverpod_lint
# 3.1.8) cannot compile against the analyzer 12 pin Flutter 3.44 ships, so
# invoking it from app/ fails the analyze job before flutter analyze runs.
# The Mind profile also has no app builders.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

(
  cd "$ROOT/packages/feature_mind"
  flutter pub get
  dart run build_runner build
)

echo "Skipping app codegen: committed Drift output is enough; riverpod_generator 4.0.8 cannot compile on analyzer 12."
