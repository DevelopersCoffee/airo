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

## Phase 1 — embedding generation (core_ai + new native plugin)

- [ ] **1.1** Add EmbeddingGemma
      (`embeddinggemma-300M_seq256_mixed-precision.tflite`, ~179 MB, generic
      variant, from `litert-community/embeddinggemma-300m`) + its
      `sentencepiece.model` tokenizer to `ModelCatalog`, tagged
      `ModelCapability.embeddings` only. Re-verify URLs/sizes against the
      live HuggingFace repo at implementation time.
- [ ] **1.2** Verify `TaskModelRouter().resolve(AiTask.embeddings, ...)`
      finds it (test).
- [ ] **1.3** Add Gradle deps
      (`com.google.ai.edge.localagents:localagents-rag:0.1.0`,
      `com.google.mediapipe:tasks-genai:0.10.22`) to
      `app/android/app/build.gradle.kts`.
- [ ] **1.4** Confirm `GeckoEmbeddingModel`'s actual embed-call method
      against the real AAR (public docs had no direct code sample) before
      finalizing the plugin contract.
- [ ] **1.5** `EmbeddingClient` Dart interface + `MethodChannel`
      implementation in `core_ai`.
- [ ] **1.6** New `EmbeddingPlugin.kt` wrapping `GeckoEmbeddingModel`.
      Decide flavor source-set split (mirror `withLitertlm`/
      `withoutLitertlm`, or something lighter) — understand *why* the
      existing split exists before assuming it transfers.

**Checkpoint — human review required.** This phase adds a real new
third-party native dependency. Re-confirm it's still wanted once its actual
diff/size is known, not just at spec-approval time.

- [ ] `flutter test` green in `core_ai`.
- [ ] New plugin compiles in its wired flavor(s).
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
