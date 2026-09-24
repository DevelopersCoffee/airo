# MultiView DJ Split Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Two-pane MultiView snaps 5/50/95 with an 80dp min pane, a short premium handle that stays 48dp on compact touch, and an equal-power DJ mix that follows the bar without touching system volume.

**Architecture:** Keep `MultiviewSplitRatio` as the persisted stop. Add extent-aware clamp/snap and `multiviewSplitGains` in the same math file. The two-pane widget reports live fraction; `MultiviewController` applies `setVolume` on the two sessions and skips pool `_routeAudio` while two-pane. Compact vs regular hit size comes from `LayoutBuilder` (`< 600` on either axis).

**Tech Stack:** Flutter, `feature_iptv`, `platform_player` pool, existing `TvFocusable` / `TvInputHandler`.

**Spec:** `docs/superpowers/specs/2026-09-24-multiview-dj-split-design.md`

**Base:** `origin/main` (already has 30/50/70 split). Do not bump Play `versionCode`. Do not touch Cast.

---

### File map

- Modify: `packages/feature_iptv/lib/application/multiview_split_ratio.dart`
- Modify: `packages/feature_iptv/test/application/multiview_split_ratio_test.dart`
- Modify: `packages/feature_iptv/lib/application/providers/multiview_provider.dart`
- Modify: `packages/feature_iptv/test/application/multiview_provider_test.dart`
- Modify: `packages/feature_iptv/lib/presentation/tv_ux/sections/multiview_two_pane_split.dart`
- Modify: `packages/feature_iptv/lib/presentation/tv_ux/sections/multiview_stage.dart`
- Modify: `packages/feature_iptv/test/iptv/presentation/tv_ux/multiview_stage_test.dart`
- Modify: `packages/platform_player/lib/src/services/airo_multiview_pool.dart` (optional `routeAudio` flag on `promote`)

---

### Task 1: 5/50/95 math, min-pane floor, equal-power gains

**Files:**
- Modify: `packages/feature_iptv/lib/application/multiview_split_ratio.dart`
- Test: `packages/feature_iptv/test/application/multiview_split_ratio_test.dart`

- [ ] **Step 1: Rewrite the ratio tests for the new stops**

Replace the file with:

```dart
import 'dart:math' as math;

import 'package:feature_iptv/application/multiview_split_ratio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('flex maps 5/50/95 to 50-950, 1-1, 950-50', () {
    expect(MultiviewSplitRatio.five.firstFlex, 50);
    expect(MultiviewSplitRatio.five.secondFlex, 950);
    expect(MultiviewSplitRatio.fifty.firstFlex, 1);
    expect(MultiviewSplitRatio.fifty.secondFlex, 1);
    expect(MultiviewSplitRatio.ninetyFive.firstFlex, 950);
    expect(MultiviewSplitRatio.ninetyFive.secondFlex, 50);
  });

  test('on a 1600px axis five is 5 percent', () {
    expect(effectiveMultiviewSplitMin(1600), closeTo(0.05, 0.0001));
    expect(
      snapMultiviewSplitFraction(0.06, extent: 1600),
      MultiviewSplitRatio.five,
    );
    expect(
      snapMultiviewSplitFraction(0.94, extent: 1600),
      MultiviewSplitRatio.ninetyFive,
    );
  });

  test('on a 360px axis five is the 80dp floor not 5 percent', () {
    expect(effectiveMultiviewSplitMin(360), closeTo(80 / 360, 0.0001));
    expect(
      snapMultiviewSplitFraction(0.05, extent: 360),
      MultiviewSplitRatio.five,
    );
    expect(clampMultiviewSplitFraction(0.05, extent: 360), 80 / 360);
  });

  test('snap prefers fifty on a tie', () {
    expect(snapMultiviewSplitFraction(0.50, extent: 1600), MultiviewSplitRatio.fifty);
  });

  test('step does not wrap past ninetyFive or five', () {
    expect(
      stepMultiviewSplitRatio(MultiviewSplitRatio.fifty, towardSecond: true),
      MultiviewSplitRatio.ninetyFive,
    );
    expect(
      stepMultiviewSplitRatio(MultiviewSplitRatio.ninetyFive, towardSecond: true),
      isNull,
    );
    expect(
      stepMultiviewSplitRatio(MultiviewSplitRatio.five, towardSecond: false),
      isNull,
    );
  });

  test('equal-power gains keep 50/50 near constant power', () {
    final mid = multiviewSplitGains(0.50, extent: 1600, globalVolume: 1);
    expect(mid.first, closeTo(math.sqrt(0.5), 0.01));
    expect(mid.second, closeTo(math.sqrt(0.5), 0.01));
    final quiet = multiviewSplitGains(0.05, extent: 1600, globalVolume: 1);
    expect(quiet.first, closeTo(0, 0.01));
    expect(quiet.second, closeTo(1, 0.01));
    final loud = multiviewSplitGains(0.95, extent: 1600, globalVolume: 0.5);
    expect(loud.first, closeTo(0.5, 0.01));
    expect(loud.second, closeTo(0, 0.01));
  });
}
```

- [ ] **Step 2: Run the test (expect FAIL on missing names)**

Run: `cd packages/feature_iptv && flutter test test/application/multiview_split_ratio_test.dart`

Expected: FAIL (`thirty` / missing `effectiveMultiviewSplitMin` / `multiviewSplitGains`).

- [ ] **Step 3: Implement the math**

```dart
import 'dart:math' as math;

enum MultiviewSplitRatio {
  five,
  fifty,
  ninetyFive;

  int get firstFlex => switch (this) {
    five => 50,
    fifty => 1,
    ninetyFive => 950,
  };

  int get secondFlex => switch (this) {
    five => 950,
    fifty => 1,
    ninetyFive => 50,
  };

  double get firstFraction => switch (this) {
    five => 0.05,
    fifty => 0.50,
    ninetyFive => 0.95,
  };
}

const double kMultiviewSplitMinFraction = 0.05;
const double kMultiviewSplitMaxFraction = 0.95;
const double kMultiviewMinPaneDp = 80;

double effectiveMultiviewSplitMin(double extent) {
  if (extent <= 0) return kMultiviewSplitMinFraction;
  final floor = kMultiviewMinPaneDp / extent;
  return math.max(kMultiviewSplitMinFraction, floor);
}

double clampMultiviewSplitFraction(double fraction, {required double extent}) {
  final min = effectiveMultiviewSplitMin(extent);
  final max = 1 - min;
  if (fraction < min) return min;
  if (fraction > max) return max;
  return fraction;
}

MultiviewSplitRatio snapMultiviewSplitFraction(
  double fraction, {
  required double extent,
}) {
  final min = effectiveMultiviewSplitMin(extent);
  final max = 1 - min;
  final clamped = clampMultiviewSplitFraction(fraction, extent: extent);
  final dFive = (clamped - min).abs();
  final dFifty = (clamped - 0.50).abs();
  final dNinetyFive = (clamped - max).abs();
  if (dFifty <= dFive && dFifty <= dNinetyFive) {
    return MultiviewSplitRatio.fifty;
  }
  if (dFive < dNinetyFive) return MultiviewSplitRatio.five;
  return MultiviewSplitRatio.ninetyFive;
}

MultiviewSplitRatio? stepMultiviewSplitRatio(
  MultiviewSplitRatio current, {
  required bool towardSecond,
}) {
  if (towardSecond) {
    return switch (current) {
      MultiviewSplitRatio.five => MultiviewSplitRatio.fifty,
      MultiviewSplitRatio.fifty => MultiviewSplitRatio.ninetyFive,
      MultiviewSplitRatio.ninetyFive => null,
    };
  }
  return switch (current) {
    MultiviewSplitRatio.ninetyFive => MultiviewSplitRatio.fifty,
    MultiviewSplitRatio.fifty => MultiviewSplitRatio.five,
    MultiviewSplitRatio.five => null,
  };
}

class MultiviewSplitGains {
  const MultiviewSplitGains({required this.first, required this.second});
  final double first;
  final double second;
}

MultiviewSplitGains multiviewSplitGains(
  double firstFraction, {
  required double extent,
  required double globalVolume,
}) {
  final min = effectiveMultiviewSplitMin(extent);
  final max = 1 - min;
  final f = clampMultiviewSplitFraction(firstFraction, extent: extent);
  final span = max - min;
  final t = span <= 0 ? 0.5 : ((f - min) / span).clamp(0.0, 1.0);
  final g = globalVolume.clamp(0.0, 1.0);
  return MultiviewSplitGains(
    first: math.sqrt(t) * g,
    second: math.sqrt(1 - t) * g,
  );
}
```

- [ ] **Step 4: Re-run the test (expect PASS)**

Run: `cd packages/feature_iptv && flutter test test/application/multiview_split_ratio_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add packages/feature_iptv/lib/application/multiview_split_ratio.dart \
  packages/feature_iptv/test/application/multiview_split_ratio_test.dart
git commit -m "$(cat <<'EOF'
feat(iptv): snap two-pane MultiView at 5/50/95 with an 80dp floor

EOF
)"
```

---

### Task 2: Rename thirty/seventy at every call site

**Files:**
- Modify every `MultiviewSplitRatio.thirty` / `.seventy` in `packages/feature_iptv/`

- [ ] **Step 1: Replace identifiers**

`thirty` → `five`, `seventy` → `ninetyFive`. Update drag tests that expected `thirty` after a left drag to expect `five`. Update flex 3/7 tests to 50/950.

- [ ] **Step 2: Analyzer on the package**

Run: `cd packages/feature_iptv && dart analyze lib test`

Expected: no errors about missing `thirty`/`seventy`.

- [ ] **Step 3: Commit**

```bash
git commit -m "$(cat <<'EOF'
refactor(iptv): rename split stops from 30/70 to 5/95

EOF
)"
```

---

### Task 3: Premium handle + compact 48dp hit

**Files:**
- Modify: `packages/feature_iptv/lib/presentation/tv_ux/sections/multiview_two_pane_split.dart`
- Test: `packages/feature_iptv/test/iptv/presentation/tv_ux/multiview_stage_test.dart`

- [ ] **Step 1: Failing tests for hit size**

Add:

```dart
testWidgets('compact host uses a 48dp split hit sliver', (tester) async {
  final sessions = [session('one'), session('two')];
  addTearDown(() => Future.wait(sessions.map((item) => item.close())));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 360,
          height: 640,
          child: MultiviewStage(
            sessions: sessions,
            featuredChannelId: sessions.first.id,
            onPromote: (_) {},
            splitRatio: MultiviewSplitRatio.fifty,
          ),
        ),
      ),
    ),
  );
  final box = tester.getSize(find.byKey(const ValueKey('multiview-split-handle')));
  expect(box.width, 48);
});

testWidgets('1920 host uses a 24dp split hit sliver', (tester) async {
  final sessions = [session('one'), session('two')];
  addTearDown(() => Future.wait(sessions.map((item) => item.close())));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 1920,
          height: 1080,
          child: MultiviewStage(
            sessions: sessions,
            featuredChannelId: sessions.first.id,
            onPromote: (_) {},
            splitRatio: MultiviewSplitRatio.fifty,
          ),
        ),
      ),
    ),
  );
  final box = tester.getSize(find.byKey(const ValueKey('multiview-split-handle')));
  expect(box.width, 24);
});
```

- [ ] **Step 2: Run (expect FAIL, still 24 everywhere)**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/tv_ux/multiview_stage_test.dart --name 'hit sliver'`

- [ ] **Step 3: Paint a short hairline; size hit from constraints**

In `_SplitHandle.build`, take `BoxConstraints` from a parent `LayoutBuilder` on the stage host (the two-pane already has one). Compact when `constraints.maxWidth < 600 || constraints.maxHeight < 600`. Hit cross-axis `48` vs `24`.

Replace `_seam` with a `CustomPaint` / stack: transparent hit `SizedBox`, then a centered middle-third column/row containing:

- 2dp hairline, `Colors.white.withValues(alpha: 0.28)`
- 8×28 stadium, `Colors.white.withValues(alpha: focused ? 0.80 : 0.55)`
- Focused: `DecoratedBox` with `BoxShadow(color: Colors.white70, blurRadius: 8)` and `Transform.scale(1.05)`

Keep `ValueKey('multiview-split-handle')` on `TvFocusable`. Pass `extent` into clamp/snap: `_onDragUpdate` already has `constraints.maxWidth/Height`.

Live flex: `(drag * 1000).round().clamp((min*1000).round(), (max*1000).round())` so 5% is 50/950.

- [ ] **Step 4: Re-run handle tests (expect PASS)**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/tv_ux/multiview_stage_test.dart`

- [ ] **Step 5: Commit**

```bash
git commit -m "$(cat <<'EOF'
feat(iptv): paint a short MultiView split grip with a 48dp phone hit

EOF
)"
```

---

### Task 4: Pool promote can skip exclusive routing

**Files:**
- Modify: `packages/platform_player/lib/src/services/airo_multiview_pool.dart`
- Test: `packages/platform_player/test/airo_multiview_pool_test.dart`

- [ ] **Step 1: Failing test**

```dart
test('promote(routeAudio: false) changes featured without muting the other', () async {
  final one = _FakeSession('one')..volume = 0.7;
  final two = _FakeSession('two')..volume = 0.7;
  final pool = AiroMultiviewPool(decoderBudget: 2);
  await pool.add(id: 'one', openSession: () async => one);
  await pool.add(id: 'two', openSession: () async => two);
  one.volume = 0.7;
  two.volume = 0.7;
  await pool.promote('two', routeAudio: false);
  expect(pool.state.featuredSessionId, 'two');
  expect(one.volume, 0.7);
  expect(two.volume, 0.7);
});
```

- [ ] **Step 2: Run (expect FAIL, promote always 1/0)**

Run: `cd packages/platform_player && flutter test test/airo_multiview_pool_test.dart --name 'routeAudio'`

- [ ] **Step 3: Add the flag**

```dart
Future<void> promote(String id, {bool routeAudio = true}) async {
  if (_closed || !_state.contains(id) || _state.featuredSessionId == id) {
    return;
  }
  if (routeAudio) await _routeAudio(id);
  _setState(
    AiroMultiviewPoolState(sessions: _state.sessions, featuredSessionId: id),
  );
}
```

Default stays true so triple/quad/Cast are unchanged.

- [ ] **Step 4: Re-run pool tests (expect PASS)**

- [ ] **Step 5: Commit**

```bash
git commit -m "$(cat <<'EOF'
feat(player): allow MultiView promote without exclusive audio routing

EOF
)"
```

---

### Task 5: Controller applies DJ mix in two-pane

**Files:**
- Modify: `packages/feature_iptv/lib/application/providers/multiview_provider.dart`
- Test: `packages/feature_iptv/test/application/multiview_provider_test.dart`

- [ ] **Step 1: Failing tests**

```dart
test('setSplitRatio on two-pane applies equal-power gains', () async {
  // open two fake sessions, setSplitRatio(ninetyFive),
  // first.volume ~ 1, second.volume ~ 0 (global 1, large extent).
});

test('promote in two-pane does not mute the mixed second tile', () async {
  // set mix at fifty, promote second with the two-pane path,
  // both volumes stay ~0.707.
});

test('adding a third session restores exclusive featured audio', () async {
  // after third add, featured volume 1, others 0.
});
```

Use a large dummy extent (1600) on `previewSplitMix` / `setSplitRatio` so 5% is real 5%.

- [ ] **Step 2: Run (expect FAIL)**

- [ ] **Step 3: Implement**

On `MultiviewController`:

```dart
void setSplitRatio(MultiviewSplitRatio ratio) {
  if (_disposed) return;
  final kind = resolveMultiviewLayout(
    preferred: state.layout,
    sessionCount: state.sessions.length,
  );
  if (!kind.isTwoPane) return;
  state = /* copy with splitRatio: ratio */;
  unawaited(_applyTwoPaneMix(ratio.firstFraction, extent: _lastSplitExtent));
}

Future<void> previewSplitMix(double firstFraction, {required double extent}) async {
  _lastSplitExtent = extent;
  await _applyTwoPaneMix(firstFraction, extent: extent);
}

Future<void> promote(String channelId) async {
  final twoPane = resolveMultiviewLayout(
    preferred: state.layout,
    sessionCount: state.sessions.length,
  ).isTwoPane;
  await _pool.promote(channelId, routeAudio: !twoPane);
  if (twoPane) {
    await _applyTwoPaneMix(state.splitRatio.firstFraction, extent: _lastSplitExtent);
  }
}

Future<void> _applyTwoPaneMix(double firstFraction, {required double extent}) async {
  if (state.sessions.length != 2) return;
  final gains = multiviewSplitGains(
    firstFraction,
    extent: extent,
    globalVolume: _primaryVolumeHeldForMultiview,
  );
  await state.sessions[0].setVolume(gains.first);
  await state.sessions[1].setVolume(gains.second);
}
```

Store `_lastSplitExtent` default `1600` so D-pad before first layout still has a TV-sized floor. After `_syncFromPool`, if two-pane re-apply mix; else leave pool exclusive routing.

Coalesce drag: the widget calls `previewSplitMix` at most once per frame (`SchedulerBinding.instance.scheduleFrameCallback`).

- [ ] **Step 4: Re-run provider tests**

- [ ] **Step 5: Commit**

```bash
git commit -m "$(cat <<'EOF'
feat(iptv): crossfade two-pane MultiView audio with the split bar

EOF
)"
```

---

### Task 6: Wire live mix + hide two-pane tile volume slider

**Files:**
- Modify: `packages/feature_iptv/lib/presentation/tv_ux/sections/multiview_two_pane_split.dart`
- Modify: `packages/feature_iptv/lib/presentation/tv_ux/sections/multiview_stage.dart`
- Modify: `packages/feature_iptv/lib/presentation/screens/iptv_screen.dart` and `airo_tv_shell.dart` to pass `onSplitMixPreview` → `previewSplitMix`
- Test: `multiview_stage_test.dart` — two-pane menu has no `multiview-volume-*`; triple still has it

- [ ] **Step 1: Failing test** — open tile menu in two-pane, `find.byKey(ValueKey('multiview-volume-one'))` is `findsNothing`. Pump three sessions, same key `findsOneWidget`.

- [ ] **Step 2: Run FAIL**

- [ ] **Step 3: Implement**

`MultiviewTwoPaneSplit` grows `ValueChanged<double>? onSplitMixPreview`. `_onDragUpdate` after `setState` calls it with `_dragFraction`. `_onDragEnd` / D-pad still call `onSplitRatioChanged`.

In `_showTileControls`, take `bool allowVolumeSlider`. Two-pane cells pass `false`.

- [ ] **Step 4: Tests PASS**

- [ ] **Step 5: Commit**

```bash
git commit -m "$(cat <<'EOF'
feat(iptv): drive two-pane mix from the handle and hide the tile fader

EOF
)"
```

---

### Task 7: Full related suite + format

- [ ] **Step 1: Run**

```bash
cd packages/feature_iptv && dart format lib test && flutter test test/application/multiview_split_ratio_test.dart test/application/multiview_provider_test.dart test/iptv/presentation/tv_ux/multiview_stage_test.dart
cd packages/platform_player && dart format lib test && flutter test test/airo_multiview_pool_test.dart test/multiview_layout_kind_test.dart
```

Expected: 0 failures.

- [ ] **Step 2: Commit format if needed**

```bash
git commit -m "$(cat <<'EOF'
style(iptv): format DJ split resize

EOF
)"
```

Do not bump `app/pubspec_tv.yaml`.
