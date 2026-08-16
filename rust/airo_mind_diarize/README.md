# airo_mind_diarize

Wave 3 scaffolding for on-device speaker diarization in Airo Mind.

Sits between whisper ASR (`airo_mind_whisper`) and transcript processing
(`airo_mind_transcript`). Today ships a deterministic **single-speaker**
fallback so the pipeline can carry `speaker_id` through segments before
ECAPA-TDNN embeddings and online clustering land.

## Pipeline position

```text
audio → airo_mind_audio (16 kHz PCM)
     → whisper (segments: id, start_ms, end_ms, text)
     → airo_mind_diarize (segments + speaker_id)
     → airo_mind_transcript (normalize + chunk)
     → Meeting IR / minutes
```

## API

```rust
use airo_mind_diarize::{diarize_segments, DiarizationStrategy};

// Product transcribe path (solo v0):
let result = diarize_segments(&segments, Some(&pcm), DiarizationStrategy::Solo)?;

// CLI / dev tests (stub embedder + clustering):
let result = diarize_segments(
    &segments,
    Some(&pcm),
    DiarizationStrategy::StubEmbedding {
        similarity_threshold: 0.85,
    },
)?;
```

Legacy helper:

```rust
use airo_mind_diarize::{Diarizer, SingleSpeakerDiarizer, DiarizationInput};

let result = SingleSpeakerDiarizer::new().diarize(&DiarizationInput {
    segments: &transcript_segments,
    pcm: None,
})?;
```

## Verify

```bash
cargo test -p airo_mind_diarize
```

## Non-goals (this crate)

- Sarvam Edge ASR or cloud diarization APIs
- Full ECAPA-TDNN / ONNX runtime (planned follow-up)
- `EmbeddingDiarizer` + `StubSpeakerEmbedder` for dev/tests; swap embedder for ONNX
- Word-level diarization (segment-level v1 only)
