# Native buffer-size tuning — parked research

Date: 2026-07-27
Status: **Parked** — explicitly not scheduled for this release. Revisit
with a deeper research pass before committing to an approach.

## Why this exists

Follow-up from the playback-resilience work in PR #1237 (stall-failover
wiring). That PR's design doc scoped out native buffer/LoadControl tuning
as a separate, larger effort. This doc preserves the technical discovery
already done so it doesn't have to be re-derived next time this is picked
up.

## The gap

The TV app has no way to configure ExoPlayer's buffer sizes (min/max
buffer duration, buffer-for-playback-ms). It relies entirely on the
`video_player` plugin's internal defaults. `StreamingConfig.
targetBufferDuration`/`minBufferDuration` exist in
`packages/platform_player/lib/src/services/iptv_streaming_service.dart`
but never reach the native player — `targetBufferDuration` is display-only
(feeds a `bufferHealth` percentage), `minBufferDuration` is unused.

## Three options researched (playback-architect discovery pass)

### 1. Fork `video_player`/`video_player_android`/`video_player_platform_interface`
- The native injection point already exists: both `TextureVideoPlayer.java`
  and `PlatformViewVideoPlayer.java` already build a `DefaultLoadControl`,
  just for one field (`backBufferDurationMs`, retained back-buffer only —
  not forward buffer). Adding `setBufferDurationsMs(...)` is a small
  native diff (~15 lines each).
- The real cost is threading a new option end-to-end: pigeon-generated
  `Messages.kt`/`.java`, `VideoPlayerOptions` in
  `video_player_platform_interface`, and `video_player`'s own wrapper —
  a 3-package federated-plugin fork, pinned locally.
- This repo already has precedent for pinned/local forks
  (`packages/stubs/file_picker_stub`, the `slm_edge_intelligence` git
  dependency in `feature_iptv/pubspec.yaml`), so the *pattern* isn't
  novel here — the ongoing maintenance burden of tracking upstream
  `video_player` releases against a 3-package fork is the real cost.
- Medium scope, no reversal of any documented decision.

### 2. Switch the TV engine to mpv/media_kit
- **Ruled out.** `app/android/app/build.gradle.kts` (lines ~196-216)
  contains an explicit, dated `CV-030` decision: mpv/media_kit native
  libs (`libmpv.so`, `libplayer.so`, `libavcodec.so`, etc.) are
  deliberately stripped from TV-variant builds because TV boxes are
  storage-starved (~8GB). `MediaKitMpvPlayerFacade`'s own doc comment
  confirms its intended shipping matrix is Windows/Linux (primary) plus
  Android-mobile/iOS/macOS (codec fallback) — TV is absent by design.
- mpv *does* expose real buffer/cache control (`cache-secs`,
  `demuxer-max-bytes` via `PlayerConfiguration.bufferSize`, or the raw
  `setProperty()` escape hatch in `media_kit`'s native player), so this
  option is technically the richest — but choosing it means deliberately
  reversing CV-030, not just adding a feature. Any future revisit of this
  option must re-litigate CV-030 explicitly, with whoever owns
  release/build config and APK size budget, not just Playback Architect.

### 3. Full native Media3/ExoPlayer platform channel, bypassing `video_player`
- Media3 ExoPlayer is **already a transitive Android dependency**
  (`androidx.media3:media3-exoplayer` + HLS/RTSP/smoothstreaming
  extensions resolve in the Gradle cache, almost certainly pulled in via
  `video_player_android`) — no new native dependency needed to reach it.
- This repo has a clean, established pattern for native plugins this size
  (`app/android/app/src/product/kotlin/io/airo/app/
  AiroBackgroundAudioPlugin.kt`, `AiroPictureInPicturePlugin.kt`,
  `PhoneMediaPickerPlugin.kt`).
- Largest scope by far: means owning the full player
  surface/`PlatformView`/`Texture`, media session, and lifecycle
  currently provided by `video_player_android` for free. Full,
  unconstrained control (buffer sizes, and eventually real in-stream ABR
  via Media3's `TrackSelector`) is the payoff.

## Recommendation made, not acted on

Option 1 (fork) was recommended as the smallest real scope that doesn't
reverse a documented decision. The user chose to park all three rather
than commit to an approach now, wanting a deeper research pass before
picking one — noted explicitly: "we are not in current state to take any
of the risk... we will plan this after doing deep research."

## Before picking this back up

- Re-verify the exact resolved `video_player`/`video_player_android`
  versions at that time (`app/.dart_tool/package_config.json`) — pin
  drift is likely between now and whenever this restarts.
- Re-check whether CV-030's storage constraint still holds (TV device
  storage minimums may have shifted release-to-release) before
  re-considering Option 2.
- If Option 3 is chosen, confirm the actual Media3 version pulled in
  transitively at that time (only confirmed via shared Gradle cache here,
  not a direct build-output inspection — treat as strong-but-not-certain
  until re-verified).
- Consider whether real ABR (a separate, related parked item) should be
  designed together with buffer tuning if Option 3 is chosen, since both
  point toward the same underlying native-player investment.
