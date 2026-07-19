# Immediate Action Player — Design

Status: Draft (spec self-reviewed, pending user review)
Owner: Airo TV mobile (feature_iptv, platform_player)
Related: `docs/superpowers/plans/2026-07-17-cv015-slice2-epg-grid.md` (predecessor EPG grid work), follow-up spec `2026-07-19-live-grid-epg-nav-design.md` (not yet written)

## Background

Market scan (Pluto TV, Tubi, YouTube TV, Hulu + Live TV, Sling, Bigo Live — see
Sources) confirms the 2025/26 norm for live-TV mobile apps: a single tap on a
channel starts playback immediately, with no intermediate detail/preview
screen, and cold-start/deep-link entry into a specific channel skips the
browse grid entirely. Airo TV's mobile `IPTVScreen._playChannel` already plays
inline on tap (no detail screen today), so the "Default to Live" work here is
about (a) auditing/closing any remaining friction on tap-to-play and (b)
building the missing cold-start/deep-link path, plus native PiP and
background-audio support, neither of which exist today (confirmed: no
`PictureInPictureParams`/`AVPictureInPictureController` references anywhere
in `packages/` or `app/`).

Sources:
- https://blog.mercury.io/designing-great-streaming-tv-apps-pt-1-introduction/
- https://www.forasoft.com/blog/article/streaming-app-ux-best-practices

## Goals

1. Tapping a channel (browse grid, EPG, search, recently-watched) starts full
   playback with no interstitial screen.
2. Launching the app via a channel deep link or Android/iOS "resume last
   channel" affordance lands directly in playback, not the browse grid.
3. System-level PiP (`AVPictureInPictureController` on iOS,
   `PictureInPictureParams` on Android) is available while a channel is
   playing.
4. A manual audio-only toggle exists in player controls; audio-only is also
   entered automatically on backgrounding as a fallback when PiP isn't
   available.
5. On backgrounding, PiP is attempted first; audio-only is the fallback when
   PiP is unsupported/denied by the OS, or when the user had already toggled
   audio-only manually before backgrounding.

## Non-Goals

- TV (Fire TV / Android TV) receiver-side PiP or backgrounding — TV is
  receiver-only per existing project principle (see memory: "Core TV
  Device-Role Principle"). This spec is mobile (iOS/Android) only.
- The EPG grid navigation redesign (time-axis scrolling, now-anchor,
  progress ticker, reminders) — split into a separate spec per user
  decision, to follow this one.
- VOD PiP/background-audio — scoped to live channel playback only for this
  spec; VOD can reuse the same platform_player primitives later but isn't
  in scope now.

## Architecture

Capabilities are added to `platform_player` (not `feature_iptv` directly),
following the existing `AiroNativeFullscreen` pattern
(`packages/platform_player/lib/src/services/native_fullscreen.dart`): a
static service class wrapping a `MethodChannel`, with iOS/Android native
implementations, exported from `platform_player.dart`.

### New components

**`AiroNativePictureInPicture`** (`platform_player/lib/src/services/native_picture_in_picture.dart`)
- `static Future<bool> isSupported()` — platform + OS-version capability
  check (`AVPictureInPictureController.isPictureInPictureSupported()` on
  iOS; Android `PackageManager.FEATURE_PICTURE_IN_PICTURE` check + API 26+).
- `static Future<bool> requestEnter()` — invoked when app is about to
  background during active playback. Returns whether PiP actually engaged.
- `static void setStateChangeHandler(void Function(bool isActive)? handler)` —
  native → Dart callback so the player widget can swap its UI (hide
  overlay controls while in PiP).
- Android: implemented via `PictureInPictureParams.Builder` +
  `Activity.enterPictureInPictureMode()`, triggered from `onUserLeaveHint`.
- iOS: implemented via `AVPictureInPictureController` attached to the
  existing native video layer; requires the player's `AVPlayerLayer` to be
  reachable from platform code, same integration point `native_fullscreen`
  already uses for the native player surface.

**`AiroBackgroundAudioMode`** (`platform_player/lib/src/services/background_audio_mode.dart`)
- `static Future<void> setEnabled(bool enabled)` — toggles whether the
  active engine keeps decoding audio-only when the video surface is
  torn down (backgrounded without PiP, or user tapped the manual toggle).
- Wires into existing lock-screen / notification media controls
  (`MPNowPlayingInfoCenter` iOS, `MediaSession` Android) so the OS shows
  play/pause/channel-name — required for any backgrounded audio per
  platform policy, not just a nicety.
- Manual toggle in `video_player_widget.dart` overlay controls calls this
  directly; automatic fallback (see Lifecycle Decision below) also calls it.

### Lifecycle decision (app backgrounding during playback)

```
App backgrounding event
  │
  ├─ user manually toggled audio-only before backgrounding?
  │     yes → AiroBackgroundAudioMode.setEnabled(true), skip PiP
  │
  └─ no → AiroNativePictureInPicture.requestEnter()
            ├─ engaged → stay in PiP, video keeps playing
            └─ not supported/denied → AiroBackgroundAudioMode.setEnabled(true)
```

This decision lives in a new `PlayerBackgroundingCoordinator` in
`feature_iptv` (mirrors the existing `wakelock_playback_coordinator.dart`
pattern already wired in `iptv_screen.dart` `initState`), since it needs
access to app lifecycle events (`AppLifecycleState`) and the current
channel/streaming-service state, not just the raw platform capability.

### Default-to-live wiring

- **Tap-to-play audit**: verify `_playChannel` in `iptv_screen.dart` and
  the EPG's `onChannelSelected` path (`IptvGuideScreen`) both call
  `iptvStreamingServiceProvider.playChannel` synchronously on tap with no
  intermediate route push. Fix any path found to insert a detail screen.
- **Cold-start/deep-link**: new optional route param on the existing
  `/iptv` route (`?channel=<id>`) resolved by the app's router before
  `IPTVScreen` builds; if present, `IPTVScreen` calls `_playChannel`
  immediately in `initState` instead of waiting for user tap, and skips
  rendering the browse grid as the first frame (renders the fullscreen
  player immediately, with browse grid available on back/minimize).
  Deep link source (universal link, home-screen widget, "continue
  watching" notification tap) is unified through this one route param —
  no per-source special casing.

## Data Flow

1. User taps channel card / deep link resolves with `channel=<id>` →
   `_playChannel(channel)` called immediately.
2. `iptvStreamingServiceProvider.playChannel` starts the engine; player
   widget renders fullscreen with no interstitial.
3. `PlayerBackgroundingCoordinator` observes `AppLifecycleState.paused`
   while `iptvStreamingServiceProvider.currentState.isPlaying` → runs the
   lifecycle decision above.
4. On `AppLifecycleState.resumed`, if PiP was active, `AiroNativePictureInPicture`
   fires the state-change handler with `isActive: false`; coordinator
   restores normal fullscreen UI. If audio-only was active, video resumes
   rendering; user must tap to exit audio-only manually if they enabled it
   themselves (auto-triggered audio-only exits automatically on resume).

## Error Handling

- `isSupported()` false (old OS, PiP disabled by MDM/parental controls,
  device without PiP support) → silently fall through to audio-only, no
  user-facing error. Log via existing `debugPrint`/telemetry pattern used
  in `native_fullscreen.dart`.
- Deep link resolves to a channel ID no longer in the playlist → fall back
  to normal browse-grid landing with a snackbar, don't crash on missing
  channel.
- `MethodChannel` `MissingPluginException` (platform impl not registered,
  e.g. running on macOS/web where PiP channel doesn't exist) → treated as
  `isSupported() == false`, same fallback path. Matches existing
  `native_fullscreen.dart` error handling.

## Testing

- Unit tests for `PlayerBackgroundingCoordinator`'s lifecycle decision
  table (manual-audio-only-set / PiP-succeeds / PiP-denied / not-supported
  branches) using a fake `AiroNativePictureInPicture` + fake streaming
  service, following the existing `fake_playback_engine.dart` pattern.
- Widget test confirming tap on a channel card renders the fullscreen
  player on the next frame with no intermediate route in the navigator
  stack.
- Widget test confirming `/iptv?channel=<id>` deep link renders playback
  as the first frame.
- Platform channel contract tests (mocked `MethodChannel`) for
  `AiroNativePictureInPicture` and `AiroBackgroundAudioMode`, matching the
  existing `native_fullscreen` test structure.
- Manual device dogfood on physical iOS and Android hardware — PiP and
  background audio cannot be verified in simulator/emulator reliably per
  prior CV-033 notes (`platform_channel` behavior differs on real
  hardware); flag as a manual QA gate before merge, not automatable in CI.
