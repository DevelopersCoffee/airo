# airo_mind_audio

Cross-platform audio preprocess for Airo Mind: **any supported container → 16 kHz mono 16-bit PCM** (whisper input shape).

Used by `airo_mind_whisper::transcribe_recording` (product `.m4a` queue) and `airo_mind_cli` (dev loop). Not linked into `airo_mind_core`, which stays std-only.

## API

```rust
airo_mind_audio::preprocess_path(path) -> Result<wav::Pcm, String>
```

## Supported inputs

- AAC in MP4 (`.m4a`)
- WAV (any rate/channels — resampled/downmixed as needed)
- PCM in common symphonia containers

16 kHz mono 16-bit WAV takes a fast path through `airo_mind_core::wav::decode`.

## Dependencies (Constitution §6)

| Crate | License | Role |
|---|---|---|
| [symphonia](https://github.com/pdeljanov/Symphonia) | Apache-2.0 / MIT | Demux + decode AAC/M4A/WAV without a platform binary |
| [rubato](https://github.com/HEnquist/rubato) | MIT | Resample to 16 kHz |

Both ship inside the `airo_mind_whisper` cdylib on mobile — review binary-size impact when changing features.

## Verify

```bash
cargo test -p airo_mind_audio
```
