# Airo Mind — Platform Capability Matrix

This matrix is the human-readable projection of
`MindQualificationMatrix.current()`
(`packages/feature_mind/lib/src/qualification/mind_qualification.dart`). Each
cell is the **declared ceiling**; the value surfaced at runtime is capped down
to what `MindRuntimeCapabilitySignals` reports (see
`production-qualification.md` §1). States: `PROD` / `PREVIEW` / `EXP` (experimental)
/ `—` (unsupported).

| Capability | Desktop | Android | iOS | Web |
| --- | --- | --- | --- | --- |
| Recording | PREVIEW | PREVIEW | — | — |
| Offline STT | PREVIEW | PREVIEW | — | — |
| Live STT | PREVIEW | — | — | — |
| Stabilization | PREVIEW | — | — | — |
| Vocabulary | PREVIEW | PREVIEW | — | — |
| Live speaker activity | PREVIEW | — | — | — |
| Final diarization | PREVIEW | PREVIEW | — | — |
| Live Conversation IR | EXP | — | — | — |
| Live insights | EXP | — | — | — |
| Post-recording IR | PREVIEW | PREVIEW | — | — |
| Search | PREVIEW | PREVIEW | — | — |
| Memory | PREVIEW | PREVIEW | — | — |

## Why each column is capped

- **Desktop** (macOS/Linux/Windows): the only host that runs the live pipeline
  today (`liveTranscriptionPreviewSupported`). Native engines build for all
  three. Tops out at `PREVIEW` — no production gates pass yet. Live Conversation
  IR and live insights are `EXPERIMENTAL` (IR is post-recording only; the
  insights rail is a stub).
- **Android**: recording, offline STT, and post-recording intelligence are on
  the qualification path (`PREVIEW`), but the live pipeline is **not** wired to
  the native Android audio fan-out, so all live rows are unsupported.
- **iOS**: `feature_mind` does not declare the iOS platform and the native Mind
  engines are not wired (issue #1546), so every capability is unsupported until
  that build path exists.
- **Web**: no `dart:ffi`; the whisper/llama engines are stubbed. Everything is
  unsupported by construction — the runtime resolver forces `UNSUPPORTED` on web
  even if signals claim otherwise (test:
  `web is always unsupported even if signals claim otherwise`).

## Runtime capping examples (from tests)

- Native bridge fails to load → **every** capability resolves to `UNSUPPORTED`.
- Host cannot run the live pipeline → all live rows resolve to `UNSUPPORTED`
  while post-recording rows stay at their declared ceiling.
- No file recorder present → `Recording` resolves to `UNSUPPORTED`.

## Maintaining this matrix

Change the declared ceilings in `MindQualificationMatrix.current()` and update
this table together. A cell may only be raised to `PROD` when the gates in
`production-qualification.md` §3 are green for that capability/platform, with
evidence linked in `latency-benchmarks.md` and `evaluation-results.md`. The unit
tests assert the no-production-by-default and never-exceeds-ceiling invariants.
