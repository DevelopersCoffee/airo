#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ $# -gt 0 ]]; then
  scan_paths=("$@")
else
  scan_paths=("app/lib" "packages")
fi

existing_paths=()
for path in "${scan_paths[@]}"; do
  if [[ -e "$path" ]]; then
    existing_paths+=("$path")
  fi
done

if [[ ${#existing_paths[@]} -eq 0 ]]; then
  echo "No worker policy paths found."
  exit 0
fi

rg_dart() {
  rg -n \
    --glob '*.dart' \
    --glob '!**/test/**' \
    --glob '!**/third_party/**' \
    --glob '!**/*.g.dart' \
    "$@" \
    "${existing_paths[@]}" || true
}

has_failures=false

direct_worker_matches="$(
  rg_dart \
    -e '(^|[^A-Za-z0-9_])compute\s*\(' \
    -e 'Isolate\.run\s*(<|\()' |
    grep -Ev '(^|/)packages/platform_worker_jobs/lib/src/worker_executor\.dart:' || true
)"

if [[ -n "$direct_worker_matches" ]]; then
  has_failures=true
  cat >&2 <<'EOF'
Worker offload policy violation: direct compute()/Isolate.run usage found.
Use platform_worker_jobs AiroWorkerExecutor so scheduling, tracing, and
fallback behavior stay reusable.

EOF
  echo "$direct_worker_matches" >&2
  echo >&2
fi

presentation_matches="$(
  rg_dart \
    -e '\bjsonDecode\s*\(' \
    -e '\bjsonEncode\s*\(' \
    -e "split\('\\\\n'\)" \
    -e 'split\("\\n"\)' \
    -e '#EXTINF' |
    awk -F: '
      $1 ~ /(^|\/)presentation\// ||
      $1 ~ /(^|\/)screens\// ||
      $1 ~ /(^|\/)widgets\// ||
      $1 ~ /(^|\/)app\/lib\/main_tv\.dart$/ ||
      $1 ~ /(^|\/)packages\/feature_iptv\/lib\// {
        print
      }
    ' || true
)"

if [[ -n "$presentation_matches" ]]; then
  has_failures=true
  cat >&2 <<'EOF'
Worker offload policy violation: parsing or serialization work found in a
presentation/screen/widget path. Move heavy JSON, playlist, EPG, cache
hydration, or line-oriented parsing behind a platform package using
AiroWorkerExecutor or a native backend.

EOF
  echo "$presentation_matches" >&2
  echo >&2
fi

if [[ "$has_failures" == "true" ]]; then
  exit 1
fi

echo "Worker offload policy check passed."
