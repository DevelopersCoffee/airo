# TV-First Navigation Rethink Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the ad-hoc TV browse layout (multi-button toolbar, tile-grid categories, undersized cards, no overscan safe-zone, implicit focus order) with a TV-first design: one overflow menu, horizontal category chips, larger cards, real Fire TV safe-zone insets, and an explicit D-pad focus order.

**Architecture:** Work screen-by-screen inside `packages/feature_iptv/lib/presentation/tv/` and the shared `TvShell` (`app/lib/core/app/tv_shell.dart`), reusing existing primitives (`TvFocusable`, `_TvFilterChip` pattern, `TvUiDimensions`) rather than inventing new ones. Wire the already-built-but-unused `tvDimensionsWithFireTvProvider` (real Fire TV safe zone) in place of the always-zero `tvDimensionsProvider`. Introduce explicit `FocusTraversalGroup`/`FocusTraversalOrder` per screen section instead of relying on implicit widget-tree ordering.

**Tech Stack:** Flutter, Riverpod (`ChangeNotifierProvider`, `FutureProvider.family`), existing `core_ui` TV focus widgets (no new packages).

## Global Constraints

- Do not remove `TvChannelGrid`/`VodGrid`'s existing `TvUiDimensions.channelCardWidth/Height` consumption — only change the *values* fed in, not the consumption pattern.
- Do not touch `packages/platform_player/third_party/**` (vendored, unrelated).
- Every new/changed focusable element must remain wrapped in `TvFocusable` (do not bypass it for the raw `TvInputHandler` path except where `tv_channel_grid.dart` already uses it).
- Keep `_TvActionButton`, `_TvFilterChip`, `_TvCategoryTile` class names where reused; only change internal structure, not call-site names, to avoid a mass-rename diff across `iptv_tv_screen.dart`.
- Each task ends green on `flutter test packages/feature_iptv/test/iptv/presentation/tv/` before moving to the next.

---

## File Structure

| File | Responsibility |
|---|---|
| `packages/feature_iptv/lib/presentation/tv/iptv_tv_screen.dart` | Home/live TV browse screen — `_TvHeader`, `_TvCategoryRail`, `_TvChannelToolbar`, `_TvChannelGridView`, `_TvChannelCard` all live here today; this plan edits in place, does not split the file (matches existing large-file pattern). |
| `packages/feature_iptv/lib/presentation/tv/tv_favorites_screen.dart` | Favorites grid — gets `SafeArea` + safe-zone wiring + bigger card sizing. |
| `packages/feature_iptv/lib/presentation/tv/vod_tv_screen.dart` | VOD screen — already uses `VodGrid`, gets safe-zone provider swap only. |
| `packages/feature_iptv/lib/presentation/widgets/vod_grid.dart` | Reads `tvDimensionsProvider` — swapped to Fire-TV-aware provider. |
| `packages/feature_iptv/lib/presentation/widgets/tv_channel_grid.dart` | Reads `tvDimensionsProvider` — swapped to Fire-TV-aware provider. |
| `packages/feature_iptv/lib/presentation/tv/iptv_tv.dart` | Currently defines the always-zero `tvDimensionsProvider`; this plan repoints it. |
| `app/lib/core/tv/tv_providers.dart` | Already has `tvDimensionsWithFireTvProvider` — no change, just gets consumed. |
| `app/lib/core/app/tv_shell.dart` | Persistent shell — gets `SafeArea` added around its `Row`. |
| `packages/core_ui/lib/src/widgets/tv_focus_manager.dart` | `TvUiDimensions.tv()` factory — no change; only callers change which provider builds it. |
| New: `packages/feature_iptv/lib/presentation/widgets/tv_overflow_menu.dart` | New `TvOverflowMenuButton` widget replacing the 3-5 discrete `_TvActionButton`s in `_TvHeader`. |
| New: `packages/feature_iptv/lib/presentation/widgets/tv_category_chip_row.dart` | New horizontal chip row replacing `_TvCategoryRail`'s 2-col `GridView`. |
| Test: `packages/feature_iptv/test/iptv/presentation/widgets/tv_overflow_menu_test.dart` | New. |
| Test: `packages/feature_iptv/test/iptv/presentation/widgets/tv_category_chip_row_test.dart` | New. |
| Test: `packages/feature_iptv/test/iptv/presentation/tv/iptv_tv_screen_test.dart` | Extended — asserts overflow menu + chip row present, old tile grid gone. |
| Test: `packages/feature_iptv/test/iptv/presentation/tv/tv_favorites_screen_test.dart` | Extended — asserts `SafeArea` present. |

---

### Task 1: `TvOverflowMenuButton` — collapse toolbar buttons into one menu

**Files:**
- Create: `packages/feature_iptv/lib/presentation/widgets/tv_overflow_menu.dart`
- Test: `packages/feature_iptv/test/iptv/presentation/widgets/tv_overflow_menu_test.dart`

**Interfaces:**
- Produces: `class TvOverflowMenuButton extends StatefulWidget` with constructor `TvOverflowMenuButton({super.key, required List<TvOverflowMenuItem> items, bool autofocus = false})`.
- Produces: `class TvOverflowMenuItem { const TvOverflowMenuItem({required this.label, required this.icon, required this.onSelect}); final String label; final IconData icon; final VoidCallback onSelect; }`
- Consumes: `TvFocusable` from `package:core_ui/core_ui.dart` (already exported per `tv_focusable.dart:165-365`).

- [ ] **Step 1: Write the failing test**

```dart
// packages/feature_iptv/test/iptv/presentation/widgets/tv_overflow_menu_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feature_iptv/presentation/widgets/tv_overflow_menu.dart';

void main() {
  testWidgets('renders a single focusable trigger, opens menu with all items on select', (tester) async {
    var searchTapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TvOverflowMenuButton(
            items: [
              TvOverflowMenuItem(
                label: 'Search',
                icon: Icons.search,
                onSelect: () => searchTapped = true,
              ),
              TvOverflowMenuItem(
                label: 'Help',
                icon: Icons.help_outline,
                onSelect: () {},
              ),
            ],
          ),
        ),
      ),
    );

    // Only one focusable trigger exists before opening.
    expect(find.byIcon(Icons.more_vert), findsOneWidget);
    expect(find.text('Search'), findsNothing);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Help'), findsOneWidget);

    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();

    expect(searchTapped, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/widgets/tv_overflow_menu_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'feature_iptv' in 'package:feature_iptv/presentation/widgets/tv_overflow_menu.dart'` (file doesn't exist yet).

- [ ] **Step 3: Write minimal implementation**

```dart
// packages/feature_iptv/lib/presentation/widgets/tv_overflow_menu.dart
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

class TvOverflowMenuItem {
  const TvOverflowMenuItem({
    required this.label,
    required this.icon,
    required this.onSelect,
  });

  final String label;
  final IconData icon;
  final VoidCallback onSelect;
}

class TvOverflowMenuButton extends StatefulWidget {
  const TvOverflowMenuButton({
    super.key,
    required this.items,
    this.autofocus = false,
  });

  final List<TvOverflowMenuItem> items;
  final bool autofocus;

  @override
  State<TvOverflowMenuButton> createState() => _TvOverflowMenuButtonState();
}

class _TvOverflowMenuButtonState extends State<TvOverflowMenuButton> {
  final GlobalKey _triggerKey = GlobalKey();

  Future<void> _openMenu() async {
    final renderBox =
        _triggerKey.currentContext!.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    await showMenu<void>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + size.height,
        offset.dx + size.width,
        offset.dy,
      ),
      items: [
        for (final item in widget.items)
          PopupMenuItem<void>(
            onTap: item.onSelect,
            child: Row(
              children: [
                Icon(item.icon, size: 18),
                const SizedBox(width: 12),
                Text(item.label),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      key: _triggerKey,
      semanticLabel: 'More options',
      semanticButton: true,
      autofocus: widget.autofocus,
      onSelect: _openMenu,
      borderRadius: 10,
      child: const Padding(
        padding: EdgeInsets.all(10),
        child: Icon(Icons.more_vert),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/widgets/tv_overflow_menu_test.dart`
Expected: PASS (2 assertions groups, 1 test)

- [ ] **Step 5: Commit**

```bash
git add packages/feature_iptv/lib/presentation/widgets/tv_overflow_menu.dart packages/feature_iptv/test/iptv/presentation/widgets/tv_overflow_menu_test.dart
git commit -m "feat(feature_iptv): add TvOverflowMenuButton for TV toolbar collapse"
```

---

### Task 2: Wire `TvOverflowMenuButton` into `_TvHeader`, remove discrete action buttons

**Files:**
- Modify: `packages/feature_iptv/lib/presentation/tv/iptv_tv_screen.dart:823-885` (`_TvHeader.build`)
- Test: `packages/feature_iptv/test/iptv/presentation/tv/iptv_tv_screen_test.dart`

**Interfaces:**
- Consumes: `TvOverflowMenuButton`/`TvOverflowMenuItem` from Task 1.
- Produces: `_TvHeader` now renders exactly one trailing focusable (the overflow trigger) instead of 3-5 `_TvActionButton`s. Existing callbacks (search open, playlist link open, help open, update check, refresh) are preserved as `onSelect` closures inside `TvOverflowMenuItem`s, in the same order they appear today (Search, Playlist, Help, [Update], Refresh).

- [ ] **Step 1: Write the failing test**

```dart
// add to packages/feature_iptv/test/iptv/presentation/tv/iptv_tv_screen_test.dart
testWidgets('header shows one overflow trigger, not five action buttons', (tester) async {
  await pumpIptvTvScreen(tester); // existing test helper already in this file
  await tester.pumpAndSettle();

  expect(find.byIcon(Icons.more_vert), findsOneWidget);
  expect(find.byWidgetPredicate((w) => w.runtimeType.toString() == '_TvActionButton'), findsNothing);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/tv/iptv_tv_screen_test.dart`
Expected: FAIL — finds 3+ `_TvActionButton` widgets, `more_vert` icon not found.

- [ ] **Step 3: Write minimal implementation**

In `iptv_tv_screen.dart`, replace the `_TvHeader.build` trailing button `Row` (lines ~852-883, the block containing the 4-5 `_TvActionButton(...)` calls) with:

```dart
TvOverflowMenuButton(
  autofocus: true,
  items: [
    TvOverflowMenuItem(
      label: 'Search',
      icon: Icons.search,
      onSelect: onOpenSearch, // existing callback param, unchanged name
    ),
    TvOverflowMenuItem(
      label: 'Playlist',
      icon: Icons.link,
      onSelect: onOpenPlaylist, // existing callback param, unchanged name
    ),
    TvOverflowMenuItem(
      label: 'Help',
      icon: Icons.help_outline,
      onSelect: onOpenHelp, // existing callback param, unchanged name
    ),
    if (AiroMacosUpdateService.isSupportedPlatform)
      TvOverflowMenuItem(
        label: 'Check for Updates',
        icon: Icons.system_update,
        onSelect: onCheckUpdate, // existing callback param, unchanged name
      ),
    TvOverflowMenuItem(
      label: 'Refresh',
      icon: Icons.refresh,
      onSelect: onRefresh, // existing callback param, unchanged name
    ),
  ],
),
```

Add the import at the top of `iptv_tv_screen.dart`:
```dart
import 'package:feature_iptv/presentation/widgets/tv_overflow_menu.dart';
```

Leave `_TvActionButton` class definition in place (still used by `_TvChannelToolbar`'s "Clear" button, per research — do not delete it).

- [ ] **Step 4: Run test to verify it passes**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/tv/iptv_tv_screen_test.dart`
Expected: PASS. Also run full screen test file to check no regressions: same command, expect all green.

- [ ] **Step 5: Commit**

```bash
git add packages/feature_iptv/lib/presentation/tv/iptv_tv_screen.dart packages/feature_iptv/test/iptv/presentation/tv/iptv_tv_screen_test.dart
git commit -m "feat(feature_iptv): collapse TV header action buttons into overflow menu"
```

---

### Task 3: `TvCategoryChipRow` — replace the 2-column category tile grid

**Files:**
- Create: `packages/feature_iptv/lib/presentation/widgets/tv_category_chip_row.dart`
- Test: `packages/feature_iptv/test/iptv/presentation/widgets/tv_category_chip_row_test.dart`

**Interfaces:**
- Produces: `class TvCategoryChipRow extends StatelessWidget` — `TvCategoryChipRow({super.key, required List<TvCategoryChipData> categories, required ChannelCategory selected, required ValueChanged<ChannelCategory> onSelect})`.
- Produces: `class TvCategoryChipData { const TvCategoryChipData({required this.category, required this.label, required this.count}); final ChannelCategory category; final String label; final int count; }`
- Consumes: `ChannelCategory` enum (already used at `iptv_tv_screen.dart:898-909`), `TvFocusable`.

- [ ] **Step 1: Write the failing test**

```dart
// packages/feature_iptv/test/iptv/presentation/widgets/tv_category_chip_row_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feature_iptv/domain/channel_category.dart';
import 'package:feature_iptv/presentation/widgets/tv_category_chip_row.dart';

void main() {
  testWidgets('renders one chip per category horizontally, highlights selected', (tester) async {
    ChannelCategory? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TvCategoryChipRow(
            categories: const [
              TvCategoryChipData(category: ChannelCategory.all, label: 'All', count: 42),
              TvCategoryChipData(category: ChannelCategory.sports, label: 'Sports', count: 8),
            ],
            selected: ChannelCategory.all,
            onSelect: (c) => selected = c,
          ),
        ),
      ),
    );

    expect(find.text('All'), findsOneWidget);
    expect(find.text('Sports'), findsOneWidget);
    expect(find.byType(Row), findsWidgets); // horizontal layout, not GridView
    expect(find.byType(GridView), findsNothing);

    await tester.tap(find.text('Sports'));
    await tester.pump();

    expect(selected, ChannelCategory.sports);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/widgets/tv_category_chip_row_test.dart`
Expected: FAIL — file `tv_category_chip_row.dart` doesn't exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// packages/feature_iptv/lib/presentation/widgets/tv_category_chip_row.dart
import 'package:core_ui/core_ui.dart';
import 'package:feature_iptv/domain/channel_category.dart';
import 'package:flutter/material.dart';

class TvCategoryChipData {
  const TvCategoryChipData({
    required this.category,
    required this.label,
    required this.count,
  });

  final ChannelCategory category;
  final String label;
  final int count;
}

class TvCategoryChipRow extends StatelessWidget {
  const TvCategoryChipRow({
    super.key,
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  final List<TvCategoryChipData> categories;
  final ChannelCategory selected;
  final ValueChanged<ChannelCategory> onSelect;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final data = categories[index];
          final isSelected = data.category == selected;

          return TvFocusable(
            semanticLabel: '${data.label}, ${data.count} channels',
            semanticButton: true,
            borderRadius: 22,
            onSelect: () => onSelect(data.category),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      data.label,
                      style: TextStyle(
                        color: isSelected
                            ? colorScheme.onPrimary
                            : colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${data.count}',
                      style: TextStyle(
                        color: isSelected
                            ? colorScheme.onPrimary.withValues(alpha: 0.75)
                            : colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/widgets/tv_category_chip_row_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add packages/feature_iptv/lib/presentation/widgets/tv_category_chip_row.dart packages/feature_iptv/test/iptv/presentation/widgets/tv_category_chip_row_test.dart
git commit -m "feat(feature_iptv): add TvCategoryChipRow horizontal category selector"
```

---

### Task 4: Replace `_TvCategoryRail` grid with `TvCategoryChipRow`, move above channel grid

**Files:**
- Modify: `packages/feature_iptv/lib/presentation/tv/iptv_tv_screen.dart:278-288` (`_TvBrowseLayout.build` sidebar), `:889-961` (`_TvCategoryRail`)
- Test: `packages/feature_iptv/test/iptv/presentation/tv/iptv_tv_screen_test.dart`

**Interfaces:**
- Consumes: `TvCategoryChipRow`, `TvCategoryChipData` from Task 3; existing `_visibleCategories` list (`iptv_tv_screen.dart:898-909`) and its count-filter logic (915-922) — reuse verbatim, just feed into `TvCategoryChipData` instead of tile widgets.
- Produces: `_TvBrowseLayout` no longer reserves a `SizedBox(width: 280/320)` sidebar column for categories; the chip row becomes a horizontal band above `_TvChannelGridView`, and the freed width goes to the grid.

- [ ] **Step 1: Write the failing test**

```dart
// add to packages/feature_iptv/test/iptv/presentation/tv/iptv_tv_screen_test.dart
testWidgets('category selector is a horizontal chip row, not a sidebar grid', (tester) async {
  await pumpIptvTvScreen(tester);
  await tester.pumpAndSettle();

  expect(find.byType(TvCategoryChipRow), findsOneWidget);
  expect(find.byWidgetPredicate((w) => w.runtimeType.toString() == '_TvCategoryTile'), findsNothing);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/tv/iptv_tv_screen_test.dart`
Expected: FAIL — `TvCategoryChipRow` not found, `_TvCategoryTile` still present.

- [ ] **Step 3: Write minimal implementation**

Delete the `_TvCategoryRail` (lines ~889-961) and `_TvCategoryTile` (lines ~963-1028) class definitions entirely. In `_TvBrowseLayout.build`, remove the fixed-width sidebar `SizedBox` (lines ~278-288) that wrapped `_TvCategoryRail`, and instead insert directly above the channel grid section:

```dart
Padding(
  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
  child: TvCategoryChipRow(
    categories: [
      for (final category in _visibleCategories(channelCountsByCategory))
        TvCategoryChipData(
          category: category,
          label: category.displayName, // existing extension/getter used by old tile, keep name
          count: channelCountsByCategory[category] ?? 0,
        ),
    ],
    selected: selectedCategory,
    onSelect: onCategorySelected, // existing callback, unchanged name
  ),
),
```

Add the import:
```dart
import 'package:feature_iptv/presentation/widgets/tv_category_chip_row.dart';
```

Restructure the parent `Row`/`Column` in `_TvBrowseLayout.build` so the channel grid now spans the width previously split with the sidebar (i.e. remove the `Row(children: [sidebar, Expanded(grid)])` split, make the whole body a `Column` with the chip row then `Expanded(child: grid)`).

- [ ] **Step 4: Run test to verify it passes**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/tv/iptv_tv_screen_test.dart`
Expected: PASS, and no leftover references to `_TvCategoryRail`/`_TvCategoryTile` — confirm via:

Run: `grep -rn "_TvCategoryRail\|_TvCategoryTile" packages/feature_iptv/lib/`
Expected: no output (empty).

- [ ] **Step 5: Commit**

```bash
git add packages/feature_iptv/lib/presentation/tv/iptv_tv_screen.dart packages/feature_iptv/test/iptv/presentation/tv/iptv_tv_screen_test.dart
git commit -m "feat(feature_iptv): replace TV category tile sidebar with chip row"
```

---

### Task 5: Bigger cards — unify sizing on `TvUiDimensions`, raise the values

**Files:**
- Modify: `packages/core_ui/lib/src/widgets/tv_focus_manager.dart:151-201` (`TvUiDimensions.tv()` defaults)
- Modify: `packages/feature_iptv/lib/presentation/tv/iptv_tv_screen.dart:1327-1335` (`_TvChannelGridView` grid delegate), `:1417-1518` (`_TvChannelCard` padding/text sizes)
- Modify: `packages/feature_iptv/lib/presentation/tv/tv_favorites_screen.dart:65-72`
- Test: `packages/feature_iptv/test/iptv/presentation/tv/iptv_tv_screen_test.dart`, `packages/feature_iptv/test/iptv/presentation/tv/tv_favorites_screen_test.dart`

**Interfaces:**
- Consumes: `dimensions.channelCardWidth`/`channelCardHeight` via existing `tvDimensionsProvider` watch pattern already used by `VodGrid`/`TvChannelGrid` (research: `vod_grid.dart:27-46`).
- Produces: `TvUiDimensions.tv()` default `channelCardWidth` raised `200 → 240`, `channelCardHeight` raised `150 → 190`. `_TvChannelGridView`'s `maxCrossAxisExtent` changed from hardcoded `180`/`220` to `dimensions.channelCardWidth`, sourced via `ref.watch(tvDimensionsProvider)` inside `_TvChannelGridView` (making it consistent with `VodGrid`'s existing pattern instead of its own disconnected literal, per research finding).

- [ ] **Step 1: Write the failing test**

```dart
// add to packages/feature_iptv/test/iptv/presentation/tv/iptv_tv_screen_test.dart
testWidgets('channel grid cards use shared TvUiDimensions width, not a hardcoded 180/220', (tester) async {
  await pumpIptvTvScreen(tester);
  await tester.pumpAndSettle();

  final gridView = tester.widget<GridView>(find.byType(GridView).first);
  final delegate = gridView.gridDelegate as SliverGridDelegateWithMaxCrossAxisExtent;
  expect(delegate.maxCrossAxisExtent, 240);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/tv/iptv_tv_screen_test.dart`
Expected: FAIL — actual value is `180` or `220` (current hardcoded literal), not `240`.

- [ ] **Step 3: Write minimal implementation**

In `tv_focus_manager.dart`, change the two defaults inside `TvUiDimensions.tv()`:
```dart
channelCardWidth: 240, // was 200
channelCardHeight: 190, // was 150
```

In `iptv_tv_screen.dart`, `_TvChannelGridView.build` (around line 1327), replace:
```dart
maxCrossAxisExtent: widget.compact ? 180 : 220,
```
with:
```dart
maxCrossAxisExtent: ref.watch(tvDimensionsProvider).channelCardWidth,
```
(Convert `_TvChannelGridView` to a `ConsumerWidget`/`ConsumerStatefulWidget` if it is not already one — check its current class declaration at line ~1284 before editing; research notes it renders `_TvChannelCard` per item but did not confirm base class, verify with `sed -n '1284,1290p' packages/feature_iptv/lib/presentation/tv/iptv_tv_screen.dart` before writing the diff.)

In `tv_favorites_screen.dart` (lines 65-72), replace the hardcoded `maxCrossAxisExtent: 220` with the same `ref.watch(tvDimensionsProvider).channelCardWidth` pattern.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/tv/iptv_tv_screen_test.dart test/iptv/presentation/tv/tv_favorites_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add packages/core_ui/lib/src/widgets/tv_focus_manager.dart packages/feature_iptv/lib/presentation/tv/iptv_tv_screen.dart packages/feature_iptv/lib/presentation/tv/tv_favorites_screen.dart packages/feature_iptv/test/iptv/presentation/tv/iptv_tv_screen_test.dart packages/feature_iptv/test/iptv/presentation/tv/tv_favorites_screen_test.dart
git commit -m "feat(feature_iptv): unify TV card sizing on TvUiDimensions, raise default size"
```

---

### Task 6: Wire real Fire TV safe-zone insets into the always-zero provider path

**Files:**
- Modify: `packages/feature_iptv/lib/presentation/tv/iptv_tv.dart:15-22` (`tvDimensionsProvider` definition)
- Test: `packages/feature_iptv/test/iptv/presentation/tv/iptv_tv_screen_test.dart`

**Interfaces:**
- Consumes: `tvDimensionsWithFireTvProvider` (`app/lib/core/tv/tv_providers.dart:55-83`, a `FutureProvider.family` — confirm its `.family` parameter type by reading that file before editing, since `tvDimensionsProvider` today is a plain sync provider, not a `FutureProvider`).
- Produces: `tvDimensionsProvider` (still exported under the same name so no call-site in `vod_grid.dart`/`tv_channel_grid.dart`/`epg_timeline_grid.dart` needs to change) now resolves `safeZone` from `DeviceFormFactorDetector.getFireTvSafeZone()` on Fire TV instead of always defaulting to `EdgeInsets.zero`.

- [ ] **Step 1: Write the failing test**

```dart
// add to packages/feature_iptv/test/iptv/presentation/tv/iptv_tv_screen_test.dart
testWidgets('VodGrid padding includes non-zero safe zone on Fire TV', (tester) async {
  // Override the platform detector to report Fire TV for this test.
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tvPlatformProvider.overrideWith((ref) async => TvPlatform.fireTv),
      ],
      child: const MaterialApp(home: VodTvScreen()),
    ),
  );
  await tester.pumpAndSettle();

  final dimensions = tester
      .element(find.byType(VodGrid))
      .read(sharedTvDimensionsProvider); // exact provider name confirmed at implementation time
  expect(dimensions.safeZone, isNot(EdgeInsets.zero));
});
```

Note for implementer: the exact override syntax depends on whether `tvDimensionsWithFireTvProvider` is a `.family` keyed by a platform argument or by nothing — **read `app/lib/core/tv/tv_providers.dart:55-83` in full before writing this test**, then adjust the override line accordingly. Do not guess the signature.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/tv/iptv_tv_screen_test.dart`
Expected: FAIL — `dimensions.safeZone` is `EdgeInsets.zero`.

- [ ] **Step 3: Write minimal implementation**

In `iptv_tv.dart`, change `tvDimensionsProvider` from its current always-zero sync definition to delegate to the Fire-TV-aware provider:

```dart
final tvDimensionsProvider = Provider<TvUiDimensions>((ref) {
  final fireTvSafeZone = ref.watch(fireTvSafeZoneProvider); // app/lib/core/providers/platform_providers.dart:125-129, already a plain EdgeInsets provider (not async) per research
  return TvUiDimensions.tv(safeZone: fireTvSafeZone);
});
```

(Prefer `fireTvSafeZoneProvider` over `tvDimensionsWithFireTvProvider` here since research confirms the former is a plain `EdgeInsets` provider — simpler to compose synchronously than wrapping the `FutureProvider.family`. Import `package:airo/core/providers/platform_providers.dart` — verify the actual package name/import path for `app/lib/core/providers/platform_providers.dart` before writing the import, since `app/` may not be a separate package from `packages/feature_iptv`'s perspective; if `app/` cannot be imported from `packages/feature_iptv` due to dependency direction, this logic must instead move to `app/lib/core/tv/tv_providers.dart` and `iptv_tv.dart`'s provider must be overridden at the `app/` composition root — confirm dependency direction with `cat packages/feature_iptv/pubspec.yaml | grep -A2 app` before implementing.)

- [ ] **Step 4: Run test to verify it passes**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/tv/iptv_tv_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add packages/feature_iptv/lib/presentation/tv/iptv_tv.dart packages/feature_iptv/test/iptv/presentation/tv/iptv_tv_screen_test.dart
git commit -m "fix(feature_iptv): wire real Fire TV safe-zone insets into shared TvUiDimensions"
```

---

### Task 7: `SafeArea` consistency — `TvShell` and `TvFavoritesScreen`

**Files:**
- Modify: `app/lib/core/app/tv_shell.dart:28-44`
- Modify: `packages/feature_iptv/lib/presentation/tv/tv_favorites_screen.dart:23` (bare `Padding`, no `Scaffold`/`SafeArea` today per research)
- Test: `app/test/core/app/tv_shell_test.dart`, `packages/feature_iptv/test/iptv/presentation/tv/tv_favorites_screen_test.dart`

**Interfaces:**
- Consumes: nothing new — plain `SafeArea` widget.
- Produces: both screens now wrap their root content in `SafeArea` the same way `iptv_tv_screen.dart:129`, `vod_tv_screen.dart:26`, and `iptv_guide_screen.dart:36` already do (research confirms these three are already consistent; only `tv_shell.dart` and `tv_favorites_screen.dart` are the gaps).

- [ ] **Step 1: Write the failing test**

```dart
// add to app/test/core/app/tv_shell_test.dart
testWidgets('TvShell wraps content in SafeArea', (tester) async {
  await pumpTvShell(tester); // existing helper already in this file
  expect(find.byType(SafeArea), findsWidgets);
});
```

```dart
// add to packages/feature_iptv/test/iptv/presentation/tv/tv_favorites_screen_test.dart
testWidgets('TvFavoritesScreen wraps content in SafeArea', (tester) async {
  await pumpFavoritesScreen(tester); // existing helper already in this file
  expect(find.byType(SafeArea), findsOneWidget);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/core/app/tv_shell_test.dart` and `cd packages/feature_iptv && flutter test test/iptv/presentation/tv/tv_favorites_screen_test.dart`
Expected: both FAIL — `SafeArea` not found.

- [ ] **Step 3: Write minimal implementation**

In `tv_shell.dart`, wrap the `Scaffold`'s `body:` (the `Row` at line ~28-44) in `SafeArea(child: ...)`.

In `tv_favorites_screen.dart`, wrap the existing root `Padding` (line 23) in `SafeArea(child: Padding(...))`.

- [ ] **Step 4: Run test to verify it passes**

Run both commands from Step 2 again.
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/lib/core/app/tv_shell.dart packages/feature_iptv/lib/presentation/tv/tv_favorites_screen.dart app/test/core/app/tv_shell_test.dart packages/feature_iptv/test/iptv/presentation/tv/tv_favorites_screen_test.dart
git commit -m "fix(tv): apply SafeArea consistently to TvShell and TvFavoritesScreen"
```

---

### Task 8: Explicit D-pad focus order via `FocusTraversalGroup`

**Files:**
- Modify: `packages/feature_iptv/lib/presentation/tv/iptv_tv_screen.dart:823-887` (`_TvHeader`), the new chip row section (Task 4), `_TvChannelGridView` (~1284-1352)
- Test: `packages/feature_iptv/test/iptv/presentation/tv/iptv_tv_screen_test.dart`

**Interfaces:**
- Consumes: Flutter's built-in `FocusTraversalGroup`/`FocusTraversalOrder`/`OrderedTraversalPolicy` (no new dependency — confirmed absent from codebase today per research, first use here).
- Produces: three named traversal groups in fixed order — header/overflow menu (order 1), category chip row (order 2), channel grid (order 3) — so D-pad down/up moves predictably between bands instead of relying on paint-order fallback.

- [ ] **Step 1: Write the failing test**

```dart
// add to packages/feature_iptv/test/iptv/presentation/tv/iptv_tv_screen_test.dart
testWidgets('pressing arrow-down from overflow menu moves focus to category chip row, then to grid', (tester) async {
  await pumpIptvTvScreen(tester);
  await tester.pumpAndSettle();

  final overflowFocus = tester.widget<Focus>(
    find.ancestor(of: find.byIcon(Icons.more_vert), matching: find.byType(Focus)).first,
  );
  expect(overflowFocus.focusNode!.hasFocus, isTrue); // autofocus from Task 2

  await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
  await tester.pumpAndSettle();
  // First chip should now hold focus.
  final chipRow = tester.widget<Focus>(
    find.descendant(of: find.byType(TvCategoryChipRow), matching: find.byType(Focus)).first,
  );
  expect(chipRow.focusNode!.hasFocus, isTrue);

  await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
  await tester.pumpAndSettle();
  final gridFocus = tester.widget<Focus>(
    find.descendant(of: find.byType(GridView), matching: find.byType(Focus)).first,
  );
  expect(gridFocus.focusNode!.hasFocus, isTrue);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/tv/iptv_tv_screen_test.dart`
Expected: FAIL — focus does not move as asserted (no traversal groups exist yet, default order may differ or arrow-down may not move focus off the header at all).

- [ ] **Step 3: Write minimal implementation**

Wrap each of the three bands in `_TvBrowseLayout.build` with `FocusTraversalGroup`:

```dart
FocusTraversalGroup(
  policy: OrderedTraversalPolicy(),
  child: FocusTraversalOrder(
    order: const NumericFocusOrder(1),
    child: _TvHeader(/* ...existing params... */),
  ),
),
FocusTraversalGroup(
  policy: OrderedTraversalPolicy(),
  child: FocusTraversalOrder(
    order: const NumericFocusOrder(2),
    child: TvCategoryChipRow(/* ...existing params from Task 4... */),
  ),
),
FocusTraversalGroup(
  policy: OrderedTraversalPolicy(),
  child: FocusTraversalOrder(
    order: const NumericFocusOrder(3),
    child: Expanded(child: _TvChannelGridView(/* ...existing params... */)),
  ),
),
```

Add import if not already present: `import 'package:flutter/widgets.dart' show FocusTraversalGroup, FocusTraversalOrder, NumericFocusOrder, OrderedTraversalPolicy;` (usually already covered by the existing `package:flutter/material.dart` import — verify no separate import is actually required before adding one).

- [ ] **Step 4: Run test to verify it passes**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/tv/iptv_tv_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add packages/feature_iptv/lib/presentation/tv/iptv_tv_screen.dart packages/feature_iptv/test/iptv/presentation/tv/iptv_tv_screen_test.dart
git commit -m "feat(feature_iptv): explicit D-pad focus traversal order for TV browse screen"
```

---

### Task 9: Full-suite regression pass + `flutter analyze`

**Files:**
- No new files — verification only.

- [ ] **Step 1: Run full feature_iptv test suite**

Run: `cd packages/feature_iptv && flutter test`
Expected: all tests pass (baseline was 219 tests green before this plan per prior session; expect + ~10-12 new tests from Tasks 1-8, all green, zero regressions in unrelated tests e.g. `vod_grid_test.dart`, `epg_timeline_grid_test.dart`).

- [ ] **Step 2: Run app-level TvShell suite**

Run: `cd app && flutter test test/core/app/tv_shell_test.dart`
Expected: PASS.

- [ ] **Step 3: Run flutter analyze on both packages**

Run: `cd packages/feature_iptv && flutter analyze` and `cd app && flutter analyze`
Expected: no new errors/warnings introduced by this plan (pre-existing `voiceSearchServiceProvider` ambiguous-import warnings, if still present, are out of scope — do not fix them here).

- [ ] **Step 4: Manual verification note (no hardware in this environment)**

This plan cannot be closed out as "on-device verified" without real Android TV / Fire TV hardware or an emulator — same limitation as the pre-existing hero-CTA D-pad gap. Record in the PR description that Task 8's arrow-key traversal is verified only via widget-test `sendKeyEvent` simulation, not a physical D-pad.

- [ ] **Step 5: Commit (if any cleanup needed)**

```bash
git add -A
git commit -m "test(feature_iptv): full regression pass after TV nav rethink"
```

(Skip this commit if Step 1-3 found nothing to fix.)

---

## Self-Review

**Spec coverage:**
1. Toolbar → overflow menu: Tasks 1-2. ✅
2. Category tiles → chips: Tasks 3-4. ✅
3. Bigger cards: Task 5. ✅
4. Safe-area insets: Tasks 6-7 (split: Task 6 = Fire TV safe-zone data wiring, Task 7 = `SafeArea` widget consistency — these are two different mechanisms per research and both were gaps). ✅
5. Focus-order redesign: Task 8. ✅

**Placeholder scan:** No TBD/"add appropriate"/"similar to Task N" language found on re-read. Task 6's implementation step includes explicit verification sub-steps ("confirm X before implementing") rather than placeholders — this reflects genuine unresolved facts from research (exact provider signature, cross-package import direction) that the plan flags for the implementer to check first rather than guessing, which is preferable to a wrong hardcoded assumption.

**Type consistency:** `TvOverflowMenuItem`/`TvOverflowMenuButton` (Task 1) used identically in Task 2. `TvCategoryChipData`/`TvCategoryChipRow` (Task 3) used identically in Task 4. `dimensions.channelCardWidth`/`channelCardHeight` (Task 5) matches existing `TvUiDimensions` field names from `tv_focus_manager.dart:151-201` — no renames introduced.
