# Semantic search for the Mind scribe (#508)

## Objective

Add semantic ranking on top of the scribe's existing full-text search
(`searchMeetings`, Rust-side FTS over transcript + minutes), so a query like
"the pricing discussion" surfaces a meeting that never used those exact words.

**Target user**: someone with more than a screenful of recorded meetings, who
remembers what a conversation was *about* but not the words used in it.

**Scope, resolved after investigation** (see "What was ruled out" below):
scribe meetings only (`MeetingRecord`/`searchMeetings`), not the Mind Runtime's
`ProjectionPort.search`. Keyword search stays authoritative; semantic scoring
re-ranks and supplements it. This is a smaller slice than #508's literal
listed targets (Transcript, Summary, Participants, Topics, Projects, Tasks) —
those live in the Mind Runtime, which has no working search backend yet (see
below). Extending to the runtime is future work, not this spec.

## What was ruled out, and why

- **`ProjectionPort.search` (the Mind Runtime's graph/timeline/search
  primitive)**: its own doc comment says "ranked locally by embedding plus
  keyword" — the eventual design already matches this spec's shape — but
  `RustMindRuntime`'s implementation is a stub (`_pending`, tracked by
  #1218/#1219/#1220). #1220 (the search projection itself) depends on #1218
  (replay pipeline), which depends on #1194 (Operation Log) and #1196
  (Capability SDK). None of the four are built. `FixtureMindRuntime` is the
  only working implementation today. Building semantic ranking on top of a
  stub is building on a foundation that doesn't exist.
- **A new Rust embedding engine inside `feature_mind`** (a third cdylib
  alongside whisper/llama): rejected — a native Android SDK already does
  exactly this (see Architecture), and adding a Rust engine would mean a
  *second* new native surface for the same feature.
- **Reusing `LiteRtLmPlugin.kt`'s existing `Engine`/`Conversation` API**
  (this spec's first draft assumed this): investigated and ruled out.
  EmbeddingGemma is not published as a `.litertlm` package — the
  `litert-community/embeddinggemma-300m` HuggingFace repo has only raw
  `.tflite` files (chip-specific and generic variants) plus a
  `sentencepiece.model` tokenizer. `.litertlm` is what `LiteRtLmPlugin.kt`
  loads via LiteRT-LM's `Engine`/`Conversation` API; a raw `.tflite` needs a
  different loader. Confirmed before writing any Kotlin.
- **`AiTask`/`TaskModelRouter` gains a new task for this**: not needed.
  `AiTask.embeddings` already exists (PR #1564) and is exactly the right
  shape — this spec is the first real caller of it, not a reason to add
  another.

## Architecture

```
MeetingRecord (transcript + minutes)
        │
        ▼
EmbeddingService.embed(text) -> List<double>          [new, core_ai]
        │  backed by a new EmbeddingPlugin method channel
        │  wrapping Google's AI Edge RAG SDK GeckoEmbeddingModel [new native plugin]
        │  resolved via TaskModelRouter(AiTask.embeddings, installed)
        ▼
MeetingEmbeddingStore                                  [new, feature_mind]
   - one vector per meeting, keyed by meeting id
   - persisted locally (see Storage)
        │
        ▼
SemanticSearchRanker.rank(query, keywordHits)          [new, feature_mind]
   - embeds the query
   - cosine-similarity against stored vectors
   - merges with searchMeetings' keyword hits (union, not replacement --
     a keyword match a query didn't semantically resemble is still a real
     match and must not disappear)
        │
        ▼
MindHomeScreen's existing search box                   [existing, unchanged call site --
                                                          only what backs it changes]
```

### The real native path — Google AI Edge RAG SDK, not LiteRT-LM

Confirmed by reading the actual Android integration guide (not assumed):
Google publishes an **AI Edge RAG SDK** (`com.google.ai.edge.localagents:localagents-rag:0.1.0`,
alongside `com.google.mediapipe:tasks-genai:0.10.22`) with a `GeckoEmbeddingModel`
class built exactly for this: `GeckoEmbeddingModel(modelPath, Optional.of(tokenizerPath), useGpu)`,
consuming a `.tflite` file plus a `sentencepiece.model` tokenizer — precisely
the file shape `litert-community/embeddinggemma-300m` ships. Output is a
768-dimension vector.

This is a **new native plugin**, not an addition to `LiteRtLmPlugin.kt` —
different Gradle dependency, different Android API surface
(`Embedder<String>`, not `Engine`/`Conversation`). Real new-dependency cost:
one new AAR pair (small, code only) and a `ModelCatalog` entry for
`embeddinggemma-300M_seq256_mixed-precision.tflite` (~179 MB, generic/
no-chip-suffix variant — chosen over chip-specific variants for one
consistent choice, and over longer `seq512`/`seq1024`/`seq2048` variants
since search queries and meeting-chunk embeddings are short text).

**Not bundled in the APK.** Same distribution as every other `ModelCatalog`
entry (`ADR-0018 §1`/`§2` — neither app ships model weights in the binary):
the model is a `ModelDownloadService` download the user opts into, discovered
through the existing model-library UI the same way chat models already are —
a card with a download button, not an automatic fetch. Semantic search
degrades to keyword-only (see `SemanticSearchRanker`) until the user chooses
to download it. The new Gradle/AAR dependency (code, not model weights) does
land in the APK regardless of whether the user ever downloads the model —
that part isn't optional the way the model itself is, and is the actual
"deserves review before landing" cost (`chief-open-source-officer`'s usual
scope for a new third-party dependency).

### Storage

Meeting count for a personal scribe is expected to stay in the hundreds, not
millions. Brute-force cosine similarity over an in-memory list of vectors,
loaded from a small local file (one JSON array per meeting, or a Drift table
if `feature_mind` already has a local db dependency — check before adding
one) is sufficient. No ANN index (e.g. HNSW) in this spec — premature for the
expected scale, and it would be new infrastructure with no evidence it's
needed yet.

Embeddings regenerate, not sync: if the embedding model changes, existing
vectors are stale and must be recomputed, not migrated. Store the model id
that produced each vector (mirrors `ADR-0018 §5`'s "record what produced
this, don't infer it later" pattern already used for `MeetingRecord.model`)
so a version mismatch is detectable rather than silently wrong.

## Commands

```bash
# feature_mind (new store, ranker)
cd packages/feature_mind && flutter analyze && flutter test

# core_ai (new EmbeddingService, ModelCatalog entry, EmbeddingClient)
cd packages/core_ai && flutter analyze && flutter test

# Android native change (new plugin, new Gradle dependency)
cd app/android && ./gradlew :app:compileDebugKotlin   # exact task/module TBD

# Full regression
cd app && flutter analyze && flutter test
```

## Project Structure (files likely touched)

- `packages/core_ai/lib/src/registry/model_catalog.dart` — add EmbeddingGemma
  entry, `ModelCapability.embeddings`.
- `packages/core_ai/lib/src/embeddings/embedding_client.dart` (new) — Dart
  interface + `MethodChannel` implementation, mirrors `LiteRtLmClient`'s
  shape but its own channel/plugin.
- `app/android/app/src/.../EmbeddingPlugin.kt` (new — exact flavor source
  set TBD, likely mirrors `withLitertlm`/`withoutLitertlm`'s split since this
  is also a large optional native dependency) — wraps `GeckoEmbeddingModel`.
- `app/android/app/build.gradle.kts` — add
  `com.google.ai.edge.localagents:localagents-rag` +
  `com.google.mediapipe:tasks-genai` dependencies.
- `packages/core_ai/lib/src/embeddings/embedding_service.dart` (new) —
  wraps `TaskModelRouter` + `EmbeddingClient`.
- `packages/feature_mind/lib/src/search/meeting_embedding_store.dart` (new).
- `packages/feature_mind/lib/src/search/semantic_search_ranker.dart` (new).
- `packages/feature_mind/lib/src/mind_service.dart` — `search()` gains
  semantic re-ranking, same public signature.
- Tests alongside each new file.

## Code Style

Match what's already in `feature_mind`/`core_ai`: `@immutable` value types,
constructor-injected collaborators defaulting to production implementations
(the `ModelProvider`/`MindSpeechBridge` pattern), doc comments that explain
*why* a design choice was made, not what the code does. No new state
management framework — this is plain Dart classes, consistent with
`MindService`.

## Testing Strategy

- `EmbeddingService`: fake `EmbeddingClient`/`TaskModelRouter`, no real model
  load in unit tests (mirrors `download_model_provider_test.dart`'s no-real-
  network approach).
- `MeetingEmbeddingStore`: round-trip persistence, stale-model-id detection.
- `SemanticSearchRanker`: keyword-only hit surfaces even with no embedding
  match (union, not replacement) — this is the one behavior most likely to
  regress silently if reimplemented carelessly, so it gets its own explicit
  test, not just a snapshot of combined output.
- No test may require a real on-device model or network access.

## Boundaries

- **Always**: keep `searchMeetings`'s keyword results in the final output.
  Semantic scoring may reorder and add, never remove, a keyword match.
- **Ask first**: any change to `ModelCatalog`'s existing entries, any new
  native platform channel method beyond `embed`, moving this to sync across
  devices (out of scope — embeddings are local-only, regenerable, and not an
  op-log entity).
- **Never**: touch `packages/core_ai/lib/src/router/task_model_router.dart`
  or `ai_task.dart` for this — `AiTask.embeddings` already has the right
  shape. Never add a vector index/ANN library without first confirming the
  brute-force approach is actually too slow (measured, not assumed). Never
  wire this into `ProjectionPort.search` until #1220 has a real
  implementation — this spec's `MindService.search()` integration point is
  deliberately the scribe's existing surface, not the runtime's.

## Open Questions

- Exact Android flavor source-set split for `EmbeddingPlugin.kt` — mirror
  `withLitertlm`/`withoutLitertlm`, or does this new dependency warrant its
  own flag? Decide during implementation, not guessed here.
- Whether `feature_mind` already has a local db (Drift) dependency suitable
  for the embedding store, or whether a flat file is simpler — check before
  choosing.
- Exact `Embedder<String>`/`GeckoEmbeddingModel` method signature for
  extracting a vector (the Android guide didn't show a direct code sample) —
  confirm against the actual AAR's API during implementation.
