# Aika Stream Spatial Mode — PCM tap spike (#2081)

Parent epic: [#2080](https://github.com/DevelopersCoffee/airo/issues/2080).

## Current audio paths (verified in-repo)

| Journey | Dart entry | Native backend | PCM visibility |
|--------|------------|----------------|----------------|
| **Aika Stream IPTV (production TV/phone)** | `feature_iptv` → `VideoPlayerStreamingService` | `VideoPlayerAiroPlaybackEngine` → Flutter `video_player` → ExoPlayer (Android) / AVPlayer (iOS) | **TV (Aika Stream APK): PCM tap via forked `video_player_android`** (`AiroExoRenderersFactoryBridge` → `AiroSpatialPcmTap.renderersFactory`). **Phone/other flavors:** still opaque (stock pub.dev plugin). |
| **TV Media3 streaming surface (in progress)** | `platform_streaming_engine` → `AiroStreamingSurfaceView` | `AiroStreamingSurfaceViewFactory` → Media3 `ExoPlayer` | **Tap installed (this spike)** — `AiroIdentitySpatialAudioProcessor` on `DefaultAudioSink` |
| **Desktop fallback** | same resolver | `MpvAiroPlaybackEngine` | Opaque at Dart layer |
| **Web** | `video_player` `<video>` | browser decode | Opaque |

On **Aika Stream TV APK**, IPTV `ExoPlayer` instances built by the forked
`video_player_android` plugin (Media3 **1.11.1**, matched to the app) share
`AiroSpatialPcmTap.renderersFactory` with the streaming-engine surface. The PCM
processor extends Media3 `BaseAudioProcessor` and is **inactive in Original mode**
(`AudioFormat.NOT_SET`) so behavior matches stock `DefaultAudioSink`. Other
flavors still use pub.dev `video_player_android` (opaque).

## Proposed tap point

```
decode (MediaCodec) → PCM → [AiroIdentitySpatialAudioProcessor] → AudioTrack / AAudio
```

Implementation: `DefaultRenderersFactory.buildAudioSink()` override in
`AiroSpatialPcmTap.renderersFactory()`, wired via
`AiroExoRenderersFactoryBridge` (IPTV) and `AiroStreamingSurfaceViewFactory`
(streaming surface POC).

`AiroSpatialAudioMode.original` → processor `isActive() == false` (zero added latency).  
`AiroSpatialAudioMode.spatial` → identity copy today; binaural DSP replaces the copy in #2082.

## Latency / A–V skew risks

- **Original mode:** processor inactive — no extra buffer stage.
- **Spatial mode (identity):** one in-memory copy per audio buffer; expect sub‑millisecond CPU on stereo 48 kHz vs the ~50 ms epic budget. Real DSP must stay buffer-size stable and avoid main-thread work.
- **IPTV TV path:** mode toggles processor `isActive()` on the shared native singleton; identity copy only when Spatial is on.

## Framework contract (`platform_player`)

- `AiroSpatialAudioMode` — `original` (default) | `spatial`
- `AiroPlaybackEngine.spatialAudioMode` / `setSpatialAudioMode` / `querySpatialAudioTap`
- `AiroSpatialPcmProcessor` + `AiroIdentitySpatialPcmProcessor` (Dart reference)
- `AiroSpatialAudioPlatform` — `com.airo.player/spatial_audio` method channel (TV Media3 status)

Store copy remains **“Spatial Mode (experimental)”** — no third-party spatial trademarks in v1.

## Next steps (#2082+)

1. Replace identity processor with on-device binaural / safe upmix (Oboe/AAudio out if needed).
2. In-player toggle + analytics (#2083 beyond Playback Settings).
3. Remote kill-switch to Original.
4. iOS / web parity or explicit “Android TV only” gating in UI.
5. Device matrix QA (#2084).

## Future native multichannel (PR notes only — out of scope here)

- **IAMF:** When users supply IAMF-bearing streams, Media3 IAMF decoder paths would decode to PCM *before* the same tap (no IAMF encode in client v1).
- **Passthrough:** AC-3/E-AC-3/JIS DTS bitstream passthrough to HDMI/SPDIF is a different product path (receiver handles decode/spatial). This spike does **not** add Dolby/DTS SDK decode or certification-branded spatial audio.

## Emulator smoke — iptv-org public playlist

Prerequisites: Android SDK, emulator API 30+, `AIRO_ALLOW_ANDROID_EMULATOR=true` (repo policy).

```bash
cd /path/to/airo
export AIRO_ALLOW_ANDROID_EMULATOR=true
make boot-pixel9   # or any API 30+ AVD with Google APIs

cd app
cp pubspec_tv.yaml pubspec.yaml && flutter pub get

eval "$(../scripts/aika_stream_version.sh)"
flutter run -d emulator-5554 \
  -t lib/main_tv.dart \
  --dart-define=APP_VARIANT=tv \
  --dart-define=APP_PLATFORM=androidTv \
  --build-name="$AIKA_STREAM_BUILD_NAME" \
  --build-number="$AIKA_STREAM_BUILD_NUMBER"
```

In app:

1. Log in (demo credentials if shown).
2. Add playlist URL: `https://iptv-org.github.io/iptv/index.m3u`
3. Open any stereo channel → confirm playback with Spatial **off** (Original).
4. Settings → Playback → enable **Spatial Mode (experimental)** → replay channel.
5. Verify tap (Spatial **must be ON** — Original keeps the processor inactive, so no
   `pcm_after_decode` lines): `adb logcat -s AiroSpatial` → `using AiroSpatialPcmTap
   renderers factory` at player create, then `pcm_after_decode passthrough` during playback.
6. Optional: `adb logcat -s AiroStreamingSurface` for the separate Media3 test surface.

Release-style TV APK: `make build-tv` (runs `scripts/build-tv.sh` with `pubspec_tv.yaml` swap).

## Cloud agent note

This VM has no Android emulator / Flutter SDK in PATH for the agent shell; validation is `flutter test` / `flutter analyze` on touched packages when the SDK is available, plus Kotlin compile via Gradle on developer/CI hosts.
