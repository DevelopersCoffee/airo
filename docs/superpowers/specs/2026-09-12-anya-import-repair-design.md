# Anya import repair — heuristics now, on-device LLM port later

**Date:** 2026-09-12
**Status:** Approved for implementation (this slice); GGUF/Nano adapters deferred
**Product:** Anya — import Review
**Depends on:** [2026-09-10 Anya MVP](./2026-09-10-anya-mvp-design.md)
**Follow-up:** extract Mind GGUF completion into a shared lib (Mind, Anya, Airovia, super-app) — [#1991](https://github.com/DevelopersCoffee/airo/issues/1991).

## Problem

Heuristic PDF/paste parse splits real foods (`Green tea` → `Green` / `T` / `ea`), treats meal-type labels as food rows (`Dinner`, `Breakfast`), and shows `quantity missing` instead of keeping `quantityRaw`. Chrome Review is the dogfood loop. Pixel has GGUF, web does not.

## This slice

1. Deterministic heuristic repair in `feature_anya_core` after `DietPdfNormalizer.parseProgram`.
2. `PlanRepairPort` seam in `feature_anya` with `NoopPlanRepairPort`.
3. `RepairStatus` on the existing Riverpod session. Review banner only.
4. `AiroAnyaApp` overrides the port to no-op. No llama in `pubspec_anya.yaml`. No `feature_mind` / `core_ai` deps.

## Non-goals (this slice)

- Wiring `LlamaGgufService` or any GGUF binary into the Anya flavor
- Chrome Prompt API / `window.ai` / Gemini Nano
- Cloud LLM
- OCR
- Calorie or BMI invention
- Changing `pendingProgram` to `Map<String, dynamic>`

## Wellness

Same banner. Repair may merge names and drop junk rows. It must not invent calories, medical targets, or rewrite unclear quantities (`1k` stays `1k`).

## Heuristic repair (`feature_anya_core`)

Pure Dart, unit-tested, runs on web and device.

Input: `DietProgram` from `DietPdfNormalizer` plus the original extracted page text. Output: same type.

Rules (minimum):

- Join adjacent 1–2 character name fragments in the same slot into one food (`Green` + `T` + `ea` → `Green tea`) when the concatenation (with or without spaces) appears in the original page text.
- Drop a `FoodItem` whose name is only a meal-type or slot label (`Breakfast`, `Lunch`, `Dinner`, `Evening`, `Snack`, `Early morning`, `Mid Morning`).
- Keep `quantityRaw` as parsed. Empty raw stays empty; UI may show `quantity missing` only when raw is empty after repair.
- Do not invent units. Do not drop `1k`.
- Preserve `id`, `source`, phase ids, day numbers, slot times.

Fixtures: Day-7 poha still has `quantityRaw: "1k"`. Add a Green-tea / meal-label fixture from the broken Review screenshot.

## Port (`feature_anya`)

```dart
enum RepairStatus { idle, cleaning, complete, failed }

abstract class PlanRepairPort {
  bool get isAvailable;
  /// Token stream of a JSON DietProgram. Never applied until complete + valid.
  Stream<String> repair(DietProgram draft);
}

class NoopPlanRepairPort implements PlanRepairPort {
  const NoopPlanRepairPort();
  @override
  bool get isAvailable => false;
  @override
  Stream<String> repair(DietProgram draft) => const Stream.empty();
}
```

`anyaSessionProvider` already holds `DietProgram? pendingProgram` and `ExtractionValidation? pendingValidation`. Add `RepairStatus repairStatus` (default `idle`). Keep types; do not store JSON maps in session state.

Pipeline after heuristic parse:

1. Set `pendingProgram` to heuristic result. If `port.isAvailable`, set `repairStatus = cleaning`; else `idle` and return.
2. Buffer `port.repair(draft)` tokens. Do not write tokens into `pendingProgram`.
3. Strip optional markdown fences. `jsonDecode` → `DietProgram.fromJson`.
4. Merge: keep heuristic `id` and `source`. For each food, if the model omitted `quantityRaw` or cleared it, keep the heuristic item’s `quantityRaw` (match by slot time + name, else by index).
5. Refresh `pendingValidation` with `DietPdfNormalizer.validate(pages: originalPages, program: merged)`.
6. Success → swap `pendingProgram`, `repairStatus = complete`. Any throw → keep heuristic program, `repairStatus = failed`.

Review UI: status line for `cleaning` (“Cleaning with on-device model…”) and `failed` (“Could not refine. Showing parsed plan.”). `complete` needs no banner. Confirm plan unchanged.

## Injection

Same as repository. `planRepairPortProvider` defaults to `NoopPlanRepairPort`. `AiroAnyaApp` overrides it explicitly. Tests do not need a model.

Conditional import is allowed for a web stub of the port default; the Anya flavor still must not import Mind.

## Follow-up shared lib (not this slice)

Extract Mind’s `LlamaGgufService.generate` (including `grammar` / GBNF) into a package both Mind and Anya (and Airovia / super-app) can depend on without taking `feature_mind`. Chrome Prompt API and GGUF are two adapters behind `PlanRepairPort`. Related existing work: #1628 (Rust `LlmBackend` + llama.cpp), #1827 (reasoning engine epic), **#1991** (this follow-up).

### Tracking (attach to the follow-up issue)

- Schema-valid JSON rate on Pixel 9 (success / (success + failed fallback))
- p50 / p95 wall time for one import repair on Pixel 9 with the default GGUF
- Fallback count (status `failed`, heuristic kept)
- Zero `feature_anya` → `feature_mind` edges in `module.yaml` / pubspec

## Success criteria (this slice)

- Chrome Review no longer splits `Green tea` or lists `Dinner` as a food on the screenshot fixture.
- Day-7 `1k` still round-trips.
- No llama / `core_ai` / `feature_mind` on Anya packages.
- With `NoopPlanRepairPort`, `repairStatus` stays `idle` and Review never shows a cleaning spinner.
- Fake available port that returns invalid JSON → `failed`, heuristic program unchanged.
- Fake available port that returns valid JSON → `complete`, `id`/`source` preserved.

## Rollback

Revert the heuristic function and port fields. Import Review returns to current parser-only behavior.
