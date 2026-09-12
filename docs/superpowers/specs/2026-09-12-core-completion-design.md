# Shared on-device completion seam (`core_completion`)

**Date:** 2026-09-12
**Status:** Approved for implementation (this slice)
**Issue:** [#1991](https://github.com/DevelopersCoffee/airo/issues/1991)
**Owner:** Framework Agent (`packages/core_completion`). Mind cutover owned with Product Manager / Platform Architect as reviewers.
**Depends on:** [Anya import repair](./2026-09-12-anya-import-repair-design.md) (`PlanRepairPort` already shipped, stays no-op)
**Related:** #1628 (Rust `LlmBackend` + llama.cpp), #1827 (reasoning engine)

## Problem

Mind owns `LlamaGgufService.generate` (token stream + optional GBNF `grammar`) inside `feature_mind`. Anya, Airovia, and the super-app need the same engine without depending on Mind UI, meeting IR, or `feature_mind`. This issue is the **Dart completion seam**, not a new trainer and not a move of `airo_mind_llama`.

## This slice

1. New lean package `packages/core_completion` with `CompletionClient.generate({prompt, grammar, maxTokens}) → Stream<String>`.
2. `FakeCompletionClient` and `jsonObjectGbnf` (no product types).
3. `GgufCompletionClient` that prefers an injected `GgufNativeBackend` (Mind’s existing FRB path, the one that already forwards `grammar`) and otherwise uses `llama_flutter_android`.
4. Mind cutover: `LlamaGgufService.generate` delegates to `GgufCompletionClient`. Load/unload stay in Mind. Chat and NER call sites stay on `LlamaGgufService`.
5. Anya flavor unchanged: `NoopPlanRepairPort`, no llama, no `core_completion` on `feature_anya` / `pubspec_anya.yaml`.

## Non-goals (this slice)

- Wiring Anya `PlanRepairPort` to GGUF (next Anya slice; llama may enter `pubspec_anya.yaml` then, never `feature_anya`)
- Chrome Prompt API / `window.ai` / Gemini Nano
- Cloud LLM
- Moving `airo_mind_llama`, FRB generated code, or desktop load policy (#1628)
- Teaching the JNI plugin a grammar sampler if it has no `grammar` parameter — do not fake it
- pub.dev publish
- Calories, OCR, DietProgram types in `core_completion`

## Architecture

```
feature_mind LlamaGgufService.load / unload
        │
        ▼
core_completion GgufCompletionClient
        ├── GgufNativeBackend?  (MindFrbGgufBackend → DesktopGgufBackend / FRB)
        └── llama_flutter_android JNI fallback (Android, grammar may be dropped)
```

Web: `isAvailable == false`. `generate` throws `CompletionUnavailable`.

`core_completion` must not depend on `app`, `feature_mind`, `feature_anya`, or `core_ai`. Copy a tiny GBNF helper rather than taking `core_ai`’s graph (LiteRT, downloads, cloud).

## Public API

```dart
abstract class CompletionClient {
  bool get isAvailable;
  Stream<String> generate({
    required String prompt,
    String? grammar,
    int maxTokens = 512,
  });
  Future<void> stop();
}

class CompletionUnavailable implements Exception {
  const CompletionUnavailable(this.code);
  final String code; // e.g. gguf_model_not_loaded, gguf_backend_unavailable
}

abstract class GgufNativeBackend {
  bool get isReady;
  Stream<String> generate({
    required String prompt,
    required int maxTokens,
    String? grammar,
  });
  Future<void> stop();
}

/// GBNF with start symbol `root` that emits one JSON object.
/// [requiredKeys] become required object members. No diet/meeting vocabulary.
String jsonObjectGbnf({Iterable<String> requiredKeys = const []});
```

`FakeCompletionClient` records last prompt/grammar/maxTokens and yields a scripted token list or throws.

`GgufCompletionClient({GgufNativeBackend? native, LlamaController? jni})`:
- If `native?.isReady == true`, forward prompt/grammar/maxTokens to it.
- Else if Android JNI is loaded, stream JNI tokens. Pass `grammar` only when the plugin API has that parameter; otherwise omit it and document that JNI is unconstrained.
- Else throw `CompletionUnavailable`.

## Mind cutover

- `feature_mind` depends on `core_completion`; `module.yaml` `allowed_dependencies` adds `core_completion`.
- `MindFrbGgufBackend` in `feature_mind` implements `GgufNativeBackend` by forwarding to the existing desktop/FRB generate path (the branch that already passes `grammar`).
- `LlamaGgufService.generate` maps `CompletionUnavailable` to `StateError` with the same codes today’s tests expect (`gguf_model_not_loaded`, `gguf_backend_unavailable`). Timeout on JNI stays 2 minutes + `stop()`.
- Assistant runtime and NER keep calling `LlamaGgufService`. No chat UX change.

## Anya

No file changes in `feature_anya`, `feature_anya_core`, or `pubspec_anya.yaml`. Zero edges to `feature_mind` / `core_completion` / llama. `PlanRepairPort` remains no-op so Chrome Review stays heuristic-only.

## Errors

| Condition | Package | Mind wrapper |
|---|---|---|
| Not loaded / web / no backend | `CompletionUnavailable` | `StateError(code)` (existing tests) |
| JNI hang | `TimeoutException` after 2 min + `stop()` | unchanged |
| Native grammar error | surfaces | no silent unconstrained retry |
| JNI without grammar API | unconstrained JNI generate | documented; FFI remains the GBNF path |

## Tests (host, no GGUF file)

- Fake streams tokens; records grammar.
- `jsonObjectGbnf` contains `root` and each required key; fixture asserts the source has no `diet` / `meeting` / `DietProgram` strings.
- `GgufCompletionClient` with a fake native backend forwards prompt, grammar, maxTokens.
- Unavailable client: `isAvailable == false`; `generate` errors.
- Existing `llama_gguf_service_test` and NER GBNF test still pass.
- New Mind test: after a fake-native ready backend is injected, `LlamaGgufService.generate(..., grammar: g)` forwards `g`.

Automation: `cd packages/core_completion && dart test` (or `flutter test` if the JNI import requires Flutter). `cd packages/feature_mind && flutter test test/services/llama_gguf_service_test.dart test/provenance/data/local_gguf_ner_complete_test.dart`.

## Evaluation (later Anya adapter, not this PR)

Tracked on #1991: schema-valid JSON rate on Pixel 9, p50/p95 repair wall time, fallback count, zero `feature_anya` → `feature_mind` edges.

This slice’s eval is host tests + Mind chat/NER still compiling against `LlamaGgufService`.

## Security / privacy

Local GGUF only. No new network. Prompts stay in-process. Package does not log prompt bodies. Grammar strings are caller-supplied, not evaluated as code.

## Council

New `module.yaml`:

- owner: Framework Agent
- reviewers: Chief Architect, Platform Architect, Chief Security Officer, Chief QA Officer, Chief Open Source Officer (moved `llama_flutter_android` coordinate, not a new dependency)
- allowed_dependencies: none besides Flutter/SDK (JNI plugin is a pub dependency, declared in pubspec)
- forbidden_dependencies: `app`, `feature_mind`, `feature_anya`, `core_ai`

Add `core_completion` to the Framework Agent row in `docs/agents/COUNCIL.md`. Do not add a gstack routing table to `AGENTS.md`.

## Rollback

Delete `packages/core_completion` and restore `LlamaGgufService.generate` body. Anya is untouched.

## Success criteria

- Mind chat and NER still generate through `LlamaGgufService`; grammar still reaches FRB.
- `core_completion` has no `feature_mind` / `core_ai` / `feature_anya` deps.
- Anya packages and `pubspec_anya.yaml` unchanged.
- Host tests above pass without a model file.
