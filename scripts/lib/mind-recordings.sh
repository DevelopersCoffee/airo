#!/usr/bin/env bash
# Shared helpers for local meeting-recording dev loops (macOS).
#
# Override the recordings root:
#   export AIRO_MIND_RECORDINGS_DIR=/path/to/your/m4a/files
#
# shellcheck shell=bash

mind_recordings_root() {
  if [[ -n "${AIRO_MIND_RECORDINGS_DIR:-}" ]]; then
    printf '%s\n' "$AIRO_MIND_RECORDINGS_DIR"
    return
  fi
  printf '%s\n' "${HOME}/Documents/data"
}

mind_recordings_artifacts_dir() {
  if [[ -n "${AIRO_MIND_ARTIFACTS_DIR:-}" ]]; then
    printf '%s\n' "$AIRO_MIND_ARTIFACTS_DIR"
    return
  fi
  local root="${AIRO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
  printf '%s\n' "${root}/artifacts/mind-macos-e2e"
}

mind_models_dir() {
  if [[ -n "${AIRO_MIND_MODELS_DIR:-}" ]]; then
    printf '%s\n' "$AIRO_MIND_MODELS_DIR"
    return
  fi
  local root="${AIRO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
  local staged="${root}/packages/feature_mind/assets/models"
  local sandbox="${HOME}/Library/Containers/com.developerscoffee.airo.tv/Data/Library/Application Support/com.developerscoffee.airo.tv/airo_mind"
  # Prefer multilingual tiny for Hindi/English meetings.
  if [[ -f "${staged}/ggml-tiny.bin" ]]; then
    printf '%s\n' "$staged"
    return
  fi
  if [[ -f "${sandbox}/ggml-tiny.bin" ]]; then
    printf '%s\n' "$sandbox"
    return
  fi
  if [[ -d "$staged" ]]; then
    printf '%s\n' "$staged"
    return
  fi
  if [[ -d "$sandbox" ]]; then
    printf '%s\n' "$sandbox"
    return
  fi
  printf '%s\n' "$staged"
}

mind_recording_duration_sec() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    return 1
  fi
  if command -v ffprobe >/dev/null 2>&1; then
    ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$file" 2>/dev/null \
      | awk '{printf "%.0f", $1}'
    return
  fi
  afinfo "$file" 2>/dev/null | awk '/estimated duration/ {printf "%.0f", $3}'
}

mind_recording_human_duration() {
  local sec="$1"
  local h=$((sec / 3600))
  local m=$(((sec % 3600) / 60))
  local s=$((sec % 60))
  if (( h > 0 )); then
    printf '%dh %dm' "$h" "$m"
  else
    printf '%dm %ds' "$m" "$s"
  fi
}

mind_recordings_list_files() {
  local dir
  dir="$(mind_recordings_root)"
  if [[ ! -d "$dir" ]]; then
    echo "recordings dir missing: $dir" >&2
    return 1
  fi
  find "$dir" -maxdepth 1 -type f \( -iname '*.m4a' -o -iname '*.wav' \) | sort
}

mind_recordings_resolve() {
  local query="${1:-}"
  local dir
  dir="$(mind_recordings_root)"

  if [[ -z "$query" ]]; then
    echo "usage: resolve <name|alias|path>" >&2
    return 1
  fi

  if [[ -f "$query" ]]; then
    printf '%s\n' "$query"
    return 0
  fi

  if [[ -f "${dir}/${query}" ]]; then
    printf '%s\n' "${dir}/${query}"
    return 0
  fi

  case "$query" in
    short|smallest)
      mind_recordings_shortest
      return
      ;;
    medium)
      mind_recordings_nth_shortest 2
      return
      ;;
    long|49m)
      mind_recordings_nth_longest 2
      return
      ;;
    full|longest|74m)
      mind_recordings_longest
      return
      ;;
  esac

  local match
  match="$(find "$dir" -maxdepth 1 -type f \( -iname "*${query}*.m4a" -o -iname "*${query}*.wav" \) 2>/dev/null | head -1)"
  if [[ -n "$match" && -f "$match" ]]; then
    printf '%s\n' "$match"
    return 0
  fi

  echo "no recording matched '$query' under $dir" >&2
  return 1
}

mind_recordings_sorted_by_duration() {
  local dir
  dir="$(mind_recordings_root)"
  while IFS= read -r file; do
    [[ -n "$file" ]] || continue
    local dur
    dur="$(mind_recording_duration_sec "$file")"
    printf '%s\t%s\n' "${dur:-0}" "$file"
  done < <(mind_recordings_list_files 2>/dev/null) | sort -n -k1,1
}

mind_recordings_shortest() {
  mind_recordings_sorted_by_duration | head -1 | cut -f2-
}

mind_recordings_longest() {
  mind_recordings_sorted_by_duration | tail -1 | cut -f2-
}

mind_recordings_nth_shortest() {
  local n="${1:-1}"
  mind_recordings_sorted_by_duration | sed -n "${n}p" | cut -f2-
}

mind_recordings_nth_longest() {
  local n="${1:-1}"
  mind_recordings_sorted_by_duration | tail -n "$n" | head -1 | cut -f2-
}

mind_recordings_basename_id() {
  basename "$1" | sed 's/\.[^.]*$//'
}

mind_extract_transcript_lines() {
  local log="$1"
  local out="$2"
  python3 - "$log" "$out" <<'PY'
import re
import sys

log_path, out_path = sys.argv[1:3]
segment_re = re.compile(
    r"^\[\d{2}:\d{2}(?:\.\d+)? -> \d{2}:\d{2}(?:\.\d+)?\] "
)
lines = []
header = None
with open(log_path, encoding="utf-8", errors="replace") as f:
    for line in f:
        line = line.rstrip("\n")
        if line.startswith("-- transcript"):
            header = line
            continue
        if header and segment_re.match(line):
            lines.append(line)
        if header and line.startswith("-- loading llama"):
            break
        if header and line.startswith("== done"):
            break

with open(out_path, "w", encoding="utf-8") as out:
    if header:
        out.write(header + "\n")
    for line in lines:
        out.write(line + "\n")
print(len(lines))
PY
}
