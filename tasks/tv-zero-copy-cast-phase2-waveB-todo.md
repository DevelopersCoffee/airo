# Phase 2 Wave B — DNS Resolver Cache + Connection Pool: Task List

Plan: `tasks/tv-zero-copy-cast-phase2-waveB-plan.md` · Spec: `SPEC.md`
Public/free-tier work — confirmed against SPEC's package table, nothing
here touches `packages_pro/`.

**Read before starting:** Tasks 2–3's pure-logic parts are genuinely
JVM-unit-testable (`./gradlew :app:testDebugUnitTest`, no device). Real
network/pooling/DNS behavior is not — track that in the device-verification
GH issue, don't claim it from a passing unit test.

## Task 1: Propose OkHttp + media3-datasource-okhttp — approval checkpoint
- [ ] Not started — **blocks Task 3 until user confirms**, same gate as
  Wave A's Media3 proposal (Task 3 there)
- **Tier:** architect (proposal only)
- **Verification:** N/A — gate is explicit user confirmation
- **Dependencies:** None

## Task 2: Resolver cache (pure Kotlin, JVM-tested)
- [ ] Not started
- **Tier:** implement
- **Verification:** `./gradlew :app:testDebugUnitTest` — real automated
  coverage, no device needed for this task
- **Dependencies:** None to start (fake transport); Task 1 if DoH
  transport ends up OkHttp-backed

## Task 3: Connection pool config + custom DataSource.Factory
- [ ] Not started
- **Tier:** implement + chief-performance-officer review
- **Verification:** JVM tests for config/delegation logic + **device
  issue for real pooling behavior** (don't open a new one, extend #1574
  or file alongside it)
- **Dependencies:** Task 1 (confirmed), Task 2

## Task 4: Pre-warming hook + wire into SurfaceViewFactory
- [ ] Not started
- **Tier:** implement
- **Verification:** 3-variant Gradle compile + **device re-verification
  that the Wave A test stream still plays through the new DataSource**
- **Dependencies:** Task 3

## Checkpoint: Wave B complete
- [ ] Tasks 1–4 done, JVM tests green, all 3 Gradle variants compile
- [ ] Device-verification GH issue filed/extended
- [ ] Human review of new dependency + hot-path Kotlin
- [ ] Only then: plan Wave C (first pro-gated wave)
