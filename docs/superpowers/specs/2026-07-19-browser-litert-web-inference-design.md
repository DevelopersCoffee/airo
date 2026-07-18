# Browser (Web) LiteRT Inference — Design

Status: Approved (pending spec review)
Date: 2026-07-19

## Problem

Airo's Mind chat (`app/#/mind`) falls back to Gemini Cloud on web builds and shows
"Gemini Cloud is not configured" because there is no local inference path in the
browser. `LiteRtLmRuntimeAdapter.prepareModel()` explicitly throws
`UnsupportedError('LiteRT-LM is not available on web.')`
(`packages/core_ai/lib/src/litert/litert_lm_runtime_adapter.dart:122-124`), and
`isAvailable()` / `hydrateDownloadedModel()` / `downloadedModelPath()` all early-return
false/no-op under `kIsWeb`.

## Goal

Give the Flutter web build of Airo a working local LLM runtime, using Google's
MediaPipe LLM Inference API (WASM + WebGPU), reusing the existing model
catalog/registry/router architecture rather than building a parallel system.

## Non-goals

- Full 6-model dynamic RAM-tiering table exactly as sketched in the originating
  request (TinyLlama, Phi-4 Mini) — out of scope for this pass. Only Gemma
  4-E2B/E4B ship with confirmed web support; Qwen2.5-1.5B is added to the catalog
  but gated behind a verification step (see Open Question below).
- New chat UI screens. Reuses the existing Model Library picker.
- Vendoring MediaPipe WASM assets into the repo. Loaded from CDN at runtime.

## Architecture

```
AssistantRuntimeService (app/lib/features/agent_chat/...)   -- UNCHANGED
        │
LiteRtLmService (app/lib/core/services/litert_lm_service.dart)  -- adapter picked by kIsWeb
        │
   ┌────┴──────────────────────────┐
Native (existing)              MediaPipeWebRuntimeAdapter (NEW)
LiteRtLmRuntimeAdapter              │
(MethodChannel)                dart:js_interop → @mediapipe/tasks-genai (CDN)
                                     │
                                model bytes cached via browser Cache API
```

`LiteRtLmService` is the only call site that changes: it picks
`kIsWeb ? MediaPipeWebRuntimeAdapter() : LiteRtLmRuntimeAdapter()` at construction.
Every layer above it — `AssistantRuntimeService`, the Mind chat screen, the Model
Library screen — is unmodified. Both adapters implement the same
`LocalInferenceRuntimeAdapter` contract from
`packages/core_ai/lib/src/runtime/local_inference_runtime_adapter.dart`.

## Components

### `MediaPipeWebRuntimeAdapter` (new)

`packages/core_ai/lib/src/litert/mediapipe_web_runtime_adapter.dart`

- Implements `LocalInferenceRuntimeAdapter`.
- `runtimeKind` gets a new `LocalRuntimeKind.mediaPipeWeb` enum value.
- `capabilitiesForModel`: WASM CPU always available; WebGPU backend advertised
  only if `navigator.gpu` exists in the JS environment.
- `prepareModel()` / `generateText()`: lazy-loads the MediaPipe GenAI WASM bundle
  from CDN (jsdelivr) via `dart:js_interop`, downloads the model's `.task` bundle
  (browser `fetch`, cached in the Cache API keyed by model id), instantiates
  `LlmInference`, and calls `generateResponse`.
- `hydrateDownloadedModel()` / `downloadedModelPath()`: check the Cache API
  instead of filesystem; return a cache key in place of a file path.
- `isAvailable()`: returns true if WASM can load (always true in supported
  browsers) rather than false as today.
- Guarded so it is only ever constructed/used when `kIsWeb` — mirrors how the
  native adapter guards `kIsWeb` today, just inverted.

### `ModelCatalog` changes

`packages/core_ai/lib/src/registry/model_catalog.dart` — two new fields added to
`OfflineModelInfo`:

- `bool supportsWebRuntime`
- `String? webAssetUrl` (the MediaPipe `.task` bundle URL; distinct from the
  existing native `downloadUrl` since the web LLM Inference API needs its own
  bundle format, not the raw `.litertlm`)

Populated for:
- `gemma-4-e2b-it-litertlm` — default on web (small tier)
- `gemma-4-e4b-it-litertlm` — manual upgrade (large tier)
- `qwen2.5-1.5b-instruct` — **new catalog entry**, gated (see Open Question)

### Default model selection

Reuses `DeviceCapabilityService._getWebMemoryEstimate()`
(`device_capability_service.dart:116-121`, already returns 4GB total / 2GB
available on web) and the existing `ModelRegistry.checkCompatibility` tiering
logic used natively. Under ~2GB available → Gemma-4-E2B; above → Gemma-4-E4B.
Manual override available through the existing Model Library screen — offline
packages with `supportsWebRuntime: true` become visible there when `kIsWeb`.

## Error handling

Reuses the existing diagnostic/exception machinery in
`app/lib/features/agent_chat/data/services/assistant_runtime_service.dart`
(`AssistantRuntimeUnavailableException`, `AssistantRuntimeDiagnosticEnvelope`).
Adds one new message constant in `assistant_runtime_ids.dart` for
"WebGPU/WASM initialization failed" — the adapter falls back from WebGPU to
WASM CPU automatically (MediaPipe supports both natively) before surfacing
this error, so it should only trigger if WASM itself fails to load (e.g.
CDN unreachable, browser too old).

## Testing

- Unit tests for `MediaPipeWebRuntimeAdapter`, mirroring
  `packages/core_ai/test/litert/litert_lm_runtime_adapter_test.dart` structure,
  with the `dart:js_interop` boundary mocked.
- `ModelCatalog` test asserting the new fields are populated for the Gemma
  web-capable entries.
- Widget test: Mind chat screen produces a response when running under a
  simulated web platform with the adapter mocked.
- No changes to the native adapter's existing test suite.

## Open question (must resolve before implementation touches Qwen/SmolLM2)

Google's `litert-community` HuggingFace org has confirmed official MediaPipe
web `.task` bundles for Gemma only as of this writing. Whether an official
`.task` bundle exists for Qwen2.5-1.5B or SmolLM2 needs verification during
implementation. If none exists, that catalog entry ships with
`supportsWebRuntime: false` and is simply excluded from the web picker until
one appears — this does not block the Gemma path.

## Worktree

Isolated work happens in a new git worktree (following this repo's
`.worktrees/<slug>` convention), not on `main` directly.
