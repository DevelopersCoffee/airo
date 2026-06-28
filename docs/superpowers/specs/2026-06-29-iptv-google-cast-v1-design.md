# IPTV Google Cast V1 Design

Date: 2026-06-29
Status: Approved design for planning
Branch/worktree base: `origin/main` at `75a65602e8a2ca71d6c3eb6b683adb0af07fef5d`

## Summary

Airo Media Hub needs a reliable first version of TV casting for IPTV channels.
V1 supports Google Cast only, public network-accessible IPTV stream URLs only,
and one active receiver session at a time. The Flutter app acts as a sender and
remote control. A Sony Bravia, Android TV, Google TV, or Chromecast receiver
fetches the HLS/MP4 URL directly and plays it without any Airo app installed on
the TV.

Future scope is explicit: AirPlay, browser/laptop receivers, local-device file
casting, local LAN media serving, custom Cast receivers, proxies for header-only
streams, device groups, and multi-device orchestration are not part of V1.

## References

- Google Cast overview: https://developers.google.com/cast
- Google Cast supported media guidance: https://developers.google.com/cast/docs/media
- Default Media Web Receiver: https://developers.google.com/cast/docs/web_receiver/basic
- Android sender setup: https://developers.google.com/cast/docs/android_sender
- iOS sender setup: https://developers.google.com/cast/docs/ios_sender

## Current Project Context

Airo already has an IPTV feature with a layered structure:

- `app/lib/features/iptv/domain/models/iptv_channel.dart`
- `app/lib/features/iptv/domain/services/iptv_streaming_service.dart`
- `app/lib/features/iptv/domain/services/video_player_streaming_service.dart`
- `app/lib/features/iptv/application/providers/iptv_providers.dart`
- `app/lib/features/iptv/presentation/screens/iptv_screen.dart`
- `app/lib/features/iptv/presentation/widgets/video_player_widget.dart`

The IPTV screen currently has a Cast action placeholder. Existing media-hub docs
define app-level player UX and IPTV integration, but there is no reusable Cast
contract yet.

## Critical Agent Gate

**Problem:** Users can watch IPTV channels on mobile but cannot delegate playback
to a Chromecast-enabled TV from Airo.

**User / actor:** A mobile Airo user on Android or iOS with a Sony Bravia,
Android TV, Google TV, or Chromecast receiver on the same Wi-Fi network.

**Framework or application layer:** Mixed. The Cast abstraction and platform
setup are reusable framework/platform capabilities. IPTV channel adaptation and
user-facing cast controls are application/domain behavior.

**Owning agent:** Media / IPTV Domain Agent.

**Reviewing agents:** Framework Agent, Mobile UI Agent, Security and Privacy
Agent, QA Automation Agent, Release and DevEx Agent.

**Impacted modules/files:** Expected implementation touches
`app/lib/features/iptv`, a new reusable cast/domain boundary under `app/lib/core`
or `packages`, Android manifest/native setup, iOS plist setup, tests, and media
hub docs.

**Base branch/worktree:** Confirmed from latest `origin/main`: yes. Planning
worktree created from fetched `origin/main` at
`75a65602e8a2ca71d6c3eb6b683adb0af07fef5d`.

**Open questions:** None for V1 scope. Implementation must still validate the
exact Flutter Cast package or native bridge before coding.

**Decision:** Ready for issue planning. Not ready for feature code until the
GitHub issues include the contracts, deterministic automation flows, and
platform setup checklist below.

## Product Scope

### In V1

- Discover Google Cast receivers on the same local network.
- Show a single-select device picker from the IPTV screen.
- Connect to one receiver at a time.
- Cast one IPTV channel URL to the receiver.
- Use the receiver to fetch and play public HLS or progressive MP4 streams.
- Show casting state in the mobile app.
- Support play, pause, stop, and volume controls where the receiver permits it.
- Replace any previous active Cast session when starting a new cast.
- Handle local network permission, no-device, connection, media-load, and
  disconnect failures with clear user-facing states.
- Provide fake discovery/session adapters for deterministic tests.
- Verify manually against at least one real Chromecast-enabled TV, with Sony
  Bravia / Android TV as the target hardware class.

### Out of V1

- AirPlay.
- Browser/laptop receiver.
- Local file casting.
- Local HTTP media server on the phone.
- Custom Cast receiver application.
- Mobile proxy for streams requiring custom headers, auth, geofencing bypass, or
  DRM workarounds.
- Multi-device simultaneous casting.
- Device groups.
- Cross-device playback sync.
- Recording, EPG, scheduling, or REST API.
- Monetization UI changes.

## Architecture Decision

Use a Single Cast Session Adapter.

```text
Airo Flutter mobile app
  IPTV screen, Cast button, device picker, remote controls
        |
        v
Cast feature layer
  discovery manager, session manager, media dispatcher, state adapter
        |
        v
Google Cast receiver
  Sony Bravia / Android TV / Google TV / Chromecast
        |
        v
Public IPTV stream URL
  HLS (.m3u8) or progressive MP4 fetched directly by receiver
```

This is the smallest design that supports the real target device class without
requiring a TV app, edge device, local proxy, or custom receiver.

## Component Contracts

### Framework / Platform Cast Contract

Owns reusable Cast concepts and platform integration.

Required model concepts:

- `CastDevice`: id, display name, model name, host, port if exposed, receiver
  capabilities, last seen timestamp.
- `CastDiscoveryState`: idle, permissionRequired, discovering, found, noDevices,
  failed.
- `CastSessionState`: idle, connecting, connected, loadingMedia, playing,
  paused, stopped, disconnected, failed.
- `CastMediaRequest`: media URL, content type, title, subtitle, image URL,
  stream type, metadata, optional duration.
- `CastError`: permissionDenied, discoveryFailed, noDevicesFound,
  connectionTimeout, receiverUnavailable, mediaLoadFailed, unsupportedStream,
  receiverDisconnected, platformUnavailable.

Required API shape:

```dart
abstract interface class CastController {
  Stream<CastDiscoveryState> get discoveryState;
  Stream<CastSessionSnapshot> get sessionState;

  Future<void> initialize();
  Future<void> startDiscovery();
  Future<void> stopDiscovery();
  Future<void> connect(CastDevice device);
  Future<void> load(CastMediaRequest request);
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> setVolume(double volume);
  Future<void> disconnect();
  Future<void> dispose();
}
```

V1 behavior: only one active session exists. `connect()` or `load()` for a new
device stops or replaces the previous session.

### IPTV Domain Adapter Contract

Owns conversion from IPTV domain state into Cast requests.

Responsibilities:

- Convert `IPTVChannel` to `CastMediaRequest`.
- Select `channel.getStreamUrl(selectedQuality)` as the cast URL.
- Infer `contentType` from URL or channel metadata:
  - `.m3u8` -> `application/x-mpegURL` or equivalent package-supported HLS type.
  - `.mp4` -> `video/mp4`.
  - audio-only streams -> audio content type where known.
- Mark a channel uncastable when it has required headers, unsupported URL
  scheme, empty URL, or known unsupported format.
- Keep local IPTV playback state consistent when casting starts or stops.

### Mobile UI Contract

Owns user-facing Cast flow.

Required UX:

- Replace the placeholder Cast snackbar in `IPTVScreen` with a real action.
- Device picker bottom sheet:
  - permission state,
  - scanning state,
  - available devices,
  - refresh,
  - no-device guidance.
- Connected cast banner or mini controller:
  - device name,
  - current channel,
  - loading/playing/paused/error state,
  - play/pause,
  - stop casting,
  - volume affordance if supported.
- If the user starts another cast, explain that the previous receiver will be
  replaced.
- No multi-device UI, AirPlay UI, local-file UI, or laptop receiver UI in V1.

### Security and Privacy Contract

Required constraints:

- Request only platform permissions needed for Cast discovery and network
  access.
- iOS must include local network usage copy and Bonjour service declaration for
  Cast discovery.
- Android must include required network and Cast framework setup.
- Do not log full IPTV URLs by default because URLs can contain private tokens
  even when current sources are intended to be public.
- Do not proxy streams, bypass DRM, bypass geofencing, or transform headers in
  V1.
- Show Airo as a neutral playback/casting tool. Do not imply that Airo owns or
  provides IPTV content.
- Any legal copy must state that users are responsible for content rights.

## User Flow

1. User opens IPTV / Stream screen.
2. User taps Cast.
3. App requests local network permission if the platform requires it.
4. App discovers Google Cast receivers on the same Wi-Fi.
5. User selects one device.
6. App creates one Cast session.
7. User selects or confirms the current IPTV channel.
8. App sends the channel public HLS/MP4 URL to the receiver.
9. Mobile player pauses or switches to casting mode.
10. User controls play/pause/stop/volume from the mobile app.
11. If the session disconnects, app clears active session and keeps the channel
    available for local playback.

## State Machine

Primary states:

```text
idle
  -> discovering
  -> deviceSelected
  -> connecting
  -> connected
  -> loadingMedia
  -> playing
  -> paused
  -> stopped
```

Failure states:

```text
permissionDenied
noDevicesFound
connectionFailed
mediaLoadFailed
receiverDisconnected
unsupportedStream
```

Replacement rule:

```text
active session + user starts cast to another device
  -> stop or disconnect current session
  -> connect new device
  -> load selected channel
```

## Error Handling

- **Local network permission denied:** show permission explanation and retry path.
- **No Cast devices found:** show refresh and same-Wi-Fi guidance.
- **Connection timeout:** show retry and choose-another-device actions.
- **Invalid or unreachable IPTV URL:** do not start Cast; show channel
  unavailable.
- **Receiver media load failed:** keep session visible; show retry and stop.
- **Receiver disconnected:** clear active session and keep selected channel ready
  for local playback.
- **Stream requires headers/auth:** mark unsupported in V1 unless the receiver can
  load it directly.

## Deterministic Automation Flows

Automation must use fake adapters rather than requiring real TVs in CI.

1. **Discovery success:** fake Cast adapter returns two devices; device picker
   renders both; selecting one calls `connect()`.
2. **No devices:** fake discovery completes empty; UI shows no-device state and
   refresh action.
3. **Permission denied:** fake platform permission denied; UI shows permission
   copy and does not call discovery.
4. **Castable IPTV channel:** `IPTVChannel` with `.m3u8` URL converts to a
   `CastMediaRequest` with HLS content type and channel metadata.
5. **Uncastable header stream:** `IPTVChannel.headers` present; adapter rejects
   with `unsupportedStream` in V1.
6. **Media load success:** fake session transitions
   `connecting -> connected -> loadingMedia -> playing`; UI shows connected
   banner and remote controls.
7. **Media load failure:** fake adapter emits `mediaLoadFailed`; UI offers retry
   and stop.
8. **Receiver disconnect:** fake adapter emits `receiverDisconnected`; state
   clears active session and leaves local playback available.
9. **Session replacement:** start casting to Device B while Device A is active;
   fake adapter records stop/disconnect for A before connecting B.
10. **Stop casting:** user taps Stop; fake adapter receives `stop()` and state
    returns to idle/stopped.

## Manual Verification Matrix

- Android phone sender to Sony Bravia / Android TV receiver on same Wi-Fi.
- iPhone sender to same receiver on same Wi-Fi.
- Public HLS IPTV channel success.
- Public progressive MP4 sample success if available in fixtures.
- TV offline during discovery.
- TV disconnects during playback.
- Mobile moves off Wi-Fi during session.
- App backgrounds and returns while receiver continues playing.

## Acceptance Criteria

- A Cast-enabled Sony Bravia / Android TV appears in device discovery on the
  same Wi-Fi.
- A public HLS IPTV channel casts to one TV without installing an Airo app on the
  TV.
- Play, pause, stop, and volume controls update Cast session state.
- Starting a second cast replaces the first active session.
- Android and iOS sender setup is documented and implemented.
- No local file casting, AirPlay, browser/laptop receiver, custom receiver,
  proxy, or multi-device UI appears in V1.
- Fake adapters cover success and failure flows in automated tests.
- Real-device manual test checklist is completed before release.

## Rollback Plan

- Gate the Cast action behind a feature flag or runtime availability check.
- If Cast initialization fails on a platform, hide or disable the Cast action and
  keep local IPTV playback unchanged.
- If release telemetry or manual QA finds receiver instability, revert UI exposure
  while keeping the inactive abstractions in place.

## GitHub Issue Plan

### Epic: IPTV Google Cast V1 Single-Device Casting

Labels: `epic`, `media-hub`, `enhancement`, `priority/P1`

Purpose: Track all V1 Cast work and enforce the approved scope boundary.

### Issue 1: Framework Cast Contract and Platform Setup

Labels: `agent/core-architecture`, `agent/mobile-ui`, `media-hub`,
`type/task`, `priority/P1`

Scope:

- Define Cast models and controller interface.
- Select package/native bridge after implementation research.
- Add Android Cast framework setup.
- Add iOS local network and Bonjour setup.
- Provide fake Cast adapter for tests.

### Issue 2: IPTV Cast Media Adapter

Labels: `agent/core-architecture`, `media-hub`, `type/task`, `priority/P1`

Scope:

- Convert `IPTVChannel` to `CastMediaRequest`.
- Validate URL scheme and basic content type.
- Reject header/auth-dependent streams in V1.
- Keep local IPTV player state consistent when casting starts/stops.

### Issue 3: Cast Device Picker and Remote Controls

Labels: `agent/mobile-ui`, `media-hub`, `ui`, `type/task`, `priority/P1`

Scope:

- Replace Cast placeholder in IPTV screen.
- Add device picker bottom sheet.
- Add connected casting banner or mini controller.
- Add play/pause/stop/volume actions.
- Ensure no multi-device UI appears.

### Issue 4: Security, Privacy, and Store Compliance

Labels: `agent/security`, `media-hub`, `security`, `type/task`, `priority/P1`

Scope:

- Review permission prompts.
- Ensure IPTV URLs are redacted from logs.
- Add neutral-tool legal copy where needed.
- Confirm no proxy, DRM bypass, or geofencing bypass behavior.

### Issue 5: Cast Automation and Real-Device QA

Labels: `agent/qa-testing`, `media-hub`, `type/task`, `priority/P1`

Scope:

- Add fake discovery/session tests for all deterministic flows.
- Add integration/widget tests for picker, banner, errors, and replacement.
- Create real-device checklist for Android sender, iOS sender, and Sony Bravia /
  Android TV receiver.

### Issue 6: Release and DevEx Readiness

Labels: `agent/devex`, `agent/release`, `media-hub`, `type/task`, `priority/P2`

Scope:

- Document local developer setup.
- Document manual Cast test prerequisites.
- Add release checklist entries.
- Ensure CI remains deterministic without receiver hardware.

## Future Scope

V2 may add multi-device casting through a `MultiCastController`,
`SessionOrchestrator`, per-device state tracking, device groups, and broadcast
commands. V2 must remain backward-compatible with the V1 single-session API.

V2+ may add AirPlay, browser/laptop receivers, local file casting through a
secure LAN HTTP server, and custom Cast receivers for richer diagnostics or
streams that need receiver-side customization.
