# Mind scribe semantic search (#508) — task list

Plan: `tasks/mind-scribe-semantic-search-plan.md`. Spec:
`docs/superpowers/specs/2026-08-09-mind-scribe-semantic-search.md`.

**Revised after investigation**: not extending `LiteRtLmPlugin.kt`.
EmbeddingGemma ships as raw `.tflite` + `sentencepiece.model`, not
`.litertlm`. Real path is Google's AI Edge RAG SDK (`GeckoEmbeddingModel`) —
a new native plugin and a new Gradle dependency. Model itself is a
`ModelDownloadService` download, never bundled in the APK — same as every
other `ModelCatalog` entry.

Likely 2-3 PRs: Phase 1 (new native plugin + dependency) first, its own
checkpoint before Phase 2+3.

## Phase 1 — embedding generation (core_ai + new native plugin) ✅ DONE, VERIFIED

**Status: done — real Android build, real device.** The gate held: Phase 2
did not start until this cleared for real, and clearing it for real changed
the code (the guessed method name was wrong).

```text
Phase 1
├── Dart interface              PASS
├── Tests                       PASS — 326/326
├── Gradle/flavor wiring        PASS by inspection
├── Native AAR API              CONFIRMED — javap on the real AAR
└── Kotlin compilation          CONFIRMED — compileDebugKotlin succeeds
                 │
                 ▼
        Pixel 9 build (USB, 2026-08-09)
                 │
               GREEN
                 │
          Phase 2 unblocked
```

What the real build found: `computeEmbeddings(text)` does not exist on
`GeckoEmbeddingModel` — `compileDebugKotlin` failed with "Unresolved
reference." Extracted the real AAR from `~/.gradle`'s module cache
(`javap` on the decompiled `classes.jar`) and found the actual API:
`getEmbeddings(EmbeddingRequest<String>) -> ListenableFuture<ImmutableList<Float>>`,
built via `EmbeddingRequest.create(listOf(EmbedData.create(text, taskType)))`.
Fixed, rebuilt clean, installed on a physical Pixel 9
(`io.airo.app.mind`), launched, stayed alive, zero embedding-related
logcat errors.

**One real design note surfaced, not decided here**: the SDK's `TaskType`
enum offers `RETRIEVAL_QUERY`/`RETRIEVAL_DOCUMENT` for asymmetric
query-vs-document embedding, which would improve search quality over the
single `SEMANTIC_SIMILARITY` this plugin currently always uses. `embed(text)`
doesn't yet distinguish a query from a document. Whoever builds
`SemanticSearchRanker` (Task 5, Phase 3) should decide whether that
distinction is worth threading through — flagged, not implemented.

- [x] **1.1** Add EmbeddingGemma
      (`embeddinggemma-300M_seq256_mixed-precision.tflite`, ~179 MB, generic
      variant, from `litert-community/embeddinggemma-300m`) + its
      `sentencepiece.model` tokenizer to `ModelCatalog`, tagged
      `ModelCapability.embeddings` only. Landed separately: PR #1573.
- [x] **1.2** Verified `TaskModelRouter().resolve(AiTask.embeddings, ...)`
      finds it, and never returns the tokenizer entry (PR #1573).
- [x] **1.3** Gradle deps added
      (`com.google.ai.edge.localagents:localagents-rag:0.1.0`,
      `com.google.mediapipe:tasks-genai:0.10.22`) to
      `app/android/app/build.gradle.kts`, gated behind a new
      `embeddingAvailable` flag (`AIRO_USE_EMBEDDING_STUB` env var) mirroring
      `liteRtLmAvailable`'s existing mechanism exactly — same reasoning,
      separate flag so toggling one dependency never silently toggles the
      other.
- [x] **1.4** `GeckoEmbeddingModel`'s embed-call method — **confirmed
      against the real AAR** via `javap`. Was wrong as guessed
      (`computeEmbeddings`); real call is `getEmbeddings(EmbeddingRequest<String>)`.
      Fixed, rebuilt, verified on a physical Pixel 9.
- [x] **1.5** `EmbeddingClient` Dart interface + `MethodChannelEmbeddingClient`
      in `core_ai`, mirroring `LiteRtLmClient`'s shape (timeout,
      `PlatformException`/`MissingPluginException` handling). 6 tests.
- [x] **1.6** New `EmbeddingPlugin.kt`, two flavor variants
      (`withEmbedding`/`withoutEmbedding`), mirroring `withLitertlm`/
      `withoutLitertlm` exactly — confirmed the existing split's real reason
      first (a CI/stub-build toggle for a public-Maven dependency, per
      `app/android/build.gradle.kts`'s own comment) before replicating the
      mechanism, rather than assuming it transfers.

**Checkpoint — CLEARED.** Gate held through one real red/green cycle before
opening: build failed on the guessed API, fix was made against verified
evidence (not a second guess), rebuild succeeded.

- [x] `flutter test` green in `core_ai` (326/326, all packages, zero
      regressions).
- [x] New plugin compiles: `AIRO_MIND_BUILD_MODE=debug scripts/build-mind.sh`
      succeeds end to end (`app-debug.apk`, 192 MB).
- [x] 1.4's finding (real method signature) confirmed via `javap` on the
      actual AAR, not guessed a second time.
- [x] Installed and launched on a physical Pixel 9 (USB) — stable, zero
      embedding-related logcat errors. (Plugin isn't called by anything yet —
      this confirms registration/load, not the embed call itself; that needs
      Phase 2/3's real caller.)

**Phase 2 is now unblocked.**

## Phase 2 — embedding service + storage ✅ DONE

- [x] **2.1** `EmbeddingService` in `core_ai` (`TaskModelRouter` +
      `EmbeddingClient`, typed `EmbeddingResult` — ready/noModelInstalled/
      modelFailed — never downloads anything itself). Finds the paired
      tokenizer via the tag convention Task 1's catalog entry was given
      (`tags` containing both `'tokenizer'` and the resolved model's id).
      6 tests, including a fake `ModelDownloadService` whose `downloadModel`
      throws — proves "never downloads" by failing loudly, not by an
      assertion that would pass either way.
- [x] **2.2** `MeetingEmbeddingStore` in `feature_mind` — flat JSON file,
      keyed by meeting id, stores the producing model id alongside each
      vector (mirrors `MeetingRecord.model`). No new db dependency — not
      proven necessary. 7 tests, including real temp-dir file I/O across
      two store instances (genuine restart-survival, not mocked) and a
      corrupt-file-degrades-to-empty case.

**Checkpoint**
- [x] `flutter test` green in both packages (core_ai 331/331, feature_mind
      372/372, zero regressions).
- [x] `git diff origin/main -- packages/core_ai/lib/src/router` — confirmed
      empty.

## Phase 3 — ranking + integration ✅ DONE

- [x] **3.0** (found while implementing, not planned): `EmbeddingService`
      (Task 3) didn't expose which model produced a vector —
      `MeetingEmbeddingStore.put()` needs that for its staleness-detection
      design. Added `EmbeddingResult.modelId`, 2 new tests in `core_ai`.
- [x] **3.1** `SemanticSearchRanker` — union merge (every keyword hit
      survives), named `similarityThreshold` constant (0.6, documented as a
      starting point, not tuned against real usage yet), graceful
      keyword-only fallback when no embedding model is installed. Also
      handles the previously-unaddressed question of *when* a meeting gets
      an embedding: lazily, on first search after it exists, cached in
      `MeetingEmbeddingStore` — no save-time indexing step yet (documented
      as a reasonable v1 tradeoff, not decided as final).
- [x] **3.2** Dedicated test: keyword hit with zero (in fact negative)
      semantic similarity still appears in output.
- [x] **3.3** Dedicated test: no embedding model installed → keyword-only,
      no crash. Plus: below-threshold semantic match excluded, no duplicate
      when a meeting is both a keyword and semantic match, embeddings cache
      across repeated calls (only the query re-embeds), multi-result
      ranking by descending similarity. 7 tests total.
- [x] **3.4** Wired into `MindService.search()` — signature unchanged
      (`Future<List<rust.SearchHit>> search(String query)`), `MindHomeScreen`
      untouched. Ranker built lazily via an injectable
      `rankerBuilder(Directory)` (mirrors every other collaborator's
      "injectable, defaults to production" pattern) since it needs
      `modelsDirectory()`, which is async — can't build it in the
      constructor the way the other collaborators are built.

## Verification (full)

```bash
cd packages/core_ai && flutter analyze && flutter test         # 332/332
cd packages/feature_mind && flutter analyze && flutter test    # 379/379
cd app && flutter analyze                                      # clean
git diff origin/main -- packages/core_ai/lib/src/router        # empty
```

## Checkpoint: Complete

- [x] All Phase 1-3 tasks checked.
- [x] Device walk (partial, real, Pixel 9 USB, 2026-08-09): installed
      `app-debug.apk`, launched `io.airo.app.mind`, recorded a real meeting
      via the phone mic (audio source: nearby YouTube playback), stopped,
      transcription ran (Whisper produced `[MUSIC]`/`[BLANK_AUDIO]` tags —
      no clear speech in that clip, not a bug), minutes were generated
      (LLM produced generic boilerplate from the near-empty transcript — a
      real UX gap worth a separate issue, out of #508's scope), saved as
      "Meeting 3". Searched via `MindService.search()`:
      - keyword hit: query `"stakeholders"` returned Meeting 3 with the
        correct matching snippet — confirms the full search path (keyword
        → `SemanticSearchRanker.rank` → union merge) runs end to end on a
        real device with zero logcat errors.
      - no-match query (`"stakeholdersbudget"`, garbled by a mistyped
        clear-field tap, incidentally still a valid no-hit case): returned
        "No meeting mentions that." — clean empty state, no crash. This is
        the "no embedding model installed → graceful keyword-only
        behavior" acceptance criterion, confirmed for real.
      **Not done**: a real semantic-only hit (query worded differently from
      the transcript, model bridges the gap). Blocked on downloading
      `embeddinggemma-300m-embed` (~179 MB) — there is no model-library UI
      surface wired up yet to trigger that download; `EmbeddingService`
      only *consumes* an already-downloaded model, it never downloads one
      itself (by design). Flagged as a real gap, not silently skipped.
- [x] PR(s) opened: #1573 (Task 1-2), #1576 (Task 1.4 fix + verification),
      #1577 (unrelated doc fix), #1578 (Task 3-4), this PR (Task 5-6 + the
      3.0 addendum).
