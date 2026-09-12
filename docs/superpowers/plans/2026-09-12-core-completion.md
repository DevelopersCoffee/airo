# core_completion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (this session: inline). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship `packages/core_completion` as the Dart `generate(prompt, {grammar, maxTokens})` seam and cut Mind `LlamaGgufService.generate` over to it without changing Anya.

**Architecture:** Lean Flutter package. `GgufCompletionClient` prefers injected `GgufNativeBackend` (Mind FRB) and otherwise `llama_flutter_android` JNI without inventing a grammar parameter. Mind keeps load/unload. Anya stays no-op.

**Tech Stack:** Dart/Flutter, `llama_flutter_android` ^0.2.6 (already in Mind), `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-09-12-core-completion-design.md` (#1991)

---

## File map

Create:
- `packages/core_completion/pubspec.yaml`
- `packages/core_completion/module.yaml`
- `packages/core_completion/README.md`
- `packages/core_completion/analysis_options.yaml`
- `packages/core_completion/lib/core_completion.dart`
- `packages/core_completion/lib/src/completion_client.dart`
- `packages/core_completion/lib/src/completion_unavailable.dart`
- `packages/core_completion/lib/src/fake_completion_client.dart`
- `packages/core_completion/lib/src/gguf_native_backend.dart`
- `packages/core_completion/lib/src/gguf_completion_client.dart`
- `packages/core_completion/lib/src/json_object_gbnf.dart`
- `packages/core_completion/test/fake_completion_client_test.dart`
- `packages/core_completion/test/json_object_gbnf_test.dart`
- `packages/core_completion/test/gguf_completion_client_test.dart`
- `packages/feature_mind/lib/src/services/mind_frb_gguf_backend.dart`

Modify:
- `packages/feature_mind/pubspec.yaml` — path dep `core_completion`
- `packages/feature_mind/module.yaml` — allowed_dependencies
- `packages/feature_mind/lib/src/services/llama_gguf_service.dart` — delegate generate
- `packages/feature_mind/test/services/llama_gguf_service_test.dart` — grammar forward
- `docs/agents/COUNCIL.md` — Framework Agent owns `core_completion`
- `docs/agents/AGENT_POLICY.md` — ownership map row

Do not modify `feature_anya`, `feature_anya_core`, `pubspec_anya.yaml`.

---

### Task 1: Fake + jsonObjectGbnf

- [ ] Failing tests for Fake token stream / recorded grammar, jsonObjectGbnf `root` + keys, source has no diet/meeting/DietProgram
- [ ] Implement until `flutter test` in `packages/core_completion` passes those files
- [ ] Commit `feat(completion): add CompletionClient fake and JSON GBNF helper`

### Task 2: GgufCompletionClient

- [ ] Failing tests: fake native forwards prompt/grammar/maxTokens; unavailable errors `CompletionUnavailable`
- [ ] Implement `GgufCompletionClient` (native first; JNI without grammar param; 2 min timeout)
- [ ] Commit `feat(completion): add GgufCompletionClient with injected native backend`

### Task 3: Mind cutover

- [ ] `MindFrbGgufBackend` + `LlamaGgufService.generate` delegates; map `CompletionUnavailable` → `StateError`
- [ ] Test: injected ready native receives grammar
- [ ] Existing `llama_gguf_service_test` + NER test pass
- [ ] Commit `feat(mind): delegate GGUF generate to core_completion`

### Task 4: Council docs

- [ ] Ownership rows; `python3 scripts/check-module-manifests.py` includes the new manifest
- [ ] Commit `docs(completion): assign core_completion to Framework Agent`

---

## Spec coverage

| Spec item | Task |
|---|---|
| CompletionClient + Fake + jsonObjectGbnf | 1 |
| GgufCompletionClient + native inject + JNI fallback | 2 |
| Mind generate cutover + StateError mapping | 3 |
| Anya unchanged | 3 (verify no files) |
| Council / module.yaml | 1+4 |
| No core_ai / feature_mind / feature_anya deps in package | 1–2 |
| FRB/airo_mind_llama not moved | 3 |
