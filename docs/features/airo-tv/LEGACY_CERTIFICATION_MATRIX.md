# Airo TV Legacy Certification Matrix

This matrix defines the first platform certification contract for Airo TV
v2.0.0.1 legacy and Lite Receiver support. Support claims must be based on
evidence against these gates, not Android version alone.

Implementation contract:

- Package: `packages/platform_certification`
- Schema: `kAiroCertificationSchemaVersion`
- Default matrix: `AiroTvLegacyCertification.matrix()`
- Current release branch: `codex/next-v2.0.0.0`

## Target Classes

| Target ID | Support claim | Device class | Required evidence |
| --- | --- | --- | --- |
| `android-tv-api-26-lite` | Certified | Android TV API 26/27 Lite Receiver | Physical Android 8/8.1 TV run plus host release checks |
| `android-tv-api-28-lite` | Compatible | Android TV API 28 Lite Receiver | Physical Android 9 TV run plus host release checks |
| `fire-tv-legacy-lite` | Compatible | Fire TV legacy Lite Receiver | Physical Fire TV run, remote evidence, thermal stability, and host release checks |
| `lower-api-experimental` | Unsupported | API 23-25 experimental receiver | No public support claim until dependency, security, and device certification gates pass |

## Required Gates

| Gate | Physical evidence required | Purpose |
| --- | --- | --- |
| Install and launch | Yes | Release APK installs, launches, and reaches TV home |
| D-pad focus | Yes | Remote-only navigation remains stable during artwork loading |
| Baseline playback | Yes | H.264/AAC/HLS/MPEG-TS/MP4 fixtures play with native rendering |
| Subtitle rendering | Yes | Subtitle fixtures render without focus or playback regression |
| Pairing flow | Yes | Pairing and restricted receiver trust work on real hardware |
| Compact EPG | Yes | Current/next guide displays without local full XMLTV processing |
| Memory pressure | Yes | Caches reduce while active playback is preserved |
| Low storage | Yes | Credentials, favorites, and progress survive low-storage handling |
| Sleep and wake | Yes | Playback state and navigation recover after sleep/wake |
| Thermal stability | Yes for Fire TV legacy | Long playback remains usable under thermal pressure |
| Credential preservation | Yes | Credential storage survives pressure and update flows |
| Packaged content scan | No | Release package contains no bundled playlists or provider media |
| Dependency baseline | No | Release profile keeps API 26-compatible dependency constraints |

## Release Rule

A target can be advertised only when `AiroCertificationMatrix.evaluate` returns
`passed == true` and `canAdvertiseSupport == true` for that target.

Host-only checks can satisfy package and dependency gates. They cannot satisfy
physical-device gates. Physical evidence collection, benchmark runners, device
inventory, and store-channel submission checks are follow-up implementation
work, not app-layer shortcuts.
