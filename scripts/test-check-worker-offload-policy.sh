#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/check-worker-offload-policy.sh"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

clean_dir="$TMP_DIR/clean"
bad_isolate_dir="$TMP_DIR/bad-isolate"
bad_presentation_dir="$TMP_DIR/bad-presentation"

mkdir -p "$clean_dir/packages/platform_worker_jobs/lib/src"
cat >"$clean_dir/packages/platform_worker_jobs/lib/src/worker_executor.dart" <<'DART'
import 'dart:isolate';

Future<int> runWorker() {
  return Isolate.run(() => 1);
}
DART

mkdir -p "$clean_dir/packages/platform_playlist_import/lib/src"
cat >"$clean_dir/packages/platform_playlist_import/lib/src/cache.dart" <<'DART'
import 'dart:convert';

Object decodeCache(String raw) => jsonDecode(raw);
DART

"$SCRIPT" "$clean_dir" >/tmp/airo-worker-policy-clean.out
grep -q "Worker offload policy check passed" /tmp/airo-worker-policy-clean.out

mkdir -p "$bad_isolate_dir/packages/feature_iptv/lib/application"
cat >"$bad_isolate_dir/packages/feature_iptv/lib/application/bad_worker.dart" <<'DART'
import 'dart:isolate';

Future<int> badWorker() => Isolate.run(() => 1);
DART

if "$SCRIPT" "$bad_isolate_dir" >/tmp/airo-worker-policy-bad-isolate.out 2>&1; then
  echo "Expected direct Isolate.run policy failure." >&2
  exit 1
fi
grep -q "direct compute()/Isolate.run usage found" \
  /tmp/airo-worker-policy-bad-isolate.out

mkdir -p "$bad_presentation_dir/packages/feature_iptv/lib/presentation/widgets"
cat >"$bad_presentation_dir/packages/feature_iptv/lib/presentation/widgets/bad_json.dart" <<'DART'
import 'dart:convert';

Object badWidgetDecode(String raw) => jsonDecode(raw);
DART

if "$SCRIPT" "$bad_presentation_dir" >/tmp/airo-worker-policy-bad-json.out 2>&1; then
  echo "Expected presentation jsonDecode policy failure." >&2
  exit 1
fi
grep -q "parsing or serialization work found" \
  /tmp/airo-worker-policy-bad-json.out

echo "check-worker-offload-policy tests passed"
