# Live latency benchmarks

Status: **Harness only.** Date: 2026-08-23
Targets (not claims): partial &lt; 500 ms, stable &lt; 1 s.

## What is measured

`LiveSpeechPipeline` with a fake `SpeechEngine` that returns immediately:

- **Partial latency:** time from `push_pcm` + `step` until a `Partial` event.
- **Stable latency:** time from the silence window `step` until a `Stable` event.

Test: `airo_mind_audio` `fake_engine_partial_and_stable_latencies_are_measurable`.

This proves the pipeline can *record* those intervals and that the fake engine
path is well under the targets. It is **not** evidence about whisper.cpp on a
device.

## Not yet a release gate

A CI gate on real weights needs:

1. A pinned speech fixture and model (see `speech_offline.rs` / tiny.en).
2. Repeatable wall-clock budgets with machine-class exemptions.
3. Explicit fail thresholds after a measured baseline, not these targets copied
   as if they were already met.

Until that exists, live latency remains **Preview**.
