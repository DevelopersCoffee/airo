# Aika Stream Spatial Mode — PCM tap spike (#2081)

Parent epic: [#2080](https://github.com/DevelopersCoffee/airo/issues/2080).

## Current audio paths (verified in-repo)

| Journey | Dart entry | Native backend | PCM visibility |
|--------|------------|----------------|----------------|
| **Aika Stream IPTV (production TV/phone)** | `feature_iptv` → `VideoPlayerStreamingService` | `VideoPlayerAiroPlaybackEngine` → Flutter `video_player` → ExoPlayer (Android) / AVPlayer (iOS) | **Opaque** — no `AudioProcessor` / custom `DefaultAudioSink` hook in our code |
| **TV Media3 streaming surface (in progress)** | `platform_streaming_engine` → `AiroStreamingSurfaceView` | `AiroStreamingSurfaceViewFactory` → Media3 `ExoPlayer` | **Tap installed (this spike)** — `AiroIdentitySpatialAudioProcessor` on `DefaultAudioSink` |
| **Desktop fallback** | same resolver | `MpvAiroPlaybackEngine` | Opaque at Dart layer |
| **Web** | `video_player` `<video>` | browser decode | Opaque |

Decoded audio reaches the device on Android IPTV today entirely inside the stock `video_player` ExoPlayer instance. Spatial Mode UI (#2083) must not assume a PCM tap exists until IPTV playback migrates to the Media3 engine (or we fork/extend the Android `video_player` embedding).

## Proposed tap point

```
decode (MediaCodec) → PCM → [AiroIdentitySpatialAudioProcessor] → AudioTrack / AAudio
```

Implementation: `DefaultRenderersFactory.buildAudioSink()` override in `AiroSpatialPcmTap.renderersFactory()`, wired in `AiroStreamingSurfaceViewFactory` (`tv` flavor only).

`AiroSpatialAudioMode.original` → processor `isActive() == false` (zero added latency).  
`AiroSpatialAudioMode.spatial` → identity copy today; binaural DSP replaces the copy in #2082.

## Latency / A–V skew risks

- **Original mode:** processor inactive — no extra buffer stage.
- **Spatial mode (identity):** one in-memory copy per audio buffer; expect sub‑millisecond CPU on stereo 48 kHz vs the ~50 ms epic budget. Real DSP must stay buffer-size stable and avoid main-thread work.
- **IPTV `video_player` path:** toggling mode in Dart updates contract state only until native hook lands — no skew change yet.

## Framework contract (`platform_player`)

- `AiroSpatialAudioMode` — `original` (default) | `spatial`
- `AiroPlaybackEngine.spatialAudioMode` / `setSpatialAudioMode` / `querySpatialAudioTap`
- `AiroSpatialPcmProcessor` + `AiroIdentitySpatialPcmProcessor` (Dart reference)
- `AiroSpatialAudioPlatform` — `com.airo.player/spatial_audio` method channel (TV Media3 status)

Store copy remains **“Spatial Mode (experimental)”** — no third-party spatial trademarks in v1.

## Next steps (#2082+)

1. Route Aika Stream IPTV `ExoPlayer` through the same `DefaultAudioSink` processor chain (Media3 migration or controlled `video_player` Android fork).
2. Replace identity processor with on-device binaural / safe upmix (Oboe/AAudio out if needed).
3. Persist mode per device; remote kill-switch to Original.
4. Device matrix QA (#2084) — this spike targets **Android emulator smoke only**.

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
3. Open any stereo channel → confirm playback (Original path — stock `video_player` audio).
4. Optional: `adb logcat -s AiroStreamingSurface` if exercising the Media3 test surface (separate from main IPTV grid).

Release-style TV APK: `make build-tv` (runs `scripts/build-tv.sh` with `pubspec_tv.yaml` swap).

## Cloud agent note

This VM has no Android emulator / Flutter SDK in PATH for the agent shell; validation is `flutter test` / `flutter analyze` on touched packages when the SDK is available, plus Kotlin compile via Gradle on developer/CI hosts.
