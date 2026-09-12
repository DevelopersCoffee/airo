# Anya GGUF PlanRepairPort Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (this session: inline). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bind Anya import Review to on-device GGUF via `GgufPlanRepairPort` in the Anya shell, keeping `feature_anya` free of llama.

**Architecture:** Adapter in `app/lib/anya/` wraps `CompletionClient`. Conditional import: web stub always no-op; IO factory resolves a `.gguf` path and loads Android JNI. Session already buffers/validates/merges.

**Tech Stack:** Dart/Flutter, `core_completion`, `llama_flutter_android` (Anya flavor), `path_provider`, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-09-12-anya-gguf-plan-repair-design.md` (#1991)

---

## File map

Create:
- `app/lib/anya/gguf_plan_repair_port.dart`
- `app/lib/anya/anya_gguf_path.dart`
- `app/lib/anya/anya_plan_repair_factory_stub.dart`
- `app/lib/anya/anya_plan_repair_factory_io.dart`
- `app/test/anya/gguf_plan_repair_port_test.dart`
- `app/test/anya/anya_plan_repair_factory_test.dart`

Modify:
- `app/lib/main_anya.dart` — factory + `AiroAnyaApp.planRepairPort`
- `app/pubspec_anya.yaml` — `core_completion`, `path_provider`
- `app/pubspec.yaml` — `core_completion` so `main_anya.dart` analyzes in the phone package

Do not modify `packages/feature_anya`, `packages/feature_anya_core`.

---

### Task 1: GgufPlanRepairPort

- [x] Failing tests: available/unavailable, prompt contains draft JSON, grammar required keys, tokens forwarded
- [x] Implement port
- [x] `flutter test test/anya/gguf_plan_repair_port_test.dart`

### Task 2: Path + factory

- [x] Failing tests: configured existing file; missing file → null; searchRoots first `*.gguf`; factory no path / bind fail → `NoopPlanRepairPort`; injected available client → `GgufPlanRepairPort`
- [x] Implement path helper + IO factory + web stub
- [x] Tests pass

### Task 3: Wire shell

- [x] `createAnyaPlanRepairPort()` in `composeApp`; `AiroAnyaApp` override uses injected port (default no-op)
- [x] pubspecs
- [x] `flutter analyze` on touched files; existing `main_anya_shell_test` still passes
