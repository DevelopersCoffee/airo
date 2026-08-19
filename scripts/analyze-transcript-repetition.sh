#!/usr/bin/env bash
# Summarize repetition / hallucination loops in a Whisper transcript artifact.
#
# Usage:
#   scripts/analyze-transcript-repetition.sh [transcript.txt]
#   scripts/mind-meeting-recordings.sh analyze
#
# With no args, uses artifacts/mind-macos-e2e/transcript-latest.txt or transcript-full.txt.
#
# Prints: total segments/lines, first loop timestamp (if segment JSON), top repeated phrases.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="${AIRO_MIND_ARTIFACTS_DIR:-$ROOT/artifacts/mind-macos-e2e}"

if [[ $# -ge 1 ]]; then
  FILE="$1"
else
  if [[ -f "${ARTIFACTS}/transcript-latest.txt" ]]; then
    FILE="${ARTIFACTS}/transcript-latest.txt"
  elif [[ -f "${ARTIFACTS}/transcript-full.txt" ]]; then
    FILE="${ARTIFACTS}/transcript-full.txt"
  else
    echo "usage: $0 [transcript.txt]" >&2
    echo "  or run: scripts/mind-meeting-recordings.sh transcribe short" >&2
    exit 1
  fi
  echo "using: $FILE"
fi
if [[ ! -f "$FILE" ]]; then
  echo "file not found: $FILE" >&2
  exit 1
fi

python3 - "$FILE" <<'PY'
import re
import sys
from collections import Counter

path = sys.argv[1]
lines = [ln.strip() for ln in open(path, encoding="utf-8", errors="replace") if ln.strip()]
segment_line = re.compile(
    r"^\[(\d+(?:\.\d+)?|\d{2}:\d{2}(?:\.\d+)?|\d{2}:\d{2}:\d{2}(?:\.\d+)?)\s*->"
)
lines = [ln for ln in lines if segment_line.match(ln) or '"text"' in ln]
print(f"lines (segments): {len(lines)}")

def parse_ts_to_sec(ts: str) -> float:
    ts = ts.strip()
    if re.match(r"^\d+(\.\d+)?$", ts):
        return float(ts)
    # MM:SS.mmm or HH:MM:SS.mmm from airo_mind_cli
    parts = ts.split(":")
    if len(parts) == 2:
        return float(parts[0]) * 60 + float(parts[1])
    if len(parts) == 3:
        return float(parts[0]) * 3600 + float(parts[1]) * 60 + float(parts[2])
    return 0.0

# Segment-style lines: [start -> end] text  OR JSON with "text"
texts = []
starts = []
for ln in lines:
    m = re.match(
        r"\[(\d+(?:\.\d+)?|\d{2}:\d{2}(?:\.\d+)?|\d{2}:\d{2}:\d{2}(?:\.\d+)?)\s*->\s*"
        r"(\d+(?:\.\d+)?|\d{2}:\d{2}(?:\.\d+)?|\d{2}:\d{2}:\d{2}(?:\.\d+)?)\]\s*(.*)",
        ln,
    )
    if m:
        starts.append(parse_ts_to_sec(m.group(1)))
        texts.append(m.group(3).strip())
    elif '"text"' in ln:
        tm = re.search(r'"text"\s*:\s*"([^"]*)"', ln)
        if tm:
            texts.append(tm.group(1).strip())
    else:
        texts.append(ln)

if not texts:
    print("no parseable segment text found")
    sys.exit(0)

counts = Counter(texts)
repeated = [(t, c) for t, c in counts.items() if c > 3 and len(t) > 8]
repeated.sort(key=lambda x: -x[1])

print(f"unique segment texts: {len(counts)}")
if repeated:
    print("\nTop repeated phrases (>3 occurrences, len>8):")
    for text, count in repeated[:15]:
        preview = text if len(text) <= 72 else text[:69] + "..."
        print(f"  {count:5d}  {preview}")

    worst_text, worst_count = repeated[0]
    # Find first run of worst phrase in sequence
    first_idx = next(i for i, t in enumerate(texts) if t == worst_text)
    if starts and first_idx < len(starts):
        print(f"\nFirst repeat of top phrase at ~{starts[first_idx]:.1f}s ({first_idx} segments in)")
    else:
        print(f"\nFirst repeat of top phrase at segment index {first_idx}")

    # Consecutive run length at first occurrence
    run = 1
    for t in texts[first_idx + 1:]:
        if t == worst_text:
            run += 1
        else:
            break
    print(f"Consecutive run length at first block: {run}")
else:
    print("no heavy phrase repetition detected (>3 repeats)")
PY
