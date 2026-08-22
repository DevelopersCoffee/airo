# Live capture fan-out — one microphone, two consumers

Status: **Contract.** Companion to
[`docs/superpowers/specs/2026-08-22-streaming-stt-zero-copy-design.md`](../../superpowers/specs/2026-08-22-streaming-stt-zero-copy-design.md)
(§6.5) and [ADR-0025](../../adr/0025-streaming-speech-engine-boundary.md).
Date: 2026-08-22
Owner: Platform Architect. Required reviewers: Chief Security Officer (mic
entry point), Chief Performance Officer (copy budget), Rust Architect (ring).

This file exists because "where does the PCM come from" is the part of live
transcription that differs per platform, and the part most likely to be solved
locally in a way that quietly breaks the rule everywhere else.

## The rule

One microphone session feeds **two independent consumers**:

```text
                        ┌─────────────────────────────────────┐
   Microphone  ────────►│  Platform capture (native)          │
                        └───────────────┬─────────────────────┘
                                        │ fan-out
                        ┌───────────────┴───────────────┐
                        ▼                               ▼
        ┌───────────────────────────┐   ┌───────────────────────────────┐
        │ Encoded file (AAC/WAV)    │   │ Bounded PCM ring (native)     │
        │ written incrementally     │   │ 16 kHz mono i16, drop-oldest  │
        │ DURABILITY / IMPORT       │   │ LIVE STT ONLY                 │
        └───────────────────────────┘   └───────────────┬───────────────┘
                        │                               ▼
                        │                        VAD → windowing
                        │                               ▼
                        │                    SpeechEngine (streaming)
                        │                               ▼
                        │                    stabilizer → transcript events
                        ▼                               ▼
             transcribe_recording (unchanged)      Flutter live transcript
```

Two consumers, two failure modes, deliberately independent:

- The **file** is the durability story. It already works
  (`PlatformAudioRecorderPort` hands `package:record` a path and the native
  encoder writes incrementally), and it is what makes AC1 — a 90-minute
  recording survives an app kill — true. If live STT dies mid-session, the file
  must still transcribe through `transcribe_recording`.
- The **ring** is the liveness story. It is lossy on purpose: bounded, and
  drop-oldest under pressure. Dropping a span degrades one part of a live
  transcript; growing without bound kills the process and takes the recording
  with it.

Neither may be implemented in terms of the other. Decoding the encoded file
back to PCM to feed the ring (`mmap` or otherwise) is rejected — it is
compressed, it lags the encoder, and it re-reads `secret`-class audio from
disk to do work the capture layer already had in hand.

## What Dart may and may not do

| Concern | Owner |
|---|---|
| Consent gate, permission prompt | Dart (`AudioScribeConsentGate`, unchanged) |
| Session lifecycle: start / pause / resume / stop | Dart (`MeetingCaptureController`, unchanged) |
| Android foreground service | Dart → MethodChannel (`com.airo.meeting_recording`, unchanged) |
| File path selection | Dart (unchanged) |
| **PCM sample buffers** | **Native. Never Dart.** |
| Ring, VAD, windowing, stabilization | Native (`airo_mind_audio`, `airo_mind_whisper`) |
| Transcript events | Native → Dart, structured |

`push_pcm` is **not a public API**. Dart calls `start_live_session` and gets
transcript events back; it never learns that a ring exists. A PCM ingest
function may exist inside the native crates, and — under §"Interim shim" — may
be temporarily reachable from Dart on a named platform, but it is never the
contract, never documented as the way to use Airo Mind, and never depended on
by the live transcript UI.

## Per-platform status and plan

| Platform | Capture today | Fan-out path | Order |
|---|---|---|---|
| macOS / Linux / Windows | `package:record` → file | Native capture in `airo_mind_audio` (or a platform recorder that exposes PCM), feeding file + ring | **First** — no foreground-service or background-audio constraints, so ZC-1 is provable here with the least platform noise |
| Android | `package:record` (`MediaRecorder`) + `MeetingRecordingService` foreground service, type `microphone` | Needs a capture path that yields PCM frames *and* keeps the foreground service semantics — `AudioRecord` + app-side encode is the likely shape, and it is a real change to how recording works on this platform | **Second** — hardest, and the one where an interim shim is most likely to be needed |
| iOS / iPadOS | `package:record` (`AVAudioRecorder`), background audio via `UIBackgroundModes` | `AVAudioEngine` tap alongside the file writer | **Third** — gated on the Mind engine build ([#1546](https://github.com/DevelopersCoffee/airo/issues/1546)); not a blocker for the contract |
| Web | No `dart:ffi`; `feature_mind_stub` | **Not supported.** Live STT reports unavailable, the same way the rest of the Mind native path already does on web | n/a |

Android deserves the explicit warning: `MediaRecorder` gives an encoded file
and no PCM. Getting frames means moving to `AudioRecord` and owning the encode,
which touches the one platform where the foreground service, the OS privacy
indicator, and process-kill behavior all interact. Budget for that being the
real work of Stage 2, not a plumbing detail.

## Interim shim (bounded, per platform, with an owner)

If a platform cannot fan out PCM natively yet, a Dart-side PCM stream
(`record.startStream`) may feed the native session **temporarily**, under all
of the following:

1. It is used **only** through the same `start_live_session` / transcript-event
   surface. No new public API shape, so removing the shim is not a breaking
   change.
2. It is named in this file, with the platform and the tracking issue.
3. It is recorded as a known violation of ZC-1, not as a design.
4. It does not change the file path: the encoded file is still written by the
   platform recorder, so durability never depends on the shim.

No shim is in place today. This section exists so that adding one is a
documented decision rather than a discovery made later during profiling.

| Platform | Shim | Tracking |
|---|---|---|
| macOS / Linux / Windows (interim) | `record.startStream` (PCM16) → `push_live_pcm` via `MeetingLivePcmShim` | Stage 2 — remove when native fan-out lands |

## Conformance

These are the checks that make the rule enforceable rather than aspirational.
They belong with Stage 2, alongside the code that first fans out.

| Check | Where |
|---|---|
| A crash during a live session leaves a file that `transcribe_recording` accepts | Integration test per platform |
| Live session start on an over-budget device is refused before the mic opens | Host test against `Supervisor` admission |
| Ring overflow emits DEGRADED and does not grow memory | Host test, fixture PCM, forced stall |
| No PCM-shaped type crosses the FRB surface | Reviewable in the generated bridge; candidate for a `scripts/check-*` guard once the surface exists |
| Live transcript UI never rewrites STABLE text | Dart test with scripted event sequences |

## References

- `packages/feature_mind/lib/src/capture/data/audio_recorder_port.dart` — the
  recorder seam and why incremental file writing already satisfies AC1.
- `packages/feature_mind/lib/src/capture/data/meeting_recording_service_gateway.dart`
  and `app/android/app/src/product/kotlin/io/airo/app/MeetingRecordingService.kt`
  — the Android foreground service the fan-out must preserve.
- `packages/feature_mind/lib/src/capture/application/meeting_capture_controller.dart`
  — start → (pause ⇄ resume)* → stop, including OS interruption.
- `rust/airo_mind_audio/src/lib.rs` — decode/downmix/resample, and the intended
  home for the ring and VAD.
- `docs/superpowers/specs/2026-08-22-streaming-stt-zero-copy-design.md` — the
  zero-copy boundary rules (§4) and the session contract (§6).
