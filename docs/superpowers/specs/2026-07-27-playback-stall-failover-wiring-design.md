# Wire stall detection into the existing multi-source failover controller

Date: 2026-07-27
Status: Approved

## Context

Original ask: reduce pixelation/freezing on poor network connections
(lower resolution, bigger buffer, hardware decode, network tuning). A
`playback-architect` discovery pass found the real state of the codebase:

1. No native ExoPlayer/ Media3 `LoadControl` tuning exists anywhere — the
   TV app runs the stock `video_player` plugin's internal defaults, and
   `StreamingConfig.targetBufferDuration`/`minBufferDuration`
   (`platform_player/lib/src/services/iptv_streaming_service.dart:65-111`)
   never reach the native player; `targetBufferDuration` is display-only.
2. No real adaptive bitrate. `VideoPlayerAiroPlaybackEngine.selectQuality()`
   unconditionally fails; the "quality selector" does a full reload to a
   different manual URL from `channel.qualityUrls`, not in-stream ABR.
3. Hardware decoding is hardcoded `true` in diagnostics, not a real
   toggle/decision.
4. `StreamingConfig.retryDelay` is defined but never read; retry is
   manual-only (user taps "Try Again").
5. No buffer/quality settings screen exists.
6. **`AiroMultiSourceFailoverController`
   (`platform_player/lib/src/models/multi_source_failover_models.dart:226`)
   is fully implemented and tested, and is already wired for open-time
   playback errors (`video_player_streaming_service.dart:264-278`,
   `recordPlaybackError`). Its stall-triggered path
   (`recordBuffering`/`shouldFailoverForStall`, 4s threshold via
   `AiroFailoverPolicy.stallThreshold`) is never called anywhere.** The
   live buffer-monitor timer (`_startBufferMonitoring`,
   `video_player_streaming_service.dart:398-429`) only updates a
   display-only `bufferHealth` percentage every second; it never reports
   sustained buffering to the failover controller.

Items 1-5 need native platform-channel work, an engine change, or new UI
— out of scope for this pass (see "Out of scope"). Item 6 is a pure
wiring job: closing a real gap using infrastructure that already exists,
is already tested, and is already surfaced in the UI (the failover toast)
for the sibling open-time-error path. That's this spec's entire scope.

## The gap in concrete terms

Today: a channel is playing, the network degrades, the buffer drains,
`isBuffering` goes true. The buffer monitor keeps ticking `bufferHealth`
toward 0 forever. Nothing else happens. If the stream never recovers, the
user watches a frozen/buffering screen indefinitely with no automatic
recovery, even though the channel may have other quality-URL sources that
`AiroMultiSourceFailoverController` already knows about and could switch
to — the exact mechanism that already fires correctly when the *initial*
open fails.

## Design

All changes in `packages/platform_media/lib/src/video_player_streaming_service.dart`.

1. New instance fields: `DateTime? _bufferingSince` and
   `bool _isHandlingStall = false` (mirrors the existing `_isHandlingError`
   reentrancy guard).
2. `_startBufferMonitoring()` resets `_bufferingSince = null` when
   (re)started (a fresh monitor means a fresh episode — e.g. after a
   successful failover switch, per point 4 below).
3. Inside the existing 1s timer callback, after computing `isBuffering`:
   - If `isBuffering` and `_bufferingSince == null` → set
     `_bufferingSince = DateTime.now()`.
   - If `!isBuffering` → clear `_bufferingSince = null` (buffering
     recovered on its own; no failover needed).
   - If `isBuffering`, `_bufferingSince != null`, and not already
     `_isHandlingStall` → call
     `_failoverController?.recordBuffering(sourceId: currentSourceId,
     duration: DateTime.now().difference(_bufferingSince!))`.
     `shouldFailoverForStall`'s existing 4s-threshold check inside the
     controller means most ticks return `ignored` (a no-op) until the
     threshold is actually crossed — no new threshold logic needed here.
4. On a `switched` decision: set `_isHandlingStall = true`, stop the
   current engine, and call the existing
   `_playChannel(channel, preserveFailover: true, resetRetryCount: false)`
   — the exact call shape the open-time-error path already uses to open
   the controller's `nextSource`. This naturally populates the same
   `failover` state field the UI's `PlayerOverlay._buildFailoverToast`
   already renders for the sibling path — no new UI. Reset
   `_isHandlingStall = false` once `_playChannel` returns (success or
   failure both restart/replace the buffer monitor, so stale state can't
   leak into the next episode).
5. On an `exhausted` decision: call the existing `_handleError(...)` —
   the same terminal path open-time failures already use, including its
   existing retry-count/max-retries and terminal-message behavior.
6. On `ignored` (below threshold): no-op, as today.

## What this does not do

- Does not change the 4s `stallThreshold` — that's `AiroFailoverPolicy`'s
  existing, already-reviewed default.
- Does not add a new UI surface — reuses the failover toast the
  open-time-error path already drives.
- Does not touch buffer *sizing*, bitrate selection, or hardware decoding
  — those require native platform-channel work or an engine change,
  neither of which fits a same-day wiring fix.

## Testing

- Unit test on `VideoPlayerStreamingService` (or its existing test
  harness) with a fake engine that reports `bufferedRanges` producing
  `isBuffering: true` for a controlled duration: assert
  `recordBuffering` fires only after crossing 4s, assert a `switched`
  decision re-opens the next source (spy on `_engine.open` calls or
  observe `_state.currentChannel`'s source), assert an `exhausted`
  decision reaches `PlaybackState.error`.
- Regression: a transient stall that recovers before 4s must not trigger
  any failover call sequence beyond the `ignored`/ no-op ticks.
- Existing failover and buffer-monitor tests must continue to pass
  unmodified in behavior for the open-time-error path.

## Review requirements (per this repo's Decision Matrix)

Changes `platform_media`'s failover trigger conditions — flagged for
Media Intelligence Architect, Platform Architect, and Chief QA Officer
review before merge, in addition to Playback Architect (package owner).

## Out of scope

- Native buffer-size (`LoadControl`) tuning.
- Real adaptive bitrate / in-stream track switching.
- Hardware-decoding toggle.
- `StreamingConfig.retryDelay` wiring (separate, unrelated dead field).
- Any buffer/quality settings UI.

These remain real, evidenced gaps for a future, larger pass — the
playback-architect's original discovery report is preserved in this
session's history for whoever picks that up next.
