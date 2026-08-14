# airo_mind_cli

macOS dev-loop smoke test for the full Wave 2 meeting pipeline:
`airo_mind_whisper` (ASR) → `airo_mind_transcript` (`#1632`, raw/normalized
text + overlapping semantic chunks) → `airo_mind_extract` (`#1633`, two-pass
Meeting IR extraction) → `airo_mind_llama` for the actual generation calls.
A real `.m4a` in, a grounded `MeetingIr` JSON document out, engines
Metal-accelerated. Not shipped product code — nothing here is wired into the
Flutter bridge or built by cargokit. It exists so changes to the pipeline
crates can be exercised in seconds on a Mac, before they reach the
Android/iOS app builds that eventually consume the same libraries (milestone
26: Wave 1 exit gate was "macOS CLI: GGUF gen + timestamped transcript from
real .m4a"; this is the Wave 2 extension, "POC-1: golden MoM reproduced from
existing transcript", `#1641`).

## What it does

1. Decodes the input audio to 16 kHz mono 16-bit PCM by shelling out to
   `afconvert` (built into macOS — see "Why `afconvert`" below).
2. Runs it through `WhisperSpeechEngine` behind the real `Supervisor` /
   `SpeechEngine` contract, printing each `TranscriptSegment` with its
   `start_ms`/`end_ms` timestamps, and assigns each one a stable `"s{n}"` id
   (the same scheme `airo_mind_whisper::api::meetings` uses in the real
   bridge).
3. Runs the id'd segments through `airo_mind_transcript::process` (`#1632`):
   technical-term/number normalization plus overlapping semantic chunking,
   printing each chunk's span and the segment ids it covers.
4. Runs each chunk through `airo_mind_extract::extract_chunk_facts` (`#1633`
   pass 1) against a real, already-loaded `LlamaGenerationEngine`, printing
   how many facts each chunk yielded and how long it took.
5. Consolidates every chunk's candidate facts with
   `airo_mind_extract::consolidate` (`#1633` pass 2), printing the resulting
   `MeetingIr` — decisions, action items (with owner, `null` when the
   transcript never named one), risks, questions, metrics, next steps,
   observations, topics — each with its evidence segment ids, plus whether
   every citation is structurally grounded to a real segment id.
6. Writes the full `MeetingIr` as pretty JSON to a temp file for inspection.

## A known, documented gap: no GBNF grammar constraint yet

Pass 1 does not use `airo_mind_extract::grammar::JSON_GRAMMAR` right now.
`llama-cpp-2` 0.1.153 (the pinned version) crashes the process
(`GGML_ASSERT(!stacks.empty())`) the moment ANY terminable GBNF grammar
reaches a fully-matched state — reproduced with a grammar as trivial as
`root ::= "{" "}"`. See
`airo_mind_extract::extract::ExtractionConfig::use_gbnf_grammar`'s doc
comment for the full account. Pass 1 instead relies on prompting + a
parse/evidence-grounding validator with retry, which is real and tested but
weaker than grammar-level guarantees.

## A known, documented limit: small-model extraction quality

Against the real pinned Qwen2.5-0.5B-Instruct model, excerpts anywhere near
the spec'd 5-10 minute chunk window make pass 1 return empty results —not
wrong facts, no facts at all — while a ~60-100 second excerpt reliably
surfaces real ones. `cli_chunk_config()` in `src/main.rs` scales chunk size
down accordingly for this dev loop specifically; production's `#1632`
default (`ChunkConfig::default()`, 5-10 minutes) is unchanged. This matches
the milestone brief's own flagged risk that a sub-7B/sub-2B model may not
reliably extract from long context, and is a model-capability finding, not a
`#1632`/`#1633` code defect — see `cli_chunk_config`'s own doc comment.

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
cargo run -p airo_mind_cli --features "airo_mind_llama/llama,airo_mind_llama/metal,airo_mind_whisper/whisper,airo_mind_whisper/metal"
```

**Use the `dev` profile (plain `cargo run`), not `--release`.** The
workspace's `[profile.release]` (`rust/Cargo.toml`) sets `lto = "fat"`, and
linking both `airo_mind_whisper` and `airo_mind_llama` into one release
binary fails LTO bitcode merging (`failed to load bitcode of module
"airo_mind_whisper..."`) — a pre-existing property of the release profile's
LTO setting interacting with two cdylib-shaped rlibs in one binary, not
something introduced by this crate. The `dev` profile has no such issue.

By default it uses:

| Input | Default path | Override |
|---|---|---|
| audio | `rust/fixtures/meeting_synthetic.m4a` (checked-in fixture, ~8 minutes, see below) | `AIRO_MIND_CLI_AUDIO=/path/to.m4a` or first CLI arg |
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

## The fixtures

`rust/fixtures/speech.m4a` is the original ~9.75 second fixture from the
Wave 1 CLI (`#1628`/`#1629` dev loop) — still there, still usable via
`AIRO_MIND_CLI_AUDIO`, but too short to produce more than one `#1632` chunk,
so it does not exercise chunk-boundary overlap. Synthesized once with:

```sh
say -v Samantha -o speech.aiff "Priya said the Kafka consumer lag is the \
  bottleneck, not the database. We agreed to add three more pods before \
  Friday. Raj will own the rollout and report back Monday."
afconvert -f m4af -d aac speech.aiff speech.m4a
rm speech.aiff
```

`rust/fixtures/meeting_synthetic.m4a` is this crate's default audio as of
`#1633`: a real ~8 minute, four-speaker synthetic meeting (Priya, Raj,
Devesh) covering a Kafka consumer-lag root cause, a pod-scaling decision, a
billing database migration, Q3 budget numbers, an on-call rotation change,
and a tracing next step — several of them deliberately restated near the end
in different words, so a chunk-boundary dedup test (`#1633`'s pass 2) has
something real to merge. The full dialogue script is
`rust/fixtures/meeting_synthetic_script.txt`. Regenerate the audio with:

```sh
cd rust/fixtures
say -v Samantha -o meeting_synthetic.aiff -f meeting_synthetic_script.txt
afconvert -f m4af -d aac meeting_synthetic.aiff meeting_synthetic.m4a
rm meeting_synthetic.aiff
```

Both are real AAC/M4A files (not silence, not a tone). `meeting_synthetic.m4a`
is ~2 MB — larger than the original ~48 KB `speech.m4a`, but still small
enough to check in, and it is the fixture this crate's own POC-1 exit-gate
proof depends on being reproducible from source.

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

Real output, `meeting_synthetic.m4a`, both engines on Metal (M1):

```
$ cargo run -p airo_mind_cli --features "airo_mind_llama/llama,airo_mind_llama/metal,airo_mind_whisper/whisper,airo_mind_whisper/metal"
== Airo Mind macOS dev loop: transcript -> Meeting IR (#1632 + #1633) ==
...
-- transcript (114 segment(s)) --
[s0 00:00.000 -> 00:02.640] Korea, okay, let's get started.
...

-- transcript processing (raw/normalized + chunking, #1632) --
114 segment(s) normalized into 6 chunk(s)
  chunk-0 [00:00.000 -> 01:38.600], 28 segment(s): [...]
  ...

-- loading llama.cpp (Metal) --
...
-- pass 1: per-chunk extraction (6 chunk(s)) --
  chunk-0: 3 fact(s) extracted in 13.17s
  chunk-1: 0 fact(s) extracted in 6.82s
  ...

-- pass 2: consolidation --

== Meeting IR (schema 1.0) ==
chunks consolidated: 6, total facts: 12
  [d0] decision: Add three more pods before Friday.
        evidence: s1
  [a0] action item: Own the rollout and report back Monday. (owner: Raj)
        evidence: s2, s105
  [o0] observation: The Kafka consumer lag is the bottleneck, not the database.
        evidence: s0
  ...

all evidence grounded to known segment ids: true

full Meeting IR JSON written to /var/folders/.../airo_mind_cli_meeting_ir.json

== done ==
```

Read this alongside the two "known, documented" sections above: `s0` is
whisper's real ASR error for this run (it misheard "Priya" as "Korea"), and
`o0`'s evidence citing `s0` rather than the segment that actually contains
the Kafka-lag sentence is exactly the "structurally grounded but not always
the *correct* segment" limitation the sub-1B model produces — `all evidence
grounded to known segment ids: true` proves every citation is a real segment
id *in the chunk*, not that it is the *right* one. `#1636`'s eval harness is
where "right segment, not just a real one" gets measured and gated.
