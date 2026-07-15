# ADR-003: Player Backend Evaluation -- media_kit / libmpv

## Status

Proposed

## Date

2026-07-15

## Context

Airo's IPTV feature (`feature_iptv`, `platform_player`, `platform_streams`,
`platform_media`) currently uses the **`video_player`** Flutter package
(v2.12.x) for all playback.  `video_player` delegates to platform-native
players: ExoPlayer on Android, AVPlayer on iOS/macOS, and the `<video>` tag on
Web.

This setup has known pain points:

1. **Channel zap time** -- ExoPlayer's HLS demuxer takes 1.5--3 s to start
   cold playback of a new stream.  Our `StreamingConfig.live` targets 1 s
   minimum buffer, but the underlying player often overshoots.
2. **Codec gaps** -- `video_player` (ExoPlayer) does not decode MPEG-TS unicast
   streams without HLS wrapper.  VP9 works but AV1 support is device-dependent.
   HEVC (H.265) requires hardware support that varies by Android TV SoC.
3. **Limited control surface** -- `VideoPlayerController` exposes position,
   buffered ranges, and play/pause, but not low-level options like
   `--demuxer-max-back-bytes`, hardware decode toggle, or audio-track
   selection.  Our `LiveEdgeDetector` has to use heuristics (duration, buffer
   ranges) rather than metadata the demuxer could expose directly.
4. **Desktop parity** -- `video_player` on Linux has minimal support via
   GStreamer; Windows uses the Media Foundation backend which lacks codec
   coverage.

Issue #770 asks whether **media_kit** (pub.dev/packages/media_kit), a
Flutter binding around **libmpv** (the library form of mpv), is a viable
replacement or complement.

### Current architecture snapshot

```
feature_iptv
  -> platform_media  (VideoPlayerStreamingService)
  -> platform_player (IPTVStreamingService interface, StreamingState)
  -> platform_streams (LiveEdgeDetector, depends on video_player controller)
  -> video_player ^2.12.0  (direct dep in feature_iptv & platform_media & platform_streams)
```

`VideoPlayerStreamingService` (in `platform_media`) is the only concrete
implementation of the `IPTVStreamingService` abstract class.  The UI layer
(`VideoPlayerWidget`) imports `VideoPlayer` and `VideoPlayerController`
directly from `video_player`.  Replacing the backend therefore requires
changes in:

- `platform_media` -- swap `VideoPlayerController` for media_kit `Player` +
  `Video` widget.
- `platform_streams` -- `LiveEdgeDetector` currently depends on
  `VideoPlayerController`; must be adapted to media_kit's stream-based state.
- `feature_iptv` -- `VideoPlayerWidget` renders `VideoPlayer(controller)`;
  would render `Video(controller: controller)` instead.

## Options Evaluated

### Option A: Keep video_player (status quo)

| Dimension | Assessment |
|---|---|
| **Zap time** | 1.5--3 s (ExoPlayer HLS cold start); warm start ~0.8 s |
| **Codec coverage** | H.264 (all), H.265 (hardware-dependent), VP9 (most), AV1 (Pixel 6+, recent TVs), MPEG-TS (no, HLS wrapper required) |
| **Platform coverage** | Android, iOS, macOS, Web; Linux/Windows partial |
| **License** | BSD-3-Clause (clean for commercial use) |
| **Bundle size impact** | ~0 (uses platform codecs) |
| **TV D-pad / leanback** | No special support; Airo wraps with `TvFocusable`/`TvInputHandler` |
| **API surface** | Limited (position, buffered, play/pause/seek/volume) |
| **Maintenance** | Flutter team maintains; stable but slow feature cadence |

### Option B: media_kit (libmpv)

| Dimension | Assessment |
|---|---|
| **Zap time** | 0.3--0.8 s typical; libmpv pre-demuxes and starts decode before buffering completes.  `--demuxer-lavf-o=fflags=+nobuffer` can cut further.  Community benchmarks report 300 ms for MPEG-TS and 500 ms for HLS. |
| **Codec coverage** | H.264, H.265/HEVC, VP8, VP9, AV1, MPEG-TS, MPEG-PS, HLS, DASH, RTSP, RTMP, MKV, FLV -- essentially everything FFmpeg decodes.  Software fallback when hardware decode unavailable. |
| **Platform coverage** | Android (API 21+), iOS (14+), macOS (11+), Windows (10+), Linux (X11/Wayland), **Web not supported** (no WASM FFmpeg in media_kit today). |
| **License** | **LGPL-2.1 (libmpv) + GPL-2.0-or-later (FFmpeg with GPL codecs)**.  media_kit Dart bindings are MIT, but the native libraries carry LGPL/GPL.  Dynamic linking satisfies LGPL, but enabling `--enable-gpl` codecs (x264, x265) triggers full GPL.  This is a **commercial distribution concern** -- Airo distributes the binary via Play Store / App Store, and GPL requires source offer for the entire combined work under some interpretations. |
| **Bundle size impact** | +15--25 MB per ABI on Android (libmpv.so + libavcodec/format/util).  iOS: +20--30 MB (static framework).  Significant for app size budgets. |
| **TV D-pad / leanback** | No built-in support; same as video_player -- Airo's existing `TvFocusable`/`TvInputHandler` wrappers would apply identically. |
| **API surface** | Rich: streams for position/duration/buffer/width/height/audioBitrate/tracks, subtitle support, audio track selection, playback speed, `--demuxer-*` options passthrough, screenshot, equalizer, HTTP headers. |
| **Maintenance** | Community-maintained (alexmercerind); active but single-maintainer risk.  v1.x released; API surface stable. |

### Option C: just_audio + video (split audio/video)

| Dimension | Assessment |
|---|---|
| **Zap time** | Audio-only: fast (<0.5 s via ExoPlayer).  Video: still depends on video_player.  No improvement for video channels. |
| **Codec coverage** | Audio: MP3, AAC, OGG, FLAC, WAV, HLS audio.  Video: same as Option A. |
| **Platform coverage** | Audio: Android, iOS, macOS, Web, Linux, Windows.  Video: same as Option A. |
| **License** | MIT (clean) |
| **Bundle size impact** | Minimal (~200 KB) |
| **TV D-pad / leanback** | N/A for audio; video same as Option A |
| **API surface** | Excellent for audio (gapless, crossfade, playlist); video unchanged |
| **Maintenance** | Ryan Heise (active, well-maintained) |

> Note: A `just_audio_stub` already exists in `packages/stubs/just_audio_stub/`,
> suggesting audio-only playback was previously considered.

## Comparison Matrix

| Criterion | Weight | video_player (A) | media_kit (B) | just_audio+video (C) |
|---|---|---|---|---|
| Zap time | High | 1.5--3 s | **0.3--0.8 s** | 1.5--3 s (video) |
| Codec breadth | High | H.264, partial H.265/VP9/AV1 | **All FFmpeg codecs** | Same as A (video) |
| MPEG-TS native | High | No | **Yes** | No |
| Web support | Medium | **Yes** | No | Partial |
| License risk | High | **None (BSD)** | **GPL/LGPL concern** | None (MIT) |
| Bundle size | Medium | **0 MB** | +15--25 MB/ABI | ~0 MB |
| API richness | Medium | Basic | **Rich** | Audio: rich; Video: basic |
| TV D-pad | Low | Manual (existing) | Manual (existing) | Manual (existing) |
| Maintenance bus factor | Medium | Flutter team | **1 maintainer** | 1 maintainer |
| Migration effort | -- | None | Moderate (3 packages) | Low (audio path only) |

## Recommendation

**Accept media_kit as the target backend for Android, Android TV, iOS, macOS,
Linux, and Windows, with a phased migration behind a feature flag.  Retain
video_player as the Web backend.**

### Rationale

1. **Zap time improvement is substantial** -- going from 1.5--3 s to sub-second
   channel changes directly affects the core IPTV UX.  For a TV product, zap
   time is the single most important quality metric.
2. **MPEG-TS and codec breadth eliminate user-reported playback failures** on
   channels that serve raw transport streams without HLS wrapping.
3. **The abstraction layer already exists** -- `IPTVStreamingService` is an
   abstract class; `VideoPlayerStreamingService` is the only implementation.
   Adding `MediaKitStreamingService` behind the same interface is
   straightforward.

### Tradeoffs to accept

1. **GPL/LGPL license risk** -- must be mitigated:
   - Build libmpv/FFmpeg with `--disable-gpl` (LGPL-only codecs).  This drops
     x264/x265 encoders but retains H.264/H.265 *decoders* (which are
     LGPL-safe in FFmpeg).
   - Use dynamic linking for LGPL compliance.
   - Add license attribution in Settings > Open Source Licenses.
   - Legal review required before shipping.
2. **Bundle size increase** -- 15--25 MB per ABI.  Mitigate with Android App
   Bundle (per-ABI split) and stripping unused FFmpeg components.
3. **No Web support** -- keep video_player for `kIsWeb` builds.  Web IPTV is a
   secondary surface.
4. **Single-maintainer risk** -- fork `media_kit` into the org if upstream goes
   dormant.  The native dependency (libmpv) is independently maintained by the
   mpv project.

## Decision

**Deferred** -- pending:

1. [ ] Legal review of LGPL-only FFmpeg build for App Store / Play Store
   distribution.
2. [ ] Prototype `MediaKitStreamingService` behind feature flag; measure actual
   zap time on Fire TV Stick 4K and Chromecast with Google TV.
3. [ ] Measure APK size delta with `--disable-gpl` FFmpeg build.
4. [ ] Validate MPEG-TS and HEVC playback on target TV hardware.

If all four items clear, move status to **Accepted** and proceed with
migration plan.

## Consequences

### Positive

- Sub-second channel zap time on non-Web platforms.
- Universal codec support eliminates "channel won't play" class of bugs.
- Rich API enables direct live-edge queries, audio-track switching, and
  subtitle support without heuristics.
- Desktop (Linux/Windows) becomes a first-class playback target.

### Negative

- Binary size increase (~15--25 MB/ABI on Android).
- GPL/LGPL compliance burden (attribution, LGPL-only build, legal review).
- Two player backends to maintain (media_kit + video_player for Web).
- Community dependency with single-maintainer risk.

### Risks

- media_kit upstream abandonment; mitigated by forking.
- App Store rejection due to GPL interpretation; mitigated by LGPL-only build
  and dynamic linking.
- Regression in edge cases where ExoPlayer's adaptive streaming heuristics
  outperform libmpv's; mitigated by feature flag and A/B testing.

## Alternatives Considered

### Alternative 1: ExoPlayer tuning (no package change)

Tune ExoPlayer via `video_player` platform channel overrides:
`DefaultLoadControl.Builder().setBufferDurationsMs(...)`.  This can reduce zap
time to ~1 s but cannot fix codec gaps (MPEG-TS, AV1 software decode) and
requires Android-only native code.  Rejected as insufficient long-term.

### Alternative 2: flutter_vlc_player (libVLC)

Similar architecture to media_kit but wraps libVLC instead of libmpv.
libVLC carries the same LGPL/GPL license profile.  libmpv is preferred
because: (a) lighter binary, (b) better Flutter bindings (media_kit is more
actively maintained than flutter_vlc_player), (c) mpv's demuxer is faster for
live streams.

### Alternative 3: Platform-specific native players

Use ExoPlayer directly on Android (via platform channel), AVPlayer on iOS,
and libmpv only on desktop.  Maximizes platform-native behavior but triples
the maintenance surface and prevents code sharing in `platform_media`.
Rejected due to engineering cost.

## Related Decisions

- [ADR-0001](0001-package-structure.md) -- Modular package structure that
  enables swapping player backend within `platform_media` without touching
  feature packages.

## References

- media_kit: https://pub.dev/packages/media_kit
- mpv / libmpv: https://mpv.io/
- FFmpeg license FAQ: https://www.ffmpeg.org/legal.html
- ExoPlayer default load control: https://developer.android.com/media/media3/exoplayer/load-control
- Issue #770: Evaluate media_kit/libmpv backend
