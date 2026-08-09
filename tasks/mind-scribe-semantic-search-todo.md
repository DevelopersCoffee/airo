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

## Phase 1 — embedding generation (core_ai + new native plugin) ✅ MOSTLY DONE

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
- [ ] **1.4** `GeckoEmbeddingModel`'s embed-call method — **not confirmed
      against the real AAR**. No source/javadoc access in this session; the
      public integration guide showed only the constructor, not a call
      site. Implemented as `computeEmbeddings(text).get()`, inferred from
      the AI Edge RAG SDK's `Embedder<String>`/`ListenableFuture` convention
      and clearly flagged in the plugin's own doc comment as the one thing
      needing verification before this ships. Isolated to a single call
      site — if wrong, only that line changes.
- [x] **1.5** `EmbeddingClient` Dart interface + `MethodChannelEmbeddingClient`
      in `core_ai`, mirroring `LiteRtLmClient`'s shape (timeout,
      `PlatformException`/`MissingPluginException` handling). 6 tests.
- [x] **1.6** New `EmbeddingPlugin.kt`, two flavor variants
      (`withEmbedding`/`withoutEmbedding`), mirroring `withLitertlm`/
      `withoutLitertlm` exactly — confirmed the existing split's real reason
      first (a CI/stub-build toggle for a public-Maven dependency, per
      `app/android/build.gradle.kts`'s own comment) before replicating the
      mechanism, rather than assuming it transfers.

**Checkpoint — human review required, and 1.4 is still open.** This phase
adds a real new third-party native dependency and one unverified native API
call. Do not proceed to Phase 2 assuming 1.4's contract shape is final —
confirm it first (Android Studio decompiled sources, the SDK's own javadoc,
or a real device build attempt).

- [x] `flutter test` green in `core_ai` (326/326, all packages, zero
      regressions).
- [ ] New plugin compiles in its wired flavor(s) — **not verified**, no
      `gradlew` wrapper present in this checkout (Flutter-generated, absent
      until a `flutter pub get`/build runs in `app/`). Needs a real build
      environment.
- [ ] 1.4's finding (real method signature) confirmed before Phase 2 assumes
      a contract shape.

## Phase 2 — embedding service + storage

- [ ] **2.1** `EmbeddingService` in `core_ai` (`TaskModelRouter` +
      `EmbeddingClient`, typed "no model installed" result, does not
      download anything itself).
- [ ] **2.2** `MeetingEmbeddingStore` in `feature_mind` — flat-file, keyed by
      meeting id + producing model id, survives restart. No new db
      dependency unless proven necessary.

**Checkpoint**
- [ ] `flutter test` green in both packages.
- [ ] `git diff packages/core_ai/lib/src/router` — empty.

## Phase 3 — ranking + integration

- [ ] **3.1** `SemanticSearchRanker` — union merge (every keyword hit
      survives), named similarity threshold constant, graceful keyword-only
      fallback when no embedding model is installed.
- [ ] **3.2** Dedicated test: keyword hit with zero semantic similarity
      still appears in output.
- [ ] **3.3** Dedicated test: no embedding model installed → keyword-only,
      no crash.
- [ ] **3.4** Wire into `MindService.search()` — signature unchanged,
      `MindHomeScreen` untouched.

## Verification (full)

```bash
cd packages/core_ai && flutter analyze && flutter test
cd packages/feature_mind && flutter analyze && flutter test
cd app && flutter analyze && flutter test
git diff packages/core_ai/lib/src/router   # must be empty
cd app/android && ./gradlew :app:compileDebugKotlin   # exact task TBD (1.6)
```

## Checkpoint: Complete

- [ ] All tasks above checked.
- [ ] Device walk: download embedding model through normal model-library UI,
      record meeting, search by meaning not exact words, confirm real
      semantic hit. Also confirm keyword-only search still works with the
      model *not* downloaded.
- [ ] PR(s) opened, reviewed.
