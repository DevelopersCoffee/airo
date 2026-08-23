# Airo Mind — Evaluation Results

Status: **Not executed.** A golden evaluation corpus does not exist yet, and the
evaluation cannot be run in the CI/cloud environment that produced this document
(no audio-capture hardware, no built native engines, no model weights, no
recorded golden meetings). This file defines the corpus, the metrics, and the
harness so results can be produced from a real run — not assumed.

## Harness that exists

- `rust/airo_mind_eval` — golden evaluation crate with WER and Minutes-quality
  gates (per the audit). It has the machinery for scoring but **no
  multi-language golden meeting corpus** to score against.
- Rust conformance tests under `rust/airo_mind_*/tests/` cover deterministic
  units (stabilizer, vocabulary, ring/VAD, IR extraction) but are not
  end-to-end conversation evaluations.

## Required golden corpus (spec §16)

Representative recordings, each with a hand-checked expected transcript,
speaker segments, entities, actions, decisions, topics, and timestamps:

```text
English meeting            two speakers            proper nouns
Hindi meeting              four speakers           technical terminology
Hinglish meeting           speaker interruption    long meeting
technical meeting          overlapping speech      short meeting
background noise           quiet speech
fast speech                slow speech
```

## Metrics (spec §16)

| Metric | Definition | Gate (target) |
| --- | --- | --- |
| WER | Word error rate vs expected transcript | to be set from baseline |
| CER | Character error rate | to be set from baseline |
| Speaker error | Diarization error rate | to be set |
| Entity accuracy | Extracted entities vs expected | to be set |
| Action accuracy | Detected action items vs expected | to be set |
| Decision accuracy | Detected decisions vs expected | to be set |
| Partial/stable/finalization latency | See `latency-benchmarks.md` | §4 targets |
| Memory / CPU / thermal | Peak during evaluation run | to be set |

## Procedure

```text
1. Record + annotate the corpus above (offline, one-time).
2. Build the native engines and download pinned weights.
3. Replay each case through the batch and live pipelines.
4. Score with airo_mind_eval; emit a JSON + markdown report into artifacts/.
5. Wire the thresholds as blocking CI gates (spec §17).
```

## Results

_None yet — see status above._

| Case | WER | CER | Speaker err | Entity | Action | Decision | Pass? |
| --- | --- | --- | --- | --- | --- | --- | --- |
| — | — | — | — | — | — | — | — |

Until this table is populated from a real run meeting the gates, the affected
capabilities (offline/live STT, diarization, IR extraction) stay at `PREVIEW` or
below in the capability matrix.
