# Midas Stream v0.0.6 candidate

Status: **prepared, not released**
Version/build: `0.0.6+8`
Intended tag: `airo-tv-v0.0.6`
Intended branch: `release/airo-tv-v0.0.6`

This candidate concentrates on launch reliability, remote-first TV navigation,
player recovery, provider-backed content sources, local-media onboarding, and
release trust.

## Candidate highlights

- Coins resolves to one launcher activity and the build/smoke scripts verify
  the installed launcher component.
- TV D-pad traversal reaches the rail from Search, Name sort, and the first
  channel; playback surfaces use one exclusive loading/buffering/error state.
- Saved M3U, Xtream, and Stalker sources are selectable and exclusive at
  runtime. Xtream supplies live channels, XMLTV data, and VOD; Stalker supplies
  live channels after an authenticated handshake.
- Android TV can browse a user-authorized USB/removable folder through the
  Storage Access Framework or discover and browse a compatible DLNA/UPnP
  ContentDirectory server. Unsupported targets omit the corresponding action.
- First-run TV setup includes URL entry and a short-lived LAN QR session whose
  expiry can be regenerated without exposing the submitted playlist URL.
- Store screenshots are captured from a deterministic local runtime fixture,
  processed to compliant RGB PNGs, and paired with an original text-free
  feature graphic.
- Android production-signing inputs, third-party notices, and GitHub artifact
  provenance are prepared.

## Privacy and scope

- Airo remains bring-your-own-content. No channels, subscriptions, or media are
  bundled.
- Local paths, LAN endpoints, DLNA control handles, Xtream credentials, Stalker
  tokens, and playlist URLs are excluded from diagnostic strings and bounded
  log reports.
- No cloud indexing, telemetry, online subtitle search, or background DLNA
  scanning was added.

## Required before publishing

- Run and attach the v0.0.6 physical matrix on Pixel 9, Fire TV Stick, and iPad.
- Build the production-signed candidate from the reviewed release commit and
  verify its certificate fingerprint, checksums, manifest, and provenance.
- Review processed listing captures for privacy and visual quality.
- Obtain the required Critical Agent and council approvals.

Preparation must not create a tag, GitHub Release, Play upload, Firebase
distribution, or public artifact.
