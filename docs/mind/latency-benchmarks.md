# Airo Mind — Latency Benchmarks

Status: **Not measured.** Live-path latency instrumentation does not exist yet
(Phase 1 audit finding), and it cannot be measured in the CI/cloud environment
that produced this document (no audio-capture hardware, no built native engines,
no downloaded whisper weights). This file defines the targets, the measurement
method, and where instrumentation must hook — so numbers can be filled in from a
real desktop run, not assumptions.

## Targets (measured, not claimed)

| Metric | Target | Definition |
| --- | --- | --- |
| Partial latency | < 500 ms | Wall-clock from end of the audio window to `TranscriptEvent.delta` (`state = partial`) reaching Flutter. |
| Stable latency | < 1 s | Wall-clock from utterance end (VAD `SpeechEnded`) to the `stable` delta for that segment. |
| Finalization latency | (record) | From `stop_live_session` to the final segment being committed. |

These are **targets, not a hard per-frame budget.** There is deliberately no
300 ms hard processing requirement (spec §4).

## What exists today

- No wall-clock timing on live delta emission. Deltas carry only audio
  `start_ms`/`end_ms` from whisper segment timing.
- `airo_mind_core::RuntimeStats` (`prefill_ms`, `generation_ms`) measures
  *generation*, not live STT.
- `LiveStepReport` exposes `window_energy` and `degraded`, not latency.

## Required instrumentation (design)

1. Stamp each PCM window with an ingest monotonic timestamp when
   `push_live_pcm` enqueues it into the ring
   (`rust/airo_mind_audio/src/live.rs`).
2. On each emitted `TranscriptEvent::Delta`, attach `emit_monotonic_ms` and the
   ingest timestamp of the window that produced it.
3. Compute partial/stable latency in the Rust session layer
   (`rust/airo_mind_whisper/src/api/meetings.rs`) and expose them on a
   `LatencySample` event (new field on the transcript event protocol, spec §5).
4. Aggregate p50/p95 in a host-only harness (extend
   `rust/airo_mind_eval`) that replays a fixed PCM fixture through the live
   session — this removes the need for a live microphone and makes the
   measurement reproducible in CI once engines build.

## Measurement procedure (desktop)

```text
1. Build airo_mind_whisper + airo_mind_llama cdylibs (cargokit).
2. Download the pinned whisper weights.
3. Replay a known WAV fixture through start_live_session/push_live_pcm at
   real-time rate.
4. Record partial/stable/finalization latency samples.
5. Report p50/p95 vs targets; fail the gate if p95 exceeds target.
```

## Results

_None yet — see status above._

| Run | Platform | Engine/model | Partial p50/p95 | Stable p50/p95 | Finalization | Pass? |
| --- | --- | --- | --- | --- | --- | --- |
| — | — | — | — | — | — | — |

Until this table has real desktop numbers meeting the targets, live STT stays
`PREVIEW` in the capability matrix.
