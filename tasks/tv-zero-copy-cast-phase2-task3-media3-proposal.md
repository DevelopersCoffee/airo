# Task 3 Proposal: Media3 dependency for the receiver streaming engine

Status: awaiting explicit user confirmation before Task 4 touches
`app/android/app/build.gradle.kts` (SPEC.md AD-P2.4 / plan boundary).

## Proposed artifacts

```kotlin
// app/android/app/build.gradle.kts, inside dependencies { }
if (isTvVariant) {
    implementation("androidx.media3:media3-exoplayer:1.11.0")
    implementation("androidx.media3:media3-common:1.11.0")
    implementation("androidx.media3:media3-datasource:1.11.0")
    implementation("androidx.media3:media3-exoplayer-hls:1.11.0")
}
```

Gating pattern (`if (isTvVariant) { implementation(...) }`) matches the
existing precedent already in this file for `!isCoinsVariant`-gated
dependencies (ML Kit GenAI, LiteRT-LM, lifecycle/coroutines) — confirmed
by reading the current `dependencies {}` block, not assumed. Phone/Mind/
Coins builds do not get Media3 on their classpath.

**Module choice, and why each one:**
- `media3-exoplayer` — the player engine itself; required.
- `media3-common` — shared types (`MediaItem`, `Player` interface) the
  custom `DataSource` and event-stream code (Task 5) will need.
- `media3-datasource` — the `DataSource` interface Wave B's custom
  implementation extends (F4.1/F4.2). Included now so Task 4's minimal
  `PlatformView` proof can already target the real interface shape
  instead of a stand-in.
- `media3-exoplayer-hls` — most community IPTV sources are HLS
  (`.m3u8`); raw MPEG-TS plays through the same core extractor without
  this module, but HLS is common enough in practice that Task 4's test
  stream will likely be HLS, so this is included from the start rather
  than added piecemeal.

Not proposed yet: `media3-ui` (Flutter owns UI via `PlatformView`, no
Media3 `PlayerView` needed), `media3-session` (MediaSession integration
— existing `audio_service`/`StreamingMediaSessionDelegate` already own
that surface, revisit only if a real conflict shows up), DASH/RTSP
extension modules (not in this repo's provider mix per requirements
doc's own framing — "raw MPEG-TS... is the dominant IPTV format").

## Version: 1.11.0 (stable, released 2026-07-07)

Confirmed via web search against Maven/Android Developers, not assumed
from training data (current as of this proposal):
[Media3 | Jetpack | Android Developers](https://developer.android.com/jetpack/androidx/releases/media3),
[Maven Repository: androidx.media3](https://mvnrepository.com/artifact/androidx.media3)

## Compatibility

- **minSdk:** Media3 1.11.0 requires API 23 (Android 6.0). This
  project's `minSdk = 26` (`build.gradle.kts:121`) — no conflict, no
  minSdk bump needed anywhere.
- **compileSdk:** project is at 36; Media3 1.11.0 targets current
  Android APIs, no known incompatibility.
- **AGP:** project is on AGP 9.3.1 (recent); Media3 1.11.0 is current
  and expects a modern AGP, no known incompatibility.
- **Kotlin/JVM target:** project targets JVM 17; no Media3 constraint
  conflicts with that.

## License

Apache License 2.0 — same as the rest of AndroidX and the project's
existing dependency set. No new license category introduced.
[GitHub - androidx/media](https://github.com/androidx/media)

## APK size impact — honest limits of this estimate

I could not find a precise, current number for these 4 modules combined
at 1.11.0 specifically; general guidance found:
[APK shrinking | Android media | Android Developers](https://developer.android.com/media/media3/exoplayer/shrinking).
What that page does confirm: ExoPlayer's `DefaultRenderersFactory`
pulls in every renderer implementation, which R8/ProGuard code shrinking
can then strip down substantially (the page cites ~40% reduction for a
DASH-playing app with shrinking enabled) — but the *unshrunk* number
depends on exactly which classes end up reachable from this app's code,
which doesn't exist yet.

**What I can respons­ibly say:** this is a mid-size native dependency
(comparable in scale to the `media_kit`/libmpv stack already in this
repo for phone, which the TV variant's packaging block already excludes
— see `build.gradle.kts` around line 282). It's `isTvVariant`-gated, so
it cannot affect phone/Mind/Coins APK size at all. **What I can't say
without measuring:** the exact MB delta on the TV APK, or whether it
threatens NFR-12 (cold start < 4s) or the implicit Fire TV Stick Lite
size budget. Recommend measuring via `flutter build apk --target-platform
android-arm64` size diff (before/after) once Task 4 actually adds the
dependency — that's a real number, this proposal's estimate is not.

## Confirmation needed

Per SPEC.md AD-P2.4, Task 4 does not touch `build.gradle.kts` until this
proposal is explicitly confirmed — not implied by a general "keep going."
