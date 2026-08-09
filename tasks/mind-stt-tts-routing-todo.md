# STT/TTS routing (#497) — task list

Plan: `tasks/mind-stt-tts-routing-plan.md`. One PR for Phase 1+2 combined (small
enough not to split); Phase 0 is a decision, not a diff.

## Phase 0 — decision checkpoint ✅ DONE

- [x] **0.1** Path A confirmed — thin availability descriptor, no chooser.
      One engine, one answer; a router would add abstraction without a real
      choice to make.
- [x] **0.2** TTS confirmed **not available** for Airo Mind. The existing
      `airo_speech_service.dart` is a distinct accessibility surface and must
      not be surfaced as `AiTask.textToSpeech` — that would claim a
      capability Mind doesn't have.

Resolved shape (as shipped):

```text
AiTask.speechToText  -> available: true,  unavailableReason: null   (bridge ok, model installed)
                      -> available: false, unavailableReason: MindUnavailable.bridgeMissing/modelsMissing
AiTask.textToSpeech  -> available: false, unavailableReason: null   (no MindUnavailable case fits --
                                                                      this is a permanent gap, not a
                                                                      startup failure)
```

No `TaskModelRouter` equivalent. Future routing deferred until a second real
implementation exists to choose between.

## Phase 1 — the descriptor ✅ DONE

- [x] **1.1** `SpeechTaskAvailability` in
      `packages/feature_mind/lib/src/speech_task_availability.dart`. Reuses
      `MindUnavailable` for the two STT failure modes; `unavailableReason:
      null` + `available: false` is the distinct "not implemented" state for
      TTS — a plain reuse of `MindUnavailable` couldn't express that without
      picking a misleading case.
- [x] **1.2** `SpeechTaskAvailabilityChecker.speechToText` — calls
      `MindSpeechBridge.loadLibrary()` and `ModelProvider.isInstalled()`
      only, no `acquire()`/download, no `MindService` instance.
- [x] **1.3** `SpeechTaskAvailabilityChecker.textToSpeech` — always
      unavailable, per 0.2.
- [x] **1.4** `flutter analyze` clean; 4 tests in
      `test/speech_task_availability_test.dart` (available, bridgeMissing,
      modelsMissing — with an explicit assertion that `acquire()` is never
      called, textToSpeech). Full package suite 365/365, zero regressions.
- [x] **1.5** `git diff packages/core_ai` empty — confirmed before commit.

## Phase 2 — reachability ✅ DONE (see note)

- [x] **2.1** Exported from `packages/feature_mind/lib/feature_mind.dart`.
- [x] **2.2** Checked `device_capability_report_screen.dart` and
      `model_health_center_screen.dart` first, per the plan — neither has an
      inline Mind-availability check (they're the LLM chat/model-catalog
      side, unrelated to the scribe). No existing check to replace, so no
      caller was wired to avoid inventing a UI hookup with no real need
      behind it. The export + tests are the deliverable; a caller lands when
      one actually needs "is speech available" outside `MindService`'s own
      full `initialize()`.

## Verification

```bash
cd packages/feature_mind && flutter analyze && flutter test   # 365/365
cd app && flutter analyze                                     # clean
git diff packages/core_ai                                     # empty
```

## Checkpoint: Complete

- [x] Phase 1 + 2 acceptance criteria met (2.2 met via verified non-need
      rather than a forced wiring — see note above).
- [ ] PR opened, one logical commit (mirrors #1564's size/shape).
- [ ] Ready for review.
