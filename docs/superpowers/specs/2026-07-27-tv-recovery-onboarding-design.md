# TV empty-state onboarding: Wi-Fi settings, QR handoff, USB decision

Date: 2026-07-27
Status: Approved
Tracks: [issue #1179](https://github.com/DevelopersCoffee/airo/issues/1179),
  the follow-up split from `issues/04-recovery-states.md` after PR #1169
  shipped the error/offline slice.

## Context

Issue #1179 bundles three requirements. Investigation before designing
found the real scope of each differs sharply from the issue text:

- **URL entry**: already shipped (`_TvEmptyPlaylistState`'s "Add Playlist
  URL" button, `showPlaylistSourceSheet` in `iptv_screen.dart:1173`). Not
  part of this spec.
- **USB onboarding**: `file_picker` is a hard no-op stub on TV builds
  (`packages/stubs/file_picker_stub` — every method returns `null`,
  wired via `pubspec_tv.yaml`). Building a USB button against it would be
  exactly the "disabled focus bait" the issue's own AC forbids. No real
  Android Storage-Access-Framework integration exists to build against.
  Decision: **omit**, documented here, no code.
- **QR phone handoff**: no pairing/token infrastructure exists anywhere
  that's actually wired to a running feature. `core_pairing` (1,349 lines
  of models spanning 9 `core_*` packages: device roles, trust levels,
  challenge lifecycle) is fully modeled but has zero service
  implementation and zero call sites outside its own tests — it reads as
  scaffolding for a future multi-device/remote-control feature, owned by
  chief-cloud-officer per the Engineering Council roster, not something to
  wire up as a side effect of an empty-state button. Decision: build a
  small, self-contained, LAN-only flow instead (below), skipping
  `core_pairing` entirely.
- **Wi-Fi settings button**: genuinely missing, genuinely small.

## A. Wi-Fi settings button

`app/lib/.../MainActivity.kt` already has the exact pattern needed —
`openCalendarPermissionSettings` opens `Settings.ACTION_APPLICATION_
DETAILS_SETTINGS` via `startActivity`. The existing `DEVICE_INFO_CHANNEL`
(`com.airo/device_info`, already registered, already consumed from Dart
by `DeviceFormFactorDetector` in `core_app_shell`) gains one more case:

```kotlin
"openWifiSettings" -> {
    try {
        startActivity(Intent(Settings.ACTION_WIFI_SETTINGS))
        result.success(mapOf("opened" to true))
    } catch (e: ActivityNotFoundException) {
        result.success(mapOf("opened" to false))
    }
}
```

Dart side: new `WifiSettingsLauncher` in `feature_iptv` (own file next to
`connectivity_provider.dart`), wrapping the same `MethodChannel('com.airo/
device_info')` constant. `isSupported` is `Platform.isAndroid` (the TV app
ships Android only) — the button simply doesn't render where unsupported,
never shows disabled. `open()` invokes the method, returns the `opened`
bool.

Wired into `_OfflineBanner` (`airo_tv_shell.dart`) as a second button next
to the existing Retry, keyed `offline-banner-wifi-settings`. On `opened:
false`, a snackbar reports failure — no silent no-op.

## B. QR phone-handoff

`feature_iptv` already depends on `platform_player`, which has
`PhoneMediaFileServer` — an audited, security-reviewed local-network HTTP
server (constant-time token comparison, private-LAN-only address
allow-list via `isPrivateLanAddress`/`selectLanAddress`, redacted logging,
idle/expiry lifecycle, rate-limited rejection diagnostics). That solves
the opposite direction (phone serves media, TV fetches) but its safety
primitives are exactly what a TV-serves/phone-submits flow needs too, and
its two address-selection static methods are already public.

New `TvPlaylistPairingServer` in `feature_iptv` (own file):

- On start: binds a random port on the LAN address selected via
  `PhoneMediaFileServer.selectLanAddress`, generates a single-use 32-char
  `Random.secure()` token (same alphabet/approach as
  `PhoneMediaFileServer._generateSessionToken`, reimplemented locally —
  that method is private, not worth exposing cross-package for one call).
- Serves exactly two routes under `/pair/<token>`:
  - `GET` → a minimal, fully self-contained HTML form (inline `<style>`,
    no external assets, no CDN — works with zero internet beyond the LAN
    hop): one text input for a playlist URL, one submit button.
  - `POST` with form field `url` → validates non-empty, completes a
    `Completer<String>` the TV side is awaiting, responds with a plain
    "done — check your TV" page, then stops the server after a short
    grace period (2s, to let the response flush before the socket
    closes).
  - Anything else → 404, matching `PhoneMediaFileServer`'s
    unauthorized-path handling shape.
- 5-minute idle timer: if nobody submits, the server stops itself and the
  awaited `Future<String?>` resolves to `null` (expired).
- The submitted URL is **never logged** — diagnostics/toString follow
  `PhoneMediaFileServer`'s `redacted` convention, since the issue
  explicitly flags that playlist URLs can carry credentials in the query
  string.

UI: `_TvEmptyPlaylistState` gains a third action, "Scan with phone"
(`Icons.qr_code_2`). On select:

1. Start `TvPlaylistPairingServer`, get back the pairing `Uri`
   (`http://<lan-ip>:<port>/pair/<token>`).
2. Show a dialog: QR code (via the new `qr_flutter` dependency —
   pure-Dart encode + `CustomPainter`, no native code, MIT-licensed,
   pending the dependency check below) + "Waiting for your phone…" +
   Cancel.
3. `await` the server's `Future<String?>`.
   - Success: close the dialog, feed the URL into the same path
     `showPlaylistSourceSheet`'s URL-entry field already uses (reuse, not
     duplicate, the existing playlist-add provider call).
   - Expired: dialog switches to "QR expired" with a "Generate new code"
     button that restarts the flow with a fresh server/token — per the
     issue's own AC, never reveals the submitted URL (there wasn't one).
   - Cancel: stop the server immediately, close the dialog, no residual
     state.

### New dependency: `qr_flutter`

Small (~500 lines), MIT-licensed, pure-Dart QR encoder + `CustomPaint`
widget, no platform channels, no native code, actively maintained,
already the de facto standard Flutter QR widget. Per this repo's
dependency-governance rule, flagged for a chief-open-source-officer check
before adding — not skipped, just noted here as the one piece with an
external-code trust decision attached.

## C. Testing

- `WifiSettingsLauncher`: unit test via `TestDefaultBinaryMessengerBinding`
  mocking the method channel (opened: true/false), plus a widget test that
  the offline banner's button appears/calls through.
- `TvPlaylistPairingServer`: unit tests mirroring
  `phone_media_file_server_test.dart`'s shape — starts on a private
  address only, rejects unknown paths, single-use token, idle timeout
  resolves `null`, submitted URL never appears in any emitted diagnostic
  event.
- Empty-state QR dialog: widget test for the three states (waiting /
  success feeds the URL into the existing add-playlist path / expired
  shows regenerate), using a fake pairing server.

## Out of scope

- `core_pairing`/`core_cloud_orchestration` integration — explicitly
  rejected above.
- USB — documented omission, no code.
- Any change to the existing "Add Playlist URL" text-entry flow itself;
  QR only feeds its existing provider call with a different URL source.

## Resolution (2026-07-27)

- **A. Wi-Fi settings**: shipped, [PR #1188](https://github.com/DevelopersCoffee/airo/pull/1188).
- **B. QR handoff**: shipped, [PR #1190](https://github.com/DevelopersCoffee/airo/pull/1190).
  Reviewed before implementation by chief-open-source-officer (`qr_flutter`,
  approve-with-caveats), chief-security-officer (approve-with-required-
  changes: constant-time comparison, atomic single-use consumption, POST
  rate cap — all three built in), and media-intelligence-architect
  (approve-with-changes: caught that the original `showPlaylistSourceSheet`
  integration was unimplementable as designed — fixed by adding an
  `initialUrl` param — and required a provider seam for testability).
- **C. USB**: documented omission, no code, folded into PR #1190's
  description.

Both PRs pass their full test suites (21/21 and 11+5/16 respectively) with
one known, pre-existing, unrelated test failure (`iptv_screen_test.dart`
"Movie Night" handoff-sheet assertion — a concurrent phone-media/Cast UI
regression already on `main`, not introduced by either PR).
