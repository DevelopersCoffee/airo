#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

cat > "$tmp_dir/known.log" <<'EOF'
E/libc: Access denied finding property "vendor.dpframework.log.enable"
E/libc: Access denied finding property "vendor.dpframework.dumpbuffer.checksum"
E/libc: Access denied finding property "vendor.dpframework.dumpbuffer.enable"
EOF

"$ROOT_DIR/scripts/check-fire-tv-playback-logs.sh" \
  --input "$tmp_dir/known.log" \
  --output "$tmp_dir/known-report.md"
grep -q 'PASS_WITH_KNOWN_PLATFORM_NOISE' "$tmp_dir/known-report.md"
grep -q 'Known Fire OS/MediaTek property denials: 3' "$tmp_dir/known-report.md"
grep -q 'Other actionable error lines: 0' "$tmp_dir/known-report.md"

cat > "$tmp_dir/actionable.log" <<'EOF'
E/libc: Access denied finding property "vendor.dpframework.log.enable"
E/flutter: playback failed for https://private.example/token
EOF

if "$ROOT_DIR/scripts/check-fire-tv-playback-logs.sh" \
  --input "$tmp_dir/actionable.log" \
  --output "$tmp_dir/actionable-report.md"; then
  echo "expected an unclassified app error to fail" >&2
  exit 1
fi
grep -q 'FAIL_ACTIONABLE_ERRORS' "$tmp_dir/actionable-report.md"
grep -q 'Other actionable error lines: 1' "$tmp_dir/actionable-report.md"
if grep -q 'private.example' "$tmp_dir/actionable-report.md"; then
  echo "raw private log content leaked into the aggregate report" >&2
  exit 1
fi

echo "check-fire-tv-playback-logs tests passed"
