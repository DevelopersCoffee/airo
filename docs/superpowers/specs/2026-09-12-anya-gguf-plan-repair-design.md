# Anya GGUF `PlanRepairPort` adapter

**Date:** 2026-09-12
**Status:** Approved for implementation (this slice)
**Issue:** [#1991](https://github.com/DevelopersCoffee/airo/issues/1991)
**Owner:** Anya / Nutrition Agent (shell wiring). Shared generate seam stays Framework Agent (`core_completion`).
**Depends on:** [core_completion](./2026-09-12-core-completion-design.md) (merged), [Anya import repair](./2026-09-12-anya-import-repair-design.md)

## Problem

`PlanRepairPort` is no-op. Pixel can run a local GGUF; Chrome cannot. Review stays heuristic unless the Anya shell binds `CompletionClient` without pulling Mind UI or putting llama inside `feature_anya`.

## This slice

1. `GgufPlanRepairPort` in the Anya **app shell** (`app/lib/anya/`), wrapping `CompletionClient`. Prompt = wellness repair instructions + `jsonEncode(draft.toJson())`. Grammar = `jsonObjectGbnf(requiredKeys: ['id', 'title', 'source', 'phases'])`.
2. Factory: web or no model file → `NoopPlanRepairPort`. Android with a loadable `*.gguf` → `GgufPlanRepairPort(GgufCompletionClient(jni: …))`.
3. `pubspec_anya.yaml` depends on `core_completion` (llama enters the **flavor**, never `feature_anya` / `feature_anya_core`).
4. `AiroAnyaApp` overrides `planRepairPortProvider` with the factory result. Session pipeline unchanged (buffer, validate, merge, fallback).

## Non-goals

- Chrome Prompt API / Gemini Nano
- Desktop FRB / `airo_mind_llama` in Anya (Pixel JNI only this slice)
- `loadModel` in `core_completion`
- Teaching JNI a grammar sampler
- Pixel metrics collection UI (still tracked on #1991)
- Calories, OCR, Anya AI tab, super-app registration

## Binding

- `feature_anya` / `feature_anya_core`: no `core_completion`, no llama, no `feature_mind`.
- Discover a file via `--dart-define=ANYA_GGUF_PATH=` or the first `*.gguf` under app support `models/`, app support, or documents. Missing file → no-op (`isAvailable == false`, Review idle).
- JNI `generate` still has no `grammar` parameter; pass grammar into `CompletionClient.generate` anyway. Session JSON validate remains the safety net.
- Load failures → `NoopPlanRepairPort`. Do not crash the shell.

## Tests (host, no model binary)

- Fake `CompletionClient`: port available; prompt contains draft JSON; grammar has required keys; tokens forwarded.
- Unavailable client / no path / bind failure → `NoopPlanRepairPort` or `isAvailable == false`.
- Existing Anya session tests still prove invalid JSON → `failed` + heuristic kept.
- Web factory stub is `NoopPlanRepairPort`.

## Success criteria

- Chrome Review unchanged: idle, no spinner, heuristic plan.
- Pixel with a GGUF file: `isAvailable == true`, cleaning banner, then complete or failed-with-heuristic.
- Zero `feature_anya` → `feature_mind` / `core_completion` edges.

## Rollback

Revert Anya shell files and `pubspec_anya.yaml` `core_completion`. Port stays no-op.
