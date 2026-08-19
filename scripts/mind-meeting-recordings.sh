#!/usr/bin/env bash
# Dev tooling for real meeting recordings (default: ~/Documents/data).
#
# List recordings, transcribe with airo_mind_cli, run POC-2, analyze loops.
#
# Usage:
#   scripts/mind-meeting-recordings.sh list
#   scripts/mind-meeting-recordings.sh info short
#   scripts/mind-meeting-recordings.sh transcribe short
#   scripts/mind-meeting-recordings.sh transcribe full --poc2 --out artifacts/mind-macos-e2e/poc2-full
#   scripts/mind-meeting-recordings.sh head 180 short
#   scripts/mind-meeting-recordings.sh analyze
#
# Env:
#   AIRO_MIND_RECORDINGS_DIR   Directory with .m4a/.wav (default: ~/Documents/data)
#   AIRO_MIND_ARTIFACTS_DIR    Transcript/output root (default: artifacts/mind-macos-e2e)
#   AIRO_MIND_MODELS_DIR       Whisper + GGUF models (auto-detects staged assets / sandbox)

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export AIRO_ROOT="$ROOT"
# shellcheck source=scripts/lib/mind-recordings.sh
source "${ROOT}/scripts/lib/mind-recordings.sh"

usage() {
  sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
  cat <<'EOF'

Commands:
  list                     Recordings with duration and size (shortest → longest)
  info <alias|path>        Show one file (aliases: short, medium, long, full)
  transcribe <alias|path>  ASR via airo_mind_cli (writes transcript artifact)
      [--poc2] [--out DIR] [--skip-eval] [--meeting-id ID] [--language CODE]
      [--with-llm]           Run one-line LLM summary after ASR (slow, noisy logs)
  head <seconds> <alias>   Trim first N seconds to artifacts/ (needs ffmpeg)
  analyze [transcript]     Repetition / loop report (default: latest artifact)
  report [transcript]      Duration, segment stats, repetition summary

Aliases pick by duration under AIRO_MIND_RECORDINGS_DIR:
  short   shortest recording (~10 min)
  medium  second shortest
  long    second longest (~49 min)
  full    longest (~74 min)
EOF
}

cmd_list() {
  local dir
  dir="$(mind_recordings_root)"
  echo "recordings: $dir"
  echo ""
  printf '%-8s  %-10s  %s\n' "alias" "duration" "file"
  local i=0
  local count
  count="$(mind_recordings_list_files | wc -l | tr -d ' ')"
  while IFS=$'\t' read -r dur file; do
    [[ -n "$file" ]] || continue
    i=$((i + 1))
    local alias="-"
    case "$i" in
      1) alias="short" ;;
      2) [[ "$count" -ge 2 ]] && alias="medium" ;;
    esac
    if [[ "$i" -eq "$((count - 1))" ]] && [[ "$count" -ge 3 ]]; then
      alias="long"
    fi
    if [[ "$i" -eq "$count" ]]; then
      alias="full"
    fi
    local size
    size="$(du -h "$file" | awk '{print $1}')"
    printf '%-8s  %-10s  %s (%s)\n' "$alias" "$(mind_recording_human_duration "$dur")" "$(basename "$file")" "$size"
  done < <(mind_recordings_sorted_by_duration)
}

cmd_info() {
  local query="${1:-}"
  local file
  file="$(mind_recordings_resolve "$query")"
  local dur size
  dur="$(mind_recording_duration_sec "$file")"
  size="$(du -h "$file" | awk '{print $1}')"
  echo "path:     $file"
  echo "duration: $(mind_recording_human_duration "$dur") (${dur}s)"
  echo "size:     $size"
}

run_cli() {
  local audio="$1"
  shift
  local models
  models="$(mind_models_dir)"
  if [[ ! -f "${models}/ggml-tiny.bin" && ! -f "${models}/ggml-tiny.en.bin" ]]; then
    echo "whisper model missing under $models — run: app/tool/fetch_mind_models.sh" >&2
    exit 1
  fi
  # Sandbox shells may set CARGO_TARGET_DIR to a temp dir; always link into rust/target.
  unset CARGO_TARGET_DIR
  local bin
  bin="$(
    cd "${ROOT}/rust"
    cargo build -p airo_mind_cli -q 2>/dev/null
    cargo metadata --format-version 1 \
      | python3 -c "import json,sys; print(json.load(sys.stdin)['target_directory'] + '/debug/airo_mind_cli')"
  )"
  if [[ ! -x "$bin" ]]; then
    echo "failed to build airo_mind_cli at $bin" >&2
    exit 1
  fi
  (
    cd "${ROOT}/rust"
    "$bin" "$audio" --models-dir "$models" "$@"
  )
}

cmd_transcribe() {
  local query="${1:-short}"
  shift || true

  local poc2=false
  local skip_eval=false
  local with_llm=false
  local language=""
  local out_dir=""
  local meeting_id=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --poc2) poc2=true ;;
      --skip-eval) skip_eval=true ;;
      --with-llm) with_llm=true ;;
      --language) language="$2"; shift ;;
      --out) out_dir="$2"; shift ;;
      --meeting-id) meeting_id="$2"; shift ;;
      *)
        echo "unknown flag: $1" >&2
        exit 1
        ;;
    esac
    shift
  done

  local file
  file="$(mind_recordings_resolve "$query")"
  local id
  id="$(mind_recordings_basename_id "$file")"
  local artifacts
  artifacts="$(mind_recordings_artifacts_dir)"
  mkdir -p "$artifacts"

  if [[ "$poc2" == "true" ]]; then
    if [[ -z "$out_dir" ]]; then
      out_dir="${artifacts}/poc2-${id}"
    fi
    local extra=()
    [[ "$skip_eval" == "true" ]] && extra+=(--skip-eval)
    [[ -n "$meeting_id" ]] && extra+=(--meeting-id "$meeting_id")
    [[ -n "$language" ]] && extra+=(--language "$language")
    run_cli "$file" --out "$out_dir" "${extra[@]}"
    echo ""
    echo "POC-2 artifacts: $out_dir"
    return
  fi

  local transcript="${artifacts}/transcript-${id}.txt"
  local log="${artifacts}/transcribe-${id}.log"
  local extra=()
  [[ "$with_llm" != "true" ]] && extra+=(--asr-only)
  [[ -n "$language" ]] && extra+=(--language "$language")

  echo "audio:      $file"
  echo "transcript: $transcript"
  echo "log:        $log"
  echo "mode:       $([[ "$with_llm" == "true" ]] && echo 'asr+llm' || echo 'asr-only')"
  echo "(Whisper tiny loops on 70+ min — use 'short' or 'head' for fast checks)"
  echo ""

  set +e
  run_cli "$file" "${extra[@]}" > >(tee "$log") 2>&1
  local status=$?
  set -e

  if [[ "$status" -eq 0 ]]; then
    local seg_count
    seg_count="$(mind_extract_transcript_lines "$log" "$transcript")"
    ln -sf "$(basename "$transcript")" "${artifacts}/transcript-latest.txt"
    echo ""
    echo "✓ wrote $transcript ($seg_count segments, symlink: transcript-latest.txt)"
    cmd_report "$transcript"
  fi
  exit "$status"
}

cmd_head() {
  local seconds="${1:-180}"
  local query="${2:-short}"
  local file
  file="$(mind_recordings_resolve "$query")"
  if ! command -v ffmpeg >/dev/null 2>&1; then
    echo "ffmpeg required for head trim — install: brew install ffmpeg" >&2
    exit 1
  fi
  local artifacts id out
  artifacts="$(mind_recordings_artifacts_dir)"
  mkdir -p "$artifacts"
  id="$(mind_recordings_basename_id "$file")"
  out="${artifacts}/${id}-head-${seconds}s.m4a"
  echo "trimming first ${seconds}s of $(basename "$file") → $out"
  ffmpeg -y -hide_banner -loglevel error -i "$file" -t "$seconds" -c copy "$out"
  echo "✓ $out"
}

cmd_report() {
  local target="${1:-}"
  local artifacts
  artifacts="$(mind_recordings_artifacts_dir)"
  if [[ -z "$target" ]]; then
    if [[ -f "${artifacts}/transcript-latest.txt" ]]; then
      target="${artifacts}/transcript-latest.txt"
    else
      echo "no transcript — run transcribe first" >&2
      exit 1
    fi
  elif [[ ! -f "$target" && -f "${artifacts}/${target}" ]]; then
    target="${artifacts}/${target}"
  fi

  echo ""
  echo "=== transcript report: $(basename "$target") ==="
  python3 - "$target" <<'PY'
import re
import sys
from collections import Counter

path = sys.argv[1]
segment_re = re.compile(
    r"^\[(\d{2}):(\d{2}(?:\.\d+)?) -> (\d{2}):(\d{2}(?:\.\d+)?)\] (.*)$"
)

def to_sec(mm, ss):
    return int(mm) * 60 + float(ss)

texts = []
starts = []
ends = []
with open(path, encoding="utf-8", errors="replace") as f:
    for line in f:
        m = segment_re.match(line.strip())
        if not m:
            continue
        starts.append(to_sec(m.group(1), m.group(2)))
        ends.append(to_sec(m.group(3), m.group(4)))
        texts.append(m.group(5).strip())

if not texts:
    print("no segments parsed")
    sys.exit(0)

duration = ends[-1] if ends else 0
unique = len(set(texts))
print(f"segments:      {len(texts)}")
print(f"unique texts:  {unique} ({100*unique/max(len(texts),1):.1f}% unique)")
print(f"coverage:      {duration/60:.1f} min of audio transcribed")
print(f"chars:         {sum(len(t) for t in texts)}")

counts = Counter(texts)
repeated = [(t, c) for t, c in counts.items() if c > 3 and len(t) > 8]
repeated.sort(key=lambda x: -x[1])
if repeated:
    worst, n = repeated[0]
    preview = worst if len(worst) <= 60 else worst[:57] + "..."
    idx = texts.index(worst)
    print(f"loop risk:     HIGH — '{preview}' × {n}")
    if idx < len(starts):
        print(f"first loop:    ~{starts[idx]/60:.1f} min")
else:
    print("loop risk:     low (no phrase >3 repeats)")
PY
  echo ""
  "${ROOT}/scripts/analyze-transcript-repetition.sh" "$target"
}

cmd_analyze() {
  local target="${1:-}"
  local artifacts
  artifacts="$(mind_recordings_artifacts_dir)"
  if [[ -z "$target" ]]; then
    if [[ -f "${artifacts}/transcript-latest.txt" ]]; then
      target="${artifacts}/transcript-latest.txt"
    elif [[ -f "${artifacts}/transcript-full.txt" ]]; then
      target="${artifacts}/transcript-full.txt"
    else
      echo "no transcript found — run: scripts/mind-meeting-recordings.sh transcribe short" >&2
      exit 1
    fi
  elif [[ ! -f "$target" ]]; then
    target="${artifacts}/${target}"
  fi
  "${ROOT}/scripts/analyze-transcript-repetition.sh" "$target"
}

main() {
  local cmd="${1:-list}"
  shift || true
  case "$cmd" in
    list) cmd_list ;;
    info) cmd_info "$@" ;;
    transcribe|transcribe-only|asr) cmd_transcribe "$@" ;;
    head|clip) cmd_head "$@" ;;
    analyze|repetition) cmd_analyze "$@" ;;
    report) cmd_report "$@" ;;
    -h|--help|help) usage ;;
    *)
      echo "unknown command: $cmd" >&2
      usage >&2
      exit 1
      ;;
  esac
}

main "$@"
