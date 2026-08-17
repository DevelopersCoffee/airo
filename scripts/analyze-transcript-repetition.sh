#!/usr/bin/env bash
# Summarize repetition / hallucination loops in a Whisper transcript artifact.
#
# Usage:
#   scripts/analyze-transcript-repetition.sh artifacts/mind-macos-e2e/transcript-full.txt
#
# Prints: total segments/lines, first loop timestamp (if segment JSON), top repeated phrases.

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <transcript.txt>" >&2
  exit 1
fi

FILE="$1"
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
print(f"lines (non-empty): {len(lines)}")

# Segment-style lines: [start -> end] text  OR JSON with "text"
texts = []
starts = []
for ln in lines:
    m = re.match(r"\[(\d+(?:\.\d+)?)\s*->\s*(\d+(?:\.\d+)?)\]\s*(.*)", ln)
    if m:
        starts.append(float(m.group(1)))
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
