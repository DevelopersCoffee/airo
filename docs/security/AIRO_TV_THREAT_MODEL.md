# Airo TV Threat Model

This document describes the data and trust boundaries for Airo TV.

## Scope

Airo TV is an Android TV IPTV player for user-supplied M3U playlists. It does not provide IPTV channels, playlists, or media content.

## Assets

- Playlist URLs and imported playlist metadata.
- Playback preferences and local UI settings.
- Cast discovery and receiver state.
- Android signing keys and release artifacts.
- GitHub release assets and checksums.

## Trust Boundaries

```text
User playlist input
  ↓
Flutter UI
  ↓
Playlist parser and search
  ↓
Playback engine
  ↓
Network media source or Cast receiver
```

## Data Handling

- Playlists stay on the user's device unless the user loads a remote playlist URL directly.
- No IPTV content is hosted by Airo.
- No playlist is uploaded to Airo-operated servers as part of normal playback.
- Release signing material must never be committed to the repository.

## Primary Risks

| Risk | Mitigation |
| --- | --- |
| Unauthorized playlist content | Legal notice and bring-your-own authorized playlist model. |
| Playlist URL exposure | Avoid logging playlist URLs or credentials. |
| Cast device discovery confusion | Show actionable same-network and receiver-reachability guidance. |
| Tampered release assets | Publish SHA256 checksums and use clean release asset names. |
| Signing key exposure | Keep keystores and key properties ignored; use CI secrets for production signing. |
| Malicious remote playlists | Treat playlist data as untrusted input and avoid executing playlist-provided data. |

## Out of Scope

- Licensing third-party IPTV content.
- Hosting IPTV streams.
- Recording or redistributing media content.
- Cloud playlist synchronization.

## Release Requirements

- Build artifacts must be generated from the v2 release line.
- Release assets must include APK, AAB, and SHA256SUMS.
- Release notes must include known limitations, security notes, and legal notice.
