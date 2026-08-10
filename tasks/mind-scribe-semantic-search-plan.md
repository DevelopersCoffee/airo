# Implementation Plan: Semantic search for the Mind scribe (#508)

Spec: `docs/superpowers/specs/2026-08-09-mind-scribe-semantic-search.md`.

## Overview

Add semantic re-ranking on top of the scribe's existing keyword search
(`searchMeetings`, Rust FTS), using Google's AI Edge RAG SDK
(`GeckoEmbeddingModel`) to generate embeddings from the EmbeddingGemma model —
a new native plugin, not an extension of the existing LiteRT-LM chat plugin
(that assumption was investigated and ruled out — see Architecture Decisions).
Keyword hits stay authoritative; semantic scoring adds and reorders, never
removes. The model is a `ModelDownloadService` download the user opts into,
same as every other `ModelCatalog` entry — never bundled in the APK.

## Architecture Decisions

- **Google AI Edge RAG SDK (`GeckoEmbeddingModel`), not `LiteRtLmPlugin.kt`** —
  the first draft of this plan assumed reusing the existing LiteRT-LM
  `Engine`/`Conversation` plugin by adding one `embed` method. Investigated
  and ruled out: EmbeddingGemma ships as raw `.tflite` + `sentencepiece.model`
  files, not the `.litertlm` package format `LiteRtLmPlugin.kt` loads. The
  real integration is Google's `com.google.ai.edge.localagents:localagents-rag`
  SDK's `GeckoEmbeddingModel(modelPath, Optional.of(tokenizerPath), useGpu)`,
  a different Gradle dependency and a different native API surface
  (`Embedder<String>`). This means a **new** native plugin, not a small
  addition to an existing one — real new-dependency cost (new AAR pair),
  flagged for review before landing.
- **Not bundled in the APK** — the model (`embeddinggemma-300M_seq256_mixed-precision.tflite`,
  ~179 MB, generic/no-chip-suffix variant, chosen for short-text queries over
  longer `seq512`+ variants) downloads through the existing
  `ModelDownloadService`/model-library UI, same as every other catalog entry.
  Only the SDK's code (small) ships in the APK unconditionally.
- **Brute-force cosine similarity, flat file storage** — meeting counts are
  expected in the hundreds for a personal scribe; no ANN index, no new db
  dependency (confirmed `feature_mind` has no Drift/sqflite today — a new
  local store must justify its own weight, or stay a flat file).
- **Union merge, not replacement** — a keyword match a query doesn't
  semantically resemble is still a real match. This is the one behavior most
  likely to regress silently, so it gets a dedicated test (Task 5).
- **`AiTask.embeddings`/`TaskModelRouter` untouched** — already the right
  shape from PR #1564; this is their first real caller, not a reason to
  change them.

## Dependency Graph

```
ModelCatalog: EmbeddingGemma entry           (Task 1, core_ai)
        │
        ├── EmbeddingClient (new plugin)      (Task 2, core_ai — Dart interface
        │       │                              + MethodChannel implementation)
        │       │
        │       └── Android: new EmbeddingPlugin.kt
        │             wrapping GeckoEmbeddingModel, new Gradle dependency
        │             (com.google.ai.edge.localagents:localagents-rag +
        │              com.google.mediapipe:tasks-genai)
        │             (Task 2, native — flavor source-set split TBD)
        │
        └── EmbeddingService                  (Task 3, core_ai)
                (wraps TaskModelRouter(AiTask.embeddings) + EmbeddingClient)
                │
                ▼
        MeetingEmbeddingStore                 (Task 4, feature_mind)
        (persist + load vectors, keyed by meeting id + model id)
                │
                ▼
        SemanticSearchRanker                  (Task 5, feature_mind)
        (embed query, cosine-similarity, union-merge with keyword hits)
                │
                ▼
        MindService.search()                  (Task 6, feature_mind)
        (existing signature; internals call the ranker)
```

Bottom-up order: the native/model layer must exist before anything in
`feature_mind` can be tested against real behavior (though each Dart layer
is unit-testable against fakes independently — see Testing Strategy).

## Task List

### Phase 1: Embedding generation (core_ai + new native plugin)

- [ ] **Task 1: Add EmbeddingGemma to ModelCatalog**

  **Description:** Add a real `OfflineModelInfo` entry for
  `litert-community/embeddinggemma-300m`'s `embeddinggemma-300M_seq256_mixed-precision.tflite`
  (~179 MB) plus its `sentencepiece.model` tokenizer (~4.68 MB — decide how
  the tokenizer is modeled: a second `OfflineModelInfo`, or a field/companion
  file on the same entry; check how multi-file models, if any, are already
  represented in the catalog before inventing a new pattern), tagged
  `ModelCapability.embeddings`.

  **Acceptance criteria:**
  - [ ] Entry follows the existing `OfflineModelInfo` shape (real HuggingFace
        `resolve/main/` download URL, accurate file size, `ModelFamily.gemma`).
  - [ ] `capabilities: [ModelCapability.embeddings]` only — this model is
        not a chat model, don't over-tag it.
  - [ ] Tokenizer file is downloadable/verifiable the same way the model file
        is (whatever pattern is chosen).

  **Verification:**
  - [ ] `cd packages/core_ai && flutter analyze && flutter test`
  - [ ] `TaskModelRouter().resolve(AiTask.embeddings, ModelCatalog.bundledModels)`
        returns the new entry (add/extend a test for this).

  **Dependencies:** None.

  **Files likely touched:**
  - `packages/core_ai/lib/src/registry/model_catalog.dart`
  - `packages/core_ai/test/registry/model_catalog_test.dart` (or wherever
    catalog tests live — check before creating a new file)

  **Estimated scope:** Small (1-2 files).

### Checkpoint: Task 1
- [ ] `flutter test` green in `core_ai`.
- [ ] Manual re-check: URLs/sizes confirmed against
      `https://huggingface.co/litert-community/embeddinggemma-300m/tree/main`
      at implementation time, not copied from this plan without re-verifying
      (model repos change).

- [ ] **Task 2: `EmbeddingClient` — new native plugin (native + Dart)**

  **Description:** New Dart `EmbeddingClient` interface +
  `MethodChannelEmbeddingClient` implementation, backed by a **new** Android
  plugin (`EmbeddingPlugin.kt`, exact package/location TBD) wrapping
  `GeckoEmbeddingModel` from `com.google.ai.edge.localagents:localagents-rag`.
  Add the Gradle dependency
  (`com.google.ai.edge.localagents:localagents-rag:0.1.0` +
  `com.google.mediapipe:tasks-genai:0.10.22`) to `app/android/app/build.gradle.kts`.
  Confirm `GeckoEmbeddingModel`'s actual embed-call method signature against
  the real AAR (the public docs didn't show a direct code sample) before
  finalizing the plugin's method-channel contract.

  **Acceptance criteria:**
  - [ ] `EmbeddingClient.embed({required String text}) -> Future<List<double>>`.
  - [ ] Native plugin loads the `.tflite` + `sentencepiece.model` pair from
        paths supplied by Dart (mirrors how `MindConfig` passes paths rather
        than the native side assuming a location).
  - [ ] Decide the flavor source-set story: mirror `withLitertlm`/
        `withoutLitertlm`'s split (a `withoutEmbedding` stub flavor), or is a
        runtime "SDK not present" check sufficient? This is a real decision,
        not a copy of the existing pattern by default — the existing split
        exists for a specific reason (bundle-size opt-out per flavor); check
        whether that reason applies here before replicating the mechanism.

  **Verification:**
  - [ ] `cd packages/core_ai && flutter analyze && flutter test` (Dart side,
        against a fake channel).
  - [ ] `cd app/android && ./gradlew :app:compileDebugKotlin` (exact task TBD).
  - [ ] Manual device check: `embed()` returns a non-empty, fixed-length
        (768-dimension, per Google's published spec — confirm against the
        real model) vector for real input on a device with the model
        installed.

  **Dependencies:** Task 1 (needs a real model to call `embed` against for
  the manual check, though the Dart interface can be built in parallel).

  **Files likely touched:**
  - `packages/core_ai/lib/src/embeddings/embedding_client.dart` (new)
  - `app/android/app/src/.../EmbeddingPlugin.kt` (new; location depends on
    the flavor-split decision above)
  - `app/android/app/build.gradle.kts`
  - Corresponding Dart + (if the native test harness supports it) Kotlin
    tests.

  **Estimated scope:** Medium-Large (a new plugin end-to-end; genuinely the
  biggest single task in this plan — consider splitting further once the
  flavor-split decision is made, if it turns out to touch more than ~5 files).

### Checkpoint: Phase 1
- [ ] Plugin compiles in whatever flavor(s) it's wired into.
- [ ] `flutter test` green in `core_ai`.
- [ ] **Review with human before proceeding** — this phase adds a real new
      third-party native dependency (Gradle/AAR) to the app. Confirm that's
      still wanted at this point, not just at spec-approval time, since the
      concrete size/shape is now known (Task 2's actual diff) rather than
      estimated.

### Phase 2: Embedding service + storage (core_ai + feature_mind)

- [ ] **Task 3: `EmbeddingService`**

  **Description:** `core_ai` service wrapping `TaskModelRouter().resolve(AiTask.embeddings, installed)`
  + `EmbeddingClient.embed`. Returns a typed failure (not a thrown exception)
  when no embedding model is installed — mirrors `MindService.initialize()`'s
  "return a status, don't throw" pattern for an expected, actionable state.

  **Acceptance criteria:**
  - [ ] `embed(String text) -> Future<EmbeddingResult>` where the result is
        either a vector or a typed "no model installed" / "model failed"
        case.
  - [ ] Does not download a model itself — same boundary `ModelProvider`
        already draws (acquisition is a separate, explicit step).

  **Verification:**
  - [ ] `cd packages/core_ai && flutter analyze && flutter test` — fake
        `TaskModelRouter`/`EmbeddingClient`, no real model load.

  **Dependencies:** Task 1, Task 2.

  **Files likely touched:**
  - `packages/core_ai/lib/src/embeddings/embedding_service.dart` (new)
  - `packages/core_ai/test/embeddings/embedding_service_test.dart` (new)

  **Estimated scope:** Small (1-2 files).

- [ ] **Task 4: `MeetingEmbeddingStore`**

  **Description:** Persist one vector per meeting id, keyed with the model
  id that produced it (stale-detection, mirrors `MeetingRecord.model`).
  Flat-file storage (JSON) in the same models/support directory
  `MindService.modelsDirectory()` already uses — do not introduce Drift/sqflite
  for this unless Task 4's implementation genuinely can't express "load N
  small vectors into memory" without one (unlikely).

  **Acceptance criteria:**
  - [ ] `put(meetingId, modelId, vector)`, `get(meetingId) -> (modelId, vector)?`,
        `all() -> Map<String, (modelId, vector)>`.
  - [ ] A vector whose `modelId` doesn't match the currently-resolved
        embedding model is reported as stale by the caller (store itself
        just returns what's on disk plus its modelId — staleness is Task
        5's concern, not storage's).
  - [ ] Survives a process restart (real file I/O in the test, temp dir —
        same pattern as `mind_service_test.dart`'s `tempDir`).

  **Verification:**
  - [ ] `cd packages/feature_mind && flutter analyze && flutter test`

  **Dependencies:** None (independent of Tasks 1-3; can be built in
  parallel).

  **Files likely touched:**
  - `packages/feature_mind/lib/src/search/meeting_embedding_store.dart` (new)
  - `packages/feature_mind/test/search/meeting_embedding_store_test.dart` (new)

  **Estimated scope:** Small (1-2 files).

### Checkpoint: Phase 2
- [ ] `flutter test` green in both `core_ai` and `feature_mind`.
- [ ] `git diff packages/core_ai/lib/src/router` empty — confirm `AiTask`/
      `TaskModelRouter` untouched.

### Phase 3: Ranking + integration

- [ ] **Task 5: `SemanticSearchRanker`**

  **Description:** Given a query and `searchMeetings`'s keyword hits, embed
  the query, score every stored meeting vector by cosine similarity, and
  produce a ranked, **union** result set.

  **Acceptance criteria:**
  - [ ] Every keyword hit appears in the output, even with zero semantic
        similarity to the query.
  - [ ] A semantic-only match (no keyword overlap) can appear if its
        similarity clears a threshold — threshold value is a named constant,
        not a magic number, and documented with why that value.
  - [ ] Behaves correctly (falls back to keyword-only) when
        `EmbeddingService` reports no model installed — this is the
        expected common case before a user has downloaded the embedding
        model, not an error path.

  **Verification:**
  - [ ] `cd packages/feature_mind && flutter analyze && flutter test`
  - [ ] Dedicated test: keyword hit with no semantic similarity still
        appears in output (the behavior most likely to silently regress).
  - [ ] Dedicated test: no embedding model installed → keyword-only results,
        no crash.

  **Dependencies:** Task 3, Task 4.

  **Files likely touched:**
  - `packages/feature_mind/lib/src/search/semantic_search_ranker.dart` (new)
  - `packages/feature_mind/test/search/semantic_search_ranker_test.dart` (new)

  **Estimated scope:** Medium (2-3 files, the core logic of this feature).

- [ ] **Task 6: Wire into `MindService.search()`**

  **Description:** `MindService.search(query)` keeps its exact existing
  signature; internally it now calls `searchMeetings` for keyword hits and
  `SemanticSearchRanker` to merge in semantic results, instead of returning
  `searchMeetings`'s output directly.

  **Acceptance criteria:**
  - [ ] `MindHomeScreen`'s search box works unchanged — no UI file needs to
        change for this task.
  - [ ] Existing `mind_service_test.dart` search tests still pass unmodified
        (signature didn't change) or are updated only if their assertions
        were specifically about keyword-only behavior that's now
        (correctly) superseded.

  **Verification:**
  - [ ] `cd packages/feature_mind && flutter test`
  - [ ] `cd app && flutter analyze && flutter test` — full regression.

  **Dependencies:** Task 5.

  **Files likely touched:**
  - `packages/feature_mind/lib/src/mind_service.dart`
  - `packages/feature_mind/test/mind_service_test.dart` (only if an existing
    assertion needs updating — check before editing)

  **Estimated scope:** Small (1-2 files).

### Checkpoint: Complete
- [ ] All acceptance criteria across Tasks 1-6 met.
- [ ] `cd packages/core_ai && flutter analyze && flutter test`
- [ ] `cd packages/feature_mind && flutter analyze && flutter test`
- [ ] `cd app && flutter analyze && flutter test`
- [ ] Every affected Android flavor variant compiles.
- [ ] `git diff packages/core_ai/lib/src/router` empty.
- [ ] Device walk: download the embedding model through the normal
      model-library UI, record a meeting, search by meaning rather than
      exact words, confirm a real semantic hit surfaces. Also confirm search
      still works with the model *not* downloaded (keyword-only).
- [ ] Ready for review — likely 2-3 PRs given the phase boundaries (Phase 1
      is the natural first PR — new dependency, biggest review surface;
      Phase 2+3 can be one or two more).

## Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| `GeckoEmbeddingModel`'s actual API doesn't match the constructor signature found in docs (no direct code sample was available) | Medium | Task 2 confirms against the real AAR before finalizing the plugin's method-channel contract; Phase 1 checkpoint is a human review gate before Phase 2+3 build on top. |
| New Gradle dependency (AI Edge RAG SDK) turns out to have licensing, size, or maintenance concerns on closer inspection | Medium | Phase 1 checkpoint explicitly re-confirms the dependency is still wanted once its real diff is known, not just at spec-approval time. |
| EmbeddingGemma file URLs/sizes go stale between planning and implementation | Low | Task 1's checkpoint calls for re-verifying against the live HuggingFace repo, not copying this plan's numbers blindly. |
| Brute-force cosine similarity becomes slow at real scale | Low | Not designed against — flagged in the spec as "revisit if measured, not assumed" if it ever becomes a real complaint. |
| Semantic ranking silently drops a keyword match during a future refactor | Medium | Task 5's dedicated union test exists specifically to catch this — treat it as a regression gate, not a one-time check. |

## Open Questions

- How the tokenizer file (`sentencepiece.model`) is modeled in `ModelCatalog`
  — second entry, or a companion field — depends on whether any existing
  entry already needs a paired file (check during Task 1).
- Flavor source-set split for the new plugin — full mirror of
  `withLitertlm`/`withoutLitertlm`, or something lighter (decide during
  Task 2, with the actual reason for the existing split understood first,
  not assumed to transfer).
- `GeckoEmbeddingModel`'s exact embed-call method name/signature — confirm
  against the real AAR, not the docs summary, during Task 2.
