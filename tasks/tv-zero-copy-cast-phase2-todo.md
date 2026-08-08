# Phase 2 — Receiver Streaming Engine: Wave A Task List

Plan: `tasks/tv-zero-copy-cast-phase2-plan.md` · Spec: `SPEC.md`
Only Wave A is task-broken (see plan's AD-P2.3 for why). Waves B–D get
their own todo list once Wave A's checkpoint passes.

**Read before starting:** every "Verification" below that says "manual,
device-required" cannot be closed out by an agent alone — it needs the
user present with the physical rig. Don't report a task done on Gradle-
green alone when its acceptance criteria include a device check.

## Task 1: `platform_streaming_engine` package scaffold + method-channel round trip
- [ ] Not started
- **Tier:** architect (package shape) → implement (scaffold)
- **Verification:** `flutter test && flutter analyze` in the new package
- **Dependencies:** None

## Task 2: Kotlin plugin skeleton + `ping`, `tv` flavor only
- [ ] Not started
- **Tier:** implement + platform-architect review before merge
- **Verification:** Gradle compile (flavor-scoped) + **manual device
  round-trip check**
- **Dependencies:** Task 1

## Task 3: Propose Media3 dependency — approval checkpoint, no code
- [ ] Not started
- **Tier:** architect (proposal only)
- **Verification:** N/A — gate is explicit user confirmation
- **Dependencies:** None (parallel-safe with 1–2)

## Task 4: Media3 dependency + minimal SurfaceView PlatformView
- [ ] Not started
- **Tier:** implement + chief-performance-officer + platform-architect review
- **Verification:** Gradle build both flavors + **manual on-device frame check**
- **Dependencies:** Task 3 (confirmed), Task 2

## Task 5: STATE event stream (phase mapping) back to Dart
- [ ] Not started
- **Tier:** implement + playback-architect review
- **Verification:** `flutter test` (mockable Dart half) + **manual device
  check for real transitions**
- **Dependencies:** Task 4

## Checkpoint: Wave A complete
- [ ] Tasks 1–5 done, Dart tests green, both flavors build
- [ ] **Interactive session with user + physical rig**: frame renders
  end-to-end on a real device — the actual go/no-go gate
- [ ] Human review of the new package/module boundary
- [ ] Only then: plan Wave B (DNS + connection pool) as its own todo list
