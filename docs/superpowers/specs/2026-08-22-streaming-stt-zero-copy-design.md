# Streaming STT + Zero-Copy — Requirement Qualification

Status: **Qualification.** Contract locked, no engine code. Implementation is
gated on this spec being accepted by the reviewers named in §11.
Date: 2026-08-22
Owner: Rust Architect (engine boundary) + Product Manager (Airo Mind surface)
Touches frozen surface: `I7` (streaming first), `C5` (capability/runtime
separation), `C6` (Supervisor admission), ADR-0018 (a capability never names a
model file). None of the three is widened here.
Product gap this answers:
[#248 Live Notes](https://github.com/DevelopersCoffee/airo/issues/248) —
"emit partial and final transcript chunks with stable timestamps".

---

## 1. What this is, and what it is not

This qualifies **live transcription of an in-progress recording**: continuous
PCM ingested inside the native runtime, transcript states emitted to Flutter as
the user speaks.

It is not a rewrite of transcription. `transcribe_recording` — the file path
that ships today — stays exactly as it is, and remains the import,
crash-recovery, and optional post-session quality path.

The source material behind this request (a Reddit
Whisper → vocabulary-extraction → correction → diarization → formatting
workflow, plus a C/C++ FFI blueprint proposing `init_native_ai_engine` /
`push_pcm_audio_chunk` / `callback(const char*)`) is **research input**. Airo
already has a better home for every part of it. §5 records what is adopted,
changed, and refused, so nobody re-derives the refusals later.

## 2. What exists today, and must not be replaced

Live capture and live STT are not the same pipeline. Capture is already live
and already durable; only *transcription* is post-hoc.

```text
Mic (package:record)
  → AAC-LC .m4a written incrementally to disk   (crash-durable)
  → stop()
  → FRB transcribe_recording(path)
  → airo_mind_audio::preprocess_path            (whole file → Vec<i16>)
  → SpeechEngine::transcribe(AudioInput<'_>)
  → TranscriptEvent::{Transcribing, TranscriptReady, Cancelled}
  → diarization labels → save_meeting → Meeting IR
```

Load-bearing facts, each confirmed against code:

- **`SpeechEngine` already takes borrowed PCM, never a path.**
  `AudioInput<'a> { samples: &'a [i16], sample_rate_hz, channels }`
  (`rust/airo_mind_core/src/engine.rs`). Its doc says it plainly: *"an engine
  that opens a file is an engine that can write one, and meeting audio is
  `secret` class"*. The engine boundary is therefore **already the right shape
  for streaming**; the file is a Meeting-capability concern (`C5`), not an
  engine concern. This is the single most important fact in this document.
- **`transcribe_recording` streams file segments after capture ends.**
  `rust/airo_mind_whisper/src/api/meetings.rs`. Its `I7` claim is "don't wait
  for the whole file to finish decoding before emitting a segment" — not live
  mic STT. `TranscriptEvent::Transcribing` carries an *already-completed*
  whisper segment, so it cannot express a revisable hypothesis.
- **Capture durability is owned by the recorder, not by us.**
  `PlatformAudioRecorderPort` (`packages/feature_mind/lib/src/capture/data/
  audio_recorder_port.dart`) hands `package:record` a path and the native
  `MediaRecorder`/`AVAudioRecorder` encoder writes incrementally. That is what
  makes AC1 (a 90-minute recording survives an app kill) true without Dart
  buffering anything. `MeetingCaptureController` already implements
  start → (pause ⇄ resume)* → stop, including OS interruption.
- **Whisper and llama are two cdylibs.** Their vendored ggml copies cannot
  share a linked image (`docs/features/airo-mind/RUST_BUILD_WIRING.md`), and
  `scripts/check-mind-no-ggml-collision.sh` enforces it. A unified
  `init_native_ai_engine(whisper_path, llm_path)` is not buildable here.
- **Structured intelligence is `MeetingIr`**, and its evidence links resolve
  through `TranscriptSegmentRecord { id, start_ms, end_ms }` in
  `transcript.json` (ADR-0022 §4). Live events must produce ids that resolve
  the same way, or live transcripts become second-class evidence.
- **"Zero-copy" in Mind docs means vault/op-log `mmap`**
  (`docs/superpowers/specs/2026-07-27-airo-mind-runtime-design.md`, I7). It has
  never meant audio buffers. This spec is the first use of the term for PCM,
  and §4 defines it narrowly so the two do not get conflated.

## 3. Core requirement (locked)

> Airo Mind shall transcribe an active recording in near real time by ingesting
> continuous PCM **inside the native runtime**, emitting **partial / stable /
> final** transcript events to Flutter, without sample buffers crossing the
> Dart FFI boundary on the inference hot path.

Live transcript is the real-time presentation of the *same canonical segment
stream* that later becomes Meeting IR, search, and memory. It is not a second
STT product with its own data path.

```text
Microphone
  → Native capture fan-out
       ├─ AAC/WAV file          (durability, import, crash recovery — unchanged)
       └─ Bounded PCM ring      (live STT)
            → VAD
            → Sliding-window SpeechEngine
            → Transcript stabilizer
            → transcript events (PARTIAL | STABLE | FINAL)
                 ├─ Flutter live transcript UI
                 └─ session close → today's TranscriptReady → save → IR/search
```

## 3.1 Transcription mode is the user's choice

Live transcription is **not** a replacement for post-processing, and the user
picks. This is P0, not a settings nicety, because the choice is also the input
to model selection (§6.7) and to the resource budget.

| Mode | Behavior | Who it is for |
|---|---|---|
| **Live** | Transcript appears while recording. Live `FINAL` is the canonical transcript; no second pass. | Someone who needs the text now — live notes, a conversation they are steering. |
| **After recording** | Today's behavior, unchanged. Nothing runs during capture; `transcribe_recording` runs on stop. | Battery- or thermal-constrained devices, long meetings, best accuracy per watt. |
| **Live + refine** | Live transcript during capture, then a post-session pass over the recorded file replaces `FINAL` text where it differs. | Someone who wants both immediacy and the best transcript. |

Rules that make this a contract rather than three code paths:

- **The mode is chosen before the session starts** and does not change
  mid-session. Switching modes mid-recording would mean two transcripts of the
  same span with no rule for which wins.
- **`After recording` must remain reachable on every device**, including one
  that cannot afford live STT. A device refused at `start_live_session` (§6.6)
  falls back to this mode rather than losing transcription entirely.
- **`Live + refine` reconciles by segment id.** The refine pass produces a new
  `FINAL` for a segment id that already exists; it does not append a second
  transcript. Meeting IR evidence links (ADR-0022 §4) therefore keep resolving
  across the replacement.
- **Default is `After recording`** until §8's evaluation says otherwise. Today's
  behavior stays the default behavior; live is opt-in until it is measured.

The setting follows the pattern `SpeechLanguageMode` already established
(`packages/feature_mind/lib/src/capture/domain/speech_language_mode.dart` plus
`speech_language_preference.dart`): a domain enum with labels and a storage
value, a `SharedPreferences`-backed notifier, and a loader usable before a
widget tree exists. A second, differently-shaped preference mechanism for this
would be a defect.

## 4. Qualifying "zero-copy"

The pasted blueprint proposes Dart allocating `Pointer<Float>` buffers and
handing addresses to native code. That is the wrong optimization for this
workload, and adopting it would cost real complexity for no measured win.

At 16 kHz mono `i16`, one second of audio is 32 KB. Copying that is
microseconds. Whisper inference on the same second is orders of magnitude more.
The copies that actually matter today are structural, not per-sample:
`preprocess_path` reads and decodes an entire recording into `Vec<i16>` before
anything runs, then `to_whisper_pcm` allocates a second full-length `Vec<f32>`.
For a live session, the one copy that would genuinely hurt is the one that does
not exist yet — FRB-serializing every sample block from Dart into Rust, 30–50
times a second, for the whole meeting.

So zero-copy here is a **boundary property**, not a prohibition on copying:

| ID | Rule | Priority |
|---|---|---|
| ZC-1 | Inference PCM is **native-owned**. Dart does not allocate, retain, or FRB-serialize sample arrays for STT. | P0 |
| ZC-2 | **One native copy is allowed** at the capture → resample → whisper-`f32` boundary. Additional per-window copies need a measurement, not an opinion. | P0 |
| ZC-3 | The PCM ring is **bounded**. Overflow drops oldest audio and reports it (§7, DEGRADED); it never grows without limit. | P0 |
| ZC-4 | Flutter receives **structured transcript events only** — never PCM, never a raw `char*`. | P0 |
| ZC-5 | Dart FFI shared pointers for live waveform rendering. | Reject for now |
| ZC-6 | `mmap` of the AAC capture file as the STT source. | Reject — encoded, not PCM; `secret` class; not a ring |
| ZC-7 | "Zero-copy everywhere" as an architectural rule. | Reject — apply where profiling shows a cost |

ZC-5 is deliberately "for now": if a waveform visualizer later needs sample
data in Dart, that is a *display* requirement with its own budget, and it must
not be smuggled in as part of the inference path.

## 5. The uploaded design, qualified

| Uploaded claim | Disposition |
|---|---|
| Whisper → vocabulary extraction → correction → diarization → formatting | **Adopt the shape.** Already how Airo is built. Vocabulary correction is P1 and runs on STABLE/FINAL text, never on every PARTIAL (§9). |
| Keep STT and text-to-text separately replaceable | **Adopt.** Already enforced by `SpeechEngine` / `GenerationEngine` and the two-cdylib split. |
| Process every 300 ms | Implementation hint. Not an acceptance criterion. |
| Word-by-word UI output | **Change** to PARTIAL/STABLE/FINAL (§6.2). Word-by-word without stabilization is what makes live transcripts look broken. |
| Sub-200 ms end-to-end | **Reject as a gate.** Targets in §6.2, measured before they become gates. |
| Dart `Pointer<Float>` waveform sharing | Out of scope (ZC-5). |
| Continuous LLM inference / live KV-cache insights | Out of this slice (§9). |
| 4 GB as the architecture constraint | **Change.** Minimum compatibility tier. Admission is `Supervisor` + `ResourceBudget`, which already answers "does this device fit this model" per device rather than per assumption. |
| whisper-turbo / v3 / distil as the model choice | **Not decided here** (§6.7). The registry ships tiny and small ggml rows; adding a family is a licence-and-digest decision under ADR-0018, not a spec sentence. |
| WhisperLive rolling-buffer pattern | **Adopt the shape** (§6.4). The proposed loop itself is rejected — it re-decodes the whole buffer every tick (§6.8). |
| Model tier chosen from total physical RAM | **Reject** (§6.9). `DeviceProfile` and `AiroRuntimeMemoryBudgetPolicy` already model available memory, pressure, thermal, and battery. |
| 4 GB is a floor, higher tiers scale up | **Agreed** — this is what "minimum compatibility tier" already meant. The disagreement is only about what selects the tier. |
| New `native_ai_bridge.cpp` with a hand-rolled C ABI | **Reject** (§6, Approach C). |
| `push_pcm_audio_chunk` as the public API | **Reject as public.** Internal native ingest only (§6.1). |
| `callback(const char* tokens)` | **Reject.** Structured events (§6.3). |
| Facial / voiceprint speaker identity | Out of this slice (§9). |

## 6. Approaches considered

**A — Flutter PCM stream (`record.startStream`) → FRB `push_pcm`.**
Quickest to wire and needs no new native capture. It **fails ZC-1**: Dart owns
and serializes every sample block for the length of the meeting. Permitted only
as a temporary platform shim on a target that cannot yet fan out PCM natively,
and only behind the same session API, never as the contract.

**B — Native-owned pipeline. Chosen.**
The capture layer fans out to (1) the existing crash-durable encoded file and
(2) a bounded PCM ring inside Rust. VAD, windowing, Whisper, and stabilization
all run natively. Dart sees session calls and transcript events. This matches
`AudioInput<'_>` as it already exists, keeps the capability free of engine
vocabulary (`C5`), keeps admission with the `Supervisor` (`C6`), and keeps model
paths below the Model Manager (ADR-0018).

**C — New C ABI `native_ai_bridge` as pasted.**
Rejected. It duplicates flutter_rust_bridge, names model files above the Model
Manager, cannot host whisper and llama in one image, and promotes
`push_pcm_audio_chunk` to the product surface.

### 6.1 Session API — not `push_pcm`

Extend the **existing** Mind speech capability. Do not invent an
`airo_engine_*` namespace.

Capability surface (meeting-shaped, over FRB, alongside today's calls):

```text
start_live_session(meeting_id, language) -> session_id
pause_live_session(session_id)
resume_live_session(session_id)
stop_live_session(session_id)     // flush STABLE -> FINAL, then TranscriptReady
cancel_live_session(session_id)   // nothing persisted, same as today's Cancelled
```

`C5` caps a capability at six functions; this is five, and it replaces nothing.

Engine surface (PCM-shaped, domain-free) — added **beside**
`SpeechEngine::transcribe`, which keeps working unchanged:

- continuous PCM ingest from the ring
- VAD-gated window selection
- overlapping sliding windows, prompted with prior text rather than re-decoding
  the session
- cancellation checked between windows (same `CancelToken` contract)
- a sink of segments that carry a **state**

Flutter must remain unable to tell whether the backend is whisper.cpp, a future
ONNX ASR, or a test stub.

### 6.2 Three transcript states

```text
PARTIAL  →  STABLE  →  FINAL
```

- **PARTIAL** — a revisable hypothesis for the current utterance tail. The UI
  may replace it in place. It is never persisted and never becomes IR evidence.
- **STABLE** — committed to the on-screen log. Must not flicker: once a segment
  id is STABLE, its text changes only via a later FINAL event naming that same
  id.
- **FINAL** — persisted, searchable, eligible as Meeting IR evidence. Ids and
  `start_ms`/`end_ms` follow the existing `TranscriptSegmentRecord` scheme so
  ADR-0022 §4 evidence resolution works unchanged.

Latency **targets**, to be measured before any of them becomes a gate:

| Stage | Target |
|---|---|
| PARTIAL after speech onset | < 500 ms |
| STABLE after clause boundary or silence | < 1 s |
| FINAL after `stop_live_session` | bounded by remaining window flush |

200 ms end-to-end and "every 300 ms" are explicitly not acceptance criteria.

### 6.3 Event protocol — extend, do not fork

Today's `TranscriptEvent` cannot express a hypothesis. Add a live variant
(names illustrative; exact wire shape is Stage 1's to fix):

```text
TranscriptDelta {
  session_id
  segment_id
  speaker_id?      // sp0 / sp1 while live; enrollment names resolve post-hoc
  text
  start_ms, end_ms
  state: Partial | Stable | Final
  confidence?
}
```

`TranscriptReady` stays as the session-close snapshot, with today's shape, so
`save_meeting`, search, and Meeting IR extraction do not fork into a live
variant and a file variant.

### 6.4 Bounded ring and VAD

- 16 kHz mono PCM, native memory, matching what capture already configures.
- **Bounded, drop-oldest.** Starting point ~1–2 s of speech audio; the real
  number comes from the budget test in §8, not from this paragraph. Dropping
  degrades transcription for that span; unbounded growth kills the app.
- **VAD is P0**, for battery and thermal reasons more than accuracy: without
  it, Whisper runs continuously through silence for the length of a meeting.
  Home is `airo_mind_audio` (already the owner of decode/downmix/resample, and
  already `#![deny(unsafe_code)]`). No Dart-side VAD, and no screen-local
  `compute()` / `Isolate.run` — that is a lint violation per `AGENTS.md`.
- Sliding window feeds new audio plus prior-text prompting. Re-decoding the
  whole session per tick is forbidden; it is quadratic and it is why naive
  live-Whisper implementations melt phones. Re-decoding the whole *retained
  buffer* per tick is the subtler version of the same mistake and is also
  forbidden — see §6.8.
- Whisper's existing anti-hallucination guards (`suppress_repetition_loops`,
  entropy/logprob thresholds, chunk `no_context` resets) must be reconsidered
  for short windows rather than inherited silently — a 1-second window has
  different repetition statistics than a 5-minute chunk.

### 6.5 One capture, two consumers

The encoded file keeps being written. Live STT must not weaken AC1 (a
90-minute recording survives an app kill) — a crash during a live session must
still leave a file that `transcribe_recording` can process.

If a platform's recorder cannot fan out PCM without a Dart round-trip, that is
a native capture defect to fix on that platform, not grounds to weaken ZC-1.
Approach A is the documented interim, per platform, with an owner.

The per-platform fan-out contract — who owns PCM, what Dart may touch, the
Android `AudioRecord` problem, and the conditions an interim shim must meet —
is [`docs/features/airo-mind/LIVE_CAPTURE_FAN_OUT.md`](../../features/airo-mind/LIVE_CAPTURE_FAN_OUT.md).

### 6.6 Admission and governance

Live sessions go through the existing `Supervisor` / `ResourceBudget`
admission (`run_speech` already calls `admit` and `admit_concurrency`). A device
that cannot afford the speech model must fail closed at
`start_live_session` — before the mic opens — with the same
`ModelUnavailable` / over-budget vocabulary the file path already uses. Failing
closed means falling back to `After recording` (§3.1), not losing
transcription: the user is told live is unavailable on this device, and the
recording still produces a transcript on stop.

Thermal and battery states (`NORMAL | WARM | HOT | CRITICAL`) are specified
here and implemented P1. The P0 mitigation already exists: VAD gating, plus
`MeetingCaptureController`'s pause path.

### 6.7 Which model runs live — open, and the current rule is wrong

**No model is pinned for live transcription, and this spec does not pin one.**
ADR-0018 forbids a capability from naming a file, a quantisation, or a runtime:
it asks for a task, a budget, a minimum quality, and a language, and the Model
Manager resolves. That inversion is right and live sessions keep it.

What today's registry offers for `ModelTask::Speech`
(`rust/airo_mind_core/src/models.rs`):

| Logical id | File | Quality | Language | Admission cost |
|---|---|---|---|---|
| `airo.speech.compact` | `ggml-tiny.en.bin` | Draft | English | 512 MB |
| `airo.speech.multilingual` | `ggml-tiny.bin` | Draft | Multilingual | 512 MB |
| `airo.speech.standard.en` | `ggml-small.en.bin` | Standard | English | 1024 MB |
| `airo.speech.standard` | `ggml-small.bin` | Standard | Multilingual | 1024 MB |

Only `ggml-tiny.en` is `required_by_default`; the rest are opt-in installs.

**The gap:** `resolve()` picks the *highest quality tier that fits the memory
budget*. For file transcription that is exactly right — a slower, better model
costs wall-clock time the user already agreed to spend. For a live session it
is the wrong axis. `ggml-small` fits a 2 GB budget comfortably and will still
miss the §6.2 PARTIAL target on a mid-range phone, because the binding
constraint is **real-time factor**, not resident memory. A model that transcribes
at 0.9× real time fits every budget and still falls behind the speaker forever.

So the live model is resolved by measurement, not by tier. Options:

1. **Cap live sessions at `ModelQuality::Draft`** using the existing
   `maximum_quality: Option<ModelQuality>` field, the same mechanism the
   compact generation fallback already uses. Zero contract change, ships
   immediately, and is wrong on a desktop that could comfortably run `small`
   in real time.
2. **Add a real-time-factor dimension to `ModelRequirement`** — the capability
   states "must sustain ≥ N× real time on this device" and the Manager resolves
   against a measured or declared RTF per registry row. Correct, and a public
   surface change to `airo_mind_core::models` that needs an ADR-0018 amendment.
3. **Probe once per device and cache.** Run a fixed fixture through each
   installed speech model at first live session, record the RTF, resolve from
   that. Most accurate, slowest to build, and needs a cache-invalidation story
   when the device is thermally throttled — which is exactly when the number
   changes.

**Recommendation: (1) now, (2) as the real answer**, with (1)'s cap recorded as
a deliberate interim in the same place the fallback cap already lives, not
scattered at the call site. (3) is a refinement of (2)'s input, not an
alternative to it. Stage 1 measures RTF for tiny and small across the rig
devices; that measurement decides whether (2) lands before or after the first
live release.

Two things this explicitly does not do:

- **No new model is added to the registry by this spec.** Whisper turbo,
  distil-whisper, and the streaming-oriented ASR families the source material
  mentions are all plausible future rows, and each is a separate
  licence-and-digest decision under ADR-0018. `sarvam_edge_speech` is already a
  probe-only availability flag and stays one.
- **No live-only model.** Whatever runs live must be a registry row that the
  file path can also resolve, so `Live + refine` (§3.1) is comparing two passes
  of a known pair rather than two unrelated engines.

### 6.8 The WhisperLive pattern — adopt the shape, not the loop

The WhisperLive architecture is the right reference, and §6.4 already describes
its shape: a rolling buffer, overlap so words are not cut mid-phrase, prior
tokens as context, and a VAD boundary that commits and resets. Using
whisper.cpp's own `stream` example as the model rather than running Collabora's
Python server on-device is correct and is what this spec already assumes.

The proposed loop, as written, must not be copied. Six specific problems:

1. **It is not incremental.** `whisper_full(ctx, params, buf.data(), buf.size())`
   every 300 ms re-decodes the *entire* buffer — up to 30 seconds of audio, 100
   times a minute. The comment calls it an "incremental inference step"; it is
   the opposite. §6.4's rule stands: feed the new window plus prior-text
   prompting, never the whole retained buffer.
2. **`no_context = false` over overlapping audio is the repetition-loop
   trigger.** `rust/airo_mind_whisper/src/whisper.rs` already carries
   `suppress_repetition_loops`, `collapse_consecutive_duplicate_text`, and
   `no_context = true` chunk resets, all added because whisper locked into
   repeated phrases on long recordings. Re-feeding overlapping audio *with*
   context is a stronger version of the same failure. Context carrying is still
   wanted for phrase continuity — it just cannot be switched on without
   re-deriving those guards for short windows, which §6.4 already requires.
3. **`params.use_gpu` does not exist.** GPU offload is a
   `whisper_context_params` field, not a `whisper_full_params` one. In this
   repo it is already handled at the dependency level: the `metal` feature on
   the macOS `whisper-rs` target makes `WhisperContextParameters::default()`
   request GPU offload with no code change (`rust/airo_mind_whisper/Cargo.toml`).
   CoreML is deliberately off — it needs a second `.mlmodelc` artifact the
   one-file-per-model registry has no slot for
   ([#1723](https://github.com/DevelopersCoffee/airo/issues/1723)).
4. **`vector::erase` from the front is not a ring buffer.** It memmoves the
   remainder on every trim, at exactly the moment the pipeline is busiest. This
   is one of the reasons §6.4 specifies a real bounded ring.
5. **The buffer is mutated with no lock in the snippet** while a capture thread
   appends to it.
6. **`send_to_flutter_ui(text)` is the rejected raw-`char*` callback**, and the
   comment calling it a "zero-copy handoff" describes a string copy. See §6.3.

`single_segment = true` is a genuinely useful hint for short live windows and
is worth testing in Stage 1 — noted, not adopted sight-unseen, because it
interacts with the timestamp fidelity `TranscriptSegmentRecord` depends on.

### 6.9 Device tiering — the mechanism exists, and it is better than RAM

The proposal to detect total physical RAM through a new `sysctl` export and map
it to a model tier should not be built. Three reasons, in increasing order of
importance.

**It duplicates infrastructure.** `DeviceProfile`
(`rust/airo_core/src/api/planner.rs`) already carries `total_memory_mb`,
`available_memory_mb`, `accelerator`, `thermal_limited`, and `battery_saver`,
and `plan_inference` already returns `InsufficientMemory` rather than guessing.
On the Dart side, `platform_device_profile`'s `AiroRuntimeMemoryBudgetPolicy`
already classifies budgets and already encodes the rule the proposal misses —
high memory pressure forces a constrained budget, and critical pressure returns
*unsupported* — regardless of how much RAM the machine physically has. A new
macOS-only dylib export would be a fifth device-capability mechanism, and the
worst-informed of them.

**Total RAM is the wrong number.** A 16 GB Mac with three other applications
resident is not a 16 GB budget. `available_memory_mb` and pressure exist for
this reason. The proposal's own fallback — assume 4 GB if the syscall fails —
is the only defensive part of it.

**For live transcription, RAM is not the constraint at all.** This is §6.7's
point restated with a concrete example: the proposed Tier 3 pairs a 16 GB
machine with `whisper-large-v3`. Large-v3 will not sustain real time on most of
those machines, so a "premium" tier chosen by RAM would give the *worst* live
experience of the three tiers while satisfying every memory check. Live model
selection is bounded by real-time factor; memory only decides whether the model
can load at all. A tier table indexed on RAM cannot express that.

What Airo does instead: the capability asks for task, budget, quality, and
language; the Model Manager resolves (ADR-0018); the `Supervisor` admits
against the real budget; and — once §6.7's option (2) lands — the live request
additionally states the real-time factor it needs. Higher-spec devices get
better models because they resolve and sustain better models, not because a
table said so.

Two related items, out of scope here but named so they are not assumed:

- **Adding `base`, `large-v3`, `q4_1` whisper rows, or 7B/8B generation rows**
  is a registry change under ADR-0018 — each needs a pinned digest, a licence
  review (Chief Open Source Officer), and a size/battery review. Note that
  Llama's licence carries a 700M-MAU clause the current `qwen2.5-0.5b` and
  `sarvam-1` rows do not.
- **Gating a quality tier behind payment** is a product and entitlements
  decision (Product Manager, plus `core_entitlements` and the `airo-pro`
  overlay), not an architecture one. It is worth saying once that hardware-based
  upselling has a failure mode: a user who paid for a premium tier and then hits
  thermal throttling gets the constrained experience they did not pay for.

## 7. Session lifecycle

Flutter must never assume the native engine is alive.

```text
UNINITIALIZED → READY → RECORDING ⇄ PAUSED → STOPPED
                            ↓
                        DEGRADED  (ring overflow, thermal backoff, window skip)
                            ↓
                          ERROR    (engine crash, model unload, mic loss)
```

`DEGRADED` is a first-class emitted state, not a log line: if audio was dropped,
the user's transcript has a hole and the UI is entitled to say so. `ERROR` must
leave the encoded file intact so the file path can recover the session.

## 8. Evaluation (required before this ships, per `I8`)

A latency or memory claim with no number is not a requirement. Golden cases:

| Case | What it protects |
|---|---|
| Single short utterance | PARTIAL → STABLE promotion, no orphan hypothesis |
| Two speakers, sequential | Speaker labels survive live windowing |
| Long silence gaps | VAD gating actually suppresses inference |
| 10+ minute session | No unbounded memory, no re-decode growth |
| Pause / resume | Timestamps stay monotonic across the gap |
| OS interruption (call, Siri) | Session survives or degrades cleanly |
| Forced ring overflow | DEGRADED emitted, no OOM, no silent hole |
| `Live + refine` over the same audio | Refined FINAL replaces by segment id; evidence links still resolve |
| Live refused on an under-budget device | Falls back to `After recording`, transcript still produced |

Metrics: PARTIAL and STABLE latency, WER of live FINAL against file-ASR output
on the same audio, peak RSS across the session, dropped-ring sample count,
and STABLE-text rewrite count (flicker is a defect, so it is measured).

**Real-time factor per model per device** is measured here too, and it is what
§6.7 needs to stop guessing: sustained RTF for `ggml-tiny(.en)` and
`ggml-small(.en)` on each rig device (Pixel 9, iPad Air 4, and a desktop),
including under thermal load. A model that cannot sustain > 1× real time is not
a live model on that device, whatever its memory cost says.

Host-runnable with fixture PCM. No device rig required to prove the contract.

## 9. Explicitly out of this slice

Named here so they are refusals rather than omissions:

- Live insights panel, action/decision extraction during recording, and any
  per-chunk LLM inference. The LLM stays out of the live loop.
- A 3B generation model held resident during capture.
- Vocabulary-aware correction on every PARTIAL. The correction idea from the
  source material is good and stays **P1**, applied to STABLE/FINAL text or
  post-session.
- Facial recognition and voiceprint identity as the live speaker label. Live
  stays `sp0`/`sp1`; enrollment resolution remains post-hoc (#504).
- Replacing or deprecating `transcribe_recording`.
- A new `ConversationSession` / Conversation IR type. Meeting IR is the IR;
  extending it is a separate, later decision.
- `core_native` / `airo_core` as the AI runtime — that is the TV/media FFI
  core, and its `RuntimeId::{LlamaCpp, Onnx, LiteRt, Mlx}` values are contract
  enums with a mock registry, not engines.
- A Go audio engine; Dart isolates for STT.
- System-audio capture alongside the mic (gap G1 in the meeting-intelligence
  coverage spec) — orthogonal, and consent-loaded.

## 10. Feature Packet

**Primary owner agent:** Rust Architect (engine boundary, ring, VAD,
stabilizer) with Product Manager (Airo Mind surface).
**Review agents:** Chief Architect, Platform Architect, Chief Performance
Officer, Chief Security Officer, Chief QA Officer.
**Layer:** Mixed — framework-led (engine + runtime contracts), application
follows (live transcript UI).
**Parent roadmap:** Airo Mind meeting intelligence;
[#248](https://github.com/DevelopersCoffee/airo/issues/248),
[#241](https://github.com/DevelopersCoffee/airo/issues/241).

### Critical Agent Gate

**Problem:** Transcription only starts after recording stops. A user speaking
for 40 minutes sees nothing until they press stop, and the live-notes surface
(#248) has no contract to build against.
**User / actor:** A person recording a meeting or note on phone, tablet, or
desktop.
**Framework or application layer:** Mixed, framework-led.
**Owning agent:** Rust Architect (framework) + Product Manager (surface).
**Reviewing agents:** as above.
**Impacted modules:** `rust/airo_mind_core` (engine boundary),
`rust/airo_mind_audio` (ring, VAD), `rust/airo_mind_whisper` (session API,
windowing), `packages/feature_mind` (bridge, capture, live UI).
**Base branch:** `origin/main`, freshly fetched.
**Open questions:** ring size and window length (measured in Stage 1, §12);
whether post-session file ASR remains a quality pass (§12).
**Decision:** Ready for the contract to be reviewed. Not ready for engine code
until it is.

### Cross-Agent Contract

Framework provides: a streaming `SpeechEngine` path over borrowed PCM, a
bounded native ring, VAD gating, a stabilizer, and typed transcript events with
`PARTIAL | STABLE | FINAL`, ids compatible with `TranscriptSegmentRecord`.

Application provides: a live transcript surface that renders STABLE and FINAL
as committed text and PARTIAL only as the uncommitted tail, plus session
controls mapped onto the existing capture lifecycle.

Neither side may cross: Flutter never learns the backend identity and never
handles PCM; Rust never learns what a "live notes screen" is.

### Deterministic Use Cases

1. Start a session, speak one sentence, stop → PARTIAL then STABLE during
   speech, FINAL and a `TranscriptReady` matching today's shape on stop.
2. Start, speak, pause 30 s, resume, speak, stop → no inference during the
   pause, timestamps monotonic across it.
3. Start with a device below the speech model's budget → refused at
   `start_live_session`, mic never opens, session continues in
   `After recording` mode and still produces a transcript on stop.
4. Force ring overflow → DEGRADED emitted, session continues, no OOM.
5. Kill the app mid-session → encoded file on disk still transcribes through
   `transcribe_recording`.
6. Record in `After recording` mode → nothing runs during capture, and the
   result is byte-for-byte what today's pipeline produces.
7. Record in `Live + refine` → live FINAL is shown during capture, the refine
   pass replaces text by segment id, and an action item extracted from a
   refined segment still resolves to an audio timestamp.

### Automation Flow

Host tests with fixture PCM drive the ring and engine directly (no mic, no
device). Dart-side tests use a fake bridge emitting scripted event sequences,
including out-of-order and DEGRADED, to prove the UI never rewrites STABLE
text. §8's metrics run as a benchmark in `packages/benchmarks` before the gates
in §6.2 are promoted from targets to acceptance criteria.

### Security and Privacy Posture

Unchanged and non-negotiable: meeting audio is `secret` class. No plaintext
transcript temp files, no PCM written to disk beyond the existing encoded
capture file, no network. The consent gate
(`audio_scribe_consent_gate.dart`) runs before a live session exactly as it
does before a recording — live transcription does not introduce a second,
weaker entry point into the mic.

### Rollback

The transcription mode (§3.1) is the rollback. `After recording` is the
default and is today's pipeline unchanged, so withdrawing live transcription is
a matter of hiding the other two options — no data migration, no schema change,
and no user left without a transcript. Capture still writes the file, and
`transcribe_recording` still produces the text.

## 11. Ownership and required review

| Surface | Owner | Required reviewers |
|---|---|---|
| `SpeechEngine` streaming path, ring, VAD, stabilizer | Rust Architect | Chief Performance Officer, Chief Architect |
| FRB session API + event types | Platform Architect + Rust Architect | Chief Architect |
| Capture fan-out (durable file + PCM ring) | Platform Architect | Chief Security Officer |
| Live transcript UI | Product Manager | Chief UX Officer, Chief QA Officer |
| Copy budget, peak RSS, battery | Chief Performance Officer | — |
| Mic entry points, `secret`-class audio | Chief Security Officer | — |

## 12. Implementation order (after this spec is accepted)

1. **Stage 0 — contracts.** This spec, plus ADR-0025 for the engine-boundary
   widening. No behavior change.
2. **Stage 1 — native core.** Bounded ring, VAD, streaming engine path,
   stabilizer, event types. Host tests with fixture PCM. Ring size and window
   length measured here and written back into §6.4.
3. **Stage 2 — capture fan-out.** First on the platform where native capture is
   easiest to prove ZC-1 (desktop/macOS), then Android — where the foreground
   service (`com.airo.meeting_recording`) makes it hardest. iOS follows the
   Mind engine build ([#1546](https://github.com/DevelopersCoffee/airo/issues/1546))
   and is not a blocker for the contract.
4. **Stage 3 — Flutter live transcript.** STABLE/FINAL committed, PARTIAL as
   tail, DEGRADED surfaced.
5. **Stage 4 — close the loop.** `stop_live_session` produces today's
   `TranscriptReady` so save, search, diarization, and Meeting IR are untouched.

Open, non-blocking:

- Exact ring size and window length — measured in Stage 1.
- **Which speech model runs live** (§6.7) — interim is the `maximum_quality:
  Some(Draft)` cap; the real answer is a real-time-factor dimension on
  `ModelRequirement`, which needs an ADR-0018 amendment. Stage 1's RTF
  measurement decides whether that lands before or after the first live
  release.
- Whether `Live + refine` is on by default once it exists (§3.1). Default stays
  `After recording` until §8's WER comparison says live FINAL is good enough to
  promote.

## 13. References

- `rust/airo_mind_core/src/engine.rs` — `SpeechEngine`, `AudioInput<'_>`,
  `TranscriptionOptions`.
- `rust/airo_mind_whisper/src/api/meetings.rs` — `transcribe_recording`,
  `TranscriptEvent`, `TranscriptSegmentRecord`.
- `rust/airo_mind_whisper/src/whisper.rs` — windowing, chunking, and the
  anti-hallucination guards §6.4 must revisit.
- `rust/airo_mind_audio/src/lib.rs` — decode/downmix/resample, the ring's home.
- `rust/airo_mind_core/src/models.rs` — the speech registry rows and the
  `resolve()` rule §6.7 says is the wrong axis for live.
- `rust/airo_core/src/api/planner.rs` and `packages/platform_device_profile/`
  — the device-capability and memory-budget mechanisms §6.9 says not to
  duplicate.
- `rust/airo_mind_whisper/Cargo.toml` — Metal via the `whisper-rs` `metal`
  feature, and why CoreML is deliberately off.
- `packages/feature_mind/lib/src/capture/domain/speech_language_mode.dart` and
  `.../application/speech_language_preference.dart` — the settings pattern the
  transcription-mode preference (§3.1) must follow.
- `packages/feature_mind/lib/src/capture/` — recorder port, capture controller,
  Android foreground-service gateway.
- [`docs/features/airo-mind/LIVE_CAPTURE_FAN_OUT.md`](../../features/airo-mind/LIVE_CAPTURE_FAN_OUT.md)
  — per-platform capture fan-out contract and conformance checks.
- [`docs/adr/0025-streaming-speech-engine-boundary.md`](../../adr/0025-streaming-speech-engine-boundary.md)
  — the engine-boundary decision this spec depends on.
- `docs/adr/0022-meeting-ir-mind-persistence-mapping.md` §4 — evidence
  resolution through segment ids.
- `docs/adr/0018-airo-mind-model-acquisition-and-trust.md` — a capability never
  names a model file.
- `docs/superpowers/specs/2026-07-27-meeting-intelligence-coverage.md` —
  real-time transcription recorded as a gap; G1 system audio, out of scope here.
- `docs/features/airo-mind/RUST_BUILD_WIRING.md` — the two-cdylib constraint.
