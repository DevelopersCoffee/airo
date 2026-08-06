# Airo Mind — restore the journey coverage the split removed

**Date:** 2026-08-06
**Status:** Draft, pre-implementation
**Follows:** #1549 (the split), #1550 (Android device fixes)
**Closes a regression introduced by:** #1549

## 1. Objective

Put the record → transcribe → minutes → save → search journey back under
automated test.

`#1549` split the runtime into two cdylibs because whisper.cpp and llama.cpp
vendor incompatible copies of ggml. Two Rust tests could not survive that:

| Deleted | Why it cannot exist |
|---|---|
| `tests/user_journey.rs` | loaded both engines into one test binary — the same one-definition-rule conflict that forced the split |
| `generation_offline.rs::audio_becomes_minutes_offline` | same, for the audio → minutes join |

Their coverage was declared as "moves to Dart and the device walk." The device
walk has since happened, by hand, once — on a Pixel 9, and it passed. Nothing
automated covers it. **This spec is the part that was promised and not
delivered.**

**Target users:** the engineers who will change `MindService`, the bridges, or
either engine crate next, and currently have nothing that would tell them they
broke the pipeline.

## 2. Scope

Two layers, because one cannot do both jobs:

- **Composition tests** (fast, CI, no models, no native libraries) — the
  sequencing `MindService` now owns.
- **One device journey test** (real engines, real models, manual/gated) — the
  thing only a device can prove, made repeatable so it is not a person with a
  phone each time.

**Out of scope:** the Rust-side tests that still exist and still pass
(`speech_offline.rs`, `generation_offline.rs` minus the deleted case, the 44
`airo_mind_core` tests). Widening engine coverage. Any change to the runtime's
architecture or the frozen `MindRuntime` port.

## 3. The seam

`MindService.process()` calls top-level generated functions
(`rust.transcribeRecording`, `llama.generateMinutes`, `rust.saveMeeting`), so
there is nothing to fake. That is the blocker, and it is why these tests do not
exist yet rather than an oversight.

The constructor already takes its collaborators:

```dart
MindService({AudioRecorder? recorder, ModelInstaller? installer})
  : _recorder = recorder ?? AudioRecorder(),
    _installer = installer ?? const ModelInstaller();
```

Two more follow the same shape, not a new pattern:

```dart
abstract class MindSpeechBridge {
  Stream<TranscriptEvent> transcribe({required String wavPath});
  Future<String> save({ /* title, recordedAtMs, transcript, minutes, model */ });
  void cancel();
}

abstract class MindGenerationBridge {
  Future<void> ensureLoaded();          // the lazy load, observable
  bool get isLoaded;
  Stream<GenerationEvent> generate({required String transcript});
  String modelId();
  void cancel();
}
```

Default implementations delegate to the generated functions and hold the
`initializeLlamaBridge()` guard currently in `library_loader.dart`. The
production path is unchanged; the tests get somewhere to stand.

**This is the one design decision in this spec that adds indirection.** It is
worth it only because the alternative is no coverage of the composition at all,
and the composition is exactly what the split moved into Dart.

## 4. Commands

```bash
# Composition tests — fast, no models, no device
cd packages/feature_mind && flutter test

# The Mind flavour's own suite (the define is not optional)
cp app/pubspec_mind.yaml app/pubspec.yaml
cp app/analysis_options_mind.yaml app/analysis_options.yaml
cd app && flutter pub get
flutter test test_mind/ --dart-define=APP_VARIANT=mind

# Device journey — real engines, real models, a real phone
app/tool/fetch_mind_models.sh          # ~570 MB, digest-verified
AIRO_MIND_BUILD_MODE=release scripts/build-mind.sh
cd app && flutter test integration_test/mind_journey_device_test.dart \
  --dart-define=APP_VARIANT=mind -d <device-id>
```

## 5. Project structure

```
packages/feature_mind/
  lib/src/
    bridges/
      mind_speech_bridge.dart        # abstraction + default delegating impl
      mind_generation_bridge.dart    # abstraction + default, owns the lazy load
    mind_service.dart                # takes both; process() unchanged in behaviour
  test/
    mind_composition_test.dart       # T3, T4, T5 and the error paths
    support/fake_bridges.dart        # scripted event sequences, call recorders

app/integration_test/
  mind_journey_device_test.dart      # the replacement for user_journey.rs
```

## 6. Testing strategy

### Composition, with fakes

| # | Property | Replaces |
|---|---|---|
| T3 | the emitted `MindStage` sequence is exactly transcribing → generating → saving → done | `user_journey.rs` sequencing |
| T4 | `cancelProcessing()` cancels **both** bridges, at every point in the pipeline | nothing — this is new, and is the risk the split created |
| T5 | a transcribe-only run never loads the generation bridge | the lazy-load claim, currently unproven |
| T6 | `TranscriptEvent_Cancelled` mid-transcribe yields `idle` and never reaches generation | `user_journey.rs` cancel path |
| T7 | `saveMeeting` is called with the transcript, the minutes, and the model id from the generation bridge | `ADR-0018 §5` — what produced a summary is recorded |
| T8 | a bridge that throws surfaces as `MindStage.failed` with the message, not an unhandled exception | existing behaviour, currently untested |

T4 deserves its emphasis: cancellation used to be one `CancelToken` inside one
Rust library. It is now two, coordinated from Dart, and the handover is both the
most likely moment to press Stop and the easiest place to leave an engine
running.

### Device journey, with real engines

One test, mirroring what was walked by hand: record a fixture through the
recorder seam → transcribe → minutes → save → list → search → open. Asserts a
meeting exists, its transcript is non-empty, its minutes are non-empty, and
search returns it.

**It is gated, not part of the default suite.** It needs ~570 MB of models, a
device, and roughly a minute of inference. `flutter test integration_test/`
already exists in the Makefile; this joins it behind the same explicit
invocation, and CI does not run it until there is a device lane that can.

### Honest limit

The composition tests use fakes, so they prove sequencing, not inference. The
device test proves inference but runs rarely. Neither replaces `user_journey.rs`
exactly — that test ran real engines on every `cargo test`. **That specific
property is gone and does not come back**, because the two engines cannot share
a process at link time. Saying so here is better than implying parity.

## 7. Boundaries

**Always**

- Keep `MindService`'s public API unchanged. The seam is constructor-injected
  with working defaults; no caller passes anything new.
- Assert the `MindStage` sequence, not internals. It is the contract widgets
  bind to and the reason the split is invisible to the UI.
- Fakes script event sequences and record calls. No mocking framework beyond
  what the package already uses.

**Ask first**

- Any change to `process()`'s behaviour rather than its testability. This spec
  is about restoring coverage, and a behavioural change hidden inside a test PR
  is how the two get confused.
- Moving more responsibility into Dart. Budget (`C6`) and cancellation (`I7`)
  are runtime properties; T4 exists to hold that line, not to license crossing
  it.

**Never**

- Recombine the engines to make a test easier. `check-mind-no-ggml-collision.sh`
  fails the build, and on Apple the link would otherwise succeed and quietly run
  one engine against the other's ggml.
- Claim the device test ran when it did not. It is gated; a green default suite
  says nothing about it.
- Ship a fake as a production default.

## 8. Acceptance criteria

1. T3–T8 pass in `packages/feature_mind`'s default suite, with no models and no
   native libraries present.
2. Each of T4 and T5 fails if its enforcement is removed — checked by removing
   it, not by assertion.
3. The device journey test passes on the Pixel 9 against real engines.
4. `MindService`'s public API is unchanged, proven by the existing tests passing
   untouched.
5. The Rust suites still pass: `cargo test --workspace`, plus each engine crate
   with its feature.
