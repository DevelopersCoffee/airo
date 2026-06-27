#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAX_BYTES="${AIRO_MAX_BUNDLED_MODEL_BYTES:-5242880}"
SCAN_PATHS="${AIRO_MODEL_ARTIFACT_SCAN_PATHS:-app packages}"
REPORT_FILE="${AIRO_MODEL_ARTIFACT_REPORT_FILE:-model-artifact-report.md}"
ALLOWLIST="${AIRO_MODEL_ARTIFACT_ALLOWLIST:-}"

cd "$ROOT_DIR"

stat_bytes() {
  local file="$1"
  if stat -c%s "$file" >/dev/null 2>&1; then
    stat -c%s "$file"
  else
    stat -f%z "$file"
  fi
}

format_bytes() {
  awk -v bytes="$1" 'BEGIN { printf "%.2f MB", bytes / 1048576 }'
}

is_allowlisted() {
  local file="$1"
  [ -z "$ALLOWLIST" ] && return 1

  local pattern
  IFS=',' read -ra patterns <<< "$ALLOWLIST"
  for pattern in "${patterns[@]}"; do
    pattern="${pattern#"${pattern%%[![:space:]]*}"}"
    pattern="${pattern%"${pattern##*[![:space:]]}"}"
    [ -z "$pattern" ] && continue
    if [[ "$file" == $pattern ]]; then
      return 0
    fi
  done

  return 1
}

{
  echo "# Bundled Model Artifact Guardrail"
  echo ""
  echo "Max allowed bundled model artifact size: $(format_bytes "$MAX_BYTES")"
  echo ""
} > "$REPORT_FILE"

find_args=()
for path in $SCAN_PATHS; do
  [ -e "$path" ] || continue
  find_args+=("$path")
done

if [ "${#find_args[@]}" -eq 0 ]; then
  echo "No configured scan paths exist: $SCAN_PATHS" >> "$REPORT_FILE"
  cat "$REPORT_FILE"
  exit 0
fi

candidates=()
while IFS= read -r candidate; do
  candidates+=("$candidate")
done < <(
  find "${find_args[@]}" \
    \( -path '*/build/*' -o -path '*/.dart_tool/*' -o -path '*/.gradle/*' -o -path '*/Pods/*' \) -prune \
    -o -type f \
    \( \
      -iname '*.gguf' -o -iname '*.ggml' -o -iname '*.safetensors' \
      -o -iname '*.pt' -o -iname '*.pth' -o -iname '*.onnx' \
      -o -iname '*.tflite' -o -iname '*.litert' -o -iname '*.task' \
      -o -iname '*.mlmodel' -o -iname '*.mlpackage' \
    \) -print | sort
)

if [ "${#candidates[@]}" -eq 0 ]; then
  echo "No bundled model artifacts found in release-bearing paths." >> "$REPORT_FILE"
  cat "$REPORT_FILE"
  exit 0
fi

failed=0
{
  echo "| File | Size | Status |"
  echo "|------|------|--------|"
} >> "$REPORT_FILE"

for file in "${candidates[@]}"; do
  size="$(stat_bytes "$file")"
  status="OK: below small pinned-model cap"

  if is_allowlisted "$file"; then
    status="OK: allowlisted"
  elif [ "$size" -gt "$MAX_BYTES" ]; then
    status="FAIL: bundled model exceeds cap"
    echo "::error file=$file::$file is $(format_bytes "$size"); models larger than $(format_bytes "$MAX_BYTES") must be delivered at runtime."
    failed=1
  else
    echo "::warning file=$file::$file is a bundled model artifact below the cap. Prefer runtime delivery unless this is an intentional tiny classifier."
  fi

  echo "| $file | $(format_bytes "$size") | $status |" >> "$REPORT_FILE"
done

cat "$REPORT_FILE"

if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  cat "$REPORT_FILE" >> "$GITHUB_STEP_SUMMARY"
fi

exit "$failed"
