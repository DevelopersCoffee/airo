# Midas Stream v0.0.6 physical-device matrix

Candidate: `0.0.6+8`
State: **prepared; mandatory device execution incomplete**
Release state: **not created**

This is the complete #1265 carry-forward matrix for the v0.0.6 candidate. It
does not convert host tests, emulators, old APK results, or ADB key injection
into physical-device PASS evidence.

Every completed row must record the exact Git commit, APK/AAB checksum, public
device model, OS/API and build, fixture, network topology, timestamp, operator,
and a redacted evidence path. A failure requires a bounded follow-up defect.

## Consolidated #1265 rows

| Source | Required physical check | Required rig/fixture | Current result |
|---|---|---|---|
| #877 | mDNS discovery fallback when ordinary local UDP discovery is blocked | AP-isolated or VLAN test network; two compatible local devices | Pending — topology unavailable |
| #884 | APK/AAB size before/after, Baseline Profile cold-start effect, and single-tile repaint scope | 1 GB-class TV device; production-comparable AAB/APK pair; DevTools repaint capture | Pending — reference hardware and comparable signed artifacts unavailable |
| #900 | 100k playlist cold open below 1 s and warm open below 300 ms, with memory ceiling | Fire TV-class hardware; synthetic 100k fixture; cold/warm measurement harness | Pending — hardware run not performed |
| #901 | Multi-field deterministic search below 10 ms at 100k channels | TV hardware; indexed 100k fixture; percentile trace | Pending — hardware run not performed |
| #903 | Four live streams, focus-follows-audio, independent tracks, dropped frames and RSS | Fire TV-class hardware; four authorized streams; track/bitrate fixtures | Pending — device and authorized fixture unavailable |
| #904 | Fifty-query on-device SLM eval at ≥90% exact intent and an airplane-mode demo below 1.5 s | Supported on-device model target; barista-tuning artifact; canonical eval set | Pending — required model artifact/device unavailable |
| #967 | Killed/background reminder delivery, reboot persistence, deep link, and 24 h guide interaction performance | Physical TV; multi-day XMLTV fixture; future reminder window; reboot authorization | Pending — device run not performed |
| #978 | Home enters pinned PiP, audio-only lockscreen controls stay PLAYING, and rapid transitions leave no stuck state | Unlocked Pixel 9; authorized stream; `dumpsys` evidence | Pending — Pixel 9 is unlocked, but no authorized stream/PiP run was performed |
| #979 | TalkBack end-to-end add/search/play/favorite journey and 1.3×/2× text-scale audit | Unlocked phone with TalkBack operator; authorized playlist | Pending — operator/device session unavailable |

## Release-profile device rows

| Device | Required checks | Current result |
|---|---|---|
| Pixel 9 / Android 17 | Coins cold launch renders content within 10 s; tab navigation; background/resume; PiP/media session | Partial — unlocked `0.0.6` code 8 focused `CoinsActivity` within 1 s, rendered vault semantics under secure-window screenshot redaction, and retained PID across background/resume; physical tabs and PiP remain |
| iPad Air 4 | Launch, adaptive layout, playback, rotation, background/resume | Pending — device is offline |
| Fire TV Stick AFTSSS | Fresh-install render; physical-remote rail/player/modal/recovery/BACK matrix; bounded log-rate sample | Partial — v7a renders at 1080p; physical Select/modal, recovery focus, live playback, Back-to-Home, and bounded logs pass; fresh install and rail traversal remain |
| Android TV + USB | SAF permission denial/grant, folder traversal, direct content-URI playback, sidecar subtitle, resume | Pending — no connected TV/removable media |
| Android TV + DLNA/UPnP | SSDP discovery, ContentDirectory traversal, direct playback, server-loss retry, identifier redaction | Pending — no connected TV and controlled DLNA server |

## Evidence already available, but not a final physical PASS

- Host automation covers TV rail geometry, D-pad modal ownership, source
  selection, USB/DLNA browse and failure paths, direct content-URI playback,
  store viewports, and player overlay exclusivity.
- The locally validation-signed TV APK is `io.airo.app.tv` version `0.0.6`
  code `8`, SHA-256
  `6410e30e684b4629b26b8f8a4b9dbbf95d37e4c26650a9618b4cb2e28508fbde`.
- The AFTSSS hardware run used the release-mode `armeabi-v7a` payload,
  version `0.0.6` split code `1008`. Its validation-signed source SHA-256 is
  `d1b7b18674385b89326fd0313121b8ec160f31681e7358ed5bb7f464670801db`;
  the installed rig re-sign SHA-256 is
  `6593f02c5982e90fff507d7c610215a468b60e6b471c8d3fdc0ca9ef92bbf6a6`.
  Re-signing preserved the existing dogfood app data and does not prove the
  distribution signature.
- Physical Fire TV captures:
  [home render](assets/airo-tv-v006-physical-2026-07-29/fire-tv-aftsss-home.png)
  [Playlist sources modal](assets/airo-tv-v006-physical-2026-07-29/fire-tv-aftsss-playlist-modal.png),
  [retry focus](assets/airo-tv-v006-physical-2026-07-29/fire-tv-aftsss-recovery.png),
  [live playback](assets/airo-tv-v006-physical-2026-07-29/fire-tv-aftsss-live-playback.png),
  and
  [Home after Back](assets/airo-tv-v006-physical-2026-07-29/fire-tv-aftsss-home-after-back.png).
- The
  [bounded active-playback report](assets/airo-tv-v006-physical-2026-07-29/fire-tv-playback-log-report.md)
  records 489 known platform property denials in 5 seconds, zero other
  actionable errors, and zero fatal signatures. Logcat buffer headers are
  normalized out before totals and classification.
- Historical v0.0.5 Fire TV and Pixel evidence remains useful for regression
  context, but it is not evidence for this candidate.

Publication stays blocked until every mandatory row is a reproducible PASS or
the owning council records an explicit release waiver.
