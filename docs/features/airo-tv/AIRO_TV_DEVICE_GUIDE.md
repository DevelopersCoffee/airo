# Airo TV Device Guide

Last reviewed: 2026-07-16

Airo TV is a bring-your-own-content IPTV and personal media player. It does not
sell, bundle, recommend, or unlock channels. Use only playlist URLs, EPG data,
and media sources that you are authorized to access.

This guide mirrors the shape of a public IPTV tutorial hub: setup by device,
common tutorials, troubleshooting, and a clear feature-status table for current
Airo TV v2 work.

## Supported Device Paths

| Device path | Current guidance | Status |
| --- | --- | --- |
| Android TV / Google TV | Primary TV experience. Use the TV remote to add or load an authorized playlist, browse Live TV, search channels, open Guide, and start playback. | Supported v2 target |
| Fire TV / Fire TV Stick | Install the compatible Android TV APK path when available for testing. Use the Fire TV remote like a TV D-pad remote. | Compatible/qualification target |
| Android phone / tablet | Use for mobile playback and validation where a mobile build is available. TV pairing, web-editor style organization, and full companion sync are not complete v2 features yet. | Partial |
| Chromecast / Google Cast | Cast playback from a supported sender build to a discovered receiver on the same network. VPNs and guest Wi-Fi can block discovery. | Supported by existing Cast work; device QA still applies |
| Desktop / macOS builds | Use only where an Airo TV desktop artifact is explicitly published for the release line. Feature behavior can differ from TV builds. | Release-dependent |
| Legacy / low-memory TV boxes | Prefer search, recent channels, and compact guide views. Avoid very large playlists until the device passes the v2 qualification profile. | Qualification target |

## Quick Start: Android TV and Google TV

1. Install the Airo TV build from the approved release channel for the device.
2. Open Airo TV and confirm that no channels appear until you add your own
   authorized source.
3. Add an M3U playlist URL or local test playlist through the available source
   entry flow.
4. Open Live TV to browse channels.
5. Use Search for large playlists instead of scrolling every category.
6. Open Guide to see current/next programme data when compact EPG data is
   available.
7. Select a channel to start playback.
8. Use Back to return to channel browsing and Go Live when playback has drifted
   from the live edge.

## Quick Start: Fire TV

1. Install the Fire TV-compatible Airo TV APK only from a trusted release source.
2. If sideloading is required for testing, enable installation only for the
   installer app you are using, then turn it off again after installation.
3. Add your own authorized M3U source.
4. Navigate with the D-pad, Select, Back, Play/Pause, and menu buttons.
5. If focus movement feels wrong on a Fire TV remote, capture the device model,
   Fire OS version, and the screen where focus was lost.

Fire TV remains a qualification target until release evidence confirms remote
focus, playback, Cast behavior, and performance across representative devices.

## Quick Start: Android Phone or Tablet

1. Install the matching Airo build for the release line.
2. Add the same authorized playlist used on TV.
3. Use the phone or tablet to validate playlist parsing, search, playback, and
   Cast discovery.
4. Cast to a TV receiver when both devices are on the same usable network.

Phone-to-TV pairing, remote control, favorites sync, and web-editor style
organization are planned work, not guaranteed current v2 behavior.

## Quick Start: Chromecast / Google Cast

1. Put the phone/tablet sender and receiver on the same network.
2. Start Airo TV from the sender build that includes Cast controls.
3. Open the Cast picker and choose the receiver.
4. Start a playable stream from an authorized playlist.
5. If the receiver does not appear, disable guest isolation, check VPN routing,
   and verify that both devices can see other local-network services.

## Tutorials

### 1. Add IPTV Access

Airo TV supports bring-your-own playlists. The expected user input is an
authorized M3U source. Airo TV should never imply that it provides channels,
subscriptions, or credentials.

If channels do not appear:

- Confirm the playlist URL is reachable on the same device/network.
- Confirm the source is M3U or another provider type currently supported by the
  build.
- Try a smaller known-good playlist to separate source problems from device
  performance problems.
- Refresh the source after network changes.

### 2. Browse Live TV

Use Live TV for the main channel list. On TV devices, D-pad navigation is the
primary interaction model. For large playlists, Search and recent channels are
the fastest paths.

Expected current behavior:

- M3U channels can load through the IPTV provider path.
- M3U8 streams can play when the platform decoder supports the stream.
- Large playlist performance depends on the v2 worker and virtualization work.

### 3. Use the Guide

The current v2 guide is a compact TV guide. It shows channels with current/next
programme information when compact EPG data exists. It is not yet the full
multi-hour grid experience.

If guide data is missing:

- Confirm the source includes compatible EPG/XMLTV data.
- Confirm the channel identifiers match between playlist and EPG source.
- Expect channels to remain playable even when guide metadata is unavailable.

Full grid, guide search, and XMLTV source management are tracked in
[issue #825](https://github.com/DevelopersCoffee/airo/issues/825).

### 4. Favorites and Organization

Favorites, hidden categories, and durable TV organization are planned v2 work.
Until that lands, use Search, recent channels, and source cleanup outside the
app to keep navigation manageable.

Tracked work:

- [issue #826](https://github.com/DevelopersCoffee/airo/issues/826): favorites
  and hidden categories with persistence.
- [issue #821](https://github.com/DevelopersCoffee/airo/issues/821): smart
  playlists and canonical channels.
- [issue #833](https://github.com/DevelopersCoffee/airo/issues/833):
  companion pairing and TV organization sync.

### 5. Player and Playback Controls

Current player guidance:

- Select a channel to play.
- Use Play/Pause where supported by the platform.
- Use Back to leave playback.
- Use Go Live when live playback falls behind the live edge.
- Use Cast controls only from builds that expose the Cast sender path.

Planned playback improvements:

- [issue #820](https://github.com/DevelopersCoffee/airo/issues/820): audio
  track selection, subtitle/track handling, and VOD timeline behavior.
- [issue #812](https://github.com/DevelopersCoffee/airo/issues/812): captions,
  accessibility, and TV surf mode.

### 6. TimeShift and Recording

TimeShift and local recording are not current v2 user-facing features. They
need storage, privacy, background execution, provider-policy, and device-profile
decisions before UI work.

Tracked work:

- [issue #831](https://github.com/DevelopersCoffee/airo/issues/831): TimeShift
  and recording capability.

### 7. Provider Types and VOD

Current public guidance should lead with M3U/M3U8 support. Additional provider
adapters and local VOD listing are planned work.

Tracked work:

- [issue #823](https://github.com/DevelopersCoffee/airo/issues/823): Xtream,
  Stalker, and Jellyfin provider adapter contracts.
- [issue #824](https://github.com/DevelopersCoffee/airo/issues/824): local VOD
  listing over bring-your-own-content sources.
- [issue #827](https://github.com/DevelopersCoffee/airo/issues/827): TV
  settings and provider management.

### 8. Remote Control and TV Input

TV devices must work well with D-pad remotes first. Numeric channel entry,
button remapping, and richer TV input behavior are tracked separately.

Tracked work:

- [issue #828](https://github.com/DevelopersCoffee/airo/issues/828): TV remote
  UX, numeric entry, button remapping, and TV input framework.

### 9. Network Protection and VPN Behavior

Airo TV does not bundle a VPN. If a user chooses to use a VPN, it can affect
playlist loading, playback, and local device discovery for Cast.

Planned v2 work is an opt-in network-protection mode that can explain protected,
unprotected, blocked, and local-discovery-limited states without recommending a
VPN provider.

Tracked work:

- [issue #832](https://github.com/DevelopersCoffee/airo/issues/832): VPN and
  network protection mode.

## Troubleshooting

| Problem | Checks |
| --- | --- |
| No channels show | Confirm the playlist URL, network access, source format, and whether the playlist works in a small controlled test. |
| A stream does not play | Try another channel from the same source, check whether the stream is M3U8, and capture the playback error if diagnostics are available. |
| Guide is empty | Confirm EPG/XMLTV data exists and channel IDs match. Playback can still work without guide metadata. |
| Cast device is missing | Check same-network access, guest Wi-Fi isolation, VPN routing, and receiver availability. |
| Fire TV focus gets stuck | Record device model, Fire OS version, screen name, and the remote action that failed. |
| Large playlist feels slow | Use Search/recent channels and validate against a smaller playlist; large-list hardening is active v2 work. |
| Phone works but TV does not | Compare network, decoder support, playlist source, and whether the TV build is a qualified release build. |

## Feature Status Matrix

| Feature | Current v2 status | Tracking |
| --- | --- | --- |
| Bring-your-own M3U playlist | Supported target | Existing IPTV provider path |
| M3U8 playback | Supported when decoder/network allow it | Existing player path |
| Android TV / Google TV | Supported target | Release qualification |
| Fire TV | Compatible qualification target | Release qualification |
| Phone/tablet playback | Partial, build-dependent | Release qualification |
| Google Cast | Supported by Cast work, still device-sensitive | Existing Cast epic and QA |
| Compact current/next guide | Partial/current | Existing guide screen |
| Full EPG grid/search/XMLTV management | Planned | [#825](https://github.com/DevelopersCoffee/airo/issues/825) |
| Favorites and hidden categories | Planned | [#826](https://github.com/DevelopersCoffee/airo/issues/826) |
| Xtream/Stalker/Jellyfin adapters | Planned | [#823](https://github.com/DevelopersCoffee/airo/issues/823) |
| VOD listing | Planned | [#824](https://github.com/DevelopersCoffee/airo/issues/824) |
| Track selection/subtitles/VOD timeline | Planned | [#820](https://github.com/DevelopersCoffee/airo/issues/820) |
| TimeShift/recording | Gap now tracked | [#831](https://github.com/DevelopersCoffee/airo/issues/831) |
| VPN/network protection mode | Gap now tracked | [#832](https://github.com/DevelopersCoffee/airo/issues/832) |
| Web-editor style TV organization | Gap now tracked | [#833](https://github.com/DevelopersCoffee/airo/issues/833) |
| Bundled channels or subscriptions | Not supported | Out of scope |

## Release and Milestone Notes

The tutorial-parity items above are assigned to the active v2 product-hardening
milestone, `v2.0.0.1 - Airo TV Platform Hardening`, because they are user-facing
Airo TV capability gaps. Performance-only work remains in the separate Airo TV
v2 performance milestone.

Public user guides must be updated only after each feature reaches release
qualification. Until then, this document is the implementation and support guide
for what the app can explain today and what the v2 backlog is tracking next.
