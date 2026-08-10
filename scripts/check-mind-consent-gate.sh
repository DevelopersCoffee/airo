#!/usr/bin/env bash
set -euo pipefail

# Audio Scribe two-party consent gate (#1459).
#
# Recording a conversation is a legal act. This gate asserts that the only
# call site of VoiceSearchService.startListening() -- the entry point Audio
# Scribe uses to reach the microphone encoder -- inside the assistant
# presentation layer is the one wrapped by
# AudioScribeConsentGate.startRecording(). A second call site anywhere else
# in that tree is a path to the encoder that never asked the gate.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

GATE_FILE="packages/feature_mind/lib/src/assistant/consent/audio_scribe_consent_gate.dart"
SCAN_DIR="packages/feature_mind/lib/src/assistant"

# Positive control. This gate's whole job is to find a call site that is not
# wrapped by the gate, so a broken search reports OK having checked nothing.
# Prove both halves of the pattern still exist before trusting a clean scan.
if ! grep -q 'Future<T> startRecording<T>(' "$GATE_FILE" 2>/dev/null; then
  echo "FATAL: could not find startRecording on AudioScribeConsentGate in" >&2
  echo "$GATE_FILE, so this gate cannot verify the encoder is behind it." >&2
  echo "Passing silently would be worse than failing." >&2
  exit 127
fi

if ! grep -rq '\.startListening(' "$SCAN_DIR" --include='*.dart' 2>/dev/null; then
  echo "FATAL: no call to startListening() found under $SCAN_DIR, so this" >&2
  echo "gate cannot verify it is the encoder's only entry point. Passing" >&2
  echo "silently would be worse than failing." >&2
  exit 127
fi

failed=false
guarded_call_found=false

while IFS= read -r match; do
  file="${match%%:*}"
  rest="${match#*:}"
  line_no="${rest%%:*}"
  line="${rest#*:}"

  # The gate file itself defines startRecording()'s parameter and body -- it
  # is the door, not a caller of it.
  if [[ "$file" == "$GATE_FILE" ]]; then
    continue
  fi

  # `dart format` is free to wrap a call's arguments onto their own lines, so
  # the guard is not always on the same source line as the call it guards.
  # Widen the check to the three lines above the match -- wide enough to
  # survive reformatting a single call expression, narrow enough that an
  # unrelated startRecording() call three lines up a different function
  # would be an implausible false negative in a file this size.
  window_start=$(( line_no > 3 ? line_no - 3 : 1 ))
  window=$(sed -n "${window_start},${line_no}p" "$file")

  if [[ "$window" == *"startRecording("* ]]; then
    guarded_call_found=true
    continue
  fi

  failed=true
  echo "Consent gate violation: $file:$line_no calls startListening() without" >&2
  echo "going through AudioScribeConsentGate.startRecording():" >&2
  echo "  $line" >&2
done < <(grep -rn '\.startListening(' "$SCAN_DIR" --include='*.dart')

if [[ "$guarded_call_found" != true ]]; then
  echo "FATAL: found no startListening() call routed through startRecording()," >&2
  echo "so this gate cannot confirm the guarded path is actually used. Passing" >&2
  echo "silently would be worse than failing." >&2
  exit 127
fi

if [[ "$failed" == true ]]; then
  cat >&2 <<'EOF'

Recording is a legal act. Every call to VoiceSearchService.startListening()
from the assistant presentation layer must be wrapped by
AudioScribeConsentGate.startRecording(), so consent is checked before the
encoder ever runs. Route the call through the gate rather than calling the
service directly.
EOF
  exit 1
fi

echo "Consent gate OK: startListening() is only reached through AudioScribeConsentGate.startRecording()."
