# Fire OS Local Network Testing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Get Airo TV deployed to a physical Fire TV Stick over the local network, run it through a manual test checklist, and log real-device evidence into the device guide.

**Architecture:** No new app code. Airo TV already builds as a standard leanback Android APK (`APP_VARIANT=tv` flavor) — Fire OS runs stock Android APKs directly. This plan wires up isolated worktree, ADB-over-WiFi deploy pipeline, and manual verification, then records findings.

**Tech Stack:** Flutter (`flutter build apk` / `flutter run`), ADB, existing `app/android` Gradle `tv` flavor.

## Global Constraints

- Out of scope: Amazon Appstore submission, Amazon IAP, Fire App Builder compliance, Vega OS.
- Entrypoint must be `app/lib/main_tv.dart`, not `main.dart`.
- Build must use `--dart-define=APP_VARIANT=tv` (selects `io.airo.app.tv` applicationId + leanback manifest — without it Gradle falls back to the `full` flavor's non-TV manifest).
- Mac and Fire Stick must be on the same LAN/WiFi for `adb connect` to work.
- No automated test suite is being added — verification is manual against the checklist in Task 4.

---

### Task 1: Create isolated worktree

**Files:**
- None (git operation only)

**Interfaces:**
- Produces: working directory `../airo-fire-os` on branch `fire-os-testing`, used as the cwd for every later task.

- [ ] **Step 1: Confirm current workspace is clean enough to branch from**

```bash
git -C /Users/udaychauhan/workspace/airo status
```
Expected: shows the pre-existing uncommitted `platform_player` changes — that's fine, they stay behind in the main workspace and are NOT touched by this plan.

- [ ] **Step 2: Create the worktree**

```bash
git -C /Users/udaychauhan/workspace/airo worktree add ../airo-fire-os -b fire-os-testing
```
Expected: `Preparing worktree (new branch 'fire-os-testing')` then a checkout confirmation line.

- [ ] **Step 3: Verify worktree registered**

```bash
git -C /Users/udaychauhan/workspace/airo worktree list
```
Expected: new row `/Users/udaychauhan/workspace/airo-fire-os  <sha> [fire-os-testing]`.

- [ ] **Step 4: Fetch Flutter deps in the new worktree**

```bash
cd /Users/udaychauhan/workspace/airo-fire-os/app && flutter pub get
```
Expected: exits 0, `Got dependencies!` (or similar) with no error lines.

---

### Task 2: Enable developer mode on the Fire TV Stick and capture its LAN IP

**Files:**
- None (device-side configuration, done through the Fire TV remote UI)

**Interfaces:**
- Consumes: nothing.
- Produces: `<stick-ip>` — the Fire Stick's LAN IPv4 address, used as the ADB target for every later task.

- [ ] **Step 1: Enable Developer Options**

On the Fire TV Stick: Settings → My Fire TV → About → click the device name (e.g. "Fire TV Stick") 7 times. A toast confirms "You are now a developer!" and a "Developer Options" entry appears one level up in My Fire TV.

- [ ] **Step 2: Enable ADB debugging and unknown-source installs**

Settings → My Fire TV → Developer Options → turn on "ADB Debugging" and "Apps from Unknown Sources".

- [ ] **Step 3: Read the Stick's LAN IP**

Settings → My Fire TV → About → Network. Note the IPv4 address shown, e.g. `192.168.1.42`. Write it down — call it `<stick-ip>` in all later steps.

- [ ] **Step 4: Confirm the Mac is on the same LAN**

```bash
ipconfig getifaddr en0 || ipconfig getifaddr en1
```
Expected: an IP in the same subnet as `<stick-ip>` (e.g. both `192.168.1.x`). If not, join the Mac to the same WiFi network the Stick is on before continuing.

---

### Task 3: Connect ADB and deploy the TV build

**Files:**
- None (build/deploy only — no source changes)

**Interfaces:**
- Consumes: `<stick-ip>` from Task 2, worktree at `/Users/udaychauhan/workspace/airo-fire-os` from Task 1.
- Produces: Airo TV (`io.airo.app.tv`) installed and launched on the Stick, ready for Task 4's manual checklist.

- [ ] **Step 1: Connect ADB over WiFi**

```bash
adb connect <stick-ip>:5555
```
Expected: `connected to <stick-ip>:5555`. If it instead says `unable to connect`, re-check Task 2 Step 2 (ADB Debugging toggle) and that both devices are on the same network.

- [ ] **Step 2: Confirm the device is visible to Flutter**

```bash
cd /Users/udaychauhan/workspace/airo-fire-os/app && flutter devices
```
Expected: a line containing `<stick-ip>:5555` with a device name like `AFTT` / `AFTMM` (Amazon Fire TV model codes) and platform `android-arm` or `android-arm64`.

- [ ] **Step 3: Build the TV flavor release APK**

```bash
cd /Users/udaychauhan/workspace/airo-fire-os/app
flutter build apk --flavor tv --dart-define=APP_VARIANT=tv -t lib/main_tv.dart
```
Expected: exits 0, ends with `Built build/app/outputs/flutter-apk/app-tv-release.apk`.

- [ ] **Step 4: Install it on the Stick**

```bash
adb -s <stick-ip>:5555 install -r build/app/outputs/flutter-apk/app-tv-release.apk
```
Expected: `Success`.

- [ ] **Step 5: Launch it**

```bash
adb -s <stick-ip>:5555 shell monkey -p io.airo.app.tv -c android.intent.category.LAUNCHER 1
```
Expected: no error output; the Fire TV screen switches to the Airo TV splash/home screen. Confirm visually (physically look at the TV, or screen-mirror if available) that the app launched — the ADB command exiting 0 only proves the intent was sent, not that the UI rendered.

- [ ] **Step 6: (Iteration mode, optional) Use flutter run instead of build+install for faster cycles**

```bash
cd /Users/udaychauhan/workspace/airo-fire-os/app
flutter run -d <stick-ip>:5555 -t lib/main_tv.dart --dart-define=APP_VARIANT=tv
```
Expected: hot-reload session starts, same as running against any Android device. Use this instead of Steps 3-5 when iterating on fixes found during Task 4.

---

### Task 4: Run the manual test checklist and log results

**Files:**
- Create: `docs/superpowers/plans/2026-07-25-fire-os-test-results.md` (raw findings, working notes)
- Modify: `docs/features/airo-tv/AIRO_TV_DEVICE_GUIDE.md` (Fire TV rows, per existing table structure)

**Interfaces:**
- Consumes: running app on the Stick from Task 3.
- Produces: dated real-device evidence in `AIRO_TV_DEVICE_GUIDE.md`, replacing the current "compatible/qualification target" placeholder for Fire TV where evidence now exists.

- [ ] **Step 1: Capture device identity for the evidence record**

```bash
adb -s <stick-ip>:5555 shell getprop ro.product.model
adb -s <stick-ip>:5555 shell getprop ro.build.version.release
adb -s <stick-ip>:5555 shell getprop ro.build.version.incremental
```
Record all three outputs (device model, Android base version, Fire OS build) — the device guide's existing troubleshooting row already asks for "device model, Fire OS version" on any focus bug, so capture it once up front.

- [ ] **Step 2: Create the raw findings file**

```bash
cat > /Users/udaychauhan/workspace/airo-fire-os/docs/superpowers/plans/2026-07-25-fire-os-test-results.md << 'EOF'
# Fire OS Local Test Results — 2026-07-25

Device model: <fill in from Step 1>
Android base version: <fill in from Step 1>
Fire OS build: <fill in from Step 1>

| Check | Result | Notes |
|---|---|---|
| Leanback launcher icon + banner render on Fire TV home | | |
| D-pad focus navigation, all screens, no dead ends | | |
| Back button behavior (exits screens correctly, no crash) | | |
| Local-network IPTV stream playback | | |
| No touchscreen-only affordances blocking navigation | | |
| Memory/performance acceptable on Stick-class hardware | | |
| App survives backgrounding + resume | | |
EOF
```

- [ ] **Step 3: Walk the checklist on-device**

For each row, drive the app via the physical Fire TV remote (or `adb shell input keyevent` for D-pad simulation if remote isn't in hand), fill in Pass/Fail + notes directly in the file from Step 2. Use `docs/features/airo-tv/AIRO_TV_DEVICE_GUIDE.md` as the reference for expected user flow if any screen's behavior is ambiguous.

Useful `adb` key event codes for remote simulation:
```bash
adb -s <stick-ip>:5555 shell input keyevent KEYCODE_DPAD_UP
adb -s <stick-ip>:5555 shell input keyevent KEYCODE_DPAD_DOWN
adb -s <stick-ip>:5555 shell input keyevent KEYCODE_DPAD_LEFT
adb -s <stick-ip>:5555 shell input keyevent KEYCODE_DPAD_RIGHT
adb -s <stick-ip>:5555 shell input keyevent KEYCODE_DPAD_CENTER
adb -s <stick-ip>:5555 shell input keyevent KEYCODE_BACK
```

- [ ] **Step 4: Update the device guide with verified evidence**

Open `docs/features/airo-tv/AIRO_TV_DEVICE_GUIDE.md`. In the device support table (around line 18) and the "Quick Start: Fire TV" section (around lines 39-49), replace the "Compatible/qualification target" language with the actual result: if all checklist rows passed, change status to something like "Verified — see `docs/superpowers/plans/2026-07-25-fire-os-test-results.md` for device evidence (model, Fire OS version, date)". If any row failed, keep the qualification-target status but add a line linking to the specific failure in the results file instead of a bare "target" claim.

- [ ] **Step 5: Commit**

```bash
cd /Users/udaychauhan/workspace/airo-fire-os
git add docs/superpowers/plans/2026-07-25-fire-os-test-results.md docs/features/airo-tv/AIRO_TV_DEVICE_GUIDE.md
git commit -m "docs(airo-tv): log Fire TV Stick real-device test evidence"
```
Expected: commit succeeds with both files listed.

---

### Task 5: Wrap up

**Files:**
- None

**Interfaces:**
- Consumes: commit from Task 4.

- [ ] **Step 1: Push the branch**

```bash
git -C /Users/udaychauhan/workspace/airo-fire-os push -u origin fire-os-testing
```
Expected: branch pushed, upstream set.

- [ ] **Step 2: Decide PR vs. keep-local**

If findings are clean (all checklist rows passed), open a PR for the device guide update. If findings surfaced bugs, file separate GitHub issues per bug before opening the docs PR, and link them from the results file. Use `gh pr create` per the repo's standard PR flow once ready — this is a manual decision point, not a scripted step.
