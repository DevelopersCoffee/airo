# feature_iptv → AiroPlaybackEngine Migration (Minimum Slice) — Design

**Date:** 2026-07-18
**Status:** Approved (brainstorm) → pending implementation plan
**Owner package:** `platform_media` (+ `platform_player` for the new source-handle
factory, `buildView()` contract addition, and `AiroPlaybackBufferedRange`;
`platform_streams` for `LiveEdgeDetector`'s engine-agnostic rewrite)
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

**Revision note:** an earlier version of this design assumed
`VideoPlayerAiroPlaybackEngine` was a feature-complete drop-in for direct
`VideoPlayerController` usage. It isn't: it exposes no renderable video surface
and never emits continuous position/duration/buffering updates (only on
explicit method calls). Both gaps surfaced during plan-writing and are closed
here — see "The Gap," items 4 and 5.

## Goals

- Make `AiroPlaybackState.tracks` (including CV-016's projected external
  subtitles) visible in the existing `feature_iptv` player UI.
- Let the user attach an external subtitle URL to a VOD item and select it,
  per CV-031's original acceptance criteria.
- Zero behavior change to anything not explicitly listed above: DVR, live-edge
  detection, buffer health, network-quality estimation, retry-on-timeout,
  audio-context focus, wakelock, cast — all keep producing the same observable
  outcomes as today, even though the live-edge detector's data source changes
  internally (poll-the-controller → read-the-engine-state).
- Close the `AiroPlaybackSourceHandle` gap that currently makes it impossible
  to open a real IPTV/VOD URL through any `AiroPlaybackEngine` at all.
- Complete `AiroPlaybackEngine`'s contract with the two capabilities any real
  UI needs — a renderable view and continuous state — so this is the last time
  a consumer hits this gap.

## Non-Goals (deferred, explicitly out of scope for this slice)

- **No mpv fallback wiring.** `AiroEngineFallbackCoordinator` /
  `AiroPlaybackEngineResolver` are not consumed here. The service continues to
  construct a single `VideoPlayerAiroPlaybackEngine` directly, same as it
  constructs a single `VideoPlayerController` today. Wiring the fallback
  coordinator (so a codec failure actually falls back to mpv on
  Android-mobile/iOS/macOS) is a follow-up slice once this one is proven safe
  in production.
- **No mpv rendering.** `MpvAiroPlaybackEngine.buildView()` returns `null` in
  this slice — wiring real mpv video output needs the `media_kit_video`
  package (a new dependency, its own council review) and isn't exercised
  since mpv isn't consumed by `feature_iptv` here.
- **No `StreamingState` field removal.** `StreamingState`, `PlaybackState`,
  `BufferStatus`, `NetworkQuality`, `LiveStreamState` keep every existing
  field; this slice only adds `tracks`/`selectedTrackIds`. No provider outside
  the ones explicitly touched needs to change.
- **No live-channel subtitle-attach UI.** External-subtitle attach is VOD-only
  per CV-031's original scope; live channels only get the track-selector
  button (for embedded/external tracks already present on open).
- **No new abstraction layer / parallel adapter class.** In-place refactor of
  the existing `VideoPlayerStreamingService`, not a new class alongside it.
- **No aspect-ratio/BoxFit logic inside the engine.** `buildView()` returns a
  widget sized to the video's intrinsic dimensions; the caller keeps wrapping
  it in `FittedBox(fit: _boxFitFor(aspectRatioFit))` exactly as today — CV-031
  already decided aspect ratio is a view-layer concern, and this design
  doesn't re-litigate that.

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
  — reused here for `VideoPlayerStreamingService` and
  `VideoPlayerAiroPlaybackEngine` tests instead of hitting a real network
  stream.
- `AiroPlaybackViewFit` + `_boxFitFor` mapping (`video_player_widget.dart:793`,
  CV-031) — untouched, still the view layer's job.

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
4. **`AiroPlaybackEngine` exposes no renderable video surface.**
   `video_player_widget.dart:221,241` does `service.controller` →
   `VideoPlayer(controller)` to paint the picture, reading
   `controller.value.size`/`.isInitialized` too. `VideoPlayerAiroPlaybackEngine`
   wraps its `VideoPlayerController` privately with zero accessor — nothing to
   paint with once the raw controller is gone.
5. **`VideoPlayerAiroPlaybackEngine` never emits continuous state.**
   `VideoPlayerStreamingService._onControllerUpdate()`
   (`video_player_streaming_service.dart:178-200`) has a
   `controller.addListener` that continuously folds `position`/`duration`/
   buffering into `StreamingState`, driving the progress bar, the
   buffer-health timer, and `LiveEdgeDetector.attach(VideoPlayerController)`
   (`platform_streams/lib/src/services/live_edge_detector.dart:39`, hard-typed
   to the raw controller, polling `.value.position`/`.value.duration`/
   `.value.buffered` on its own timer). `VideoPlayerAiroPlaybackEngine` has no
   equivalent — `AiroPlaybackState.position` only changes on explicit `seek()`
   calls, and there's no buffered-ranges field on `AiroPlaybackState` at all.

## Architecture

```
IPTVChannel.getStreamUrl()  ──►  AiroPlaybackSourceHandle.direct(url)  ──►  AiroMediaOpenRequest
                                                                                    │
                                                                                    ▼
VideoPlayerStreamingService  ──►  AiroPlaybackEngine (VideoPlayerAiroPlaybackEngine)
   (implements IPTVStreamingService,          │  continuously emits AiroPlaybackState
    unchanged public shape + new methods)      │  (position, duration, bufferedRanges,
                                                │   tracks, error, phase) via controller
                                                │  listener — not just on open/seek
                                                ▼
                                    AiroPlaybackState ──► folded into StreamingState
                                                │           (unchanged shape + new fields)
                                                │
                                                ├──► engine.buildView() ──► VideoPlayerStreamingService
                                                │     (Widget?, sized to intrinsic       .buildVideoView()
                                                │      video dimensions)                       │
                                                │                                               ▼
                                                │                                    video_player_widget.dart
                                                │                                    (FittedBox(fit: _boxFitFor(...),
                                                │                                     child: videoView))
                                                │
                                                └──► LiveEdgeDetector.attachToEngine(engine)
                                                      (subscribes to engine.states, same
                                                       Timer.periodic cadence, reads cached
                                                       state instead of controller.value)

(existing, untouched) iptv_providers.dart, tv_player_controls.dart, adaptive_iptv_ui.dart
```

No engine resolver, no fallback coordinator, no mpv rendering. `VideoPlayerAiroPlaybackEngine`
is a completed drop-in for the raw `VideoPlayerController` this service already
drives — its own `open()` internally does the same
`VideoPlayerController.networkUrl(...)` + `.initialize()` the service does
today, now with a controller listener wired up so its `states` stream is a
faithful, continuous mirror of the controller's `value`.

## Components

### `platform_player` — new `AiroPlaybackSourceHandle.direct()` factory

New factory alongside the existing `.redacted()`. Skips the URL-rejection
check in `validate()` (these are legitimate internally-resolved stream URLs
from our own channel/provider adapters, not raw user input passed by mistake —
the scenario `.redacted()`'s validation exists to catch). `toString()` still
returns the redacted form; the safety invariant (never log/print the raw
value) is unchanged. The existing `.redacted()` factory, its validation rules,
and its tests are untouched — this is a second, parallel acceptance path, not
a loosening of the first.

### `platform_player` — `AiroPlaybackEngine.buildView()`

New method on the interface:

```dart
/// Returns a widget rendering this engine's video surface, sized to the
/// video's intrinsic dimensions (ready to be wrapped in a FittedBox by the
/// caller for aspect-ratio fitting). Returns null when there is nothing
/// local to render: not yet opened, no local video surface for this
/// backend (e.g. cast), or the backend doesn't support rendering yet
/// (mpv, until media_kit_video is wired in a follow-up slice).
Widget? buildView();
```

Requires `platform_player` to import `package:flutter/widgets.dart` in the
engine interface file — the package already depends on the Flutter SDK
(`pubspec.yaml` has `flutter: sdk: flutter`), so this is not a new dependency.

Implementations:
- `VideoPlayerAiroPlaybackEngine.buildView()` — returns
  `SizedBox(width: controller.value.size.width, height: controller.value.size.height, child: VideoPlayer(controller))`
  when the controller exists and is initialized, else `null`.
- `MpvAiroPlaybackEngine.buildView()` — returns `null` (documented: no
  `media_kit_video` dependency in this slice).
- `FakeAiroPlaybackEngine.buildView()` — returns a small deterministic
  placeholder widget (e.g. `const SizedBox(key: Key('fake-engine-view'))`) so
  widget tests can assert presence/absence without a real platform channel.
- `UnavailableAiroPlaybackEngine.buildView()` — returns `null`.

### `platform_player` — `AiroPlaybackBufferedRange` + `AiroPlaybackState.bufferedRanges`

```dart
class AiroPlaybackBufferedRange extends Equatable {
  const AiroPlaybackBufferedRange({required this.start, required this.end});
  final Duration start;
  final Duration end;
  @override
  List<Object?> get props => [start, end];
}
```

`AiroPlaybackState` gains `bufferedRanges: List<AiroPlaybackBufferedRange>`
(default `const []`), added to the constructor, `copyWith`, and `props` —
same pattern as the existing `tracks` field.

### `platform_player` — additive fields on `StreamingState`

- `tracks: List<AiroPlaybackTrackOption>` (default `const []`)
- `selectedTrackIds: Map<AiroPlaybackTrackKind, String>` (default `const {}`)

Field names deliberately mirror `AiroPlaybackState`'s own field names for a
direct, zero-translation-logic copy in the service's state-update path.

### `platform_media` — `VideoPlayerAiroPlaybackEngine` continuous state emission

New controller listener, wired in `open()` after the controller is created,
removed in `_disposeController()`:

```dart
void _onControllerValueChanged() {
  final controller = _controller;
  if (controller == null) return;
  final value = controller.value;
  if (value.hasError) {
    _fail(AiroPlaybackErrorCode.decoderFailed, 'playback', _state.request);
    return;
  }
  final nextPhase = value.isBuffering
      ? AiroPlaybackEnginePhase.buffering
      : (_state.phase == AiroPlaybackEnginePhase.buffering
          ? AiroPlaybackEnginePhase.playing
          : _state.phase);
  _emit(
    _state.copyWith(
      phase: nextPhase,
      position: value.position,
      duration: value.duration,
      bufferedRanges: value.buffered
          .map((r) => AiroPlaybackBufferedRange(start: r.start, end: r.end))
          .toList(),
    ),
  );
}
```

This is the same logic `VideoPlayerStreamingService._onControllerUpdate()` has
today, moved into the engine where it belongs — the engine is now the single
owner of "translate `VideoPlayerController.value` into typed state," instead
of that logic living redundantly in every caller.

### `platform_streams` — `LiveEdgeDetector`, decoupled from `VideoPlayerController`

- `attach(VideoPlayerController controller)` → `attachToEngine(AiroPlaybackEngine engine)`.
- Internal `VideoPlayerController? _controller` → `AiroPlaybackEngine? _engine`
  + `AiroPlaybackState? _lastState` + `StreamSubscription<AiroPlaybackState>? _engineSubscription`.
- `attachToEngine` subscribes to `engine.states`, caching each state into
  `_lastState`; also seeds `_lastState = engine.currentState` immediately so
  the first timer tick isn't working from `null`.
- The existing `Timer.periodic(_config.updateInterval, ...)` cadence is
  unchanged — `_updateLiveEdgeState()` now reads `_lastState` instead of
  `_controller!.value`.
- `_detectLiveStream`/`_calculateLiveEdge`/`_determineLiveState`/
  `_detectDvrWindow` keep their exact logic; only their inputs change type:
  `Duration` position/duration stay `Duration`, `List<DurationRange>` becomes
  `List<AiroPlaybackBufferedRange>` (same `.start`/`.end` shape), and
  `value.isPlaying` becomes `state.phase == AiroPlaybackEnginePhase.playing`.
- `detach()` cancels `_engineSubscription` in addition to stopping the timer.
- `package:video_player/video_player.dart` import removed from this file and
  from `platform_streams/pubspec.yaml` — no longer used anywhere in the
  package once this lands.

### `platform_media` — `VideoPlayerStreamingService` (in-place refactor)

- `VideoPlayerController? _controller` → `AiroPlaybackEngine _engine`
  (constructor-injectable, defaults to `VideoPlayerAiroPlaybackEngine()` — same
  DI seam pattern `MpvAiroPlaybackEngine`/CV-030 already established via
  `playerFactory` for testability without a real platform channel).
- `playChannel(channel)` builds:
  ```dart
  AiroMediaOpenRequest(
    requestId: <generated>,
    sourceHandle: AiroPlaybackSourceHandle.direct(channel.getStreamUrl(_state.selectedQuality)),
    mediaKind: <inferred from channel/URL shape — see Open Questions>,
    externalSubtitles: _pendingExternalSubtitles,
  )
  ```
  and calls `_engine.open(request)` in place of constructing
  `VideoPlayerController` directly.
- `play()`/`pause()`/`seek()`/`setVolume()` delegate to `_engine`.
- Subscribes to `_engine.states` once, in the constructor or on first use
  (replacing the old `controller.addListener(_onControllerUpdate)`, which had
  to be re-added after every `open()` since each open created a fresh
  controller — subscribing to `_engine.states` once is simpler since the
  engine instance itself doesn't change across opens). A new
  `_onEngineStateUpdate(AiroPlaybackState)` folds `tracks`, `selectedTrackIds`,
  `position`, `duration`, `bufferedRanges` (→ existing `BufferStatus` shape),
  and typed `error` into `StreamingState.copyWith(...)`.
- `_liveEdgeDetector.attach(_controller!)` → `_liveEdgeDetector.attachToEngine(_engine)`,
  called once after each successful `open()` (same call site as today).
- Old `VideoPlayerController? get controller` getter — **removed**. Confirmed
  via repo-wide grep it has exactly one consumer
  (`video_player_widget.dart:221`).
- New: `Widget? buildVideoView() => _engine.buildView();`
- New public methods on `IPTVStreamingService`:
  - `Future<void> selectTrack({required AiroPlaybackTrackKind kind, required String trackId})`
    — delegates to `_engine.selectTrack(...)`, folds the resulting
    `selectedTrackIds` into `StreamingState`. No re-open.
  - `void attachExternalSubtitle(AiroPlaybackExternalSubtitle subtitle)` —
    stores it in `_pendingExternalSubtitles`; takes effect on the **next**
    `playChannel`/replay (engines don't support attaching a subtitle to an
    already-open source — matches the existing engine contract).

### `feature_iptv` UI

- `video_player_widget.dart`'s `_buildPlayer` (`:209-248`): replaces
  ```dart
  final controller = service.controller;
  ...
  if (controller != null && controller.value.isInitialized)
    SizedBox.expand(
      child: FittedBox(
        fit: _boxFitFor(aspectRatioFit),
        child: SizedBox(
          width: controller.value.size.width,
          height: controller.value.size.height,
          child: VideoPlayer(controller),
        ),
      ),
    )
  ```
  with
  ```dart
  final videoView = service.buildVideoView();
  ...
  if (videoView != null)
    SizedBox.expand(
      child: FittedBox(
        fit: _boxFitFor(aspectRatioFit),
        child: videoView,
      ),
    )
  ```
  Same shell, same fallback branches (`_buildLoading()`/`_buildPlaceholder(state)`)
  — only the widget construction moves from the widget into the engine.
- New subtitle-track button in the control bar. Visible only when
  `tracks.isNotEmpty` (mirrors the CV-pro-17 PiP-toggle visibility pattern —
  hidden entirely when there's nothing to show, never a dead control).
  Tapping opens a track list; selecting one calls `selectTrack()`.
- Minimal external-subtitle-URL entry point on `vod_screen.dart` only, calling
  `attachExternalSubtitle()` then re-triggering `playChannel()` for the same
  synthetic channel so the subtitle takes effect. UI copy should read as
  "reload to apply," not instant — matches the engine contract, not a UI bug.

## Data Flow & Error Handling

- **Channel switch:** `playChannel(channel)` → build request →
  `_engine.open()` → engine's controller listener starts emitting
  `AiroPlaybackState` continuously on `states` → `_onEngineStateUpdate` folds
  into `StreamingState` → `streamingStateProvider` (unchanged `StreamProvider`)
  → all derived providers notified, same as today but now driven by the
  engine's listener instead of the service's own.
- **Error translation:** `AiroPlaybackState.error.code` (`decoderFailed`,
  `networkUnavailable`, etc.) maps onto the same `StreamingState.errorMessage`/
  `retryCount`/`lastError` fields the existing `PlatformException`/
  `TimeoutException` catch blocks already populate. The retry-timer logic
  triggers off `playbackState == PlaybackState.error`, not off which class
  produced the error — untouched. The engine's own `value.hasError` check
  (new, in `_onControllerValueChanged`) surfaces mid-playback decoder errors
  the same way `_onControllerUpdate`'s `value.hasError` check does today.
- **Track selection:** live operation, no re-open, matches CV-016's engine
  contract exactly (`selectTrack` on an already-open engine just updates
  `selectedTrackIds`).
- **External subtitle attach:** stored, applied on next open — not
  instantaneous. This is an engine-contract constraint (CV-030/016 as built),
  not a shortcut taken here.
- **Rendering:** `service.buildVideoView()` → `engine.buildView()` — pure
  function of the engine's current controller state, no side effects, safe to
  call on every widget rebuild (same cost profile as reading
  `service.controller` today).
- **Live-edge/DVR/buffer-health:** now driven by `LiveEdgeDetector`'s cached
  `_lastState` (updated via the `engine.states` subscription) instead of
  polling `_controller!.value` directly on each timer tick. Observable
  behavior — the DVR window math, drift detection, auto-resync — is unchanged;
  only the data source changed from "read the controller synchronously" to
  "read the last state the engine emitted," which for a `Timer.periodic` at
  1-second granularity is not observably different (the engine's own listener
  fires on every controller `notifyListeners()`, i.e. far more often than
  once a second).
- **Unaffected paths:** audio-context focus requests, wakelock, retry-timer
  scheduling, network-quality estimation heuristics — none of these read
  `_controller` in ways this refactor touches.

## Testing Strategy

Written TDD throughout (RED first against the target contract), using the
`FakeVideoPlayerPlatform` double already established in CV-030 rather than a
real network stream or platform channel:

- **`AiroPlaybackSourceHandle.direct()`** (`platform_player`): accepts raw
  http/https URLs (including Xtream-style credential-bearing paths) that
  `.redacted()` rejects; `toString()` stays redacted; existing `.redacted()`
  tests re-run unchanged as a regression guard.
- **`AiroPlaybackBufferedRange`/`AiroPlaybackState.bufferedRanges`**
  (`platform_player`): default empty, `copyWith` preserves/overrides, included
  in `props` (equality test).
- **`VideoPlayerAiroPlaybackEngine.buildView()`** (`platform_media`): `null`
  before `open()`; non-null `SizedBox`-wrapped `VideoPlayer` after a
  successful open with the fake platform's `fakeSize`; `null` again after
  `dispose()`.
- **`VideoPlayerAiroPlaybackEngine` continuous state emission**
  (`platform_media`): scripting the `FakeVideoPlayerPlatform` to emit a
  buffering→playing transition and a position change proves the engine's
  `states` stream reflects it without any explicit method call; a scripted
  `hasError` event surfaces as a typed `decoderFailed` state.
- **`LiveEdgeDetector.attachToEngine()`** (`platform_streams`): using a
  `FakeAiroPlaybackEngine` (already exists) that emits scripted states,
  proves live-vs-VOD detection, live-edge calculation, and DVR-window
  detection produce the same results as the existing controller-based tests
  (if any exist for this class — check and port/replay them against the new
  entry point).
- **`VideoPlayerStreamingService`** (`platform_media`), first real test suite
  for this class:
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
  - `buildVideoView()` returns non-null after a successful open, `null`
    before/after dispose.
  - DVR/live-edge/buffer-health assertions replayed against the refactored
    service prove no regression on any of these subsystems end-to-end (not
    just at the `LiveEdgeDetector` unit level).
- **`feature_iptv` widget tests**: subtitle button hidden when `tracks.isEmpty`,
  visible + wired to `selectTrack()` when populated; player surface renders
  via `buildVideoView()` instead of a raw controller. Existing channel-switch
  and track-management widget tests must stay green — hard regression gate
  before this lands.

## Package Placement

- `platform_player`: `AiroPlaybackSourceHandle.direct()`, `AiroPlaybackEngine.buildView()`,
  `AiroPlaybackBufferedRange`, `AiroPlaybackState.bufferedRanges`,
  `StreamingState` additive fields (`tracks`, `selectedTrackIds`).
- `platform_media`: `VideoPlayerAiroPlaybackEngine` continuous state emission +
  `buildView()`; `MpvAiroPlaybackEngine.buildView()` (returns null);
  `VideoPlayerStreamingService` in-place refactor, new `IPTVStreamingService`
  methods (`selectTrack`, `attachExternalSubtitle`), new `buildVideoView()`.
- `platform_streams`: `LiveEdgeDetector.attachToEngine()`, `video_player`
  dependency removed.
- `feature_iptv`: video-surface rendering swap + subtitle-track button
  (`video_player_widget.dart`), external-subtitle entry point
  (`vod_screen.dart`).

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
- ~~Whether any existing `LiveEdgeDetector` unit tests exist to port~~ —
  resolved: `packages/platform_streams/test` has no `live_edge_detector_test.dart`
  today. This slice writes the first ones, directly against
  `attachToEngine()` (no legacy `attach(VideoPlayerController)` tests to
  port), plus the `VideoPlayerStreamingService`-level characterization tests
  as the end-to-end regression gate.
