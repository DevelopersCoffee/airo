# Airo Mind — production qualification

Status: **NOT PRODUCTION QUALIFIED**
Date: 2026-08-23
Evidence: [platform-capability-matrix.md](./platform-capability-matrix.md),
[latency-benchmarks.md](./latency-benchmarks.md),
[evaluation-results.md](./evaluation-results.md),
[LIVE_SCRIBE_DESKTOP_PREVIEW_QUALIFICATION.md](./LIVE_SCRIBE_DESKTOP_PREVIEW_QUALIFICATION.md)

## Verdict

```text
NOT PRODUCTION QUALIFIED
```

Desktop live scribe remains **Preview**. Default mode for every platform is
**After recording**. Live modes stay gated off on Android, iOS, and web.

This document does not lower gates. Remaining P0 items are listed below.

## What this pass closed

| Gate | Evidence |
|---|---|
| Unified fan-out (file + live, live never blocks file) | `rust/airo_mind_audio` `CaptureFanout` + `IncrementalWavWriter` |
| Live inference failure does not corrupt the file | `tests/fanout_crash_recovery.rs` |
| Dead live consumer mid-session leaves a transcribable WAV | same |
| Pipeline isolates STT backend errors | `live.rs` `live_failed` |
| Admission refuses over-budget live STT | `Supervisor::check_speech_admission` tests + Dart warning path |
| Resource/thermal/battery policy (pure) | `ResourceGovernor` unit tests |
| In-process partial/stable latency harness | `fake_engine_partial_and_stable_latencies_are_measurable` |
| Incremental Conversation IR (no live LLM) | `airo_mind_meeting::live_ir` |
| Desktop one-mic (no second `AudioRecorder` file encoder) | `FanoutBackedAudioRecorderPort` |

## Still open (blocks PRODUCTION)

1. Native microphone capture inside Rust (cpal / platform AudioRecord) so PCM
   no longer crosses FRB (`push_live_pcm` / ZC-1).
2. Measured live latency on real whisper weights (partial &lt; 500 ms, stable
   &lt; 1 s) as a release gate, not only the in-process fake-engine harness.
3. Golden conversation suite (WER/CER, speakers, entities) on representative
   recordings.
4. Conversation IR events on the FRB/UI surface (insights rail is still a stub).
5. Runtime thermal/battery probes wired into the live session (policy types
   exist; OS probes do not).
6. Android / iOS native capture lifecycle and device qualification.
7. Speaker timeline reconciliation beyond provisional live lanes + post-stop
   diarization (already present when `audio_path` is passed to
   `stop_live_session`).

## Product states

| Surface | State |
|---|---|
| Desktop live STT | **PREVIEW** |
| Desktop after-recording STT | **PRODUCTION** (unchanged file path) |
| Android / iOS live | **UNSUPPORTED** (settings gated) |
| Web live | **UNSUPPORTED** |

Do not show "Production" for live intelligence until this file's verdict
changes on the basis of new test evidence.
