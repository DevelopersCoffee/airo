#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

APK_GLOB="${APK_SIZE_APK_GLOB:-app/build/app/outputs/flutter-apk/*.apk}"
BASELINE_FILE="${APK_SIZE_BASELINE_FILE:-.github/apk-size-baselines.tsv}"
COMPONENT="${APK_SIZE_COMPONENT:-default}"
MAX_MB="${APK_SIZE_MAX_MB:-35}"
MAX_BYTES="${APK_SIZE_MAX_BYTES:-}"
MAX_INCREASE_PERCENT="${APK_SIZE_MAX_INCREASE_PERCENT:-5}"
REPORT_FILE="${APK_SIZE_REPORT_FILE:-apk-size-report.md}"
TOP_ENTRIES="${APK_SIZE_TOP_ENTRIES:-20}"

cd "$ROOT_DIR"

if [ ! -f "$BASELINE_FILE" ]; then
  echo "::error::APK size baseline file not found: $BASELINE_FILE"
  exit 1
fi

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

baseline_for() {
  local component="$1"
  local artifact="$2"

  awk -F '\t' -v component="$component" -v artifact="$artifact" '
    $0 ~ /^#/ || $0 == "" || $1 == "component" { next }
    $1 == component && $2 == artifact {
      print $3 "\t" $4
      exit
    }
  ' "$BASELINE_FILE"
}

percent_delta() {
  local size="$1"
  local baseline="$2"
  awk -v size="$size" -v baseline="$baseline" 'BEGIN {
    if (baseline == 0) {
      printf "0.00"
    } else {
      printf "%.2f", ((size - baseline) * 100) / baseline
    }
  }'
}

over_threshold() {
  local size="$1"
  local threshold="$2"
  awk -v size="$size" -v threshold="$threshold" 'BEGIN { exit !(size > threshold) }'
}

baseline_threshold() {
  local baseline="$1"
  awk -v baseline="$baseline" -v percent="$MAX_INCREASE_PERCENT" 'BEGIN {
    printf "%.0f", baseline * (1 + (percent / 100))
  }'
}

write_breakdown() {
  local apk="$1"
  local artifact="$2"

  {
    echo ""
    echo "### $COMPONENT / $artifact breakdown"
  } >>"$REPORT_FILE"

  if ! command -v unzip >/dev/null 2>&1 || ! unzip -l "$apk" >/dev/null 2>&1; then
    echo "Archive breakdown unavailable." >>"$REPORT_FILE"
    return
  fi

  {
    echo ""
    echo "| Area | Size |"
    echo "|------|------|"
    unzip -l "$apk" | awk '
      NR > 3 && $1 ~ /^[0-9]+$/ && NF >= 4 {
        path = $4
        if (path == "") {
          next
        }
        split(path, parts, "/")
        area = parts[1]
        if (area ~ /^classes.*\.dex$/) {
          area = "dex"
        } else if (area == "lib") {
          area = "native libraries"
        } else if (area == "assets") {
          area = "assets"
        } else if (area == "res" || area == "resources.arsc") {
          area = "resources"
        } else if (area == "META-INF") {
          area = "signing metadata"
        } else if (area == "AndroidManifest.xml") {
          area = "manifest"
        }
        sizes[area] += $1
      }
      END {
        for (area in sizes) {
          printf "%s\t%d\n", area, sizes[area]
        }
      }
    ' | sort -k2,2nr | awk -F '\t' '{ printf "| %s | %.2f MB |\n", $1, $2 / 1048576 }'
  } >>"$REPORT_FILE"

  {
    echo ""
    echo "#### Largest APK entries"
    echo ""
    echo "| Entry | Size |"
    echo "|-------|------|"
    unzip -l "$apk" | awk '
      NR > 3 && $1 ~ /^[0-9]+$/ && NF >= 4 && $4 != "" {
        printf "%d\t%s\n", $1, $4
      }
    ' | sort -k1,1nr | head -n "$TOP_ENTRIES" | awk -F '\t' '{ printf "| %s | %.2f MB |\n", $2, $1 / 1048576 }'
  } >>"$REPORT_FILE"
}

shopt -s nullglob
# APK_GLOB is intentionally expanded by bash so CI can pass either a glob or a
# single absolute path.
apk_files=( $APK_GLOB )
shopt -u nullglob

if [ "${#apk_files[@]}" -eq 0 ]; then
  echo "::error::No APK files matched APK_SIZE_APK_GLOB=$APK_GLOB"
  exit 1
fi

default_max_bytes="${MAX_BYTES:-$(bytes_for_mb "$MAX_MB")}"
failed=0

{
  echo "## APK Size Guardrail"
  echo ""
  echo "| Component | Artifact | Size | Budget | Baseline | Delta | Status |"
  echo "|-----------|----------|------|--------|----------|-------|--------|"
} >"$REPORT_FILE"

for apk in "${apk_files[@]}"; do
  artifact="$(basename "$apk")"
  size_bytes="$(stat_bytes "$apk")"
  baseline_record="$(baseline_for "$COMPONENT" "$artifact")"

  if [ -z "$baseline_record" ]; then
    status="FAIL: missing baseline"
    echo "| $COMPONENT | $artifact | $(format_bytes "$size_bytes") | $(format_bytes "$default_max_bytes") | n/a | n/a | $status |" >>"$REPORT_FILE"
    echo "::error file=$BASELINE_FILE::No APK size baseline for $COMPONENT/$artifact"
    failed=1
    write_breakdown "$apk" "$artifact"
    continue
  fi

  baseline_bytes="$(printf '%s\n' "$baseline_record" | awk -F '\t' '{ print $1 }')"
  budget_mb="$(printf '%s\n' "$baseline_record" | awk -F '\t' '{ print $2 }')"
  budget_bytes="$default_max_bytes"
  if [ -z "$MAX_BYTES" ] && [ -n "$budget_mb" ]; then
    budget_bytes="$(bytes_for_mb "$budget_mb")"
  fi

  delta="$(percent_delta "$size_bytes" "$baseline_bytes")"
  threshold_bytes="$(baseline_threshold "$baseline_bytes")"
  status="OK"

  if over_threshold "$size_bytes" "$budget_bytes"; then
    status="FAIL: exceeds max APK size"
    echo "::error file=$apk::$artifact is $(format_bytes "$size_bytes"), exceeds max APK size $(format_bytes "$budget_bytes")"
    failed=1
  fi

  if over_threshold "$size_bytes" "$threshold_bytes"; then
    if [ "$status" = "OK" ]; then
      status="FAIL: exceeds ${MAX_INCREASE_PERCENT}% baseline increase"
    else
      status="$status; exceeds ${MAX_INCREASE_PERCENT}% baseline increase"
    fi
    echo "::error file=$apk::$artifact is ${delta}% over baseline, exceeds ${MAX_INCREASE_PERCENT}% baseline increase"
    failed=1
  fi

  echo "| $COMPONENT | $artifact | $(format_bytes "$size_bytes") | $(format_bytes "$budget_bytes") | $(format_bytes "$baseline_bytes") | ${delta}% | $status |" >>"$REPORT_FILE"
  write_breakdown "$apk" "$artifact"
done

cat "$REPORT_FILE"

if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  cat "$REPORT_FILE" >>"$GITHUB_STEP_SUMMARY"
fi

exit "$failed"
