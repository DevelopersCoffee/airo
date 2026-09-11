# Anya Import Repair Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (this session chose inline). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Repair split foods and meal-type junk rows in imported `DietProgram`s with a tested heuristic, and add a no-op `PlanRepairPort` so GGUF/Nano can plug in later (#1991).

**Architecture:** `repairImportedProgram` in `feature_anya_core` runs after `DietPdfNormalizer.parseProgram`, using original page text to join fragments. `feature_anya` adds `PlanRepairPort` / `RepairStatus`. Session never writes token fragments into `pendingProgram`. `main_anya` overrides the port to no-op.

**Tech Stack:** Dart unit tests (`feature_anya_core`), Flutter widget/provider tests (`feature_anya`), Riverpod, existing `DietProgram` JSON.

**Spec:** `docs/superpowers/specs/2026-09-12-anya-import-repair-design.md`

---

## File map

- Create: `packages/feature_anya_core/lib/src/engines/repair_imported_program.dart`
- Create: `packages/feature_anya_core/test/engines/repair_imported_program_test.dart`
- Create: `packages/feature_anya_core/test/fixtures/green_tea_split.txt`
- Modify: `packages/feature_anya_core/lib/feature_anya_core.dart`
- Create: `packages/feature_anya/lib/src/repair/plan_repair_port.dart`
- Modify: `packages/feature_anya/lib/feature_anya.dart`
- Modify: `packages/feature_anya/lib/src/presentation/providers/anya_providers.dart`
- Modify: `packages/feature_anya/lib/src/presentation/screens/import_review_screen.dart`
- Modify: `packages/feature_anya/test/presentation/anya_module_test.dart`
- Modify: `app/lib/main_anya.dart`

---

### Task 1: Heuristic repair engine

**Files:**
- Create: `packages/feature_anya_core/test/engines/repair_imported_program_test.dart`
- Create: `packages/feature_anya_core/lib/src/engines/repair_imported_program.dart`
- Create: `packages/feature_anya_core/test/fixtures/green_tea_split.txt`
- Modify: `packages/feature_anya_core/lib/feature_anya_core.dart`

- [ ] **Step 1: Write failing tests** for join-from-source-text, drop meal-type rows, keep `1k`.
- [ ] **Step 2: Run tests, confirm they fail** (`dart test test/engines/repair_imported_program_test.dart`)
- [ ] **Step 3: Implement `repairImportedProgram`**
- [ ] **Step 4: Tests pass; existing normalizer tests still pass**
- [ ] **Step 5: Commit** `fix(anya): join split import foods and drop meal-type rows`

### Task 2: PlanRepairPort + session status

**Files:**
- Create: `packages/feature_anya/lib/src/repair/plan_repair_port.dart`
- Modify: `packages/feature_anya/lib/src/presentation/providers/anya_providers.dart`
- Modify: `packages/feature_anya/lib/feature_anya.dart`
- Modify: `packages/feature_anya/test/presentation/anya_module_test.dart`

- [ ] **Step 1: Failing tests** — noop stays `idle`; fake invalid JSON → `failed` and heuristic kept; fake valid JSON → `complete` with heuristic `id`/`source`.
- [ ] **Step 2: Implement port, `RepairStatus`, wire `_normalizeImport`**
- [ ] **Step 3: Tests pass**
- [ ] **Step 4: Commit** `feat(anya): add no-op PlanRepairPort and repair status`

### Task 3: Review banner + shell override

**Files:**
- Modify: `packages/feature_anya/lib/src/presentation/screens/import_review_screen.dart`
- Modify: `packages/feature_anya/test/presentation/anya_module_test.dart`
- Modify: `app/lib/main_anya.dart`

- [ ] **Step 1: Widget test** shows cleaning copy when status is cleaning; no spinner on noop import
- [ ] **Step 2: Banner + `planRepairPortProvider.overrideWithValue(NoopPlanRepairPort())` in `AiroAnyaApp`**
- [ ] **Step 3: Tests + `flutter analyze`**
- [ ] **Step 4: Commit** `feat(anya): show import repair status on Review`

---

## Spec coverage

| Spec item | Task |
|---|---|
| Join Green/T/ea from original text | 1 |
| Drop Dinner/Breakfast rows | 1 |
| Keep 1k | 1 |
| PlanRepairPort no-op | 2 |
| Never apply token fragments | 2 |
| Merge id/source/quantityRaw | 2 |
| Review banner | 3 |
| main_anya override | 3 |
| No llama / core_ai / feature_mind | all |
| GGUF/Nano | out of slice (#1991) |
