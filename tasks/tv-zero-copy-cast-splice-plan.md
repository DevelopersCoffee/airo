# Implementation Plan: Frame-Accurate Splice-on-Keyframe (F4.4.5/F4.4.6)

Spec: `docs/specs/tv-zero-copy-cast.md`. Requirements: F4.4.5 (splice on PAT/PMT+IDR for TS, next
segment for HLS), F4.4.6 (completes within 4s, no visible interruption).
Follows Wave C Task 1 (shadow-fetch + v1 basic-swap `switchSource`,
device-verified on Pixel 9, commits `9c37d0f0`/`f42667c2`).

**This is the requirements doc's own top risk item** (§9 Risks table:
"TS splicing produces visible artifacts on some encoders... High impact").
Scoped and planned accordingly — research-first, HLS before TS, explicit
fallback path from the start rather than bolted on later.

## What's already true (from Wave C Task 1)

`AiroStreamingEngine.switchSource(url)` does an immediate `setMediaItem` +
`seekTo(currentPosition)` + `prepare()`. This is a **basic swap**, not a
splice: it doesn't wait for any boundary, doesn't inspect the outgoing or
incoming stream, and can produce a visible glitch or brief black frame.
Device-verified to *work* (returns `ok: true`, doesn't crash) but never
claimed to meet F4.4.6's "no visible interruption" bar — that gap is
exactly what this plan closes.

## Investigation findings

- **HLS and TS need genuinely different mechanisms — this is two features
  wearing one spec line, not one.** Confirmed via Media3 source research:
  `ConcatenatingMediaSource`/`ConcatenatingMediaSource2` give gapless
  transitions *between playlist items* (current item ends, next begins) —
  useful pattern, but doesn't let you splice into the *middle* of a
  currently-playing item at an arbitrary point. That's fine for HLS
  (segments are boundary-aligned by spec — every HLS segment starts on a
  keyframe, so "switch at next segment boundary" *is* "switch on
  keyframe," for free, once we detect the boundary). It doesn't help TS
  at all: a raw MPEG-TS stream has no segment structure, so detecting a
  valid splice point requires actually parsing the transport stream
  (PAT to find the PMT's PID, PMT to find the video stream's PID, then
  scanning that PID's payload for the next IDR/keyframe NAL unit).
  [ExoPlayer 2 — MediaSource composition](https://medium.com/google-exoplayer/exoplayer-2-x-mediasource-composition-6c285fcbca1f),
  [Media sources — Android Developers](https://developer.android.com/media/media3/exoplayer/media-sources)
- **No existing TS-parsing precedent in this repo.** Media3's own
  internal `TsExtractor` does exactly this parsing already (it has to, to
  demux TS for playback at all) but doesn't expose PAT/PMT/IDR boundaries
  through any public API — there's no hook to ask "where's the next
  splice-safe point." A splice detector has to be a second, independent
  pass over the same bytes (or a byte-level tee), not a reuse of
  ExoPlayer's internal extractor state.
- **The current bipbop test asset is HLS only.** Task 4/5's device
  verification (video plays, `switchSource` works) all ran against HLS.
  There is no raw-TS test URL wired up anywhere yet — needed before Task
  3/4 below can be device-verified at all.

## Architecture Decisions

- **AD-Splice.1 — HLS first, TS second, explicit fallback from day one.**
  HLS is meaningfully more tractable (boundary detection only, no binary
  parsing) and already has test infrastructure. Build and device-verify
  HLS's segment-boundary switch before starting TS's parser. The spec's
  own fallback ("200ms mute-and-cut if a clean splice point isn't found
  within 3s") is Task 0's acceptance criterion, not an afterthought —
  every subsequent task must degrade to it, never to a crash or an
  indefinite hang.
- **AD-Splice.2 — TS PAT/PMT/IDR detection is pure Kotlin, JVM-testable
  against byte fixtures.** Same principle as Wave B's resolver
  cache/connection pool: the *parsing logic* has zero Android/Media3
  dependency and can be proven correct with synthetic or captured TS
  byte sequences in a JVM unit test, before any device involvement. Only
  the actual splice *execution* (feeding the detected boundary into
  ExoPlayer's pipeline) needs a device.
- **AD-Splice.3 — Don't reuse `AiroStreamingEngine.switchSource`'s
  signature blindly.** The current `switchSource(url): Boolean` is a
  yes/no result. A real splice needs to report *how* it completed
  (spliced cleanly / fell back to mute-and-cut / failed entirely) so
  Wave C's future failover decision logic (Tasks 2-3, still blocked on
  P2C-2) can log F4.4.6 compliance rather than just "it didn't crash."

## Task List

### Task 0: Fallback path + splice outcome reporting (foundation, do this first)
**Description:** Extend the `switchSource` mechanism with a 3s deadline
and the spec's own fallback: if no clean splice point is found in time,
do a short 200ms mute-and-cut rather than hang or glitch indefinitely.
Change the return shape from `Boolean` to an outcome type (spliced /
fellBackToMuteCut / failed) mirroring `AiroShadowFetchResult`'s sealed-class
pattern from Wave C Task 1.
**Acceptance criteria:**
- [ ] A splice attempt that can't find a boundary within 3s falls back to
      mute-and-cut, never hangs
- [ ] Outcome type distinguishes clean splice / fallback / failure
- [ ] Existing HLS basic-swap behavior still works through the new
      outcome-reporting shape (regression-safe)
**Verification:** JVM tests for the deadline/fallback timing logic
(fakeable clock, same pattern as `AiroResolverCache`); device
verification that the fallback path is reachable and doesn't hang.
**Dependencies:** None.
**Estimated scope:** S-M.

### Task 1: HLS segment-boundary detection
**Description:** Detect the boundary of the *currently loading* HLS
segment via Media3's `AnalyticsListener` (`onLoadCompleted`/
`onDownstreamFormatChanged` give segment-level timing) rather than
guessing. Expose "time until next segment boundary" so Task 2 can time
the actual swap.
**Acceptance criteria:**
- [ ] Correctly identifies segment boundaries on the real bipbop test
      stream (device-verified against logged boundary timestamps)
- [ ] Works whether called during steady-state playback or immediately
      after `prepare()`
**Verification:** Device-verified (this is fundamentally about real HLS
loading timing, not something a JVM fake can prove).
**Dependencies:** None (parallel-safe with Task 0).
**Estimated scope:** M.

### Task 2: HLS splice execution at segment boundary
**Description:** Wire Task 1's boundary detection into
`switchSource`: defer the `setMediaItem`/`seekTo` swap until the next
detected boundary (bounded by Task 0's 3s deadline/fallback), instead of
swapping immediately.
**Acceptance criteria:**
- [ ] `switchSource` on an HLS stream now waits for the boundary (visible
      in timing logs) before swapping, not immediate
- [ ] F4.4.6 "no visible interruption" — verified by eye on a real
      device, not just by absence of a crash (this is the actual bar the
      v1 basic-swap never met)
**Verification:** Device-verified on Pixel 9, screen-recorded or
carefully observed frame-by-frame if a glitch is suspected.
**Dependencies:** Task 0, Task 1.
**Estimated scope:** M.

### Checkpoint: HLS splice complete
- [ ] Device-verified: switching sources on the bipbop HLS stream shows
      no visible glitch, completes within F4.4.6's implied budget
- [ ] Human review before starting the harder TS work
- [ ] Decide whether TS parsing (Tasks 3-5) is worth doing now or
      deferred — most community IPTV is TS per the requirements doc, so
      this isn't optional long-term, but it's a genuinely separate,
      larger effort than the HLS half just completed

### Task 3: Raw MPEG-TS test asset
**Description:** Source or produce a public, stable raw `.ts` stream URL
(not HLS) to test against — currently nothing in this repo's test
infrastructure uses one. Without this, Tasks 4-5 can't be device-verified
at all.
**Acceptance criteria:** A URL confirmed reachable and playable through
the existing `AiroStreamingEngine` pipeline (proves the pipeline handles
raw TS at all, independent of splicing).
**Dependencies:** None (parallel-safe with Tasks 0-2).
**Estimated scope:** XS-S (mostly research, not code).

### Task 4: PAT/PMT/IDR parser — pure Kotlin, JVM-tested
**Description:** Given a stream of TS packets (188 bytes each, sync byte
`0x47`), parse the PAT to find the PMT's PID, parse the PMT to find the
video elementary stream's PID, then scan that PID's payload for the next
IDR/keyframe NAL unit (H.264: NAL unit type 5). Report the byte offset or
packet index of the next valid splice point.
**Acceptance criteria:**
- [ ] Correctly parses PAT → PMT → video PID chain against known-good
      byte fixtures
- [ ] Correctly identifies IDR frame boundaries in H.264 payload
- [ ] Handles malformed/incomplete TS gracefully (never throws on bad
      input — this parses untrusted network data)
**Verification:** JVM unit tests against captured/synthetic TS byte
fixtures (need real TS samples from Task 3's source, or a hand-built
synthetic fixture with known PAT/PMT/IDR structure) — genuinely testable
without a device, same as Wave B's resolver cache.
**Dependencies:** Task 3 (for real fixture data — synthetic fixtures could
start sooner but should be validated against real captured bytes before
trusting this parser on live streams).
**Estimated scope:** L — likely the single hardest task in this plan;
break down further once started if the parsing logic proves more
involved than expected (very possible — TS/H.264 parsing has a lot of
edge cases: PES packet boundaries, PID discontinuities, encrypted
streams which can't be parsed this way at all and must fall back
immediately).

### Task 5: TS splice execution
**Description:** Wire Task 4's parser into `switchSource` for raw-TS
sources, mirroring Task 2's shape for HLS: defer the swap until the
parser reports a valid IDR boundary, bounded by Task 0's fallback.
**Acceptance criteria:** Same bar as Task 2 (F4.4.6, device-verified, no
visible interruption) but for TS.
**Verification:** Device-verified against Task 3's TS test asset.
**Dependencies:** Task 0, Task 3, Task 4.
**Estimated scope:** M-L.

### Checkpoint: Splice-on-keyframe complete
- [ ] Both HLS and TS paths device-verified, no visible interruption
- [ ] Fallback path (Task 0) proven reachable and correct for both
- [ ] chief-performance-officer review (hot-path Kotlin, byte-level
      parsing on the playback path is exactly the kind of code that can
      silently regress frame timing)
- [ ] Update `AiroStreamingEnginePlugin`'s `switchSource` method-channel
      response shape + Dart `AiroShadowFetchOutcome`-style outcome type to
      match Task 0's new return shape (breaking change to the existing
      Wave C Task 1 contract — needs its own Dart-side test updates)

## Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| TS splicing produces visible artifacts on some encoders (spec's own top risk) | High | Task 0's fallback path is foundational, not optional; every splice attempt has a bounded, safe failure mode |
| Encrypted/DRM-protected TS streams can't be byte-parsed for PAT/PMT/IDR at all | Med | Detect and fail over to Task 0's fallback immediately rather than attempting to parse — flag as an explicit check in Task 4, not an oversight |
| PAT/PMT/IDR parser correctness is hard to fully validate without a wide range of real-world encoder outputs | Med | Task 3's real captured samples matter more than synthetic fixtures for confidence; still ship with the fallback as the safety net regardless of parser maturity |
| This plan's own task sizing may be optimistic for Task 4 specifically | Med | Flagged explicitly in Task 4's own estimate — break down further once started, don't force it into the planned shape if reality disagrees |

## Open Questions

- **Splice-1 (resolved, with a correction):**
  `https://samples.ffmpeg.org/ts/01c56b0dc1.ts` — ffmpeg's own public
  sample archive, no auth, reachable and decodes cleanly (verified via
  `curl`/`ffprobe`). Turned out during Task 4 to be MPEG-TS-over-RTP
  (12-byte RTP header + 7×188-byte TS packets repeating), not raw TS
  despite the extension/content-type — usable after stripping RTP
  framing, but its encoder never emits spec-compliant IDR NALs at all.
  Task 4's actual JVM fixture is a small locally-generated
  ffmpeg/libx264 sample instead (real encoder, genuinely spec-compliant
  IDR frames) — see Task 4's todo entry and commit `028949ec`.
- **Splice-2:** Does this work belong in the public repo (like Wave C
  Task 1's mechanism) or does F8's "shadow failover" gating mean the
  *splice execution itself* should be pro-gated too, not just the
  decision logic? AD-P2C.1 settled this for shadow-fetch/basic-swap;
  worth re-confirming it still holds once splice complexity is this much
  higher — flagging rather than assuming the earlier answer still applies
  unchanged.
