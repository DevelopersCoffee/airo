#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORT_FILE="${MODULE_SIZE_REPORT_FILE:-module-size-report.md}"
WARN_MB="${MODULE_SIZE_WARN_MB:-1}"
FAIL_MB="${MODULE_SIZE_FAIL_MB:-3}"
PLUGIN_CACHE_MB="${PLUGIN_SIZE_CACHE_MB:-5}"
BASE_REF="${MODULE_SIZE_BASE_REF:-origin/main}"
CHECK_CHANGED_ONLY="${MODULE_SIZE_CHANGED_ONLY:-true}"
MODULE_ROOTS="${MODULE_SIZE_ROOTS:-packages plugins}"

cd "$ROOT_DIR"

bytes_for_mb() {
  awk -v mb="$1" 'BEGIN { printf "%.0f", mb * 1048576 }'
}

format_bytes() {
  awk -v bytes="$1" 'BEGIN { printf "%.2f MB", bytes / 1048576 }'
}

stat_bytes() {
  local file="$1"
  if stat -c%s "$file" >/dev/null 2>&1; then
    stat -c%s "$file"
  else
    stat -f%z "$file"
  fi
}

module_size_bytes() {
  local module="$1"
  find "$module" \
    \( -path '*/.dart_tool/*' -o -path '*/build/*' -o -path '*/.git/*' -o -path '*/coverage/*' -o -path '*/.pub-cache/*' -o -path '*/ios/Pods/*' -o -path '*/android/.gradle/*' \) -prune \
    -o -type f -print0 \
    | while IFS= read -r -d '' file; do
        stat_bytes "$file"
      done \
    | awk '{ total += $1 } END { printf "%.0f", total }'
}

is_airo_plugin_module() {
  local module="$1"
  local pubspec="$module/pubspec.yaml"
  case "$module" in
    plugins/*|packages/plugins/*|app/plugins/*) return 0 ;;
  esac
  if grep -Eq '^[[:space:]]*airo_plugin:[[:space:]]*true[[:space:]]*$' "$pubspec"; then
    return 0
  fi
  if grep -Eq '^[[:space:]]*plugin_package:[[:space:]]*true[[:space:]]*$' "$pubspec"; then
    return 0
  fi
  return 1
}

has_cache_management_hint() {
  local module="$1"
  local pubspec="$module/pubspec.yaml"
  if grep -Eq '^[[:space:]]*cache_management:[[:space:]]*true[[:space:]]*$' "$pubspec"; then
    return 0
  fi
  if [ -f "$module/CACHE_MANAGEMENT.md" ] || [ -f "$module/docs/CACHE_MANAGEMENT.md" ]; then
    return 0
  fi
  return 1
}

module_changed() {
  local module="$1"
  if [ "$CHECK_CHANGED_ONLY" != "true" ]; then
    return 0
  fi
  if ! git rev-parse --verify "$BASE_REF" >/dev/null 2>&1; then
    return 0
  fi
  git diff --name-only "$BASE_REF"...HEAD -- "$module" | grep -q .
}

warn_bytes="$(bytes_for_mb "$WARN_MB")"
fail_bytes="$(bytes_for_mb "$FAIL_MB")"
cache_bytes="$(bytes_for_mb "$PLUGIN_CACHE_MB")"
failed=0
checked=0

modules_file="$(mktemp)"
trap 'rm -f "$modules_file"' EXIT
search_roots=()
for root in $MODULE_ROOTS; do
  if [ -d "$root" ]; then
    search_roots+=("$root")
  fi
done
if [ "${#search_roots[@]}" -gt 0 ]; then
  find "${search_roots[@]}" -name pubspec.yaml -type f | sed 's#/pubspec.yaml$##' | sort >"$modules_file"
fi

{
  echo "## Plugin Module Size Gate"
  echo ""
  echo "Policy: modules over ${FAIL_MB} MB must be delivered as plugins; plugin modules over ${PLUGIN_CACHE_MB} MB must document cache management."
  echo ""
  echo "| Module | Size | Type | Status |"
  echo "|--------|------|------|--------|"
} >"$REPORT_FILE"

while IFS= read -r module; do
  [ -f "$module/pubspec.yaml" ] || continue
  if ! module_changed "$module"; then
    continue
  fi

  checked=$((checked + 1))
  size_bytes="$(module_size_bytes "$module")"
  module_type="bundled"
  status="OK"

  if is_airo_plugin_module "$module"; then
    module_type="plugin"
    if awk -v size="$size_bytes" -v limit="$cache_bytes" 'BEGIN { exit !(size > limit) }'; then
      if has_cache_management_hint "$module"; then
        status="OK: plugin cache management documented"
      else
        status="FAIL: plugin over ${PLUGIN_CACHE_MB} MB needs cache management"
        echo "::error file=$module/pubspec.yaml::$module is a plugin over ${PLUGIN_CACHE_MB} MB but has no cache management marker/docs"
        failed=1
      fi
    fi
  else
    if awk -v size="$size_bytes" -v limit="$fail_bytes" 'BEGIN { exit !(size > limit) }'; then
      status="FAIL: exceeds ${FAIL_MB} MB bundled-module limit; make it a plugin or add a plugin marker"
      echo "::error file=$module/pubspec.yaml::$module is $(format_bytes "$size_bytes"), exceeds bundled-module limit $(format_bytes "$fail_bytes")"
      failed=1
    elif awk -v size="$size_bytes" -v limit="$warn_bytes" 'BEGIN { exit !(size > limit) }'; then
      status="WARN: ${WARN_MB}-${FAIL_MB} MB requires PR size justification"
      echo "::warning file=$module/pubspec.yaml::$module is $(format_bytes "$size_bytes"); include size justification in the PR template"
    fi
  fi

  echo "| \`$module\` | $(format_bytes "$size_bytes") | $module_type | $status |" >>"$REPORT_FILE"
done <"$modules_file"

if [ "$checked" -eq 0 ]; then
  echo "| _No changed Dart/Flutter modules detected_ | n/a | n/a | OK |" >>"$REPORT_FILE"
fi

cat "$REPORT_FILE"

if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  cat "$REPORT_FILE" >>"$GITHUB_STEP_SUMMARY"
fi

exit "$failed"
