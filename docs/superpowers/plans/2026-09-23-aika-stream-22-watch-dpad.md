# Aika Stream 22 Watch D-pad Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give Watch one D-pad state machine so player controls and the Mini Guide never compete for the same keys.

**Architecture:** A pure `watchRemoteAction` function owns the contract from the spec. `_handleSurfInput` and the Mini Guide key handler call it. One `WatchOverlay` value is visible. Recently watched replaces the separate Down overlay.

**Tech Stack:** Flutter, Riverpod, `packages/feature_iptv`, `TvInputKey` from `core_ui`.

**Spec:** `docs/superpowers/specs/2026-09-23-aika-stream-22-design.md`

## Global Constraints

- Ships as `0.0.2+22` in `app/pubspec_tv.yaml`. Found in `0.0.2+21`. Never reuse versionCode 21.
- `versionName` stays `0.0.2`.
- Do not extend `TvInputKey`.
- Locked playback and diagnostic recovery keep their current key ownership.
- Mini Guide still has one muted preview decoder.
- One strong focus target. Controls and Mini Guide are never both fully visible.
- Hint copy, exact: controls `←→ Move    OK Select    Back Close`; Mini Guide `←→ Browse    OK Switch    Back Close`. Hide after 4 seconds idle.
- Delete the always-visible `MENU for more actions` string.
- Channel overlay uses `name` and, when useful, `group`. No invented resolution.
- Parsing stays off the main isolate. This change does not parse playlists.

---

### Task 1: Pure remote contract

**Files:**
- Create: `packages/feature_iptv/lib/presentation/widgets/watch_remote_contract.dart`
- Test: `packages/feature_iptv/test/presentation/widgets/watch_remote_contract_test.dart`

**Interfaces:**
- Consumes: `TvInputKey` from `package:core_ui/core_ui.dart`
- Produces: `WatchFocusZone`, `WatchRemoteAction`, `WatchRemoteAction watchRemoteAction({required WatchFocusZone zone, required TvInputKey key})`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:core_ui/core_ui.dart';
import 'package:feature_iptv/presentation/widgets/watch_remote_contract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  WatchRemoteAction act(WatchFocusZone zone, TvInputKey key) =>
      watchRemoteAction(zone: zone, key: key);

  test('video keys open one zone or step the channel', () {
    expect(act(WatchFocusZone.video, TvInputKey.select), WatchRemoteAction.openControls);
    expect(act(WatchFocusZone.video, TvInputKey.up), WatchRemoteAction.openControls);
    expect(act(WatchFocusZone.video, TvInputKey.down), WatchRemoteAction.openMiniGuide);
    expect(act(WatchFocusZone.video, TvInputKey.left), WatchRemoteAction.previousChannel);
    expect(act(WatchFocusZone.video, TvInputKey.right), WatchRemoteAction.nextChannel);
    expect(act(WatchFocusZone.video, TvInputKey.back), WatchRemoteAction.exitPlayer);
    expect(act(WatchFocusZone.video, TvInputKey.menu), WatchRemoteAction.moreActions);
  });

  test('controls keys stay on the rail or dismiss', () {
    expect(act(WatchFocusZone.controls, TvInputKey.select), WatchRemoteAction.activateFocusedControl);
    expect(act(WatchFocusZone.controls, TvInputKey.left), WatchRemoteAction.moveControl);
    expect(act(WatchFocusZone.controls, TvInputKey.right), WatchRemoteAction.moveControl);
    expect(act(WatchFocusZone.controls, TvInputKey.up), WatchRemoteAction.ignored);
    expect(act(WatchFocusZone.controls, TvInputKey.down), WatchRemoteAction.closeControls);
    expect(act(WatchFocusZone.controls, TvInputKey.back), WatchRemoteAction.closeControls);
    expect(act(WatchFocusZone.controls, TvInputKey.menu), WatchRemoteAction.moreActions);
  });

  test('mini guide keys move cards or hand focus back', () {
    expect(act(WatchFocusZone.miniGuide, TvInputKey.select), WatchRemoteAction.switchFocusedChannel);
    expect(act(WatchFocusZone.miniGuide, TvInputKey.left), WatchRemoteAction.moveChannel);
    expect(act(WatchFocusZone.miniGuide, TvInputKey.right), WatchRemoteAction.moveChannel);
    expect(act(WatchFocusZone.miniGuide, TvInputKey.up), WatchRemoteAction.showControls);
    expect(act(WatchFocusZone.miniGuide, TvInputKey.down), WatchRemoteAction.closeGuide);
    expect(act(WatchFocusZone.miniGuide, TvInputKey.back), WatchRemoteAction.closeGuide);
    expect(act(WatchFocusZone.miniGuide, TvInputKey.menu), WatchRemoteAction.moreActions);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd packages/feature_iptv && dart test test/presentation/widgets/watch_remote_contract_test.dart`

Expected: FAIL. `watch_remote_contract.dart` does not exist.

- [ ] **Step 3: Write the contract**

```dart
import 'package:core_ui/core_ui.dart';

enum WatchFocusZone { video, controls, miniGuide }

enum WatchRemoteAction {
  openControls,
  activateFocusedControl,
  switchFocusedChannel,
  previousChannel,
  nextChannel,
  moveControl,
  moveChannel,
  openMiniGuide,
  closeControls,
  closeGuide,
  showControls,
  exitPlayer,
  moreActions,
  ignored,
}

WatchRemoteAction watchRemoteAction({
  required WatchFocusZone zone,
  required TvInputKey key,
}) {
  return switch (zone) {
    WatchFocusZone.video => switch (key) {
      TvInputKey.select || TvInputKey.up => WatchRemoteAction.openControls,
      TvInputKey.down => WatchRemoteAction.openMiniGuide,
      TvInputKey.left => WatchRemoteAction.previousChannel,
      TvInputKey.right => WatchRemoteAction.nextChannel,
      TvInputKey.back => WatchRemoteAction.exitPlayer,
      TvInputKey.menu => WatchRemoteAction.moreActions,
      _ => WatchRemoteAction.ignored,
    },
    WatchFocusZone.controls => switch (key) {
      TvInputKey.select => WatchRemoteAction.activateFocusedControl,
      TvInputKey.left || TvInputKey.right => WatchRemoteAction.moveControl,
      TvInputKey.down || TvInputKey.back => WatchRemoteAction.closeControls,
      TvInputKey.menu => WatchRemoteAction.moreActions,
      _ => WatchRemoteAction.ignored,
    },
    WatchFocusZone.miniGuide => switch (key) {
      TvInputKey.select => WatchRemoteAction.switchFocusedChannel,
      TvInputKey.left || TvInputKey.right => WatchRemoteAction.moveChannel,
      TvInputKey.up => WatchRemoteAction.showControls,
      TvInputKey.down || TvInputKey.back => WatchRemoteAction.closeGuide,
      TvInputKey.menu => WatchRemoteAction.moreActions,
      _ => WatchRemoteAction.ignored,
    },
  };
}
```

Export the file from `packages/feature_iptv/lib/feature_iptv.dart` only if that barrel already exports presentation widgets. If it does not, tests import the file path above and nothing else changes.

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd packages/feature_iptv && dart test test/presentation/widgets/watch_remote_contract_test.dart`

Expected: PASS, 3 tests.

- [ ] **Step 5: Commit**

```bash
git add packages/feature_iptv/lib/presentation/widgets/watch_remote_contract.dart \
  packages/feature_iptv/test/presentation/widgets/watch_remote_contract_test.dart
git commit -m "feat(iptv): add the Watch D-pad zone contract"
```

---

### Task 2: Mini Guide reports vertical moves instead of swallowing them

**Files:**
- Modify: `packages/feature_iptv/lib/presentation/widgets/tv_mini_guide_overlay.dart`
- Test: `packages/feature_iptv/test/presentation/widgets/tv_mini_guide_overlay_test.dart`

**Interfaces:**
- Consumes: `watchRemoteAction` from Task 1
- Produces: `TvMiniGuideOverlay.onMoveToControls` and `TvMiniGuideOverlay.onDismiss`, both `VoidCallback`

Current `_handleBrowseKey` treats Up and Down as handled and does nothing. Replace that branch.

- [ ] **Step 1: Write the failing test**

Add this test next to the existing Mini Guide widget tests. Use the file’s existing `pumpOverlay` helper if it already builds `TvMiniGuideOverlay`; otherwise pump the widget with two channels and a preview factory that returns a disposed fake. The assertions are:

```dart
testWidgets('Up asks the parent to show controls and Down asks it to close', (
  tester,
) async {
  var moved = 0;
  var dismissed = 0;
  await tester.pumpWidget(
    wrapMiniGuide(
      onMoveToControls: () => moved++,
      onDismiss: () => dismissed++,
    ),
  );
  await tester.pump();
  await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
  await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
  expect(moved, 1);
  expect(dismissed, 1);
});
```

`wrapMiniGuide` must pass the two new callbacks through. Match the pump helper already in `tv_mini_guide_overlay_test.dart` (`ProviderScope`, channels, `previewFactory`).

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd packages/feature_iptv && flutter test test/presentation/widgets/tv_mini_guide_overlay_test.dart`

Expected: FAIL. `onMoveToControls` is not a parameter.

- [ ] **Step 3: Wire the callbacks**

Add the two fields to `TvMiniGuideOverlay`. In `_handleBrowseKey`, after the Left/Right branch:

```dart
final action = watchRemoteAction(
  zone: WatchFocusZone.miniGuide,
  key: key ?? TvInputKey.home,
);
if (key == null) return KeyEventResult.ignored;
switch (action) {
  case WatchRemoteAction.moveChannel:
    return KeyEventResult.ignored; // Left/Right already requested focus above.
  case WatchRemoteAction.showControls:
    widget.onMoveToControls();
    return KeyEventResult.handled;
  case WatchRemoteAction.closeGuide:
    widget.onDismiss();
    return KeyEventResult.handled;
  case WatchRemoteAction.switchFocusedChannel:
  case WatchRemoteAction.moreActions:
    return KeyEventResult.ignored; // Select and Menu stay with the parent.
  default:
    return KeyEventResult.ignored;
}
```

Keep the existing Left/Right focus move. Do not start playback inside the overlay.

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd packages/feature_iptv && flutter test test/presentation/widgets/tv_mini_guide_overlay_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add packages/feature_iptv/lib/presentation/widgets/tv_mini_guide_overlay.dart \
  packages/feature_iptv/test/presentation/widgets/tv_mini_guide_overlay_test.dart
git commit -m "feat(iptv): let the Mini Guide hand focus up or close"
```

---

### Task 3: One Watch overlay, and Down opens the guide

**Files:**
- Modify: `packages/feature_iptv/lib/presentation/widgets/video_player_widget.dart`
- Modify: `packages/feature_iptv/test/iptv/presentation/widgets/video_player_widget_test.dart`
- Modify: `packages/feature_iptv/lib/presentation/widgets/tv_transport_bar.dart` (`menuHint` default becomes `''`)

**Interfaces:**
- Consumes: `watchRemoteAction`, `TvMiniGuideOverlay.onMoveToControls`, `TvMiniGuideOverlay.onDismiss`, `recentlyWatchedChannelsProvider`
- Produces: `_watchZone` getter. `_quickBrowse == miniGuide` becomes the only browse overlay. `_TvQuickBrowse.recent` and the `_QuickBrowseOverlay` branch at the `recentlyWatchedChannelsProvider` call site are removed.

Zone mapping inside the player:

```dart
WatchFocusZone get _watchZone {
  if (_quickBrowse == _TvQuickBrowse.miniGuide) return WatchFocusZone.miniGuide;
  if (_showControlsOverlay && widget.showControls) return WatchFocusZone.controls;
  return WatchFocusZone.video;
}
```

- [ ] **Step 1: Update the existing Up test so it expects the new contract**

In `video_player_widget_test.dart`, rename the test that says `D-pad up opens the Mini Guide` to:

`Down opens the Mini Guide; Up opens controls; Left steps the channel`

Drive `LogicalKeyboardKey.arrowDown` where the test currently sends Up. Assert the Mini Guide card is present. Then send Up and assert the guide is gone and the transport Play/Pause key (`iptv-tv-transport-play-pause`) has focus. Send Left while controls are hidden and assert `playChannel` (or the existing channel-change overlay text) moved to the previous channel instead of revealing the transport bar.

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/widgets/video_player_widget_test.dart`

Expected: FAIL on the Down assertion, because Up still opens the guide.

- [ ] **Step 3: Replace `_handleSurfInput`’s switch**

When `_isLocked` or diagnostic recovery owns focus, return `TvInputResult.notHandled` before the contract, as today.

```dart
final action = watchRemoteAction(zone: _watchZone, key: key);
switch (action) {
  case WatchRemoteAction.openControls:
  case WatchRemoteAction.showControls:
    setState(() => _quickBrowse = null);
    _showControls();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _claimTvTransportFocus();
    });
    return TvInputResult.handled;
  case WatchRemoteAction.openMiniGuide:
    if (ref.read(streamingStateProvider).asData?.value.currentChannel == null) {
      return TvInputResult.notHandled;
    }
    setState(() {
      _showControlsOverlay = false;
      _quickBrowse = _TvQuickBrowse.miniGuide;
    });
    return TvInputResult.handled;
  case WatchRemoteAction.previousChannel:
    _goToPreviousChannel();
    return TvInputResult.handled;
  case WatchRemoteAction.nextChannel:
    _goToNextChannel();
    return TvInputResult.handled;
  case WatchRemoteAction.closeControls:
  case WatchRemoteAction.closeGuide:
    _suppressNextPlatformBack = action == WatchRemoteAction.closeGuide &&
        key == TvInputKey.back;
    setState(() {
      _showControlsOverlay = false;
      _quickBrowse = null;
    });
    return TvInputResult.handled;
  case WatchRemoteAction.exitPlayer:
    _suppressNextPlatformBack = false;
    final closeFullscreen = widget.onBack ?? widget.onFullscreenToggle;
    if (widget.initiallyFullscreen && closeFullscreen != null) {
      closeFullscreen();
      return TvInputResult.handled;
    }
    return TvInputResult.notHandled;
  case WatchRemoteAction.moreActions:
    // Keep the existing _showPlayerActionsSheet call.
    return TvInputResult.handled;
  case WatchRemoteAction.moveControl:
  case WatchRemoteAction.activateFocusedControl:
  case WatchRemoteAction.switchFocusedChannel:
  case WatchRemoteAction.moveChannel:
  case WatchRemoteAction.ignored:
    return TvInputResult.notHandled;
}
```

Pass `onMoveToControls` and `onDismiss` into `TvMiniGuideOverlay`. Both call the same handlers as `showControls` and `closeGuide`.

Mini Guide channels:

```dart
List<IPTVChannel> _miniGuideChannels(IPTVChannel current) {
  final recent = ref.read(recentlyWatchedChannelsProvider).asData?.value;
  if (recent != null && recent.isNotEmpty) return recent;
  // existing playlist-window fallback stays for an empty history
}
```

Delete the `if (_quickBrowse == _TvQuickBrowse.recent)` branch and `_QuickBrowseOverlay` if nothing else references them. Delete `_TvQuickBrowse.recent`.

Transport hint: pass `menuHint: _transportHint` where `_transportHint` is `←→ Move    OK Select    Back Close` only while `_watchZone == controls` and `_hintVisible` is true. A `Timer` of 4 seconds, reset from `_handleSurfInput` when an action is handled, sets `_hintVisible` false. Mini Guide hint is the same timer inside `TvMiniGuideOverlay`, text `←→ Browse    OK Switch    Back Close`, replacing the hard-coded `◀ ▶ browse   OK switch` line.

Wrap the bottom overlay in `AnimatedSwitcher(duration: const Duration(milliseconds: 200))` with one child: transport, Mini Guide, or nothing.

- [ ] **Step 4: Run the player tests**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/widgets/video_player_widget_test.dart test/presentation/widgets/video_player_widget_tv_transport_bar_test.dart test/presentation/widgets/tv_mini_guide_overlay_test.dart`

Expected: PASS. The transport test that expects `MENU for more actions` is updated to expect no text when the hint timer has fired, and the move/select/back line before it fires.

- [ ] **Step 5: Commit**

```bash
git add packages/feature_iptv/lib/presentation/widgets/video_player_widget.dart \
  packages/feature_iptv/lib/presentation/widgets/tv_transport_bar.dart \
  packages/feature_iptv/lib/presentation/widgets/tv_mini_guide_overlay.dart \
  packages/feature_iptv/test/iptv/presentation/widgets/video_player_widget_test.dart \
  packages/feature_iptv/test/presentation/widgets/video_player_widget_tv_transport_bar_test.dart
git commit -m "feat(iptv): coordinate Watch controls and the Mini Guide"
```

---

### Task 4: Version code 22

**Files:**
- Modify: `app/pubspec_tv.yaml` (`version: 0.0.2+21` → `version: 0.0.2+22`)
- Modify: `docs/release/AIKA_STREAM_PLAY_STORE_GATE.md` (next AAB is 22; do not reuse 21)

- [ ] **Step 1: Change the version and the gate note**

`pubspec_tv.yaml` version line becomes `version: 0.0.2+22`.

In the Play gate, record that 21 is consumed by this packet’s predecessor and the next upload is `0.0.2+22`.

- [ ] **Step 2: Analyze the player package**

Run: `cd packages/feature_iptv && dart analyze lib/presentation/widgets/watch_remote_contract.dart lib/presentation/widgets/video_player_widget.dart lib/presentation/widgets/tv_mini_guide_overlay.dart`

Expected: no issues.

- [ ] **Step 3: Commit**

```bash
git add app/pubspec_tv.yaml docs/release/AIKA_STREAM_PLAY_STORE_GATE.md
git commit -m "chore(tv): cut Aika Stream 0.0.2+22 for the Watch D-pad contract"
```

Do not upload an AAB in this plan. The release workflow stays opt-in.
