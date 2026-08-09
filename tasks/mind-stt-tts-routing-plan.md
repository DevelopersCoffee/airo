# Implementation Plan: STT/TTS half of task-based model routing (#497)

## Overview

PR #1564 (merged) added `AiTask` + `TaskModelRouter` in `core_ai`, resolving
text/vision tasks (chat, meeting summarization, translation, embeddings, OCR)
against `ModelCatalog`. Two `AiTask` values — `speechToText` and
`textToSpeech` — were deliberately left unresolvable: `TaskModelRouter` throws
`UnroutableTaskException` for them rather than faking an answer, because
speech lives in a different subsystem (`feature_mind`) that doesn't share
`ModelCatalog`'s `OfflineModelInfo` shape at all.

This plan investigates what "resolve the speech half" actually means given
`feature_mind`'s current architecture, and finds the premise needs checking
before code gets written: **there is nothing to route between yet.**

## What's actually there today (read, not assumed)

- **STT**: `MindSpeechBridge` (`packages/feature_mind/lib/src/bridges/mind_speech_bridge.dart`)
  wraps exactly one engine — whisper.cpp, via the generated Rust bridge. Its
  own doc comment: *"Not a claim that a second speech engine is coming.
  Whisper stays pinned; this interface exists so a test can stand somewhere,
  not as a plugin system."* This is an explicit, on-the-record design
  decision, not an oversight.
- **TTS**: `feature_mind` has no text-to-speech capability at all. The only
  TTS in the codebase is `app/lib/core/accessibility/airo_speech_service.dart`,
  an OS-level `flutter_tts` wrapper for screen-reader-style accessibility —
  architecturally unrelated to `ModelCatalog`, `OfflineModelInfo`, or
  `MindGenerationBridge` (which is LLM text generation for meeting minutes,
  not audio synthesis).
- **The model descriptor mismatch**: `feature_mind`'s model registry
  (`packages/feature_mind/lib/src/models/model_provider.dart`'s
  `RequiredModel`) has no capability/task tag and no engine identity field —
  it's `fileName`/`sizeBytes`/`sha256` for download verification only.
  `TaskModelRouter.resolve` expects `OfflineModelInfo` (with a `capabilities`
  list); the two types don't overlap and weren't designed to.
- **The extensibility seam already exists, one layer up**:
  `MindService`'s constructor already takes injectable `speechBridge`/
  `generationBridge` (`MindSpeechBridge`/`MindGenerationBridge` interfaces),
  built in Mind SSOT Phase 1 specifically so a second engine *could* be
  swapped in later. Nothing currently swaps it, because nothing else exists
  to swap to.

## The real question this plan can't answer alone

Building a `TaskModelRouter`-shaped "choose among installed speech models"
resolver for a subsystem that has exactly one non-swappable engine, by
explicit design, means writing a chooser with nothing to choose. That's the
same "looks complete, silently does nothing useful" failure mode #497's
original comment already flagged and chose not to ship for this exact reason.

Two honest paths forward, not one assumed answer:

**Path A — descriptor only, no chooser (recommended default).** Give
`AiTask.speechToText`/`textToSpeech` a real, typed answer instead of an
exception — "here is the thing that serves this task, if the platform has
it" — without pretending there's a selection among alternatives. A thin
adapter in `feature_mind` (or `core_ai`, calling into `feature_mind`) that
answers "can this device serve `AiTask.speechToText`?" and "get me the
handle" using the existing `MindSpeechBridge`/`MindUnavailable.bridgeMissing`
machinery already there. No new routing algorithm — the interface injection
Phase 1 built already *is* the routing seam; this just makes it reachable
through the same `AiTask` vocabulary the text/vision half uses.

**Path B — build the real router now anyway**, treating this as
forward-compat infrastructure for engines that don't exist yet. Larger, and
speculative: it means designing capability tags for speech models before a
second speech model is a real, funded piece of work, and maintaining code
with no test scenario except "the one engine we have."

**Recommendation: Path A.** It closes the actual gap (a caller asking "how do
I get TTS/STT the same way I ask for chat" currently gets nothing consistent)
without inventing a routing algorithm the codebase's own comments say isn't
wanted yet. If a second speech engine becomes real work later, Path A's
adapter is exactly where a real `SpeechTaskRouter` would slot in — this
doesn't foreclose Path B, it just doesn't build it before there's a second
option to route between.

## Architecture Decisions

- **Path A over Path B** (see above) — avoid building a chooser with one
  choice.
- **New type, not reused `OfflineModelInfo`** — `feature_mind`'s engines
  aren't `ModelCatalog` entries and forcing them into that shape would be
  lossy (no file hash/size fields that mean the same thing, no meaningful
  `ModelFamily`). A small `SpeechEngineHandle` (or similar) describing
  "available: yes/no, reason if no, and how to get the actual bridge" is its
  own type.
- **Lives in `feature_mind`, exported for `core_ai`/app callers** — the
  adapter must own the `MindUnavailable`/bridge-missing logic already there;
  putting it in `core_ai` would mean depending on `feature_mind`'s Rust
  bridges from a package that currently has zero platform-specific code.

## Dependency Graph

```
MindSpeechBridge / MindUnavailable            (existing, feature_mind)
        │
        ├── SpeechTaskAvailability descriptor  (new, feature_mind)
        │       │
        │       └── AiTask.speechToText/textToSpeech answer
        │               (new: a function/class exported from feature_mind,
        │                NOT added to TaskModelRouter — that stays
        │                ModelCatalog-only per its own contract)
        │
        └── Callers (MindService today; any future non-Mind caller that
              wants "is speech available" without importing feature_mind's
              internals directly)
```

Nothing in `core_ai`'s `TaskModelRouter`/`AiTask` needs to change for Path A
— `AiTask.speechToText.isCatalogResolvable` staying `false` is correct and
should not flip. The new descriptor lives entirely in `feature_mind` and is
reached separately, the same way a caller today already reaches
`MindService.initialize()` rather than going through `AIRouter`.

## Task List

### Phase 0: Decision checkpoint ✅ DONE

- [x] **Task 0.1**: **Path A confirmed.** One engine, one answer; a router
      over a single choice adds abstraction without solving anything.
- [x] **Task 0.2**: **TTS is not available for Airo Mind.** The existing
      `airo_speech_service.dart` accessibility TTS is a separate product
      surface and must not be mapped to `AiTask.textToSpeech` — doing so
      would claim a capability Mind doesn't have.

### Phase 1: The descriptor (Path A)

- [ ] **Task 1.1**: Add `SpeechTaskAvailability` (or similar name) to
      `packages/feature_mind/lib/src/`. Fields: whether the task
      (`speechToText`/`textToSpeech`) is servable on this platform/build,
      and if not, why (mirrors `MindUnavailable`'s existing cases —
      `bridgeMissing`, `modelsMissing`, `loadFailed` — reuse that enum rather
      than inventing a parallel one).
- [ ] **Task 1.2**: A function/class that answers the descriptor for
      `AiTask.speechToText`, backed by the existing `MindSpeechBridge`
      surface (does not require an active `MindService` instance — should
      answer from the bridge/model-provider state, the same checks
      `MindService.initialize()` already does).
- [ ] **Task 1.3**: The same for `AiTask.textToSpeech`. Given `feature_mind`
      has no TTS today (see Overview), this answers "not available" honestly
      — do not wire it to `airo_speech_service.dart`'s accessibility TTS
      unless a maintainer confirms that's actually the intended meaning of
      "TTS task" here (it's a different product surface: reading arbitrary
      app text aloud vs. synthesizing meeting audio).

### Checkpoint: Phase 1
- [ ] `flutter analyze` clean in `feature_mind`.
- [ ] Unit tests cover: available case, each `MindUnavailable` reason
      surfaced correctly, textToSpeech's honest "not available."
- [ ] No change to `core_ai`'s `AiTask`/`TaskModelRouter` — confirm via
      `git diff` before commit that this phase touched `feature_mind` only.

### Phase 2: Reachability from a caller's perspective

- [ ] **Task 2.1**: Export the new descriptor/function from
      `packages/feature_mind/lib/feature_mind.dart`'s public barrel.
- [ ] **Task 2.2**: One real caller wired to it — likely `MindService` itself
      or a settings/capability-report screen that currently hardcodes "Mind
      is available" logic inline (check `device_capability_report_screen.dart`
      and `model_health_center_screen.dart` for existing inline checks this
      could replace, rather than adding a second, competing check).

### Checkpoint: Phase 2 / Complete
- [ ] `cd packages/feature_mind && flutter test` — full suite green.
- [ ] `cd app && flutter analyze && flutter test` — no regressions.
- [ ] Manual/documented check: the descriptor's "not available" path is
      actually exercised somewhere (web build, or a build without the native
      artifact) — not just the happy path.
- [ ] PR opened, one logical commit, mirrors #1564's shape (small, tested,
      honest about what it does and doesn't cover).

## Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Building Path A's adapter turns into scope creep toward a full router | Med | Task 1.1-1.3 explicitly forbid touching `TaskModelRouter`/`AiTask.isCatalogResolvable` — checkpoint verifies via diff. |
| "TTS task" is assumed to mean `airo_speech_service.dart`'s accessibility TTS when a maintainer actually meant something else (or nothing yet) | Med | Task 1.3 answers "not available" rather than guessing a wiring; Phase 0 checkpoint surfaces the ambiguity before code. |
| No second speech engine ever materializes, making the whole descriptor dead weight | Low | Descriptor is small (one file, ~2 methods) and reuses `MindUnavailable` — low cost even if never extended. |

## Open Questions — resolved

- ~~Does "TTS routing" mean synthesizing audio for meetings, or surfacing
  accessibility TTS?~~ **Neither, for now** — TTS is not available for Mind.
- ~~Is a second STT/TTS engine on any roadmap?~~ **No** — routing is deferred
  until a real second implementation exists.
