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
| Pixel 9 | cold launch, Coins launcher, tab navigation, background/resume | Partial — candidate installed; secure keyguard is locked/dozing, so visual checks remain pending | `0.0.6` / code 8, launcher resolves to `CoinsActivity`, process and focused app record present |
| Fire TV Stick | D-pad rail/player, Back, buffering/error recovery, bounded log report | Pending — no connected device | Attach video/report/device build |
| iPad | launch, adaptive layout, playback, rotation/background/resume | Pending — no connected device | Attach video/sysdiagnose excerpt |
| Android TV + USB | permission prompt, folder browse, direct playback, sidecar subtitle | Pending — no connected device/media | Attach video and redacted result |
| Android TV + DLNA/UPnP | discovery, folder browse, direct playback, server-loss retry | Pending — no connected device/server | Attach video and redacted result |

Publication is blocked until every mandatory physical row passes or receives an
explicit, documented release waiver from the owning council.
