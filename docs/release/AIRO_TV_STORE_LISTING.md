# Midas Stream Store Listing Metadata

Canonical listing metadata for the first Google Play Android TV listing of
Midas Stream (`com.developerscoffee.tv.midas`). Feature claims stay inside
[Midas Stream Feature Matrix](./AIRO_TV_FEATURE_MATRIX.md). Do not claim recording,
cloud playlists, bundled channels, or a public IPTV catalogue.

See [Midas Stream Play Store gate](./MIDAS_STREAM_PLAY_STORE_GATE.md) for the
package-ID cutover and human console actions.

## Release Scope

| Field | Value |
| --- | --- |
| Product | Midas Stream |
| Android package ID | `com.developerscoffee.tv.midas` |
| Entrypoint | `app/lib/main_tv.dart` |
| Device class | Android TV, Google TV, Fire TV-compatible APK testing |
| First Play wave | Android TV / Google Play TV track |
| iOS / App Store | Deferred from the first Android publishing wave |
| Privacy Policy URL | `https://developerscoffee.github.io/airo/legal/privacy-policy/` |
| Terms URL | `https://developerscoffee.github.io/airo/legal/terms-conditions/` |

## Google Play Store

| Field | Final metadata |
| --- | --- |
| App name | `Midas Stream` |
| Short description | `Play your own authorized playlists on Android TV.` |
| Category | Video Players & Editors |
| Tags / keywords | M3U, M3U8, playlist player, Android TV, Google TV, Chromecast, Cast, HLS |
| Privacy Policy URL | `https://developerscoffee.github.io/airo/legal/privacy-policy/` |
| Content rating | Complete the IARC questionnaire in Play Console before submission. |

Short description length: 51/80 characters.

### Full Description

```text
Midas Stream is a media player for Android TV, Google TV, and compatible TV
devices. Bring your own authorized M3U or M3U8 playlist and watch it in a
clean, remote-friendly living-room interface.

This app does not include channels, playlists, or subscriptions. You add the
sources you already have the right to use.

Key features:
- Import your own M3U/M3U8 playlist URL
- Browse and search entries by name
- Add XMLTV guide sources and favorites for playlists you configured
- Play supported HLS and media streams on TV devices
- Use Chromecast/Cast controls where supported by your device and network
- Keep playlist URLs on the device unless you choose a remote URL
- Use a TV-focused interface designed for remote navigation

Important content notice:
Midas Stream is a media player only. It does not provide, host, sell, endorse,
verify, or distribute channels, playlists, streams, subscriptions, or IPTV
services. You must supply your own lawful content sources and ensure that you
have the rights to access every stream you load.

Supported playlist formats:
M3U and M3U8.

Playback support depends on the stream format, codec, device capability, and
network connection. Recording and cloud playlists are not included.
```

Full description length: 1,122/4,000 characters.

## Google Play Assets

| Asset | Requirement | Status |
| --- | --- | --- |
| App icon | 512x512 PNG, 32-bit, alpha allowed | Exported: `docs/store-assets/airo-tv/play-icon-512x512.png`. |
| Feature graphic | 1024x500 PNG/JPG | Ready in `docs/store-assets/airo-tv/feature-graphic-1024x500.png`. |
| TV screenshots | 2-8 landscape screenshots, 1920x1080 recommended | Ready in `docs/store-assets/airo-tv/` (`01`–`04`). |
| Demo video | Optional YouTube URL | Recommended after screenshots. |

Screenshot capture guidance is maintained in
[Midas Stream Release Media Assets](./AIRO_TV_MEDIA_ASSETS.md).

## Apple App Store Draft

iOS/iPadOS publication is not part of the first v2 Android release wave. Keep
this draft for future App Store Connect preparation only; do not submit it
until maintainers explicitly add iOS or tvOS to the release scope.

| Field | Draft metadata |
| --- | --- |
| App name | `Midas Stream - IPTV Player` |
| Subtitle | `IPTV playlist player` |
| Category | Entertainment |
| Keywords | `iptv,m3u,m3u8,streaming,live tv,playlist,chromecast,android tv,player,channels` |
| Privacy Policy URL | `https://developerscoffee.github.io/airo/legal/privacy-policy/` |
| App Privacy | Complete App Store Connect nutrition labels before submission. |

Keyword length: 78/100 characters.

### App Store Description Draft

```text
Midas Stream is an IPTV playlist player for users who bring their own authorized
content sources. Import an M3U or M3U8 playlist URL, search channels by name,
and watch supported live streams through a clean interface.

Midas Stream does not provide channels, playlists, subscriptions, or IPTV services.
Users are responsible for loading only legal content sources that they have the
right to access.
```

## Console Fields Requiring Human Action

- Google Play IARC/content rating questionnaire.
- Google Play Data Safety form.
- Final Play listing upload and stakeholder approval.
- Final Play icon, feature graphic, screenshots, and optional demo video.
- Any future Apple App Store Connect app record, privacy nutrition labels,
  screenshots, signing setup, and TestFlight/App Store upload credentials.
