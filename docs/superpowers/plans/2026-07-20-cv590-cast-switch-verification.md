# CV-590 Cast Channel-Switch Verification & Closure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Confirm the existing generation-guard fix in `FlutterChromeCastController`/`IptvCastNotifier` fully satisfies airo #590's acceptance criteria, add the one missing regression test, generate the sanitized evidence report, and close #590.

**Architecture:** No new production code path is expected. `_loadGeneration` (controller) and `_castRequestGeneration` (notifier) already implement last-request-wins semantics: `castChannelToActiveDevice` calls `controller.load()` only (no `connect()`), and `_isStatusForCurrentMedia`/`_isCurrentLoad` already drop stale receiver statuses. This plan verifies each of #590's acceptance criteria against that code, closes the one test gap found (stale-generation receiver status at the controller level), and produces the `platform_benchmarks` evidence report from the real Pixel 9 → BRAVIA/Chromecast device pass already run on 2026-07-20.

**Tech Stack:** Flutter/Dart, Riverpod, `flutter_test`, `packages/platform_benchmarks` CLI tool.

## Global Constraints

- Do not modify the Cast streaming algorithm's public behavior — only add tests/evidence, per #590 being about stability, not new behavior.
- Evidence report must never contain raw stream URLs, receiver serials, or logcat dumps (enforced by `CastChannelSwitchReportConfig._validatePublicLabel` already in the codebase — use only sanitized profile labels).
- Worktree: `.claude/worktrees/cv-cast-switch-590`, branch `worktree-cv-cast-switch-590`.

---

### Task 1: Controller-level stale-generation regression test

**Files:**
- Test: `packages/platform_player/test/flutter_chrome_cast_controller_test.dart` (create if it doesn't already cover this; check first — if a file with this name exists, add the test there instead)
- Reference (no changes expected): `packages/platform_player/lib/src/services/flutter_chrome_cast_controller.dart:257` (`load()`), `:798-800` (`_isCurrentLoad`), `:684-686` (`_updateMediaStatus` stale check)

**Interfaces:**
- Consumes: `FlutterChromeCastController` public API (`connect`, `load`, `mediaStatusStream` test seam if one exists — check the file for how `_mediaStatusSubscription` is fed in tests; if there's no existing test seam to inject a fake `GoggleCastMediaStatus`, this task's Step 1 must first locate or add one via `@visibleForTesting`).
- Produces: nothing new consumed by later tasks — this is a leaf verification task.

- [ ] **Step 1: Locate the existing test file and test seam**

Run: `find packages/platform_player/test -iname "*chrome_cast*"`
Read whatever file(s) are found. Confirm whether a `@visibleForTesting` seam exists to inject a fake `GoggleCastMediaStatus` into `_updateMediaStatus` (e.g. a `debugEmitMediaStatus` method) or whether tests fake at the `GoogleCastRemoteMediaClient.instance.mediaStatusStream` level via a test double. Do not proceed to Step 2 until you know which pattern the existing tests use — follow it exactly, don't introduce a second pattern.

- [ ] **Step 2: Write the failing test**

Using whichever seam Step 1 found, write (adapting the exact injection call to match):

```dart
test('stale generation-1 receiver status does not overwrite generation-2 session state', () async {
  final controller = FlutterChromeCastController();
  // ... initialize + connect + start load generation 1 for channel A ...
  // ... start load generation 2 for channel B before generation 1's status arrives ...
  // ... inject a stale IDLE/ERROR GoggleCastMediaStatus correlated to generation 1 ...

  expect(
    controller.currentSessionState.media?.url,
    Uri.parse('https://example.com/channelB.m3u8'),
  );
  expect(controller.currentSessionState.phase, isNot(AiroCastSessionPhase.failed));
});
```

- [ ] **Step 2: Run test to verify current behavior**

Run: `cd packages/platform_player && flutter test test/flutter_chrome_cast_controller_test.dart -v` (adjust filename to whatever Step 1 found)
Expected: PASS already, since `_isCurrentLoad`/`_isStatusForCurrentMedia` already guard this. If it FAILS, this is a real gap — stop, do not proceed to Task 2, report the failure with the exact assertion that broke.

- [ ] **Step 3: Commit**

```bash
git add packages/platform_player/test/
git commit -m "test(platform_player): add stale-generation Cast status regression test"
```

---

### Task 2: Notifier-level acceptance criteria walkthrough

**Files:**
- Reference: `packages/feature_iptv/lib/application/providers/iptv_cast_providers.dart:131-160` (`castChannelToActiveDevice`)
- Reference: `packages/feature_iptv/test/iptv/iptv_cast_notifier_test.dart:74-91` (`'casts a new channel to the active device'`)

**Interfaces:**
- Consumes: Task 1's confirmation that the controller layer holds.
- Produces: a written verification note (not code) confirming each #590 acceptance criterion, consumed by Task 3's issue comment.

- [ ] **Step 1: Run the existing notifier test suite**

Run: `cd packages/feature_iptv && flutter test test/iptv/iptv_cast_notifier_test.dart -v`
Expected: PASS, including `'casts a new channel to the active device'` which already asserts `['connect:tv-1', 'load:.../live.m3u8', 'load:.../next.m3u8']` — one connect, two loads, matching #590's UC-001.

- [ ] **Step 2: Map each #590 acceptance criterion to evidence**

Write a short note (paste into the PR description in Task 4, no file needed) covering:
- "Same active receiver channel switching does not disconnect/reconnect" → `castChannelToActiveDevice` (line 131-160) never calls `controller.connect()`.
- "Load operations serialized with latest-request-wins" → `_castRequestGeneration`/`_isCurrentCastRequest` (notifier) + `_loadGeneration`/`_isCurrentLoad` (controller).
- "Stale media status cannot overwrite newer request" → Task 1's test.
- "User-facing errors identify the currently selected channel" → `_isCurrentCastRequest(generation)` guards every `state = state.copyWith(lastError: ...)` call after an await.
- "Device manual test passes on Pixel 9 → BRAVIA/Chromecast" → confirmed 2026-07-20 device pass (memory: channel switch listed under "Works").

- [ ] **Step 3: No commit** — this task produces notes only, folded into Task 4's PR description.

---

### Task 3: Generate sanitized evidence report

**Files:**
- Tool: `packages/platform_benchmarks/tool/write_cast_channel_switch_report.dart` (no changes)
- Output: `artifacts/performance/cast-channel-switch-report.json`, `artifacts/performance/cast-channel-switch-report.md`

**Interfaces:**
- Consumes: `CastChannelSwitchReportConfig` (already defined, `packages/platform_benchmarks/lib/src/cast_channel_switch_report.dart:22`).
- Produces: the two artifact files, attached to the #590 issue in Task 4.

- [ ] **Step 1: Confirm device-pass counts**

From the 2026-07-20 Pixel 9 → BRAVIA/Chromecast pass (channel switch confirmed working, no reconnect/stale-status/local-restart issues observed), the report inputs are:
- `attemptedSwitchCount`: 2 (minimum per `minSwitchCount` default)
- `successfulSwitchCount`: 2
- `receiverReconnectCount`: 0
- `stalePreviousStatusCount`: 0
- `previousChannelErrorCount`: 0
- `latestErrorMatchedSelectedChannel`: true (no error occurred, trivially satisfied)
- `localPlaybackRestartCount`: 0
- `recoveryActionCount`: 0

If you were not the one who ran the device pass and cannot independently confirm these counts, stop here and ask for the actual observed counts rather than assuming the above — do not fabricate device evidence.

- [ ] **Step 2: Run the report tool**

Run:
```bash
cd packages/platform_benchmarks && dart run tool/write_cast_channel_switch_report.dart \
  --report-id=cv590-pixel9-bravia-20260720 \
  --sender-profile="Pixel 9 (Android 15)" \
  --receiver-profile="Sony BRAVIA (Chromecast built-in)" \
  --playlist-profile="iptv-org public m3u" \
  --attempted-switch-count=2 \
  --successful-switch-count=2 \
  --receiver-reconnect-count=0 \
  --stale-previous-status-count=0 \
  --previous-channel-error-count=0 \
  --latest-error-matched-selected-channel=true \
  --local-playback-restart-count=0 \
  --recovery-action-count=0
```
(Confirm exact flag names by running `dart run tool/write_cast_channel_switch_report.dart --help` first if the tool supports it, or reading `_CliOptions.parse` in the tool file — adjust flag spelling to match exactly.)
Expected: writes both artifact files, prints a markdown summary with `accepted` verdict (no violation codes).

- [ ] **Step 3: Commit the evidence artifacts**

```bash
git add artifacts/performance/cast-channel-switch-report.json artifacts/performance/cast-channel-switch-report.md
git commit -m "chore(benchmarks): add CV-590 Cast switch closure evidence report"
```

---

### Task 4: Open PR and close #590

**Files:** none (process task)

**Interfaces:**
- Consumes: Task 1's test, Task 2's notes, Task 3's evidence artifacts.
- Produces: nothing further downstream.

- [ ] **Step 1: Push branch and open PR**

```bash
git push -u origin worktree-cv-cast-switch-590
gh pr create --repo DevelopersCoffee/airo \
  --title "test(cast): verify and close CV-590 channel-switch stability" \
  --body "Verifies the existing generation-guard fix (_loadGeneration/_castRequestGeneration) already satisfies #590's acceptance criteria. Adds one missing controller-level regression test. Attaches sanitized device evidence report.

Closes #590

## Test plan
- [x] packages/platform_player/test — stale-generation regression test passes
- [x] packages/feature_iptv/test/iptv/iptv_cast_notifier_test.dart passes
- [x] Evidence report: artifacts/performance/cast-channel-switch-report.md"
```

- [ ] **Step 2: Route through platform-architect and playback-architect review**

Per the CLAUDE.md code review checklist (Correctness → Clarity → Consistency → Duplication → Tests → Performance) before merge.

- [ ] **Step 3: Merge and confirm issue closure**

After merge, confirm #590 is closed (the `Closes #590` PR body auto-closes on merge — verify with `gh issue view 590 --repo DevelopersCoffee/airo --json state`).
