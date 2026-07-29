# Airo TV v0.0.6 qualification ledger

Candidate: `0.0.6+8`
Prepared: 2026-07-29
Release state: **not created**

## Automated evidence

| Area | Evidence | Status |
|---|---|---|
| Source protocols | Active M3U/Xtream/Stalker provider, VOD, management, and UI tests | Pass |
| Player overlays | Error-layout and TV transport regression tests | Pass |
| TV D-pad | Router and channel-library focus tests | Pass |
| Coins launcher | Manifest contract, Coins shell tests, debug APK merged-manifest inspection | Pass |
| Native TV isolation | `scripts/test-check-android-tv-native-media.sh` | Pass |
| Fire TV logs | `scripts/test-check-fire-tv-playback-logs.sh` | Pass |
| Legal/provenance | license preflight and `scripts/test-android-release-provenance.sh` | Pass |
| Store media | Six Playwright runtime captures and `test_process_store_screenshots.py` | Pass |
| Build generation | Pigeon/build-runner generation and focused model/auth tests | Pass |
| Sonar/new-code coverage | CI-equivalent app run: 1,076 passed, 2 intentionally skipped; focused provider tests cover the prior main-branch hotspots | Pass locally; remote candidate analysis pending |
| macOS TV build | `build-macos-tv.sh` with isolated TV Dart/CocoaPods locks; `Airo TV.app` release build and deep code-sign verification | Pass (local validation signature) |
| TV release APK | `0.0.6+8`, `io.airo.app.tv`, 31 MiB; SHA-256 `6410e30e684b4629b26b8f8a4b9dbbf95d37e4c26650a9618b4cb2e28508fbde`; release check and forbidden-native inspection | Pass (local validation signature) |
| Offline build | sqlite3 resolves the packaged `libsqlite3.so`; no release-time binary download | Pass |

## Physical matrix — mandatory before publication

Do not replace these rows with emulator evidence.

The complete #1265 carry-forward matrix and its exact evidence requirements are
recorded in
[`AIRO_TV_V0.0.6_PHYSICAL_MATRIX.md`](AIRO_TV_V0.0.6_PHYSICAL_MATRIX.md).

| Device | Required checks | Result | Evidence |
|---|---|---|---|
| Pixel 9 | cold launch, Coins launcher, tab navigation, background/resume | Partial — unlocked candidate cold-started and resumed without process loss; physical tab/PiP checks remain | `0.0.6` / code 8; `CoinsActivity` focused within 1 s; secure-window accessibility tree rendered vault content; PID `32600` survived background/resume |
| Fire TV Stick | D-pad rail/player, Back, buffering/error recovery, bounded log report | Partial — v7a release payload renders and a physical Select opens the playlist modal; remaining remote/player checks pending | AFTSSS/API 28; rig APK SHA-256 `6593f02c5982e90fff507d7c610215a468b60e6b471c8d3fdc0ca9ef92bbf6a6`; [home](assets/airo-tv-v006-physical-2026-07-29/fire-tv-aftsss-home.png), [modal](assets/airo-tv-v006-physical-2026-07-29/fire-tv-aftsss-playlist-modal.png) |
| iPad | launch, adaptive layout, playback, rotation/background/resume | Pending — no connected device | Attach video/sysdiagnose excerpt |
| Android TV + USB | permission prompt, folder browse, direct playback, sidecar subtitle | Pending — no connected device/media | Attach video and redacted result |
| Android TV + DLNA/UPnP | discovery, folder browse, direct playback, server-loss retry | Pending — no connected device/server | Attach video and redacted result |

Publication is blocked until every mandatory physical row passes or receives an
explicit, documented release waiver from the owning council.

## Physical execution — 2026-07-29

- Pixel 9 (`tokay`), Android 17/API 37, was awake and unlocked over wireless
  ADB. Coins version `0.0.6` code `8` resolved only to `CoinsActivity`, acquired
  focus within one second, and exposed the expected vault semantics. Android's
  secure-window policy redacts screenshots, so the accessibility tree—not a
  black capture—was used for render diagnostics. The same PID survived a
  launcher background/resume cycle. Human tab navigation and PiP/media-session
  checks are still unverified.
- Fire TV Stick 3rd Gen (`AFTSSS`), Android 9/API 28, is a 32-bit
  `armeabi-v7a` target at 1920×1080. Installing the canonical arm64 candidate
  reproduced the expected ABI rejection at runtime (`libflutter.so` available
  only for `arm64-v8a`). The corrected split build produced a v7a release APK,
  version `0.0.6` split code `1008`, source SHA-256
  `d1b7b18674385b89326fd0313121b8ec160f31681e7358ed5bb7f464670801db`.
- The v7a payload was re-signed with the same local Android debug certificate
  as the installed v0.0.5 dogfood build so playlists would not be erased. The
  exact installed rig APK SHA-256 is
  `6593f02c5982e90fff507d7c610215a468b60e6b471c8d3fdc0ca9ef92bbf6a6`.
  This proves the release-mode v7a payload on hardware but is not
  distribution-signature evidence.
- A physical remote wake exposed the rendered home screen, and a physical
  Select opened the Playlist sources modal. Rail traversal, Back dismissal,
  player/recovery behavior, and playback-scoped bounded logs remain pending.
