# Airo TV Store Listing Metadata

Canonical listing metadata for the Airo TV v2 Android TV release profile.
This copy is scoped to the shipped v0.0.2 feature set in
[Airo TV Feature Matrix](./AIRO_TV_FEATURE_MATRIX.md). Do not claim planned
features such as EPG, favorites, recording, cloud playlists, or bundled
channels until the feature matrix marks them supported.

## Release Scope

| Field | Value |
| --- | --- |
| Product | Airo TV |
| Android package ID | `io.airo.app.tv` |
| Entrypoint | `app/lib/main_tv.dart` |
| Device class | Android TV, Google TV, Fire TV-compatible APK testing |
| First v2 wave | Android TV / Google Play TV track |
| iOS / App Store | Deferred from the first v2 Android publishing wave |
| Privacy Policy URL | `https://developerscoffee.github.io/airo/legal/privacy-policy/` |
| Terms URL | `https://developerscoffee.github.io/airo/legal/terms-conditions/` |

## Google Play Store

| Field | Final metadata |
| --- | --- |
| App name | `Airo TV - IPTV Player` |
| Short description | `Play your own IPTV playlists on Android TV with Cast support.` |
| Category | Entertainment / Video Players & Editors |
| Tags / keywords | IPTV, M3U, M3U8, streaming, live TV, playlist, Android TV, Google TV, Chromecast, Cast |
| Privacy Policy URL | `https://developerscoffee.github.io/airo/legal/privacy-policy/` |
| Content rating | Complete the IARC questionnaire in Play Console before submission. |

Short description length: 61/80 characters.

### Full Description

```text
Airo TV is an IPTV player for Android TV, Google TV, and compatible TV devices.
Bring your own authorized M3U or M3U8 playlist and watch live streams in a
clean, remote-friendly interface built for the living room.

Key features:
- Import your own M3U/M3U8 playlist URL
- Browse and search channels by name
- Play supported HLS and media streams on TV devices
- Use Chromecast/Cast controls where supported by your device and network
- Keep playlists local unless you choose to load a remote playlist URL
- Use a TV-focused interface designed for remote navigation

Important content notice:
Airo TV is a media player only. It does not provide, host, sell, endorse,
verify, or distribute channels, playlists, streams, subscriptions, or IPTV
services. You must supply your own legal content sources and ensure that you
have the rights to access every stream you load.

Supported playlist formats:
M3U and M3U8.

Playback support depends on the stream format, codec, device capability, and
network connection. Some planned features, including EPG, favorites, recording,
and cloud playlists, are not included in this release.
```

Full description length: 1,122/4,000 characters.

## Google Play Assets

| Asset | Requirement | Status |
| --- | --- | --- |
| App icon | 512x512 PNG, 32-bit, alpha allowed | Launcher icon exists; export final Play asset before submission. |
| Feature graphic | 1024x500 PNG/JPG | Required before Play submission. |
| TV screenshots | 2-8 landscape screenshots, 1920x1080 recommended | Required before Play submission. |
| Demo video | Optional YouTube URL | Recommended after screenshots. |

Screenshot capture guidance is maintained in
[Airo TV Release Media Assets](./AIRO_TV_MEDIA_ASSETS.md).

## Apple App Store Draft

iOS/iPadOS publication is not part of the first v2 Android release wave. Keep
this draft for future App Store Connect preparation only; do not submit it
until maintainers explicitly add iOS or tvOS to the release scope.

| Field | Draft metadata |
| --- | --- |
| App name | `Airo TV - IPTV Player` |
| Subtitle | `IPTV playlist player` |
| Category | Entertainment |
| Keywords | `iptv,m3u,m3u8,streaming,live tv,playlist,chromecast,android tv,player,channels` |
| Privacy Policy URL | `https://developerscoffee.github.io/airo/legal/privacy-policy/` |
| App Privacy | Complete App Store Connect nutrition labels before submission. |

Keyword length: 78/100 characters.

### App Store Description Draft

```text
Airo TV is an IPTV playlist player for users who bring their own authorized
content sources. Import an M3U or M3U8 playlist URL, search channels by name,
and watch supported live streams through a clean interface.

Airo TV does not provide channels, playlists, subscriptions, or IPTV services.
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
