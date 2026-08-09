# Frame-Accurate Splice-on-Keyframe: Task List

Plan: `tasks/tv-zero-copy-cast-splice-plan.md` · Spec: `SPEC.md` (F4.4.5/F4.4.6)
Follows Wave C Task 1 (`switchSource` v1 basic-swap, device-verified).

## Task 0: Fallback path + splice outcome reporting
- [x] Done — commit `a4012acd`. `AiroSpliceMode`/`AiroSplicePointFinder`/
  `AiroSpliceDecision.decide()` in shared `src/product/kotlin`
  (AD-P2B.4, zero Media3 dep). 5/5 new JVM tests + full suite 25/25
  green. All 3 Gradle variants (default/tv/coins) verified clean. NOT
  yet wired into live `switchSource` — waits on Task 1/2 or 4/5 for a
  real finder.
- **Tier:** implement
- **Verification:** JVM tests (fakeable deadline/clock) + device check
  that fallback is reachable
- **Dependencies:** None

## Task 1: HLS segment-boundary detection
- [~] Implemented, commit `0a4727ff` — `AiroSegmentBoundaryTracker`
  (pure, product/kotlin, 5/5 JVM tests) wired via
  `Player.addAnalyticsListener` in `AiroStreamingSurfaceViewFactory`;
  `AiroStreamingEngine.msUntilNextHlsBoundary()` exposed for Task 2.
  All 3 Gradle variants compile clean. **Not yet device-verified** —
  boundary-tracked logs haven't been watched against real bipbop HLS
  playback on Pixel 9. That's the remaining acceptance criterion before
  this checks off.
- **Tier:** implement
- **Verification:** Device-verified (real HLS loading timing)
- **Dependencies:** None (parallel-safe with Task 0)

## Task 2: HLS splice execution at segment boundary
- [ ] Not started
- **Tier:** implement
- **Verification:** Device-verified, F4.4.6 "no visible interruption"
  checked by eye on Pixel 9
- **Dependencies:** Task 0, Task 1

## Checkpoint: HLS splice complete
- [ ] Device-verified clean, no visible glitch
- [ ] Human review + decide whether to proceed to TS now

## Task 3: Raw MPEG-TS test asset
- [ ] Not started — mostly research, find/produce a public raw .ts URL
- **Tier:** architect/research
- **Dependencies:** None (parallel-safe with Tasks 0-2)

## Task 4: PAT/PMT/IDR parser (pure Kotlin, JVM-tested)
- [ ] Not started — **flagged as likely the hardest task in this plan**,
  break down further once started if needed
- **Tier:** implement
- **Verification:** JVM tests against TS byte fixtures
- **Dependencies:** Task 3 (for real fixture data)

## Task 5: TS splice execution
- [ ] Not started
- **Tier:** implement
- **Verification:** Device-verified against Task 3's TS asset
- **Dependencies:** Task 0, Task 3, Task 4

## Checkpoint: Splice-on-keyframe complete
- [ ] Both HLS and TS paths device-verified
- [ ] chief-performance-officer review (byte-level parsing on hot path)
- [ ] Method-channel + Dart contract updated for the new outcome shape
