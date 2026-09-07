# Aika Stream Store Listing Metadata

Canonical listing metadata for the first Google Play Android TV listing of
Aika Stream (`com.developerscoffee.tv.midas`). Feature claims stay inside
[Aika Stream Feature Matrix](./AIKA_STREAM_FEATURE_MATRIX.md). Do not claim recording,
cloud playlists, bundled channels, or a public IPTV catalogue.

See [Aika Stream Play Store gate](./AIKA_STREAM_PLAY_STORE_GATE.md) for the
package-ID cutover and human console actions.

## Release Scope

| Field | Value |
| --- | --- |
| Product | Aika Stream |
| Android package ID | `com.developerscoffee.tv.midas` |
| Entrypoint | `app/lib/main_tv.dart` |
| Device class | Android TV, Google TV, Fire TV-compatible APK testing, plus Android phone/tablet |
| First Play wave | Android TV / Google Play TV track, expanded to phone/tablet (`android.software.leanback` no longer `required`) |
| iOS / App Store | Deferred from the first Android publishing wave |
| Privacy Policy URL | `https://developerscoffee.github.io/airo/legal/privacy-policy/` |
| Terms URL | `https://developerscoffee.github.io/airo/legal/terms-conditions/` |

## Google Play Store

| Field | Final metadata |
| --- | --- |
| App name | `Aika Stream` |
| Short description | `Your sources. Your screen. An Android TV player for authorized M3U playlists.` |
| Category | Video Players & Editors |
| Tags / keywords | M3U, M3U8, playlist player, Android TV, Google TV, Chromecast, Cast, HLS |
| Privacy Policy URL | `https://developerscoffee.github.io/airo/legal/privacy-policy/` |
| Website | `https://developerscoffee.github.io/airo/aika-stream/` |
| Content rating | Complete the IARC questionnaire in Play Console before submission. |

Short description length: 77/80 characters.

### Full Description

```text
Aika Stream is a media player for Android TV and Google TV. Your sources.
Your screen.

Add an M3U or M3U8 playlist you are authorized to use, then browse, search,
and play it with a remote. The app does not include channels, playlists,
subscriptions, or a media catalog.

On Android TV you can:
• Load M3U, M3U8, Xtream, Stalker, or Jellyfin sources
• Search channels by name and keep favorites on the device
• Add an XMLTV guide for programs that are on now
• Switch audio and subtitle tracks when the stream provides them
• Browse USB or removable media on supported devices
• Use Chromecast when your TV, phone, and network allow it

Aika Stream is a player only. It does not provide, host, sell, or distribute
TV channels or IPTV services. Recording and cloud playlists are not included.

Learn more at https://developerscoffee.github.io/airo/aika-stream/

Playback depends on your source, codec, device, and network.
```

Full description length: 922/4,000 characters.

### Release notes (What's new)

Paste into Play Console → Internal testing → Release notes. Keep under 500
characters. Do not claim bundled channels or Aika Stream Pro.

```text
Your sources. Your screen.

Aika Stream is a remote-first player for authorized M3U and M3U8 sources on
Android TV. Search loaded channels by name, keep favorites on the device, add
an XMLTV guide, and play supported streams with a D-pad interface.

This app includes no channels, playlists, subscriptions, or media catalog. You
add sources you are authorized to use.

https://developerscoffee.github.io/airo/aika-stream/
```

## Google Play Assets

| Asset | Requirement | Status |
| --- | --- | --- |
| App icon | 512x512 PNG, 32-bit, alpha allowed | Exported: `docs/store-assets/airo-tv/play-icon-512x512.png`. |
| Feature graphic | 1024x500 PNG/JPG | Ready in `docs/store-assets/airo-tv/feature-graphic-1024x500.png`. |
| TV screenshots | 2-8 landscape screenshots, 1920x1080 recommended | Ready in `docs/store-assets/airo-tv/` (`01`–`04`). |
| Demo video | Optional YouTube URL | Recommended after screenshots. |

Screenshot capture guidance is maintained in
[Aika Stream Release Media Assets](./AIKA_STREAM_MEDIA_ASSETS.md).

## Apple App Store Draft

iOS/iPadOS publication is not part of the first v2 Android release wave. Keep
this draft for future App Store Connect preparation only; do not submit it
until maintainers explicitly add iOS or tvOS to the release scope.

| Field | Draft metadata |
| --- | --- |
| App name | `Aika Stream - IPTV Player` |
| Subtitle | `IPTV playlist player` |
| Category | Entertainment |
| Keywords | `iptv,m3u,m3u8,streaming,live tv,playlist,chromecast,android tv,player,channels` |
| Privacy Policy URL | `https://developerscoffee.github.io/airo/legal/privacy-policy/` |
| App Privacy | Complete App Store Connect nutrition labels before submission. |

Keyword length: 78/100 characters.

### App Store Description Draft

```text
Aika Stream is an IPTV playlist player for users who bring their own authorized
content sources. Import an M3U or M3U8 playlist URL, search channels by name,
and watch supported live streams through a clean interface.

Aika Stream does not provide channels, playlists, subscriptions, or IPTV services.
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
