# Airo TV Architecture

Airo TV is the Android TV variant of Airo. It is built from the v2 release line with package name `io.airo.app.tv`.

## High-Level Flow

```text
Flutter UI
  ↓
TV Router and IPTV Screens
  ↓
Playlist Parser and Search
  ↓
Playback Controller
  ↓
Platform Player / Cast Controller
  ↓
User-supplied Playlist Provider or Cast Receiver
```

## Components

| Component | Responsibility |
| --- | --- |
| Flutter UI | TV-first screens, focusable controls, accessibility labels, fallback mobile layout. |
| TV Router | Limits the TV variant to IPTV-focused routes. |
| IPTV feature package | Playlist import, channel list, search, playback UI, Cast UI. |
| Platform player package | Playback and Cast controller abstractions. |
| Android TV manifest | Package name, launcher, Leanback launcher, TV feature metadata. |
| Release workflow | Builds APK/AAB artifacts, verifies metadata, publishes checksums and release notes. |

## Release Boundary

Airo TV is released from `v2`. If work is not explicitly for v2, it should not be included in the Airo TV release branch.

## Data Boundary

Airo TV does not host IPTV content. Playlist URLs and playback targets originate from the user or from playlist files supplied by the user.
