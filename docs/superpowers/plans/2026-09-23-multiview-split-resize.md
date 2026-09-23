# MultiView two-pane magnetic split Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Two-pane MultiView (side-by-side or stacked) gets a seam handle that drag-snaps and D-pad-steps between 30 / 50 / 70, without reopening players or changing which tile is audible.

**Architecture:** A pure `MultiviewSplitRatio` enum owns stops, snap, step, and flex. `MultiviewController` stores the committed stop and resets it whenever the resolved mosaic is not two-pane. `MultiviewTwoPaneSplit` owns the live drag preview and the focusable handle; `MultiviewStage` uses it only for `splitHorizontal` / `splitVertical`. Cast protocol is untouched.

**Tech Stack:** Flutter widgets, `TvFocusable` + `TvInputHandler` (`core_ui`), Riverpod `StateNotifier` in `feature_iptv`, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-09-23-multiview-split-resize-design.md`

---

## File map

| File | Responsibility |
|------|----------------|
| Create: `packages/feature_iptv/lib/application/multiview_split_ratio.dart` | Enum, snap, step, flex. No Flutter widgets. |
| Create: `packages/feature_iptv/test/application/multiview_split_ratio_test.dart` | Pure unit tests for snap/step/flex. |
| Modify: `packages/platform_player/lib/src/models/multiview_layout_kind.dart` | Add `isTwoPane` getter. Do not add a layout kind or Cast field. |
| Modify: `packages/platform_player/test/multiview_layout_kind_test.dart` | Cover `isTwoPane`. |
| Modify: `packages/feature_iptv/lib/application/providers/multiview_provider.dart` | `splitRatio` on state; `setSplitRatio`; reset on layout/count. |
| Modify: `packages/feature_iptv/test/application/multiview_provider_test.dart` | Default, set, reset on third session / mosaic / return to two-pane. |
| Create: `packages/feature_iptv/lib/presentation/tv_ux/sections/multiview_two_pane_split.dart` | Stateful two-pane row/column + magnetic handle. |
| Modify: `packages/feature_iptv/lib/presentation/tv_ux/sections/multiview_stage.dart` | Use two-pane split; pass `splitRatio` / `onSplitRatioChanged`. |
| Modify: `packages/feature_iptv/test/iptv/presentation/tv_ux/multiview_stage_test.dart` | Handle, flex, drag snap, D-pad, no autofocus, Select does not promote. |
| Modify: `packages/feature_iptv/lib/presentation/screens/iptv_screen.dart` | Fullscreen stage wires controller `setSplitRatio`. |
| Modify: `packages/feature_iptv/lib/presentation/tv_ux/airo_tv_shell.dart` | Browse-grid stage wires the same. |

Do not edit Cast protocol, `MultiviewLayoutKind` wire names, Play `versionCode`, or decoder pool code.

---

### Task 1: Split-ratio math

**Files:**
- Create: `packages/feature_iptv/lib/application/multiview_split_ratio.dart`
- Test: `packages/feature_iptv/test/application/multiview_split_ratio_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:feature_iptv/application/multiview_split_ratio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('flex maps 30/50/70 to 3-7, 1-1, 7-3', () {
    expect(MultiviewSplitRatio.thirty.firstFlex, 3);
    expect(MultiviewSplitRatio.thirty.secondFlex, 7);
    expect(MultiviewSplitRatio.fifty.firstFlex, 1);
    expect(MultiviewSplitRatio.fifty.secondFlex, 1);
    expect(MultiviewSplitRatio.seventy.firstFlex, 7);
    expect(MultiviewSplitRatio.seventy.secondFlex, 3);
  });

  test('snap prefers fifty on a tie between two stops', () {
    expect(snapMultiviewSplitFraction(0.40), MultiviewSplitRatio.fifty);
    expect(snapMultiviewSplitFraction(0.60), MultiviewSplitRatio.fifty);
    expect(snapMultiviewSplitFraction(0.50), MultiviewSplitRatio.fifty);
  });

  test('snap picks the nearest stop and clamps outside 30-70', () {
    expect(snapMultiviewSplitFraction(0.30), MultiviewSplitRatio.thirty);
    expect(snapMultiviewSplitFraction(0.31), MultiviewSplitRatio.thirty);
    expect(snapMultiviewSplitFraction(0.69), MultiviewSplitRatio.seventy);
    expect(snapMultiviewSplitFraction(0.70), MultiviewSplitRatio.seventy);
    expect(snapMultiviewSplitFraction(0.0), MultiviewSplitRatio.thirty);
    expect(snapMultiviewSplitFraction(1.0), MultiviewSplitRatio.seventy);
  });

  test('step toward second does not wrap past seventy', () {
    expect(
      stepMultiviewSplitRatio(
        MultiviewSplitRatio.fifty,
        towardSecond: true,
      ),
      MultiviewSplitRatio.seventy,
    );
    expect(
      stepMultiviewSplitRatio(
        MultiviewSplitRatio.seventy,
        towardSecond: true,
      ),
      isNull,
    );
  });

  test('step toward first does not wrap past thirty', () {
    expect(
      stepMultiviewSplitRatio(
        MultiviewSplitRatio.fifty,
        towardSecond: false,
      ),
      MultiviewSplitRatio.thirty,
    );
    expect(
      stepMultiviewSplitRatio(
        MultiviewSplitRatio.thirty,
        towardSecond: false,
      ),
      isNull,
    );
  });

  test('clamp keeps a live drag inside 30-70', () {
    expect(clampMultiviewSplitFraction(0.10), 0.30);
    expect(clampMultiviewSplitFraction(0.55), 0.55);
    expect(clampMultiviewSplitFraction(0.90), 0.70);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
cd packages/feature_iptv && flutter test test/application/multiview_split_ratio_test.dart
```

Expected: FAIL compiling (`multiview_split_ratio.dart` does not exist).

- [ ] **Step 3: Write minimal implementation**

Create `packages/feature_iptv/lib/application/multiview_split_ratio.dart`:

```dart
enum MultiviewSplitRatio {
  thirty,
  fifty,
  seventy;

  int get firstFlex => switch (this) {
    thirty => 3,
    fifty => 1,
    seventy => 7,
  };

  int get secondFlex => switch (this) {
    thirty => 7,
    fifty => 1,
    seventy => 3,
  };

  double get firstFraction => switch (this) {
    thirty => 0.30,
    fifty => 0.50,
    seventy => 0.70,
  };
}

const double kMultiviewSplitMinFraction = 0.30;
const double kMultiviewSplitMaxFraction = 0.70;

double clampMultiviewSplitFraction(double fraction) {
  if (fraction < kMultiviewSplitMinFraction) {
    return kMultiviewSplitMinFraction;
  }
  if (fraction > kMultiviewSplitMaxFraction) {
    return kMultiviewSplitMaxFraction;
  }
  return fraction;
}

MultiviewSplitRatio snapMultiviewSplitFraction(double fraction) {
  final clamped = clampMultiviewSplitFraction(fraction);
  final d30 = (clamped - 0.30).abs();
  final d50 = (clamped - 0.50).abs();
  final d70 = (clamped - 0.70).abs();
  if (d50 <= d30 && d50 <= d70) return MultiviewSplitRatio.fifty;
  if (d30 < d70) return MultiviewSplitRatio.thirty;
  return MultiviewSplitRatio.seventy;
}

/// Next stop along the split axis. Null means "do not wrap; let focus leave
/// the handle toward the already-small pane."
MultiviewSplitRatio? stepMultiviewSplitRatio(
  MultiviewSplitRatio current, {
  required bool towardSecond,
}) {
  if (towardSecond) {
    return switch (current) {
      MultiviewSplitRatio.thirty => MultiviewSplitRatio.fifty,
      MultiviewSplitRatio.fifty => MultiviewSplitRatio.seventy,
      MultiviewSplitRatio.seventy => null,
    };
  }
  return switch (current) {
    MultiviewSplitRatio.seventy => MultiviewSplitRatio.fifty,
    MultiviewSplitRatio.fifty => MultiviewSplitRatio.thirty,
    MultiviewSplitRatio.thirty => null,
  };
}
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
cd packages/feature_iptv && flutter test test/application/multiview_split_ratio_test.dart
```

Expected: PASS, all tests.

- [ ] **Step 5: Commit**

```bash
git add packages/feature_iptv/lib/application/multiview_split_ratio.dart \
  packages/feature_iptv/test/application/multiview_split_ratio_test.dart
git commit -m "$(cat <<'EOF'
feat(iptv): add 30/50/70 split-ratio math for two-pane MultiView

EOF
)"
```

---

### Task 2: `isTwoPane` on layout kinds

**Files:**
- Modify: `packages/platform_player/lib/src/models/multiview_layout_kind.dart`
- Test: `packages/platform_player/test/multiview_layout_kind_test.dart`

- [ ] **Step 1: Write the failing test**

Append to `packages/platform_player/test/multiview_layout_kind_test.dart`:

```dart
  test('isTwoPane is only side-by-side and stacked', () {
    expect(MultiviewLayoutKind.splitHorizontal.isTwoPane, isTrue);
    expect(MultiviewLayoutKind.splitVertical.isTwoPane, isTrue);
    for (final kind in MultiviewLayoutKind.values) {
      if (kind == MultiviewLayoutKind.splitHorizontal ||
          kind == MultiviewLayoutKind.splitVertical) {
        continue;
      }
      expect(kind.isTwoPane, isFalse, reason: kind.wireName);
    }
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
cd packages/platform_player && flutter test test/multiview_layout_kind_test.dart
```

Expected: FAIL compiling (`isTwoPane` is not defined).

- [ ] **Step 3: Write minimal implementation**

In `packages/platform_player/lib/src/models/multiview_layout_kind.dart`, after `tileCount`, add:

```dart
  /// True for the two-pane mosaics that own a magnetic split handle.
  bool get isTwoPane =>
      this == splitHorizontal || this == splitVertical;
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
cd packages/platform_player && flutter test test/multiview_layout_kind_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add packages/platform_player/lib/src/models/multiview_layout_kind.dart \
  packages/platform_player/test/multiview_layout_kind_test.dart
git commit -m "$(cat <<'EOF'
feat(player): mark side-by-side and stacked mosaics as two-pane

EOF
)"
```

---

### Task 3: Controller stores and resets the stop

**Files:**
- Modify: `packages/feature_iptv/lib/application/providers/multiview_provider.dart`
- Test: `packages/feature_iptv/test/application/multiview_provider_test.dart`

- [ ] **Step 1: Write the failing tests**

Append to `packages/feature_iptv/test/application/multiview_provider_test.dart` (same `channel` helper already in the file):

```dart
  test('splitRatio defaults to fifty and setSplitRatio keeps a two-pane stop',
      () async {
    final controller = MultiviewController(
      decoderBudget: 4,
      primaryService: _FakePrimaryService(),
      sessionFactory: (item) async => _FakeMultiviewSession(item),
    );
    addTearDown(controller.close);

    expect(controller.state.splitRatio, MultiviewSplitRatio.fifty);
    await controller.toggle(channel('one'));
    await controller.toggle(channel('two'));
    controller.setSplitRatio(MultiviewSplitRatio.seventy);
    expect(controller.state.splitRatio, MultiviewSplitRatio.seventy);
  });

  test('third session resets splitRatio to fifty', () async {
    final controller = MultiviewController(
      decoderBudget: 4,
      primaryService: _FakePrimaryService(),
      sessionFactory: (item) async => _FakeMultiviewSession(item),
    );
    addTearDown(controller.close);

    await controller.toggle(channel('one'));
    await controller.toggle(channel('two'));
    controller.setSplitRatio(MultiviewSplitRatio.seventy);
    expect(
      await controller.toggle(channel('three')),
      MultiviewToggleResult.added,
    );
    expect(controller.state.splitRatio, MultiviewSplitRatio.fifty);
  });

  test('non two-pane setLayout resets splitRatio to fifty', () async {
    final controller = MultiviewController(
      decoderBudget: 4,
      primaryService: _FakePrimaryService(),
      sessionFactory: (item) async => _FakeMultiviewSession(item),
    );
    addTearDown(controller.close);

    await controller.toggle(channel('one'));
    await controller.toggle(channel('two'));
    controller.setSplitRatio(MultiviewSplitRatio.thirty);
    controller.setLayout(MultiviewLayoutKind.spotlight);
    expect(controller.state.splitRatio, MultiviewSplitRatio.fifty);
  });

  test('returning to two-pane after a reset starts at fifty, not the old 70',
      () async {
    final controller = MultiviewController(
      decoderBudget: 4,
      primaryService: _FakePrimaryService(),
      sessionFactory: (item) async => _FakeMultiviewSession(item),
    );
    addTearDown(controller.close);

    await controller.toggle(channel('one'));
    await controller.toggle(channel('two'));
    controller.setSplitRatio(MultiviewSplitRatio.seventy);
    controller.setLayout(MultiviewLayoutKind.quad);
    expect(controller.state.splitRatio, MultiviewSplitRatio.fifty);
    controller.setLayout(MultiviewLayoutKind.splitHorizontal);
    expect(controller.state.splitRatio, MultiviewSplitRatio.fifty);
  });

  test('setLayout between the two two-pane mosaics keeps the stop', () async {
    final controller = MultiviewController(
      decoderBudget: 4,
      primaryService: _FakePrimaryService(),
      sessionFactory: (item) async => _FakeMultiviewSession(item),
    );
    addTearDown(controller.close);

    await controller.toggle(channel('one'));
    await controller.toggle(channel('two'));
    controller.setSplitRatio(MultiviewSplitRatio.thirty);
    controller.setLayout(MultiviewLayoutKind.splitVertical);
    expect(controller.state.splitRatio, MultiviewSplitRatio.thirty);
  });
```

Add this import at the top of that test file:

```dart
import 'package:feature_iptv/application/multiview_split_ratio.dart';
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
cd packages/feature_iptv && flutter test test/application/multiview_provider_test.dart
```

Expected: FAIL compiling (`splitRatio` / `setSplitRatio` missing).

- [ ] **Step 3: Write minimal implementation**

In `packages/feature_iptv/lib/application/providers/multiview_provider.dart`:

1. Import:

```dart
import '../multiview_split_ratio.dart';
```

2. Add field on `MultiviewState` (default so existing `MultiviewState(` calls compile until updated):

```dart
    this.splitRatio = MultiviewSplitRatio.fifty,
  });

  final List<IptvMultiviewSession> sessions;
  final String? featuredChannelId;
  final int capacity;
  final MultiviewLayoutKind? layout;
  final MultiviewSplitRatio splitRatio;
```

3. Add a private helper on `MultiviewController`:

```dart
  MultiviewSplitRatio _splitRatioFor({
    required MultiviewLayoutKind? preferred,
    required int sessionCount,
    required MultiviewSplitRatio current,
  }) {
    final kind = resolveMultiviewLayout(
      preferred: preferred,
      sessionCount: sessionCount,
    );
    return kind.isTwoPane ? current : MultiviewSplitRatio.fifty;
  }
```

4. Replace `setLayout` with:

```dart
  void setLayout(MultiviewLayoutKind layout) {
    if (_disposed) return;
    state = MultiviewState(
      sessions: state.sessions,
      featuredChannelId: state.featuredChannelId,
      capacity: state.capacity,
      layout: layout,
      splitRatio: _splitRatioFor(
        preferred: layout,
        sessionCount: state.sessions.length,
        current: state.splitRatio,
      ),
    );
  }

  void setSplitRatio(MultiviewSplitRatio ratio) {
    if (_disposed) return;
    final kind = resolveMultiviewLayout(
      preferred: state.layout,
      sessionCount: state.sessions.length,
    );
    if (!kind.isTwoPane) return;
    state = MultiviewState(
      sessions: state.sessions,
      featuredChannelId: state.featuredChannelId,
      capacity: state.capacity,
      layout: state.layout,
      splitRatio: ratio,
    );
  }
```

5. In `_syncFromPool`, pass `splitRatio`:

```dart
    state = MultiviewState(
      sessions: List.unmodifiable(
        poolState.sessions.cast<IptvMultiviewSession>(),
      ),
      featuredChannelId: poolState.featuredSessionId,
      capacity: _pool.capacity,
      layout: state.layout,
      splitRatio: _splitRatioFor(
        preferred: state.layout,
        sessionCount: poolState.sessions.length,
        current: state.splitRatio,
      ),
    );
```

Leave the initial `super(MultiviewState(capacity: ...))` on the default `fifty`.

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
cd packages/feature_iptv && flutter test test/application/multiview_provider_test.dart
```

Expected: PASS, including the new splitRatio cases.

- [ ] **Step 5: Commit**

```bash
git add packages/feature_iptv/lib/application/providers/multiview_provider.dart \
  packages/feature_iptv/test/application/multiview_provider_test.dart
git commit -m "$(cat <<'EOF'
feat(iptv): store two-pane split ratio and reset it off mosaic

EOF
)"
```

---

### Task 4: Two-pane split widget and stage wiring

**Files:**
- Create: `packages/feature_iptv/lib/presentation/tv_ux/sections/multiview_two_pane_split.dart`
- Modify: `packages/feature_iptv/lib/presentation/tv_ux/sections/multiview_stage.dart`
- Test: `packages/feature_iptv/test/iptv/presentation/tv_ux/multiview_stage_test.dart`

- [ ] **Step 1: Write the failing tests**

In `multiview_stage_test.dart`, extend `pump` with optional `splitRatio` and `onSplitRatioChanged`:

```dart
    MultiviewSplitRatio splitRatio = MultiviewSplitRatio.fifty,
    ValueChanged<MultiviewSplitRatio>? onSplitRatioChanged,
```

Pass them into `MultiviewStage`. Add the import:

```dart
import 'package:feature_iptv/application/multiview_split_ratio.dart';
```

Add tests:

```dart
  List<Expanded> splitExpanded(WidgetTester tester, Key layoutKey) {
    return tester
        .widgetList<Expanded>(
          find.descendant(
            of: find.byKey(layoutKey),
            matching: find.byType(Expanded),
          ),
        )
        .toList();
  }

  testWidgets('two-pane split shows a handle and 50/50 flex by default', (
    tester,
  ) async {
    final sessions = [session('one'), session('two')];
    addTearDown(() => Future.wait(sessions.map((item) => item.close())));
    await pump(tester, sessions);

    expect(
      find.byKey(const ValueKey('multiview-split-handle')),
      findsOneWidget,
    );
    final panes = splitExpanded(
      tester,
      const ValueKey('multiview-layout-split'),
    );
    expect(panes, hasLength(2));
    expect(panes[0].flex, 1);
    expect(panes[1].flex, 1);
  });

  testWidgets('seventy stop paints flex 7/3 on the horizontal split', (
    tester,
  ) async {
    final sessions = [session('one'), session('two')];
    addTearDown(() => Future.wait(sessions.map((item) => item.close())));
    await pump(
      tester,
      sessions,
      splitRatio: MultiviewSplitRatio.seventy,
    );

    final panes = splitExpanded(
      tester,
      const ValueKey('multiview-layout-split'),
    );
    expect(panes[0].flex, 7);
    expect(panes[1].flex, 3);
  });

  testWidgets('stacked two-pane also shows the handle', (tester) async {
    final sessions = [session('one'), session('two')];
    addTearDown(() => Future.wait(sessions.map((item) => item.close())));
    await pump(
      tester,
      sessions,
      layout: MultiviewLayoutKind.splitVertical,
    );

    expect(
      find.byKey(const ValueKey('multiview-layout-split-vertical')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('multiview-split-handle')),
      findsOneWidget,
    );
  });

  testWidgets('triple and quad mosaics have no split handle', (tester) async {
    final triple = [session('1'), session('2'), session('3')];
    addTearDown(() => Future.wait(triple.map((item) => item.close())));
    await pump(tester, triple);
    expect(find.byKey(const ValueKey('multiview-split-handle')), findsNothing);

    final quad = [
      session('a'),
      session('b'),
      session('c'),
      session('d'),
    ];
    addTearDown(() => Future.wait(quad.map((item) => item.close())));
    await pump(tester, quad);
    expect(find.byKey(const ValueKey('multiview-split-handle')), findsNothing);
  });

  testWidgets('split handle is not focused after the initial pump', (
    tester,
  ) async {
    final sessions = [session('one'), session('two')];
    addTearDown(() => Future.wait(sessions.map((item) => item.close())));
    await pump(tester, sessions);

    final handleContext = tester.element(
      find.byKey(const ValueKey('multiview-split-handle')),
    );
    expect(Focus.maybeOf(handleContext)?.hasPrimaryFocus, isNot(true));
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
cd packages/feature_iptv && flutter test test/iptv/presentation/tv_ux/multiview_stage_test.dart
```

Expected: FAIL (`splitRatio` param missing and/or handle key not found).

- [ ] **Step 3: Write minimal implementation**

Create `packages/feature_iptv/lib/presentation/tv_ux/sections/multiview_two_pane_split.dart`:

```dart
import 'package:core_ui/core_ui.dart';
import 'package:feature_iptv/application/multiview_split_ratio.dart';
import 'package:flutter/material.dart';

class MultiviewTwoPaneSplit extends StatefulWidget {
  const MultiviewTwoPaneSplit({
    super.key,
    required this.axis,
    required this.ratio,
    required this.first,
    required this.second,
    this.onSplitRatioChanged,
  });

  final Axis axis;
  final MultiviewSplitRatio ratio;
  final Widget first;
  final Widget second;
  final ValueChanged<MultiviewSplitRatio>? onSplitRatioChanged;

  @override
  State<MultiviewTwoPaneSplit> createState() => _MultiviewTwoPaneSplitState();
}

class _MultiviewTwoPaneSplitState extends State<MultiviewTwoPaneSplit> {
  double? _dragFraction;

  bool get _horizontal => widget.axis == Axis.horizontal;

  int get _firstFlex {
    final drag = _dragFraction;
    if (drag == null) return widget.ratio.firstFlex;
    return (drag * 100).round().clamp(30, 70);
  }

  int get _secondFlex {
    final drag = _dragFraction;
    if (drag == null) return widget.ratio.secondFlex;
    return 100 - (drag * 100).round().clamp(30, 70);
  }

  void _onDragUpdate(DragUpdateDetails details, BoxConstraints constraints) {
    final extent = _horizontal
        ? constraints.maxWidth
        : constraints.maxHeight;
    if (extent <= 0) return;
    final delta = _horizontal ? details.delta.dx : details.delta.dy;
    final current = _dragFraction ?? widget.ratio.firstFraction;
    setState(() {
      _dragFraction = clampMultiviewSplitFraction(
        current + delta / extent,
      );
    });
  }

  void _onDragEnd(DragEndDetails _) {
    final drag = _dragFraction;
    if (drag == null) return;
    final snapped = snapMultiviewSplitFraction(drag);
    setState(() => _dragFraction = null);
    widget.onSplitRatioChanged?.call(snapped);
  }

  void _onDragCancel() {
    if (_dragFraction == null) return;
    setState(() => _dragFraction = null);
  }

  TvInputResult _onHandleInput(TvInputKey key) {
    final towardSecond = _horizontal
        ? key == TvInputKey.right
        : key == TvInputKey.down;
    final towardFirst = _horizontal
        ? key == TvInputKey.left
        : key == TvInputKey.up;
    if (!towardFirst && !towardSecond) return TvInputResult.notHandled;
    final next = stepMultiviewSplitRatio(
      widget.ratio,
      towardSecond: towardSecond,
    );
    if (next == null) return TvInputResult.notHandled;
    widget.onSplitRatioChanged?.call(next);
    return TvInputResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final children = [
          Expanded(flex: _firstFlex, child: widget.first),
          _SplitHandle(
            axis: widget.axis,
            onDragUpdate: (details) => _onDragUpdate(details, constraints),
            onDragEnd: _onDragEnd,
            onDragCancel: _onDragCancel,
            onInput: _onHandleInput,
          ),
          Expanded(flex: _secondFlex, child: widget.second),
        ];
        if (_horizontal) {
          return Row(children: children);
        }
        return Column(children: children);
      },
    );
  }
}

class _SplitHandle extends StatelessWidget {
  const _SplitHandle({
    required this.axis,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onDragCancel,
    required this.onInput,
  });

  final Axis axis;
  final GestureDragUpdateCallback onDragUpdate;
  final GestureDragEndCallback onDragEnd;
  final VoidCallback onDragCancel;
  final TvInputCallback onInput;

  @override
  Widget build(BuildContext context) {
    final horizontal = axis == Axis.horizontal;
    final gesture = horizontal
        ? GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: onDragUpdate,
            onHorizontalDragEnd: onDragEnd,
            onHorizontalDragCancel: onDragCancel,
            child: _seam(horizontal),
          )
        : GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragUpdate: onDragUpdate,
            onVerticalDragEnd: onDragEnd,
            onVerticalDragCancel: onDragCancel,
            child: _seam(horizontal),
          );
    return TvInputHandler(
      onInput: onInput,
      child: TvFocusable(
        key: const ValueKey('multiview-split-handle'),
        autofocus: false,
        semanticLabel: 'Resize split',
        semanticHint: horizontal
            ? 'Left or right to change size'
            : 'Up or down to change size',
        onSelect: () {},
        child: gesture,
      ),
    );
  }

  Widget _seam(bool horizontal) {
    return ColoredBox(
      color: Colors.white24,
      child: SizedBox(
        width: horizontal ? 24 : double.infinity,
        height: horizontal ? double.infinity : 24,
        child: Center(
          child: ColoredBox(
            color: Colors.white70,
            child: SizedBox(
              width: horizontal ? 4 : 32,
              height: horizontal ? 32 : 4,
            ),
          ),
        ),
      ),
    );
  }
}
```

`onSelect: () {}` is intentional: Select is a no-op so OK does not fall through, and `TvFocusable` still treats the handle as a control. It must not call `onPromote` / `onSwap`.

In `multiview_stage.dart`:

1. Import `multiview_split_ratio.dart` and `multiview_two_pane_split.dart`.

2. Add fields on `MultiviewStage`:

```dart
    this.splitRatio = MultiviewSplitRatio.fifty,
    this.onSplitRatioChanged,
  });
  // existing fields...
  final MultiviewSplitRatio splitRatio;
  final ValueChanged<MultiviewSplitRatio>? onSplitRatioChanged;
```

3. Replace the two-pane `switch` arms:

```dart
      MultiviewLayoutKind.splitHorizontal => KeyedSubtree(
        key: const ValueKey('multiview-layout-split'),
        child: MultiviewTwoPaneSplit(
          axis: Axis.horizontal,
          ratio: splitRatio,
          onSplitRatioChanged: onSplitRatioChanged,
          first: cell(0),
          second: cell(1),
        ),
      ),
      MultiviewLayoutKind.splitVertical => KeyedSubtree(
        key: const ValueKey('multiview-layout-split-vertical'),
        child: MultiviewTwoPaneSplit(
          axis: Axis.vertical,
          ratio: splitRatio,
          onSplitRatioChanged: onSplitRatioChanged,
          first: cell(0),
          second: cell(1),
        ),
      ),
```

Keep every other mosaic arm unchanged.

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
cd packages/feature_iptv && flutter test test/iptv/presentation/tv_ux/multiview_stage_test.dart
```

Expected: PASS, including existing promote/dismiss tests and the new handle/flex tests.

- [ ] **Step 5: Commit**

```bash
git add packages/feature_iptv/lib/presentation/tv_ux/sections/multiview_two_pane_split.dart \
  packages/feature_iptv/lib/presentation/tv_ux/sections/multiview_stage.dart \
  packages/feature_iptv/test/iptv/presentation/tv_ux/multiview_stage_test.dart
git commit -m "$(cat <<'EOF'
feat(iptv): render a two-pane MultiView handle with 30/50/70 flex

EOF
)"
```

---

### Task 5: Drag snap

**Files:**
- Test: `packages/feature_iptv/test/iptv/presentation/tv_ux/multiview_stage_test.dart`
- Modify only if drag math in `multiview_two_pane_split.dart` is wrong.

- [ ] **Step 1: Write the failing tests**

```dart
  testWidgets('drag toward the left edge snaps to thirty', (tester) async {
    final sessions = [session('one'), session('two')];
    addTearDown(() => Future.wait(sessions.map((item) => item.close())));
    MultiviewSplitRatio? committed;
    await pump(
      tester,
      sessions,
      onSplitRatioChanged: (ratio) => committed = ratio,
    );

    await tester.drag(
      find.byKey(const ValueKey('multiview-split-handle')),
      const Offset(-180, 0),
    );
    await tester.pumpAndSettle();

    expect(committed, MultiviewSplitRatio.thirty);
  });

  testWidgets('drag that stays near center snaps to fifty', (tester) async {
    final sessions = [session('one'), session('two')];
    addTearDown(() => Future.wait(sessions.map((item) => item.close())));
    MultiviewSplitRatio? committed;
    await pump(
      tester,
      sessions,
      onSplitRatioChanged: (ratio) => committed = ratio,
    );

    await tester.drag(
      find.byKey(const ValueKey('multiview-split-handle')),
      const Offset(12, 0),
    );
    await tester.pumpAndSettle();

    expect(committed, MultiviewSplitRatio.fifty);
  });
```

The stage is 640×360. From 50/50, −180px is first-fraction `0.50 + (−180/640) = 0.21875`, clamped to 0.30, snap thirty. +12px stays nearest fifty.

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
cd packages/feature_iptv && flutter test test/iptv/presentation/tv_ux/multiview_stage_test.dart --name drag
```

Expected: FAIL if `onSplitRatioChanged` is not invoked (or PASS if Task 4 drag already works — then skip Step 3).

- [ ] **Step 3: Fix drag only if the tests fail**

If `committed` is null, the handle hit target is not receiving the gesture. Wrap the `GestureDetector` around the full 24dp `SizedBox` (already in Task 4) and set `behavior: HitTestBehavior.opaque`. If the snap is wrong, do not change stops; fix `extent` to use `constraints.maxWidth` of the two-pane `LayoutBuilder`, not the handle's width.

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
cd packages/feature_iptv && flutter test test/iptv/presentation/tv_ux/multiview_stage_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add packages/feature_iptv/test/iptv/presentation/tv_ux/multiview_stage_test.dart \
  packages/feature_iptv/lib/presentation/tv_ux/sections/multiview_two_pane_split.dart
git commit -m "$(cat <<'EOF'
test(iptv): snap two-pane split drag to 30 and 50

EOF
)"
```

---

### Task 6: D-pad steps and Select no-op

**Files:**
- Test: `packages/feature_iptv/test/iptv/presentation/tv_ux/multiview_stage_test.dart`
- Modify: `packages/feature_iptv/lib/presentation/tv_ux/sections/multiview_two_pane_split.dart` only if keys are swallowed incorrectly.

- [ ] **Step 1: Write the failing tests**

```dart
  Future<void> focusHandle(WidgetTester tester) async {
    final handle = find.byKey(const ValueKey('multiview-split-handle'));
    Focus.maybeOf(tester.element(handle))!.requestFocus();
    await tester.pump();
    expect(Focus.maybeOf(tester.element(handle))!.hasPrimaryFocus, isTrue);
  }

  testWidgets('Right from fifty commits seventy; further Right leaves the handle',
      (tester) async {
    final sessions = [session('one'), session('two')];
    addTearDown(() => Future.wait(sessions.map((item) => item.close())));
    final committed = <MultiviewSplitRatio>[];
    await pump(
      tester,
      sessions,
      onSplitRatioChanged: committed.add,
    );
    await focusHandle(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(committed, [MultiviewSplitRatio.seventy]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 640,
            height: 360,
            child: MultiviewStage(
              sessions: sessions,
              featuredChannelId: sessions.first.id,
              onPromote: (_) {},
              splitRatio: MultiviewSplitRatio.seventy,
              onSplitRatioChanged: committed.add,
            ),
          ),
        ),
      ),
    );
    await focusHandle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    expect(committed, [MultiviewSplitRatio.seventy]);
    expect(
      Focus.maybeOf(
        tester.element(find.byKey(const ValueKey('multiview-promote-two'))),
      )?.hasPrimaryFocus,
      isTrue,
    );
  });

  testWidgets('Select on the handle does not promote or swap', (tester) async {
    final sessions = [session('one'), session('two')];
    addTearDown(() => Future.wait(sessions.map((item) => item.close())));
    final promoted = <String>[];
    var swapped = 0;
    await pump(
      tester,
      sessions,
      onPromote: promoted.add,
      onSwap: (_, __) => swapped++,
    );
    promoted.clear();
    await focusHandle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(promoted, isEmpty);
    expect(swapped, 0);
  });
```

The seventy pump must reuse the same `sessions` list so players stay mounted. `onPromote` fires on tile focus; the assertion after `promoted.clear()` is only for Select on the handle.

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
cd packages/feature_iptv && flutter test test/iptv/presentation/tv_ux/multiview_stage_test.dart --name 'Right from fifty|Select on the handle'
```

Expected: FAIL until `TvInputHandler` on the handle consumes Left/Right.

- [ ] **Step 3: Fix key routing only if needed**

`TvFocusable` ignores arrows, so the ancestor `TvInputHandler` in Task 4 must receive them. If Right is not committed, move `TvInputHandler` to wrap the `TvFocusable` (already specified). If further Right from seventy does not move focus, `_onHandleInput` must return `TvInputResult.notHandled` when `stepMultiviewSplitRatio` is null — do not wrap to thirty.

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
cd packages/feature_iptv && flutter test test/iptv/presentation/tv_ux/multiview_stage_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add packages/feature_iptv/test/iptv/presentation/tv_ux/multiview_stage_test.dart \
  packages/feature_iptv/lib/presentation/tv_ux/sections/multiview_two_pane_split.dart
git commit -m "$(cat <<'EOF'
feat(iptv): step the MultiView split from a focused D-pad handle

EOF
)"
```

---

### Task 7: Wire the live stages

**Files:**
- Modify: `packages/feature_iptv/lib/presentation/screens/iptv_screen.dart` (`_FullscreenMultiviewStage` around the existing `MultiviewStage(` call)
- Modify: `packages/feature_iptv/lib/presentation/tv_ux/airo_tv_shell.dart` (the `MultiviewStage(` inside the video capture `RepaintBoundary`)

No new tests: defaults keep existing pumps green; hosts must pass controller state so a snap survives a rebuild.

- [ ] **Step 1: Confirm both call sites still compile with the new optional params**

`splitRatio` defaults to fifty, `onSplitRatioChanged` is optional. Existing widgets still compile. This step is the wiring, not a red test.

- [ ] **Step 2: Wire fullscreen**

In `_FullscreenMultiviewStage.build`, on the `MultiviewStage(`:

```dart
          splitRatio: multiview.splitRatio,
          onSplitRatioChanged: (ratio) =>
              ref.read(multiviewProvider.notifier).setSplitRatio(ratio),
```

Place them next to `layout: multiview.layout`.

- [ ] **Step 3: Wire the browse-grid shell**

The shell already has `multiview` in scope. On its `MultiviewStage(`:

```dart
                        splitRatio: multiview.splitRatio,
                        onSplitRatioChanged: (ratio) => ref
                            .read(multiviewProvider.notifier)
                            .setSplitRatio(ratio),
```

- [ ] **Step 4: Analyze the touched packages**

Run:

```bash
cd packages/feature_iptv && dart analyze lib/presentation/screens/iptv_screen.dart lib/presentation/tv_ux/airo_tv_shell.dart lib/presentation/tv_ux/sections/multiview_stage.dart lib/presentation/tv_ux/sections/multiview_two_pane_split.dart lib/application/providers/multiview_provider.dart lib/application/multiview_split_ratio.dart
```

Expected: no issues.

- [ ] **Step 5: Commit**

```bash
git add packages/feature_iptv/lib/presentation/screens/iptv_screen.dart \
  packages/feature_iptv/lib/presentation/tv_ux/airo_tv_shell.dart
git commit -m "$(cat <<'EOF'
feat(iptv): persist two-pane split snaps from fullscreen and browse

EOF
)"
```

---

### Task 8: Full related suite and format

**Files:** all files from Tasks 1–7.

- [ ] **Step 1: Format**

Run:

```bash
dart format packages/feature_iptv/lib/application/multiview_split_ratio.dart \
  packages/feature_iptv/lib/application/providers/multiview_provider.dart \
  packages/feature_iptv/lib/presentation/tv_ux/sections/multiview_two_pane_split.dart \
  packages/feature_iptv/lib/presentation/tv_ux/sections/multiview_stage.dart \
  packages/feature_iptv/lib/presentation/screens/iptv_screen.dart \
  packages/feature_iptv/lib/presentation/tv_ux/airo_tv_shell.dart \
  packages/feature_iptv/test/application/multiview_split_ratio_test.dart \
  packages/feature_iptv/test/application/multiview_provider_test.dart \
  packages/feature_iptv/test/iptv/presentation/tv_ux/multiview_stage_test.dart \
  packages/platform_player/lib/src/models/multiview_layout_kind.dart \
  packages/platform_player/test/multiview_layout_kind_test.dart
```

- [ ] **Step 2: Run the related tests**

Run:

```bash
cd packages/platform_player && flutter test test/multiview_layout_kind_test.dart
cd packages/feature_iptv && flutter test \
  test/application/multiview_split_ratio_test.dart \
  test/application/multiview_provider_test.dart \
  test/iptv/presentation/tv_ux/multiview_stage_test.dart
```

Expected: PASS.

- [ ] **Step 3: Commit format only if the formatter changed files**

```bash
git add -u packages/feature_iptv packages/platform_player
git commit -m "$(cat <<'EOF'
style(iptv): format two-pane split resize

EOF
)"
```

Skip this commit if `git diff` is empty.

---

## Spec coverage

| Spec requirement | Task |
|------------------|------|
| Enum 30/50/70, flex 3/7 1/1 7/3, tie prefers 50, clamp 30–70 | 1 |
| Two-pane only (`splitHorizontal` / `splitVertical`) | 2, 4 |
| `splitRatio` on state, `setSplitRatio` writer | 3 |
| Reset when resolved layout is not two-pane; return starts at 50 | 3 |
| Keep ratio when switching horizontal ↔ vertical | 3 |
| Handle between panes, 24dp hit target, no autofocus | 4 |
| Live drag preview then snap on pointer-up | 4, 5 |
| TV Left/Right or Up/Down steps; extreme does not wrap | 6 |
| Select does not promote/swap | 6 |
| Players stay mounted (flex only) | 4 (no session rebuild) |
| Audio still featured-tile (`onPromote` unchanged) | 4, 6 |
| Cast protocol untouched | file map |
| Fullscreen + browse hosts persist snaps | 7 |
| No Play versionCode bump | file map |

## Type names (locked)

- `MultiviewSplitRatio` `{ thirty, fifty, seventy }`
- `snapMultiviewSplitFraction` / `clampMultiviewSplitFraction` / `stepMultiviewSplitRatio`
- `MultiviewLayoutKind.isTwoPane`
- `MultiviewState.splitRatio`
- `MultiviewController.setSplitRatio`
- `MultiviewTwoPaneSplit`
- Handle key: `ValueKey('multiview-split-handle')`
- Semantic label: `Resize split`
