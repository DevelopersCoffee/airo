# Phase 2 Wave B — DNS Resolver Cache + Connection Pool: Task List

Plan: `tasks/tv-zero-copy-cast-phase2-waveB-plan.md` · Spec: `docs/specs/tv-zero-copy-cast.md`
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
- [x] DONE (e4f1ed4b) — 7/7 new tests green, 11/11 total (incl. 4
  pre-existing), all 3 variants compile. Lives in shared
  src/product/kotlin, not src/tv/kotlin — see plan's corrected AD-P2B.4.
- **Tier:** implement
- **Verification:** `./gradlew :app:testDebugUnitTest` — real automated
  coverage, no device needed for this task
- **Dependencies:** None to start (fake transport); Task 1 if DoH
  transport ends up OkHttp-backed

## Task 3: Connection pool config + custom DataSource.Factory
- [x] DONE (16bd6353) — 5/5 new tests green (real loopback sockets, real
  DNS delegation), 16/16 total under tv variant. Default/coins compile
  clean, never see OkHttp or the new test file. SSLSocket tuning noted
  as a documented follow-up (plain-socket TCP_NODELAY/SO_RCVBUF only).
- **Tier:** implement + chief-performance-officer review
- **Verification:** JVM tests for config/delegation logic + **device
  issue for real pooling behavior** (don't open a new one, extend #1574
  or file alongside it)
- **Dependencies:** Task 1 (confirmed), Task 2

## Task 4: Pre-warming hook + wire into SurfaceViewFactory
- [x] DONE (eec2b785) — AiroStreamingEngine (real): system resolver +
  Cloudflare DoH JSON transport + pooled OkHttpClient + DataSource.Factory,
  wired into ExoPlayer replacing the stock default. preWarm(hosts) shares
  the same client as playback. Stub mirrors API. Dart preWarm() added,
  4/4 new tests green, 13/13 total in the package. All 3 Gradle variants
  compile clean, zero warnings on new code.
- **Tier:** implement
- **Verification:** 3-variant Gradle compile + **device re-verification
  that the Wave A test stream still plays through the new DataSource**
- **Dependencies:** Task 3

## Checkpoint: Wave B — code-complete, device verification outstanding
- [x] Tasks 1–4 done. JVM tests: 16/16 green under the tv variant
  (11 from Task 2/pre-existing + 5 from Task 3). Dart: 13/13 green.
  All 3 Gradle variants (default, tv, coins) compile clean throughout.
- [ ] Device-verification GH issue extended (#1574) — real DoH/socket
  behavior and the custom-DataSource playback path still need the
  physical rig, same as Wave A
- [ ] Human review of new dependency (OkHttp) + hot-path Kotlin
- [ ] Only then: plan Wave C (first pro-gated wave — packages_pro/pro_streaming_engine)
