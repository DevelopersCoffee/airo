# airo_mind_cli

macOS dev-loop smoke test for `airo_mind_whisper` and `airo_mind_llama`:
a real `.m4a` in, a timestamped transcript and a generated summary out, both
engines Metal-accelerated. Not shipped product code — nothing here is wired
into the Flutter bridge or built by cargokit. It exists so changes to the two
Rust inference crates can be exercised in seconds on a Mac, before they reach
the Android/iOS app builds that eventually consume the same libraries
(milestone 26, Wave 1 exit gate: "macOS CLI: GGUF gen + timestamped
transcript from real .m4a").

## What it does

1. Decodes the input audio to 16 kHz mono 16-bit PCM by shelling out to
   `afconvert` (built into macOS — see "Why `afconvert`" below).
2. Runs it through `WhisperSpeechEngine` behind the real `Supervisor` /
   `SpeechEngine` contract, printing each `TranscriptSegment` with its
   `start_ms`/`end_ms` timestamps.
3. Joins the segments into a transcript and feeds it to
   `LlamaGenerationEngine` (also behind `Supervisor`) with a one-line
   summarization prompt, streaming the generated text to stdout chunk by
   chunk as `GenerationChunk`s arrive.
4. Prints load/inference timings for both engines.

Both crates are built with their `metal` cargo feature, so watch the ggml
load-time log lines this prints to stderr to confirm the run actually used
Metal rather than falling back to CPU:

- whisper: `whisper_backend_init_gpu: using Metal backend`,
  `ggml_metal_device_init: GPU name: <your GPU>`
- llama: `llama_prepare_model_devices: using device Metal (...)`,
  `load_tensors: offloaded N/N layers to GPU`,
  `llama_kv_cache: layer N: dev = Metal`

## Re-running it

```sh
cd rust
cargo run --release -p airo_mind_cli
```

By default it uses:

| Input | Default path | Override |
|---|---|---|
| audio | `rust/fixtures/speech.m4a` (checked-in fixture, see below) | `AIRO_MIND_CLI_AUDIO=/path/to.m4a` or first CLI arg |
| whisper model | `rust/airo_mind_whisper/models/ggml-tiny.en.bin` | `AIRO_MIND_WHISPER_MODEL=/path/to/model.bin` |
| llama model | `rust/airo_mind_llama/models/qwen2.5-0.5b-instruct-q4_k_m.gguf` | `AIRO_MIND_LLAMA_MODEL=/path/to/model.gguf` |

The two model paths are exactly the ones `airo_mind_whisper/tests/speech_offline.rs`
and `airo_mind_llama/tests/generation_offline.rs` already look for — dropping
models there makes both those `--features whisper`/`--features llama` test
suites and this CLI work with a single download.

Models are gitignored (`rust/airo_mind_whisper/models/*.bin`,
`rust/airo_mind_llama/models/*.gguf`) — nothing under `models/` is committed.
Fetch them once:

```sh
mkdir -p rust/airo_mind_whisper/models rust/airo_mind_llama/models

curl -L -o rust/airo_mind_whisper/models/ggml-tiny.en.bin \
  https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.en.bin   # ~78 MB

curl -L -o rust/airo_mind_llama/models/qwen2.5-0.5b-instruct-q4_k_m.gguf \
  https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf   # ~491 MB
```

Both are the smallest viable pick for a fast local loop: whisper's smallest
English GGML model, and a 0.5B-parameter instruct GGUF at Q4_K_M.

## The fixture

`rust/fixtures/speech.m4a` is a real AAC/M4A file (not silence, not a tone) —
synthesized once on macOS with:

```sh
say -v Samantha -o speech.aiff "Priya said the Kafka consumer lag is the \
  bottleneck, not the database. We agreed to add three more pods before \
  Friday. Raj will own the rollout and report back Monday."
afconvert -f m4af -d aac speech.aiff speech.m4a
rm speech.aiff
```

It is small enough to check in (~48 KB, same precedent as `fixtures/jfk.wav`,
which `airo_mind_whisper`'s own test suite already commits).

## Why `afconvert` instead of an in-process decoder

This binary never ships and runs only on a developer's Mac, where
`afconvert` is always present. Adding an AAC/MP4 demuxer crate (e.g.
`symphonia` with its `aac`/`isomp4` features) to decode `.m4a` in-process
would need the same Constitution §6 dependency scorecard the engine crates
go out of their way to avoid — see the comment on `wav.rs` in
`airo_mind_core` — for a benefit only this dev tool would use. Shelling out
keeps the decode step real (it is still a genuine AAC decode, just done by
the OS's own tool) without adding a dependency to the workspace.

## Sample run

```
$ cargo run --release -p airo_mind_cli
== Airo Mind macOS dev loop ==
...
-- transcript (3 segment(s)) --
[00:00.000 -> 00:04.500] Priya said the Kafka consumer lag is the bottleneck, not the database.
[00:04.500 -> 00:07.300] We agreed to add three more pods before Friday.
[00:07.300 -> 00:09.700] Raj will own the rollout and report back Monday.

-- loading llama.cpp (Metal) --
...
-- generation --
Priya and Raj have agreed to add three more pods to the Kafka consumer lag
before Friday, with Priya owning the rollout and reporting back Monday.

== done ==
transcript chars: 167
generated chars:  146
```
