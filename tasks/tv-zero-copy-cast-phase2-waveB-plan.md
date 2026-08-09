# Implementation Plan: Phase 2 Wave B — DNS Resolver Cache + Connection Pool

Spec: `SPEC.md` (this branch). Requirements: F4.1 (DNS resolution), F4.2
(connection management). Follows Wave A (native bridge proof, code-complete,
device verification tracked in
[#1574](https://github.com/DevelopersCoffee/airo/issues/1574)).

**Public/free-tier, confirmed against SPEC's package table** — DNS caching
and connection pooling are core-engine baseline reliability, not the
per-network *learned ranking* or *shadow failover* that's pro (those are
Wave C, F4.3/F4.4). Nothing here touches `packages_pro/` or the `airo-pro`
repo.

## Overview

Wave A proved the native bridge (Flutter → PlatformView → Media3 →
Surface) with a stock, unmodified `DataSource`. Wave B replaces that stock
data path with the actual reliability engine: a resolver cache that races
the system resolver against DoH and pins the winning IP for the session
(F4.1), and a pre-warmed, tuned connection pool (F4.2) — then wires both
into a custom `DataSource` Media3 actually uses for playback.

## Investigation findings

- **This wave is far more JVM-unit-testable than Wave A.** The resolver
  cache and connection-pool *policy* (TTL bookkeeping, DoH-vs-system race
  logic, pre-warm scheduling) are pure logic with no Android framework
  dependency — they can live in plain Kotlin classes under
  `app/android/app/src/tv/kotlin` and get real `./gradlew
  :app:testDebugUnitTest` coverage, no device needed. Confirmed a working
  JVM-test precedent already exists in this repo:
  `app/android/app/src/test/kotlin/io/airo/app/MediaAnalysisJobTest.kt`
  (JUnit 4, already a dependency — `testImplementation("junit:junit:4.13.2")`
  in `build.gradle.kts`). Only the actual socket/DNS *I/O* and the
  integration into Media3 playback need a device.
- **No HTTP client exists yet in the Android project.** Checked — no
  `okhttp` anywhere in `app/android/app/build.gradle.kts` or any package
  pubspec. Hand-rolling connection pooling, keepalive, and DNS override
  on raw sockets is a lot of surface area to get right (and to review) for
  a Wave B slice; OkHttp already solves pooling/keepalive/`TCP_NODELAY`
  correctly and exposes a `okhttp3.Dns` interface built exactly for
  swapping in a custom resolver. Media3 ships an official
  `androidx.media3:media3-datasource-okhttp` adapter, so a custom
  `DataSource` becomes "configure OkHttp correctly" rather than
  "reimplement HTTP." This is a **new dependency proposal** (Task 1 below,
  same approval gate as Wave A's Media3 proposal) — not assumed pre-approved.

## Architecture Decisions

- **AD-P2B.1 — OkHttp + `media3-datasource-okhttp`, proposed not assumed.**
  Task 1 stops for explicit confirmation before any `build.gradle.kts`
  edit, mirroring Wave A's AD-P2.4/Task 3 pattern exactly.
- **AD-P2B.2 — Resolver cache and connection-pool config are pure Kotlin,
  JVM-tested; only the OkHttp `Dns`/`DataSource` wiring is
  device-verified.** Vertical slice again: prove the pure logic
  exhaustively in JVM tests first (fast, no device, real CI value), then
  wire the thin I/O layer on top.
- **AD-P2B.3 — IP pinning is a hard invariant, not a preference.** Per
  F4.1.4 ("resolved IP pinned for session — no mid-stream re-resolution
  under any condition"), the resolver cache's public contract must make
  it structurally impossible to re-resolve mid-session, not just
  "unlikely" — e.g. a session object that captures the resolved address
  once and exposes no re-resolve path, rather than a cache with a TTL
  that could silently expire under a long-lived connection.
- **AD-P2B.4 — CORRECTED after Task 2: source placement follows
  dependencies, not "Wave B-ness."** Originally assumed every new class
  goes in `src/tv/kotlin`. Task 2 showed that's wrong for anything a JVM
  unit test needs to reference: test files live in the always-compiled
  `src/test/kotlin`, so a class under test must be visible on *every*
  variant's unit-test compilation, not just tv's. The real rule: a class
  goes in `src/tv/kotlin` only once it actually imports something
  variant-gated (Media3, and once confirmed, OkHttp); pure logic with no
  such dependency belongs in the shared `src/product/kotlin` (same home
  as `MainActivity`, compiled for every variant except Coins) so it can
  be unit-tested without a tv-flavored compile. `AiroResolverCache`
  lives there. The real/stub split from Wave A remains correct for
  classes MainActivity references directly by name across variants
  (`AiroStreamingSurfaceViewFactory`); it was never needed for internal
  logic that doesn't touch a variant-gated dependency.

## Task List

### Task 1: Propose OkHttp + media3-datasource-okhttp — approval checkpoint, no code
**Tier:** architect (proposal only), mirrors Wave A Task 3.
**Acceptance:** exact versions, license, size estimate, minSdk compat
documented; user confirms before Task 3 touches `build.gradle.kts`.
**Dependencies:** None.
**Estimated scope:** XS.

### Task 2: Resolver cache — pure Kotlin, JVM-tested — DONE (e4f1ed4b)
7/7 new tests green + 4 pre-existing app-module unit tests still green
(11/11 total). All 3 Gradle variants compile clean. See AD-P2B.4 above
for the source-placement correction this task surfaced.
**Tier:** implement.
**Description:** `AiroResolverCache` (or similar): given a hostname,
races system `InetAddress.getAllByName` against a DoH HTTPS query
(Cloudflare/Google, per F4.1.2), 3s hard timeout, first valid answer
wins; falls back to system resolver if DoH is blocked (F4.1.6, "never
fail closed"); 10-minute in-memory TTL surviving foreground/background
(F4.1.1). DoH transport itself can be abstracted behind an interface so
the race/timeout/fallback *logic* is fully testable with fake resolvers
— no real network or device needed for this task's tests.
**Acceptance criteria:**
- [ ] Race picks whichever source answers first; loser is cancelled/ignored
- [ ] DoH timeout (3s) falls back to system resolver result if it already
      arrived, or fails closed→open (system-only) if DoH never answers
- [ ] Cache hit within TTL skips the race entirely
- [ ] TTL expiry triggers a fresh race, not a stale answer
**Verification:** `./gradlew :app:testDebugUnitTest --tests
"*AiroResolverCache*"` — real JVM tests, no device.
**Dependencies:** Task 1 (confirmed) if DoH transport is implemented via
OkHttp; otherwise none (could use `java.net.http.HttpClient` instead —
decide in-task, doesn't block starting the pure race/cache logic against
a fake transport).
**Files:** `app/android/app/src/tv/kotlin/io/airo/app/AiroResolverCache.kt`
(new), `app/android/app/src/test/kotlin/io/airo/app/AiroResolverCacheTest.kt` (new).
**Estimated scope:** M.

### Task 3: Connection pool config + custom DataSource.Factory
**Tier:** implement + chief-performance-officer review (hot-path Kotlin,
per SPEC's routing rule 2).
**Description:** `OkHttpClient` configured per F4.2: up to 6 connections
per host, 45s idle timeout, `TCP_NODELAY`, raised `SO_RCVBUF`, 3s connect
/ 8s read timeout, custom `okhttp3.Dns` backed by Task 2's resolver
cache. Wrap in `androidx.media3.datasource.okhttp.OkHttpDataSource
.Factory` — this is the actual `DataSource` Media3 will use, replacing
Wave A's stock default.
**Acceptance criteria:**
- [ ] Pool config matches F4.2.1/F4.2.4/F4.2.5 values exactly
- [ ] Custom `Dns` delegates to `AiroResolverCache`, never calls
      `InetAddress.getAllByName` directly (that's Task 2's job, not
      duplicated here)
- [ ] Once a session's `DataSource` is opened, its pinned IP is used for
      the life of that session even if the cache's TTL expires
      mid-session (AD-P2B.3 — verify this doesn't silently re-resolve)
**Verification:** JVM tests for pool-config construction and `Dns`
delegation (fakeable); **device verification for actual keepalive/pooling
behavior under real network conditions is a separate GH issue**, matching
Wave A's pattern — pool behavior under real packet loss/latency can't be
proven by a unit test.
**Dependencies:** Task 1 (confirmed), Task 2.
**Files:** `app/android/app/src/tv/kotlin/io/airo/app/AiroConnectionPool.kt`
(new), `app/android/app/src/tv/kotlin/io/airo/app/AiroCustomDataSource.kt`
(new — or extends `OkHttpDataSource` directly if no extra logic needed).
**Estimated scope:** M.

### Task 4: Pre-warming hook + wire into Wave A's SurfaceViewFactory
**Tier:** implement.
**Description:** Expose a `preWarm(hosts: List<String>)` entry point
(F4.2.2 — "while the user browses the channel grid") on the connection
pool, callable from the method channel (extends `AiroStreamingEnginePlugin`
with a `preWarm` method). Replace Wave A's `ExoPlayer.Builder(context)
.build()` stock construction with one that supplies Task 3's custom
`DataSource.Factory` via `DefaultMediaSourceFactory`.
**Acceptance criteria:**
- [ ] `preWarm` method channel call resolves without error (JVM/unit
      testable at the method-routing level; actual TCP+TLS warm-up
      requires network/device)
- [ ] `AiroStreamingSurfaceViewFactory`'s player now goes through the
      custom `DataSource`, not the Media3 default
- [ ] Wave A's existing bipbop test-stream playback still works through
      the new path (regression check, device-verified)
**Verification:** Gradle compile (all 3 variants, same discipline as
Wave A); **device re-verification that the test stream still plays** is
required before closing this out — file as part of the same device
issue Wave A already has, don't open a duplicate.
**Dependencies:** Task 3.
**Files:** `app/android/app/src/tv/kotlin/io/airo/app/AiroStreamingSurfaceViewFactory.kt`,
`AiroStreamingEnginePlugin.kt`, Dart method-channel wrapper in
`platform_streaming_engine`.
**Estimated scope:** M.

## Checkpoint: Wave B complete
- [ ] Tasks 1–4 done; JVM unit tests green (`./gradlew :app:testDebugUnitTest`)
- [ ] All 3 Gradle variants (default, tv, coins) compile clean, same
      three-variant discipline as Wave A — not just the tv variant
- [ ] GH issue filed (or Wave A's #1574 extended) for device verification
      of: custom DataSource playback, pre-warming's real network effect,
      pool behavior under real conditions
- [ ] Human review of the new dependency + hot-path Kotlin
- [ ] Only then: plan Wave C (source ranking + shadow failover — **first
      pro-gated wave**, packages_pro/pro_streaming_engine)

## Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| OkHttp adds APK size on top of Media3's already-uncertain footprint | Med | Task 1's proposal states size honestly (same discipline as Wave A's Media3 proposal); measure after, don't guess before |
| DoH endpoint (Cloudflare/Google) blocked on some networks | Med | F4.1.6 requirement already covers this — fall back to system resolver, never fail closed; Task 2's tests must cover this path explicitly |
| Custom `Dns` interacting badly with OkHttp's own connection reuse across different resolved IPs for the same host | Med | AD-P2B.3's pinning invariant is exactly the guard here — one `DataSource` instance, one resolved IP, no silent re-resolution |
| Pure-Kotlin JVM tests give false confidence that real-network behavior works | Low | Explicitly separated in the plan: JVM tests prove logic, device issue proves the real thing — never conflate the two when reporting a task done |

## Open Questions

- **P2B-1:** DoH transport — plain `HttpsURLConnection`/`java.net.http`
  vs. reusing the same OkHttp client once Task 1 is confirmed (simpler,
  one HTTP stack instead of two). Lean toward OkHttp-for-DoH-too once
  Task 1 lands, but Task 2's pure race/cache logic doesn't need to wait
  for that decision — it's built against a fake transport interface either way.
- **P2B-2:** Where does `preWarm` get called from on the Dart side —
  channel-grid scroll, playlist load, or both? Not specified yet in this
  repo's IPTV UI; defer to whoever picks up Task 4, needs a quick look at
  `feature_iptv`'s channel grid widget.
