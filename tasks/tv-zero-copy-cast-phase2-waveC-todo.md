# Phase 2 Wave C — Source Ranking + Shadow Failover: Task List

Plan: `tasks/tv-zero-copy-cast-phase2-waveC-plan.md` · Spec: `SPEC.md`
**First pro-gated wave.** Task 1 is public repo; Tasks 2-3 are pro repo
(`airo-pro/packages_pro/pro_streaming_engine`).

## Task 0: Confirm AD-P2C.1 (architecture) + entitlement-check timing
- [x] DONE — user confirmed: mechanism stays public (existing
  AiroStreamingEnginePlugin), decision logic is pro Dart; receiver-side
  entitlement re-validation deferred to Phase 4 (cast's real sender/
  receiver split), Dart-level gating only for now.

## Task 1 (public repo): Shadow-fetch + splice mechanism
- [x] DONE (9c37d0f0) — `AiroShadowFetch.probe` (F4.3.2/F4.4.3, real
  local-server tests via mockwebserver3), `AiroShadowFetchLimiter`
  (F4.4.8's 1-concurrent-shadow cap), `AiroStreamingEngine.switchSource`
  (**v1 basic swap only — not yet frame-accurate splice-on-keyframe,
  F4.4.5/F4.4.6 not yet met, tracked gap**). Method-channel commands
  `shadowFetch`/`switchSource` wired through `AiroStreamingEnginePlugin`.
  Dart: `AiroShadowFetchOutcome` + `shadowFetch()`/`switchSource()` on
  `AiroStreamingEngineChannel`. 20/20 JVM tests green (tv variant), 20/20
  Dart tests green, all 3 Gradle variants compile clean.
- **Tier:** implement + chief-performance-officer review (hot-path Kotlin)
- **Verification:** JVM tests (done) + **device-verified on Pixel 9
  (f42667c2)**: video plays, `shadowFetch` measures real throughput
  (1107.6 kbps). Two real bugs found and fixed in the process — see below.
- **Dependencies:** Wave B (confirmed on this branch)

### Device verification pass (f42667c2) — 2 real bugs found and fixed
Neither was catchable by unit tests or Gradle compile:
1. **ExoPlayer init-order NullPointerException** — `Player.Listener`
   referenced the outer `player` property before it finished being
   assigned (ExoPlayer's `addListener()` can fire a synchronous initial
   callback mid-construction). Fixed by tracking phase state as local
   fields instead. Verified: `onRenderedFirstFrame` → `onPlaybackStateChanged:
   READY` logged, video renders, played stably 17+ seconds.
2. **shadowFetch `NetworkOnMainThreadException`** — the method-channel
   handler called the blocking OkHttp probe synchronously from the main
   thread (`preWarm` already backgrounded correctly; `shadowFetch` hadn't).
   First appeared as a misleading `SSLHandshakeException` (TLS never got a
   chance to run before the thread violation). Fixed by backgrounding the
   call and posting `MethodChannel.Result` back via
   `Handler(Looper.getMainLooper())`. Verified: real measured throughput.

Also fixed a pre-existing flaky JVM test found during re-verification
(`AiroResolverCacheTest` — asserted on the losing race resolver's call
count with no synchronization guarantee it had run yet).

GH issue #1574 updated with full evidence. **All four controls now
verified** (ping/preWarm/shadowFetch/switchSource all `ok`/`measured`),
video ran stably 00:00:02→00:00:39+ in one continuous session.
**Not yet exercised:** Fire TV Stick (only Pixel 9 tested).

## Task 1-follow-up (not yet scheduled): Frame-accurate splice-on-keyframe
Real PAT/PMT + IDR boundary detection for TS (F4.4.5), next-segment
boundary for HLS, the spec's own top risk item. `switchSource`'s current
v1 basic-swap does not satisfy F4.4.5/F4.4.6. Needs its own task
breakdown when picked up — likely large enough to be its own mini-plan
(binary TS parsing, IDR frame detection, precise ExoPlayer seek/splice
timing), not a same-size task as the rest of Wave C.

## Task 2 (pro repo): Source scorer (F4.3)
- [ ] BLOCKED on P2C-2 — `airo-pro-worktrees/tv-zero-copy-cast` has not
  synced this branch (syncs from upstream GitHub, not local branches);
  starting pro Dart work now would build against code that doesn't
  durably exist in that repo yet. Needs a process decision: push+merge
  this branch first, or accept a temporary local path-override dependency
  for development purposes only.
- **Tier:** implement (pure Dart, no native dependency)
- **Dependencies:** None technically (parallel-safe with Task 1), but
  practically blocked per above

## Task 3 (pro repo): Failover decision state machine (F4.4) + ProModule wiring
- [ ] BLOCKED — same as Task 2 (P2C-2), plus depends on Task 2
- **Tier:** implement
- **Dependencies:** Task 1 (done), Task 2 (blocked)

## Checkpoint: Wave C
- [x] Public Task 1 code-complete, JVM-tested, all variants compile
- [ ] Public Task 1 device-verified (extend #1574 once splice work matures)
- [ ] P2C-2 resolved (push/merge decision) before Tasks 2-3 can start
- [ ] Pro Tasks 2-3 fully unit-tested
- [ ] Free tier confirmed to never invoke shadow-fetch/switch
- [ ] chief-architect + chief-security-officer review (open-core boundary,
      P2C-1 revisited at Phase 4)
