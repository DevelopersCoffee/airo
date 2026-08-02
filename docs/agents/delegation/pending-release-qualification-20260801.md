# Delegation Brief — Release Qualification 2026-08-01 [CLOSED]

Worktree: `airo-worktrees/release-qualification-20260801`
Branch: `agent/release/release-qualification-20260801` (from `origin/main` @ `dc7406d6`)

Status: all 4 items executed and verified 2026-08-01/02. v0.0.6-rc.1 already published on GitHub (2026-08-01T10:24:56Z) with exactly the signing/macOS posture confirmed below — no new tag was cut, none was needed.

## 1. Pixel 9 physical qualification — PASS
- Reconnected via existing wireless-adb pairing (`adb-4C031VDAQ000GG-esFRxC._adb-tls-connect._tcp`).
- `io.airo.app.coins` already at current-head (versionCode 8, versionName 0.0.6-rc.1, installed 2026-08-01 22:24) — reinstall attempt correctly blocked by `INSTALL_FAILED_VERSION_DOWNGRADE` against a stale `pubspec_coins.yaml`-profile debug build (versionCode 1); confirms `pubspec_coins.yaml` is stale relative to the shipped Coins build and should be version-aligned in a follow-up.
- Cold launch: clean, `Displayed +255ms`, no crash (screen is FLAG_SECURE-blanked by design for the vault; verified via logcat + uiautomator dump, not screenshot).
- Tab navigation: all 5 tabs (Coins/Mind/Beats/Live/More) confirmed via uiautomator content-desc dumps.
- Background/resume: same PID (4084) across HOME + relaunch, state preserved.
- Process survival: same PID survived `am send-trim-memory RUNNING_CRITICAL`.

## 2. Fire TV physical-remote qualification — PASS (1 finding)
- Traversed Home → Guide → Movies → Favorites → Settings via D-pad keyevents over adb (192.168.1.9:5555).
- Opened/closed the "Playlist sources" modal cleanly; added a real IPTV.org M3U source; started a live channel (played correctly after one dead-link skip, using the existing Try Again/Skip/Report failover UX).
- **Finding:** Back key is intermittently swallowed on the channel-browse grid after returning from playback — D-pad movement still works, only Back does nothing until focus shifts to the sidebar. Not a full lockup; worth filing as a GitHub issue against `core_remote_control`/`platform_receiver_modes` (tv-experience-architect owns this area). Not raised as an issue yet — pending user go-ahead.
- One unrelated confound during testing: a concurrent process force-stopped/reinstalled `io.airo.app.tv` mid-session (visible in logcat as `deletePackageX`) — not an app bug, just shared-device noise; re-verified cleanly after.

## 3. Release signing — PASS
- Dogfood keystore secrets (`DOGFOOD_KEYSTORE_BASE64` + friends) confirmed present in repo secrets since 2026-07-19.
- Confirmed used successfully in the 2026-08-01 10:49 UTC "Airo Mobile and Tablet Release" run (`signing_cert=dogfood-stable` branch selected).
- Local `app-debug.apk` built during Pixel qual (debug-signed, from stale `pubspec_coins.yaml`) was never installed over the device build and was not published — hard rule held.

## 4. Final release decision — RESOLVED: ship ad-hoc macOS
- No Apple Developer ID / notarization secrets exist anywhere (repo or org secrets checked) — unchanged blocker from [[airo-release-cut-playbook]].
- User decision: ship ad-hoc, unnotarized macOS alongside the proven Android dogfood build.
- Verified this is already exactly what's live: GitHub release `v0.0.6-rc.1` (published 2026-08-01T10:24:56Z, prerelease) ships `Airo-TV-0.0.6-rc.1-macOS.dmg`/`.zip` ad-hoc dogfood-signed alongside `AiroCoins-0.0.6-rc.1-8-*` and `Airo-TV-0.0.6-rc.1-*.apk`. Release notes explicitly scope out store submission, Play upload, and macOS notarization for this cut. No new tag was needed.

## Follow-ups not yet actioned
- File Fire TV Back-key-swallowed bug as a GitHub issue (owner: tv-experience-architect / core_remote_control).
- Realign `app/pubspec_coins.yaml` version (currently 0.0.1+1) with the actual shipped Coins version (0.0.6+8) so `scripts/build-coins.sh` stops producing downgrade-blocked artifacts.
- Chess AI broken in release builds — stockfish stub override bug, issue #1407. Not release-blocking for TV/Coins qual above but flag if scope expands to phone release.
- Two latent orchestrator bugs noted in release-cut playbook — still unverified, not exercised by this qual round.
