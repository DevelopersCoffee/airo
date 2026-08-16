# airo_mind_cli

Cross-platform dev-loop smoke test for `airo_mind_whisper` and `airo_mind_llama`:
a real `.m4a` or `.wav` in, a timestamped transcript and a generated summary out.
On macOS both engines can be Metal-accelerated. Not shipped product code — nothing
here is wired into the Flutter bridge or built by cargokit. It exists so changes
to the two Rust inference crates can be exercised locally before the Android/iOS
app builds pick the same libraries up.

## What it does

### Legacy dev loop (default)

1. Decodes the input audio to 16 kHz mono 16-bit PCM via `airo_mind_audio`
   (symphonia + rubato — no platform `afconvert` / ffmpeg binary).
2. Runs it through `WhisperSpeechEngine` behind the real `Supervisor` /
   `SpeechEngine` contract, printing each `TranscriptSegment` with its
   `start_ms`/`end_ms` timestamps.
3. Joins the segments into a transcript and feeds it to
   `LlamaGenerationEngine` (also behind `Supervisor`) with a one-line
   summarization prompt, streaming the generated text to stdout chunk by
   chunk as `GenerationChunk`s arrive.
4. Prints load/inference timings for both engines.

### POC-2 full offline path (`--out`)

One command runs the product pipeline end to end:

1. preprocess → whisper ASR (segment ids `s0`, `s1`, …)
2. `airo_mind_transcript::process`
3. `airo_mind_meeting::extract` → `validate` → `generate_mom`
4. Writes artifacts under `--out/`:
   `transcript.json` (raw + normalized segments), `chunks.json`,
   `meeting_ir.json`, `predicted_ir.json`, `mom.md`, `hypothesis_transcript.txt`
5. Runs `airo_mind_eval` gates (unless `--skip-eval`) and writes
   `out/eval/run-NNN.json`. Exits non-zero when any gate fails.

Whisper defaults to multilingual `ggml-tiny.bin` with auto language detection.

### Optional user recording (`meeting_001`)

For real-device POC-2 runs, symlink any local `.m4a` (not committed):

```sh
ln -sf /path/to/your/recording.m4a rust/fixtures/meeting_001.m4a
```

Preprocess-only smoke test (no models):

```sh
cd rust && cargo test -p airo_mind_audio --test meeting_001_m4a
```

Then run against the `meeting_001` eval golden set (see
`airo_mind_eval/golden/meeting_001/README.md`):

```sh
cd rust
cargo run -p airo_mind_cli -- \
  --models-dir models \
  --out ./out/meeting_001/ \
  --golden-meeting meeting_001
```

The hand-authored `meeting_001` transcript is domain-agnostic fixture text;
whisper on unrelated audio will fail WER until goldens match a real pass — use
`--skip-eval` to inspect artifacts only.

```sh
cd rust
mkdir -p models   # put ggml-tiny.bin and qwen2.5-0.5b-instruct-q4_k_m.gguf here
cargo run -p airo_mind_cli -- fixtures/speech.m4a \
  --models-dir models \
  --out ./out/
```

`--models-dir` must contain **both** the whisper `.bin` and llama `.gguf` (or the first
`.bin` / `.gguf` found). For separate locations, omit `--models-dir` and set
`AIRO_MIND_WHISPER_MODEL` / `AIRO_MIND_LLAMA_MODEL` instead.

Eval defaults score against the reference-meeting golden set in
`airo_mind_eval/golden/reference_meeting/` and
`airo_mind_meeting/tests/fixtures/golden_ir.json` — expect gate failures
when the input audio is unrelated (e.g. `speech.m4a`). That is normal; the
report still proves the wiring.

On macOS, both crates are built with their `metal` cargo feature when available.

## Re-running it

```sh
cd rust
cargo run -p airo_mind_cli
```

Dev profile, not `--release`: the workspace's `[profile.release]` sets
`lto = "fat"` (tuned for `airo_core`'s single-cdylib case — see the comment
above that block), and full LTO across two rlibs that each carry their own
`flutter_rust_bridge`-generated `frb_generated` module (`airo_mind_whisper`
and `airo_mind_llama`, both cdylib-shaped by design, statically linked into
one bin here) fails at the bitcode-merge step with a duplicate-symbol error
on `frb_dart_fn_deliver_output`. Not a regression from anything this crate
does — the two libraries were never meant to share a link unit — and not
worth chasing for a dev-only tool: `cargo build -p airo_mind_cli` (dev
profile) links them fine and every model-load/inference cost dominates the
missing optimization anyway.

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

## Audio preprocess

Decode/resample lives in `airo_mind_audio` (see that crate's README for
dependency scorecard). Supported inputs include AAC `.m4a` and WAV at any
rate/channel layout; output is always 16 kHz mono 16-bit PCM for whisper.

## Sample run

```
$ cargo run -p airo_mind_cli
== Airo Mind dev loop ==
...
-- transcript (3 segment(s)) --
[00:00.000 -> 00:04.500] Priya said the Kafka consumer lag is the bottleneck, not the database.
[00:04.500 -> 00:07.300] We agreed to add three more pods before Friday.
[00:07.300 -> 00:09.700] Raj will own the rollout and report back Monday.

-- loading llama.cpp (Metal) --
...
-- generation --
...

== done ==
transcript chars: 167
generated chars:  146
```
