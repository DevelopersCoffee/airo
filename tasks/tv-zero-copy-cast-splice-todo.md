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
- [x] Done — commits `0a4727ff` (implementation) + `803d45cf` (device-test
  fix). Device-verified on Pixel 9 against real bipbop HLS playback: 17
  consecutive boundary logs, `mediaEndTimeMs` climbing monotonically at
  ~9.9-10s intervals (129696 → 139639 → 149649 → 159593 → 169603).
  Root cause of the initial silent failure: bipbop's single-rendition
  HLS tags segment loads `C.TRACK_TYPE_DEFAULT`, not `TRACK_TYPE_VIDEO`
  — found via unconditional diagnostic logging on-device, filter now
  accepts both. Full JVM suite green (30/30), all 3 Gradle variants
  compile clean.
- **Tier:** implement
- **Verification:** Device-verified (real HLS loading timing)
- **Dependencies:** None (parallel-safe with Task 0)

## Task 2: HLS splice execution at segment boundary
- [~] Implemented, commit `450c6fb3` — `switchSource` waits for Task 1's
  boundary via new `AiroHlsSplicePointFinder` (3/3 JVM tests) through
  Task 0's `AiroSpliceDecision`; new `AiroSpliceOutcome` enum (Dart
  contract stays bool, AD-Splice.3); thread-safe position-poll cache;
  plugin call backgrounded. Full suite green (33/33), all 3 variants
  clean. **Not yet device-verified** — F4.4.6 "no visible interruption"
  needs a real splice watched on Pixel 9. That's the remaining
  acceptance criterion.
- **Tier:** implement
- **Verification:** Device-verified, F4.4.6 "no visible interruption"
  checked by eye on Pixel 9
- **Dependencies:** Task 0, Task 1

## Checkpoint: HLS splice complete
- [ ] Device-verified clean, no visible glitch — **deferred by user
  request 2026-08-09**, Task 1's boundary detection is device-verified
  but Task 2's actual splice swap is not; picked up again later
- [ ] Human review + decide whether to proceed to TS now

## Task 3: Raw MPEG-TS test asset
- [x] Done — `https://samples.ffmpeg.org/ts/01c56b0dc1.ts` (ffmpeg's own
  public sample archive, no auth). Verified via `curl`/`ffprobe`: H.264
  video + 2x AAC + AC-3 audio + DVB subtitle, 10.7s, 11MB, HTTP range
  requests supported (`Accept-Ranges: bytes`), full file decodes
  cleanly with no errors. Real broadcast-capture TS, not synthetic —
  matches the plan's own note that real captured samples matter more
  than synthetic fixtures. Unblocks Task 4 (JVM fixture bytes can be
  extracted from this file directly, no device needed). **Not yet
  played through the app's `AiroStreamingEngine` pipeline on-device** —
  deferred along with Task 1/2's checkpoint device verification, same
  user request.
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
