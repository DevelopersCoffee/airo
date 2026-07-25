# Fire OS Local Network Testing — Design

Date: 2026-07-25
Status: Approved

## Goal

Get Airo TV running on a physical Fire TV Stick over the local network for manual
testing. No Amazon Appstore submission work (no Amazon IAP, no Fire App Builder
compliance, no store listing) — this is device bring-up and QA only, per
[Amazon's "Porting an Existing App to Fire OS" guide](https://developer.amazon.com/docs/app-porting/port-existing-app.html).

## Current state (verified in repo)

- Airo TV already builds as a standard Android leanback app — Fire OS runs stock
  Android APKs, no native Amazon SDK required for sideload testing.
- TV flavor exists: `APP_VARIANT=tv` dart-define, applicationId `io.airo.app.tv`,
  label "Airo TV" (`app/android/app/build.gradle.kts`).
- TV manifest (`app/android/app/src/tv/AndroidManifest.xml`) already has:
  - `android.software.leanback` required feature
  - `android.hardware.touchscreen` not required
  - `LEANBACK_LAUNCHER` intent category
  - `android:banner` for the home screen tile
  - GMS-specific bind-services (`gsf.permission.READ_GSERVICES`,
    `aicore.service.BIND_SERVICE`) explicitly removed for this flavor
- Entrypoint is `app/lib/main_tv.dart` (not `main.dart`) — see
  `.claude/skills/run-airo-tv/SKILL.md`.
- [AIRO_TV_DEVICE_GUIDE.md](../../features/airo-tv/AIRO_TV_DEVICE_GUIDE.md) already
  lists Fire TV as a "Compatible/qualification target" but has no logged real-device
  evidence yet — that's the gap this work closes.

## Approach

1. **Worktree** — `git worktree add ../airo-fire-os -b fire-os-testing` off `main`.
   Keeps this isolated from the current workspace's uncommitted
   `platform_player` changes.
2. **Firestick one-time setup** — enable Developer Options + ADB debugging + Apps
   from Unknown Sources on the stick, note its LAN IP.
3. **Per-session connect** — `adb connect <stick-ip>:5555` (Mac and Stick on same
   WiFi/LAN).
4. **Build + deploy** — `flutter build apk --flavor tv
   --dart-define=APP_VARIANT=tv -t lib/main_tv.dart`, then `adb install -r` the
   output APK, or `flutter run -d <stick-ip>:5555 -t lib/main_tv.dart
   --dart-define=APP_VARIANT=tv` for iterative hot-reload testing.
5. **Test checklist** — leanback launcher icon/banner rendering, D-pad focus
   navigation with no dead ends, back-button behavior, local-network IPTV stream
   playback, no touchscreen-only affordances, memory/performance on Stick-class
   hardware, backgrounding/resume survival.
6. **Write findings back** — update the Fire TV row/section in
   `AIRO_TV_DEVICE_GUIDE.md` with real device evidence (model, Fire OS version,
   pass/fail per checklist item), replacing the current placeholder status where
   evidence now exists.

## Out of scope

- Amazon Appstore submission (IAP, Fire App Builder, store metadata)
- Any Amazon-specific SDK integration
- CI/automated Fire OS testing (this is manual local-network QA)

## Testing

This work *is* the test — manual verification against the checklist above on a
physical Fire TV Stick. No new automated test suite.
