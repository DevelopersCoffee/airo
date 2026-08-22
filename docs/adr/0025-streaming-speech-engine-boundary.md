# ADR 0025 — `SpeechEngine` gains a streaming session, and stays PCM-pure

## Status

Proposed

## Date

2026-08-22

Deciders: Rust Architect (owns the engine boundary), Chief Architect (contract
shape). Required reviewers: Chief Performance Officer (every Rust change),
Platform Architect (FFI surface), Chief Security Officer (mic entry point,
`secret`-class audio).

Design: [`docs/superpowers/specs/2026-08-22-streaming-stt-zero-copy-design.md`](../superpowers/specs/2026-08-22-streaming-stt-zero-copy-design.md)
Product gap: [#248](https://github.com/DevelopersCoffee/airo/issues/248)

## Context

`SpeechEngine` (`rust/airo_mind_core/src/engine.rs`) transcribes one bounded
buffer:

```rust
fn transcribe(
    &self,
    audio: AudioInput<'_>,          // &[i16], borrowed, never a path
    options: &TranscriptionOptions,
    cancel: &CancelToken,
    sink: &mut dyn FnMut(TranscriptSegment) -> Result<(), EngineError>,
) -> Result<(), EngineError>;
```

The borrowed-PCM shape is already right for streaming, and deliberately so —
the type's own doc explains that an engine which opens a file is an engine that
can write one, and meeting audio is `secret` class. What is missing is a way to
express **audio that has not arrived yet**, and **text that may still change**.

Two gaps make live transcription impossible against the current trait:

1. `transcribe` takes the whole utterance up front. A live session has no such
   buffer; it has a producer feeding a ring.
2. `TranscriptSegment { start_ms, end_ms, text }` has no state. Every segment
   it yields is final by construction, so a revisable hypothesis cannot be
   represented, and the UI has no way to know which text is safe to commit.

The workaround available today — calling `transcribe` repeatedly over a growing
buffer — is quadratic in session length and produces text that rewrites itself
without telling anyone. Neither is acceptable, so this is a contract change
rather than a call-site trick.

## Decision

**Add a streaming session beside `transcribe`. Do not replace it, and do not
let the engine learn anything new about the world.**

### 1. `transcribe` is unchanged

The file path (`transcribe_recording` → `preprocess_path` → `transcribe`) keeps
its exact signature and behavior. It remains the import, crash-recovery, and
optional post-session quality path. This ADR adds a second entry point to the
trait; it deprecates nothing.

### 2. A streaming session, PCM in and stateful segments out

The engine gains a way to open a session, accept PCM as it arrives, and yield
segments carrying a state. Exact naming is Stage 1's, but the contract is
fixed here:

- **Input stays borrowed `i16` PCM at 16 kHz mono.** No paths, no `Vec`
  ownership transfer, no format negotiation. `AudioInput<'_>` is reused as-is.
- **Segments gain a state:** `Partial | Stable | Final`. `TranscriptSegment` is
  extended (or wrapped) rather than duplicated, so one segment type continues
  to feed both paths. A segment produced by `transcribe` is `Final`, which
  keeps every existing call site correct by construction.
- **Cancellation is the existing `CancelToken`**, checked between windows.
- **Backpressure is the existing sink contract**: a sink returning `Err` stops
  the job.
- **The session is the engine's only new state.** Between sessions the engine
  holds nothing, exactly as today.

### 3. Engines stay pure (`I2`, `I4`)

The streaming path may not open files, emit operations, update projections,
download models, or read a clock. Windowing, prompting, and hypothesis
production are inference concerns and belong here. Ring buffering, VAD, and
transcript stabilization are **not** engine concerns and live above it — the
ring and VAD in `airo_mind_audio`, the stabilizer in the capability. An engine
that owned the ring would be an engine that decides retention policy.

### 4. Nothing in the runtime learns what a meeting is

`C5` holds. `start_live_session` / `stop_live_session` and the session id are
capability vocabulary in `rust/airo_mind_whisper/src/api/meetings.rs`. The
engine sees PCM, options, a cancel token, and a sink. There is no `LiveMeeting`
type in `airo_mind_core`, the same way there is no `Minutes` type there today.

### 5. Admission is unchanged

`Supervisor::run_speech` already calls `admit` (memory) and `admit_concurrency`.
A live session is admitted the same way, once, at session start — so a device
that cannot afford the model is refused before the microphone opens rather than
mid-sentence.

### 6. Zero-copy is a boundary rule, not a trait property

PCM is native-owned: Dart does not allocate, retain, or FRB-serialize sample
arrays for STT. One native copy is permitted at the capture → resample →
whisper-`f32` boundary. This is a property of the *pipeline above* the trait;
the trait enforces its half by continuing to borrow rather than own. Full
rationale, including why per-sample zero-copy through Dart is rejected, is in
the design spec §4.

## Contract Impact

**Required. Fill every row — "none" is an answer, blank is not.**

| Question | Answer |
|---|---|
| Which runtime contracts change? | `SpeechEngine` (`airo_mind_core::engine`) gains a streaming entry point, and `TranscriptSegment` gains a state discriminant. Additive: `transcribe`'s signature and semantics are unchanged, and existing segments are `Final`. Every implementor must answer the new method — today that is `WhisperSpeechEngine` and the `supervisor.rs` test fixture. `C5`, `C6`, `I2`, `I4`, ADR-0018 and ADR-0021 are unchanged and not widened. |
| Which conformance tests become invalid? | None become invalid. `rust/airo_mind_whisper/tests/speech_offline.rs` continues to hold for the file path and gains a sibling for the streaming path. The `#1629` timestamp-preservation test (`meetings.rs`) must be extended to cover live segments, since the same `u64` → Dart `BigInt` → `int` narrowing applies to them. |
| Which benchmarks must be re-run? | The whisper RTFx bench (`docs/features/airo-mind/GENERATION_BENCH_PROTOCOL.md`) is file-throughput and stays valid, but it is not evidence about a live session. New budgets required before promoting the design spec §6.2 latency targets to gates: PARTIAL/STABLE latency, peak RSS across a 10+ minute session, dropped-ring sample count, and STABLE-text rewrite count. `I8`: none of these ships as prose. |
| Which review roles must re-review? | Rust Architect (owns `airo_mind_core`, `airo_mind_audio`, `airo_mind_whisper`), Chief Performance Officer (required on every Rust change; owns the copy and RSS budgets), Chief Architect (trait/contract shape), Platform Architect (FRB session surface and capture fan-out), Chief Security Officer (a live session is a second mic entry point and must sit behind the same consent gate), Chief QA Officer (user-visible change). |
| Is G0 required again? | Yes — this changes a crate's public surface (`airo_mind_core::engine`). |

## Consequences

### Positive

- The file path and the live path share one engine, one segment type, and one
  cancellation contract, so a future ASR backend implements the trait once.
- `PARTIAL`/`STABLE`/`FINAL` makes flicker a measurable defect instead of a
  matter of taste, and gives the UI a rule it can be tested against.
- Admission at session start means "this device cannot run live STT" is a
  refusal the user sees before they start talking.
- Live segment ids stay compatible with `TranscriptSegmentRecord`, so ADR-0022
  §4 evidence resolution works for live transcripts with no new mechanism.

### Negative

- The trait grows. Every implementor, including the test fixture, must answer
  the streaming method; a non-streaming engine has to say so explicitly rather
  than inheriting a default.
- `TranscriptSegment` gaining a state touches a type that is currently used in
  exactly one, simpler way — a small tax on every existing match site.
- Two inference paths through whisper.cpp means two sets of parameters to keep
  honest. The anti-hallucination guards tuned for 5-minute chunks
  (`suppress_repetition_loops`, entropy/logprob thresholds) are unlikely to be
  correct for 1-second windows and must be re-derived, not inherited.

### Risks

- **Stabilization quality is the product risk, not throughput.** A pipeline
  that hits every latency target and rewrites committed text is worse than a
  slower one that does not. The rewrite-count metric exists to make this
  visible early.
- **Platform capture fan-out is the schedule risk.** Android's foreground
  recording service is the hardest surface; if native fan-out is not available
  there, the interim is a documented per-platform shim behind the same session
  API — never a relaxation of the native-owned PCM rule.
- **Two cdylibs stay two cdylibs.** Nothing here may tempt a future change into
  linking whisper and llama into one image; `scripts/check-mind-no-ggml-collision.sh`
  remains the guard.

## Alternatives Considered

### Alternative 1: Repeatedly call `transcribe` over a growing buffer

No contract change, and wrong. Cost grows quadratically with session length,
and every call re-emits the whole transcript, so the UI cannot tell new text
from rewritten text. It produces exactly the flicker this ADR exists to
prevent.

### Alternative 2: A separate `StreamingSpeechEngine` trait

Rejected. Two traits over one whisper context means two admission paths, two
cancellation stories, and two segment types that must be kept in sync — and a
future backend would have to implement both to be useful. The state
discriminant is the smaller change and keeps one engine boundary.

### Alternative 3: Push PCM from Dart over FRB (`push_pcm`) with no engine change

Rejected as the contract. Dart would own and serialize every sample block for
the length of the meeting, violating the native-owned PCM rule, and the trait
still could not express a revisable hypothesis — so it solves the plumbing and
leaves the actual gap open. Retained only as a documented interim shim on a
platform that cannot yet fan out PCM natively.

### Alternative 4: A new C ABI bridge (`init_native_ai_engine` / `push_pcm_audio_chunk` / `callback(const char*)`)

Rejected. Duplicates flutter_rust_bridge, names model paths above the Model
Manager (ADR-0018), assumes whisper and llama can share one linked image (they
cannot), and makes an untyped `char*` the transcript contract.

## Related Decisions

- [ADR-0018](0018-airo-mind-model-acquisition-and-trust.md) — a capability asks
  for a capability and a budget, never for a file. Unchanged by live sessions.
- [ADR-0021](0021-mind-runtime-port.md) — the frozen `MindRuntime` port. Not
  widened here; live transcription is a speech-capability surface.
- [ADR-0022](0022-meeting-ir-mind-persistence-mapping.md) — §4's evidence chain
  through segment ids, which live `FINAL` segments must satisfy.

## References

- `rust/airo_mind_core/src/engine.rs` — the trait this ADR widens.
- `rust/airo_mind_core/src/supervisor.rs` — `run_speech`, `admit`,
  `admit_concurrency`.
- `rust/airo_mind_whisper/src/whisper.rs` — chunking and anti-hallucination
  guards that need re-derivation for short windows.
- `docs/AIRO_MIND_ARCHITECTURE_FREEZE_v1.md` — `I7` streaming-first, `C5`/`C6`.
- `docs/superpowers/specs/2026-08-22-streaming-stt-zero-copy-design.md` — the
  full qualification, including the zero-copy boundary rules and evaluation.
