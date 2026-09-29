# Android Auto Release & Integration Guide for Aika Stream / Airo

This document serves as the complete technical knowledge transfer and release runbook for deploying **Aika Stream / Airo** on **Android Auto** head units and passing Google Play Store quality reviews.

---

## 1. Architectural Blueprint & Dual-Engine Model

Aika Stream operates a dual audio/video player architecture designed for cross-device support:

| Domain | Audio/Media Player Engine | Projection / Rendering Strategy |
|---|---|---|
| **Music & Audio Streams** (`BeatsAudioHandler`) | `just_audio` (`^0.10.6`) + `audio_service` (`^0.18.19`) | Full audio media browser tree, high-res downscaled artwork (320x320 px max). |
| **IPTV / Live Streams** (`TvAudioHandler`) | `platform_media` (native `androidx.media3` ExoPlayer) | **Android Auto**: Audio-only track extraction, video surface detached.<br>**Android TV / Mobile / Tablet**: Full video surface rendering enabled. |

---

## 2. Declarations & Native Manifest Requirements

### A. Automotive App Descriptor
File: [automotive_app_desc.xml](file:///Users/udaychauhan/workspace/airo/app/android/app/src/main/res/xml/automotive_app_desc.xml)
```xml
<?xml version="1.0" encoding="utf-8"?>
<automotiveApp>
    <uses name="media" />
</automotiveApp>
```

### B. Android Manifest Configuration
File: [AndroidManifest.xml](file:///Users/udaychauhan/workspace/airo/app/android/app/src/main/AndroidManifest.xml)
```xml
<!-- Android Auto Metadata -->
<meta-data
    android:name="com.google.android.gms.car.application"
    android:resource="@xml/automotive_app_desc" />

<!-- Foreground Service Declaration -->
<service
    android:name="com.ryanheise.audioservice.AudioService"
    android:foregroundServiceType="mediaPlayback"
    android:exported="true">
    <intent-filter>
        <action android:name="android.media.browse.MediaBrowserService" />
    </intent-filter>
</service>

<!-- Multi-Platform Declarations -->
<uses-feature android:name="android.software.leanback" android:required="false" />
<uses-feature android:name="android.hardware.touchscreen" android:required="false" />
```

---

## 3. Player Engine & Network Tunnel Resilience

### A. Kotlin ExoPlayer 45s Forward Buffer Engine
`NextGenAutoPlayerEngine` configures a 45-second forward chunk buffer and a 15-second silent HTTP retry loop to handle cellular dead zones and vehicle tunnels:

```kotlin
package com.airo.media

import androidx.annotation.OptIn
import androidx.media3.common.C
import androidx.media3.common.TrackSelectionParameters
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory

@OptIn(UnstableApi::class)
object NextGenAutoPlayerEngine {

    fun createAutomotiveExoPlayer(context: android.content.Context): ExoPlayer {
        // 1. 45-second adaptive forward buffer
        val loadControl = DefaultLoadControl.Builder()
            .setBufferDurationsMs(15_000, 45_000, 2_500, 5_000)
            .setPrioritizeTimeOverSizeThresholds(true)
            .build()

        // 2. HTTP DataSource with 15s connection retries
        val httpDataSourceFactory = DefaultHttpDataSource.Factory()
            .setConnectTimeoutMs(15_000)
            .setReadTimeoutMs(15_000)
            .setAllowCrossProtocolRedirects(true)

        // 3. Build player instance
        val player = ExoPlayer.Builder(context)
            .setLoadControl(loadControl)
            .setMediaSourceFactory(
                DefaultMediaSourceFactory(context).setDataSourceFactory(httpDataSourceFactory)
            )
            .build()

        // 4. Detach video surface and enforce audio-only track selection
        player.setVideoSurface(null)
        val audioOnlyParams = player.trackSelectionParameters.buildUpon()
            .setTrackTypeDisabled(C.TRACK_TYPE_VIDEO, true)
            .setTrackTypeDisabled(C.TRACK_TYPE_TEXT, true)
            .build()
        player.trackSelectionParameters = audioOnlyParams

        return player
    }
}
```

### B. Unified Multi-Platform Factory (`UnifiedPlayerEngineFactory`)
Dynamically keeps video surfaces active on Android TV / Tablets / Phones while enforcing audio-only degradation on Android Auto car projection sessions.

---

## 4. Voice Navigation & Driver Distraction Guidelines (DDG)

### A. Dart `MediaItem` Content Style Hints & Downscaling
```dart
MediaItem buildAutoMediaItem({
  required String id,
  required String title,
  required String artist,
  required Uri artUri,
  bool isBrowsable = false,
}) {
  // Cap artwork dimensions to 320x320 to prevent projection ANRs
  final optimizedArtUri = artUri.replace(
    queryParameters: {
      ...artUri.queryParameters,
      'w': '320',
      'h': '320',
      'fit': 'crop',
    },
  );

  return MediaItem(
    id: id,
    title: title,
    artist: artist,
    artUri: optimizedArtUri,
    playable: !isBrowsable,
    extras: {
      'android.media.browse.CONTENT_STYLE_SUPPORTED': true,
      'android.media.browse.CONTENT_STYLE_BROWSABLE_HINT': 2, // Grid view for categories
      'android.media.browse.CONTENT_STYLE_PLAYABLE_HINT': 1,  // List view for streams
    },
  );
}
```

### B. Google Assistant & Gemini Live `playFromSearch`
`BeatsAudioHandler` fuzzy matches query tokens against channel titles, artists, and genres. If unauthenticated or unmatched, it broadcasts `PlaybackStateCompat.STATE_ERROR` with an audio prompt ("Please log into Aika Stream on your phone when safely parked") instead of stalling the head unit.

---

## 5. Local Sideload & Physical Car Testing (e.g. Honda Elevate)

To test a non-debug build directly on a car head unit before Google Play Store review:

1. **Unlock Developer Mode**: Open Android Auto settings on test phone > Scroll to bottom > Tap **Version** 10 times rapidly > Tap 3-dots (top right) > **Developer settings** > Check **Unknown sources**.
2. **Un-hide Launcher Icon**: Phone Settings > Android Auto > **Customize launcher** > Ensure **Aika Stream** is checked.
3. **Clear Cache**: Phone Settings > Apps > Android Auto > Storage & cache > **Clear cache**.
4. **Compile Non-Debug Release APK**:
   ```bash
   cd app && flutter build apk --release -t lib/main_tv.dart
   ```
5. **Install via ADB**:
   ```bash
   adb install -r app/build/app/outputs/flutter-apk/app-release.apk
   ```

---

## 6. Google Play Console Opt-In & Release Steps

1. **Opt In to Android Auto**:
   - Google Play Console > Select App (`io.airo.app` or `com.developerscoffee.tv.midas`) > **Setup** > **Advanced settings**.
   - Select **Release types** > **Add release type** > Select **Android Auto**.
   - Complete the Driver Distraction Guidelines checklist.

2. **Trigger Automated Deployment**:
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```
   *The GitHub Actions workflow [.github/workflows/google_play_release.yml](file:///Users/udaychauhan/workspace/airo/.github/workflows/google_play_release.yml) automatically builds the signed `.aab` bundle and uploads it to the Google Play Internal Track.*
