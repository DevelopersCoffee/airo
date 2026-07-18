# feature_iptv → AiroPlaybackEngine Migration (Minimum Slice) — Design

**Date:** 2026-07-18
**Status:** Approved (brainstorm) → pending implementation plan
**Owner package:** `platform_media` (+ `platform_player` for the new source-handle
factory)
**Depends on:** CV-029 (`AiroPlaybackEngine` contract), CV-030 (mpv engine — not
consumed in this slice, but the same DI seam pattern is reused),
CV-016 (`externalSubtitleTracksFor`, track catalog on `AiroPlaybackState`)

## Problem

CV-016 (track catalog) and CV-031 (external subtitles) both landed at the
engine-adapter layer (`platform_media`'s `VideoPlayerAiroPlaybackEngine` and
`MpvAiroPlaybackEngine`), but neither is visible in the actual app: `feature_iptv`
— the package that owns every live-channel and VOD playback screen — never
adopted `AiroPlaybackEngine`. It runs a second, older, parallel implementation,
`VideoPlayerStreamingService` (`packages/platform_media/lib/src/video_player_streaming_service.dart`,
507 lines), which wraps `video_player`'s `VideoPlayerController` directly and
predates the CV-029 contract entirely. It has its own retry/timeout logic, its
own live-edge/DVR detector, its own buffer-health and network-quality
estimation — none of it routed through `AiroPlaybackEngine`.

Until `VideoPlayerStreamingService` is retrofitted to drive playback through an
`AiroPlaybackEngine`, CV-016's track catalog and CV-031's external-subtitle
handling have no UI surface: the data the engines can now produce never reaches
the widgets.

## Goals

- Make `AiroPlaybackState.tracks` (including CV-016's projected external
  subtitles) visible in the existing `feature_iptv` player UI.
- Let the user attach an external subtitle URL to a VOD item and select it,
  per CV-031's original acceptance criteria.
- Zero behavior change to anything not explicitly listed above: DVR, live-edge
  detection, buffer health, network-quality estimation, retry-on-timeout,
  audio-context focus, wakelock, cast — all keep working exactly as today.
- Close the `AiroPlaybackSourceHandle` gap that currently makes it impossible
  to open a real IPTV/VOD URL through any `AiroPlaybackEngine` at all.

## Non-Goals (deferred, explicitly out of scope for this slice)

- **No mpv fallback wiring.** `AiroEngineFallbackCoordinator` /
  `AiroPlaybackEngineResolver` are not consumed here. The service continues to
  construct a single `VideoPlayerAiroPlaybackEngine` directly, same as it
  constructs a single `VideoPlayerController` today. Wiring the fallback
  coordinator (so a codec failure actually falls back to mpv on
  Android-mobile/iOS/macOS) is a follow-up slice once this one is proven safe
  in production.
- **No `StreamingState` replacement.** `StreamingState`, `PlaybackState`,
  `BufferStatus`, `NetworkQuality`, `LiveStreamState` all stay exactly as they
  are today — only additive fields (`tracks`, `selectedTrackIds`). No provider
  or widget outside the two explicitly touched by this slice needs to change.
- **No live-channel subtitle-attach UI.** External-subtitle attach is VOD-only
  per CV-031's original scope; live channels only get the track-selector
  button (for embedded/external tracks already present on open).
- **No new abstraction layer / parallel adapter class.** In-place refactor of
  the existing `VideoPlayerStreamingService`, not a new class alongside it.

## What Already Exists (reuse, do not rebuild)

- `AiroPlaybackEngine` contract, `VideoPlayerAiroPlaybackEngine` concrete
  adapter (`platform_media`) — both engine methods and the parameterized
  conformance suite already pass 14/14.
- `externalSubtitleTracksFor(request)` (CV-016, `platform_player`) — projects
  `AiroMediaOpenRequest.externalSubtitles` into `AiroPlaybackTrackOption`
  entries; both concrete engines already call it on `open()`.
- `AiroPlaybackTrackOption.isExternal`, `selectedTrackIds` on
  `AiroPlaybackState` — already shipped.
- `FakeVideoPlayerPlatform` test double pattern (`platform_media/test/support`)
  — reused here for `VideoPlayerStreamingService` tests instead of hitting a
  real network stream.

## The Gap (what this design closes)

1. **`AiroPlaybackSourceHandle` cannot accept a real stream URL.** Its only
   constructor, `.redacted(String value)`, calls `validate()`, which *rejects*
   any value that parses as an `http`/`https` URL
   (`AiroPlaybackSourceHandleRejectionCode.urlValue`). Every IPTV channel and
   VOD item's playable URL — from `IPTVChannel.getStreamUrl()`
   (`packages/platform_channels/lib/src/models/iptv_channel.dart:205`) — is
   exactly such a URL, sometimes with Xtream/Stalker credentials embedded in
   the path. Passing it to `.redacted()` throws `ArgumentError` immediately.
   This is a real, previously-unexercised gap in the CV-029 contract: nothing
   in `platform_media`/`platform_player`'s existing tests constructs a handle
   from a real playable URL, only from opaque placeholder strings like
   `'opaque-handle-1'`.
2. **`VideoPlayerStreamingService` never adopted `AiroPlaybackEngine`.** It
   owns 100% of live/VOD playback in the shipped app (both `iptv_screen.dart`
   and `vod_screen.dart` — the latter via a synthetic-channel wrapper) but
   talks to `VideoPlayerController` directly.
3. **No track/external-subtitle surface in the UI.** Even once (1) and (2) are
   fixed, `video_player_widget.dart` and `vod_screen.dart` have no controls
   that read `tracks`/`selectedTrackIds` or call `selectTrack`/
   `attachExternalSubtitle`.

## Architecture

```
IPTVChannel.getStreamUrl()  ──►  AiroPlaybackSourceHandle.direct(url)  ──►  AiroMediaOpenRequest
                                                                                    │
                                                                                    ▼
VideoPlayerStreamingService  ──►  AiroPlaybackEngine (VideoPlayerAiroPlaybackEngine)
   (implements IPTVStreamingService,                    │
    unchanged public shape + new methods)                ▼
                                              AiroPlaybackState (tracks, position, error...)
                                                            │
                                              translated in the service's
                                              existing state-update path
                                                            ▼
                                                    StreamingState (unchanged shape + new fields)
                                                            │
                                              (existing, untouched) iptv_providers.dart,
                                              video_player_widget.dart, tv_player_controls.dart,
                                              adaptive_iptv_ui.dart
```

No new engine resolver, no fallback coordinator, no mpv. `VideoPlayerAiroPlaybackEngine`
is a straight swap-in for the raw `VideoPlayerController` this service already
drives — the engine's own `open()` internally does the same
`VideoPlayerController.networkUrl(...)` + `.initialize()` the service does today.

## Components

### `platform_player` (additive only)

- **`AiroPlaybackSourceHandle.direct(String url)`** — new factory alongside
  the existing `.redacted()`. Skips the URL-rejection check in `validate()`
  (these are legitimate internally-resolved stream URLs from our own channel/
  provider adapters, not raw user input passed by mistake — the scenario
  `.redacted()`'s validation exists to catch). `toString()` still returns the
  redacted form; the safety invariant (never log/print the raw value) is
  unchanged. The existing `.redacted()` factory, its validation rules, and its
  tests are untouched — this is a second, parallel acceptance path, not a
  loosening of the first.

### `platform_player` (additive fields on `StreamingState`)

- `tracks: List<AiroPlaybackTrackOption>` (default `const []`)
- `selectedTrackIds: Map<AiroPlaybackTrackKind, String>` (default `const {}`)

Field names deliberately mirror `AiroPlaybackState`'s own field names for a
direct, zero-translation-logic copy in the service's state-update path.

### `platform_media` (`VideoPlayerStreamingService`, in-place refactor)

- `VideoPlayerController? _controller` → `AiroPlaybackEngine _engine`
  (constructor-injectable, defaults to `VideoPlayerAiroPlaybackEngine()` — same
  DI seam pattern `MpvAiroPlaybackEngine`/CV-030 already established via
  `playerFactory` for testability without a real platform channel).
- `playChannel(channel)` builds:
  ```dart
  AiroMediaOpenRequest(
    requestId: <generated>,
    sourceHandle: AiroPlaybackSourceHandle.direct(channel.getStreamUrl(_state.selectedQuality)),
    mediaKind: <inferred from channel/URL shape>,
    externalSubtitles: _pendingExternalSubtitles,
  )
  ```
  and calls `_engine.open(request)` in place of constructing
  `VideoPlayerController` directly.
- `play()`/`pause()`/`seek()`/`setVolume()` delegate to `_engine`.
- A new `_foldEngineState(AiroPlaybackState)` maps `tracks`, `selectedTrackIds`,
  and typed `error` onto the existing `StreamingState.copyWith(...)` call sites
  — same call sites that today read from `VideoPlayerController`/catch
  `PlatformException`/`TimeoutException`. The existing retry-timer, live-edge
  detector, buffer-health timer, and network-quality estimation are untouched:
  they read `_state`/their own timers, not `_controller` fields.
- New public methods on `IPTVStreamingService`:
  - `Future<void> selectTrack({required AiroPlaybackTrackKind kind, required String trackId})`
    — delegates to `_engine.selectTrack(...)`, folds the resulting
    `selectedTrackIds` into `StreamingState`. No re-open.
  - `void attachExternalSubtitle(AiroPlaybackExternalSubtitle subtitle)` —
    stores it in `_pendingExternalSubtitles`; takes effect on the **next**
    `playChannel`/replay (engines don't support attaching a subtitle to an
    already-open source — matches the existing engine contract).

### `feature_iptv` UI (small, additive)

- Subtitle-track button in `video_player_widget.dart`'s control bar. Visible
  only when `tracks.isNotEmpty` (mirrors the CV-pro-17 PiP-toggle
  visibility pattern — hidden entirely when there's nothing to show, never a
  dead control). Tapping opens a track list; selecting one calls
  `selectTrack()`.
- Minimal external-subtitle-URL entry point on `vod_screen.dart` only, calling
  `attachExternalSubtitle()` then re-triggering `playChannel()` for the same
  synthetic channel so the subtitle takes effect. UI copy should read as
  "reload to apply," not instant — matches the engine contract, not a UI bug.

## Data Flow & Error Handling

- **Channel switch (externally unchanged):** `playChannel(channel)` → build
  request → `_engine.open()` → engine emits `AiroPlaybackState` on its
  `states` stream → `_foldEngineState` → existing `StreamingState`
  broadcast → `streamingStateProvider` (unchanged `StreamProvider`) → all
  derived providers notified exactly as today.
- **Error translation:** `AiroPlaybackState.error.code` (`decoderFailed`,
  `networkUnavailable`, etc.) maps onto the same `StreamingState.errorMessage`/
  `retryCount`/`lastError` fields the existing `PlatformException`/
  `TimeoutException` catch blocks already populate. The retry-timer logic
  triggers off `playbackState == PlaybackState.error`, not off which class
  produced the error — untouched.
- **Track selection:** live operation, no re-open, matches CV-016's engine
  contract exactly (`selectTrack` on an already-open engine just updates
  `selectedTrackIds`).
- **External subtitle attach:** stored, applied on next open — not
  instantaneous. This is an engine-contract constraint (CV-030/016 as built),
  not a shortcut taken here.
- **Unaffected paths:** live-edge detector, DVR window tracking, buffer-health
  timer, network-quality estimation, audio-context focus requests, wakelock —
  none of these read `_controller` in ways the engine swap touches.

## Testing Strategy

`VideoPlayerStreamingService` has zero existing tests today — this migration
is its first real test suite, written TDD (RED first against the target
contract, using the `FakeVideoPlayerPlatform` double already established in
CV-030 rather than a real network stream):

- **`AiroPlaybackSourceHandle.direct()`** (`platform_player`): accepts raw
  http/https URLs (including Xtream-style credential-bearing paths) that
  `.redacted()` rejects; `toString()` stays redacted; existing `.redacted()`
  tests re-run unchanged as a regression guard.
- **`VideoPlayerStreamingService`** (`platform_media`):
  - `playChannel()` opens via the injected engine, reaches
    `PlaybackState.playing` on success (characterization test against current
    behavior, written first, kept green through the refactor).
  - Engine `decoderFailed`/`networkUnavailable` surfaces through the existing
    retry-timer path unchanged.
  - `selectTrack()` updates `StreamingState.selectedTrackIds`; unknown track
    id is a typed no-op failure (mirrors the engine-level test CV-016 already
    wrote).
  - `attachExternalSubtitle()` → next `playChannel()` → subtitle appears in
    `StreamingState.tracks`.
  - DVR/live-edge/buffer-health assertions replayed against the refactored
    service prove no regression on any of the untouched subsystems.
- **`feature_iptv` widget tests**: subtitle button hidden when `tracks.isEmpty`,
  visible + wired to `selectTrack()` when populated. Existing channel-switch
  and track-management widget tests must stay green — hard regression gate
  before this lands.

## Package Placement

- `platform_player`: `AiroPlaybackSourceHandle.direct()`, `StreamingState`
  additive fields (`tracks`, `selectedTrackIds`).
- `platform_media`: `VideoPlayerStreamingService` in-place refactor, new
  `IPTVStreamingService` methods (`selectTrack`, `attachExternalSubtitle`).
- `feature_iptv`: subtitle-track button (`video_player_widget.dart`),
  external-subtitle entry point (`vod_screen.dart`).

## Open Questions for Implementation Plan

- Exact `AiroPlaybackMediaKind` inference for `playChannel`'s open request —
  today's service doesn't distinguish HLS/DASH/progressive/live at the type
  level the way `AiroMediaOpenRequest` does; the plan needs to pick a mapping
  (likely: `channel.isLive` → `AiroPlaybackMediaKind.live`, else infer from
  URL extension, defaulting to `hls` since that's the dominant IPTV format in
  this codebase).
- Whether `requestId` should be a stable per-channel id (for dedup/observability)
  or freshly generated per open — check whether anything downstream
  (diagnostics/analytics) already expects one or the other.
