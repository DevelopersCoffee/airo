# Pending Delegation Brief — Release Qualification 2026-08-01

Worktree: `airo-worktrees/release-qualification-20260801`
Branch: `agent/release/release-qualification-20260801` (from `origin/main` @ `dc7406d6`)

Status per [[airo-release-cut-playbook]] + [[pixel9-qa-2026-07-30]]: v0.0.6-rc.1 cut proven end-to-end. This brief covers remaining physical-device qual + signing gate before publish.

## 1. Pixel 9 physical qualification
- ADB shows Pixel absent. Reconnect wireless debugging first (`adb pair` / `adb connect <ip>:<port>`).
- Install current-head Airo Coins `0.0.6+8`.
- Verify: cold launch, physical tab navigation, background/resume, process survival (no OOM kill on switch-away).
- Record pass/fail + device evidence (screenshot/logcat) per task.

## 2. Fire TV physical-remote qualification
- Current-head `0.0.6-rc.1` code `1006` already installed, rendering confirmed.
- Real remote traverse: Home → Guide → Movies → Favorites → Settings.
- Open/close one modal, start one channel, Back-navigate to Home.
- Report stuck focus (known TV D-pad risk area, see [[airo-tv-dpad-design-project]]) or confirm "Fire pass."

## 3. Release signing
- Provision stable dogfood keystore (not ad-hoc debug signing).
- Rebuild Android artifacts under distribution identity.
- Verify upgrade compatibility over previous preview build (no signature mismatch on update-in-place — this bit Fire TV install last session, see [[pixel9-qa-2026-07-30]]).
- Hard rule: current locally/debug-signed files must NOT be published.

## 4. Final release decision
- Gate on Pixel + Fire results above.
- Decide: is ad-hoc, unnotarized macOS distribution acceptable for this cut? (macOS notarization currently blocked on missing Apple signing secrets — [[airo-release-cut-playbook]].)
- Only after decision: cut tags / publish artifacts.

## Known open risk carried in
- Chess AI broken in release builds — stockfish stub override bug, issue #1407. Not release-blocking for TV/Coins qual above but flag if scope expands to phone release.
- Two latent orchestrator bugs noted in release-cut playbook — check before automating this qual round.
