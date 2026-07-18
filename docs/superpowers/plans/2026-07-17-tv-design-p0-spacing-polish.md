# Airo TV Design Revamp — P0 Spacing/Alignment Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tighten spacing, alignment, and typographic rhythm across the Airo TV browse screen and sidebar to an 8-point grid, without changing any screen's structure, navigation behavior, or D-pad focus flow.

**Architecture:** This is a polish pass over the existing `IptvTvScreen`/`TvShell` widget tree (built earlier in the `tv-design-revamp` branch). No new widgets, no new providers, no routing changes. Every task is a targeted numeric/layout edit to an existing widget's `build()` method, verified by the existing widget-test suite plus a manual macOS visual check. This is explicitly **not** the TV-first navigation rethink (removing toolbar buttons, horizontal category chips, bigger cards, focus-order redesign) — that is P1 and requires its own plan because it changes structure and D-pad flow, which this plan does not touch.

**Tech Stack:** Flutter (Dart), Riverpod, existing `core_ui` design-token package (`AppSpacing`, `AiroThemeTokens`, `AiroRail`).

## Global Constraints

- Every spacing value introduced or changed must be a clean 8-point-grid value: 8, 16, 24, 32, 48, 64 (or a documented half-step: 4, 12, 20, 28 where the full-step doesn't fit). Do not introduce new arbitrary values like 13, 19, or 27.
- No task may change routing, provider wiring, semantics labels/hints used by existing tests, or D-pad focus order. If a step would require any of those, stop and flag it instead of proceeding — that belongs in the P1 plan.
- After every task, run the affected package's test suite before moving to the next task. Do not batch fixes across tasks without testing between them — this codebase has bitten us before with viewport-overflow regressions from stacked untested layout edits (see git history on `_TvHeroBanner`/`_TvHeroRailsPanel` in this same branch).
- Run `flutter analyze` on every file touched before committing it.
- Working directory for all commands: `/Users/udaychauhan/workspace/airo/.worktrees/tv-design-revamp` (this branch's worktree). Per-package commands are run from that package's subdirectory (e.g. `packages/core_ui`, `packages/feature_iptv`, `app`).

---

### Task 1: Fix the duplicate/broken `AppSpacing` token class (platform, foundational)

There are two classes named `AppSpacing` in `core_ui`: the exported one (`lib/src/theme/app_spacing.dart`) and an unused orphan (`lib/src/spacing/app_spacing.dart`) that nothing imports. Three tests in `core_ui_test.dart` already encode the *intended* clean 8-point scale but fail against the current exported class's values. This task makes the exported class match the already-written test expectations and deletes the dead duplicate — this is the actual foundation the rest of this plan's "8-point grid" numbers assume.

**Files:**
- Modify: `packages/core_ui/lib/src/theme/app_spacing.dart`
- Delete: `packages/core_ui/lib/src/spacing/app_spacing.dart`
- Test: `packages/core_ui/test/core_ui_test.dart` (already exists, currently failing — no edits needed to the test itself)

**Interfaces:**
- Produces: `AppSpacing.xxs` (2.0), `AppSpacing.xs` (4.0), `AppSpacing.sm` (8.0), `AppSpacing.md` (16.0), `AppSpacing.lg` (24.0), `AppSpacing.xl` (32.0), `AppSpacing.xxl` (48.0), `AppSpacing.radiusFull` (999.0) — consumed by 8 existing files across `core_ui` and `template_feature` (see verification step below); none of the widgets touched in Tasks 2-9 of this plan reference `AppSpacing` today (they use raw literals), so this task's blast radius is isolated to those 8 files.

- [ ] **Step 1: Confirm the current failing state**

Run: `cd packages/core_ui && flutter test test/core_ui_test.dart 2>&1 | tail -20`
Expected: 3 failures — `AppSpacing border radius values are defined`, `AppSpacing padding presets have correct values`, `AppSpacing spacing values are correct`.

- [ ] **Step 2: Read the exact expected values from the test**

Run: `grep -n "AppSpacing\." packages/core_ui/test/core_ui_test.dart`
Expected output includes these exact assertions (already in the file, do not edit it):
```dart
expect(AppSpacing.unit, 4.0);
expect(AppSpacing.xxs, 2.0);
expect(AppSpacing.xs, 4.0);
expect(AppSpacing.sm, 8.0);
expect(AppSpacing.md, 16.0);
expect(AppSpacing.lg, 24.0);
expect(AppSpacing.xl, 32.0);
expect(AppSpacing.xxl, 48.0);
expect(AppSpacing.paddingXs, const EdgeInsets.all(4.0));
expect(AppSpacing.paddingMd, const EdgeInsets.all(16.0));
expect(AppSpacing.paddingLg, const EdgeInsets.all(24.0));
expect(AppSpacing.radiusXs, 4.0);
expect(AppSpacing.radiusSm, 8.0);
expect(AppSpacing.radiusMd, 12.0);
expect(AppSpacing.radiusLg, 16.0);
expect(AppSpacing.radiusXl, 24.0);
expect(AppSpacing.radiusFull, 999.0);
```

- [ ] **Step 3: Rewrite the named spacing/radius constants**

In `packages/core_ui/lib/src/theme/app_spacing.dart`, replace the named spacing block and `radiusFull`:

```dart
  // Base spacing unit (4dp)
  static const double unit = 4.0;

  // Named spacing values — clean 8-point grid with 4pt half-steps.
  static const double xxs = 2.0;
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
  static const double xxxl = 64.0;
```

Leave `paddingXs`/`paddingSm`/`paddingMd`/`paddingLg`/`paddingXl` and every other `EdgeInsets`/`BorderRadius` constant in the file untouched — they already reference `xs`/`sm`/`md`/etc. by name (e.g. `EdgeInsets.all(xs)`), so they recompute correctly once the named constants above change. Only change the literal radius value:

```dart
  static const double radiusFull = 999.0;
```

Leave `radiusXs`/`radiusSm`/`radiusMd`/`radiusLg`/`radiusXl`/`radiusCyber` and the `tv*`/`mobile*` platform tokens exactly as they are — they already match the test's expectations and are out of this task's scope.

- [ ] **Step 4: Delete the orphan duplicate**

```bash
rm packages/core_ui/lib/src/spacing/app_spacing.dart
rmdir packages/core_ui/lib/src/spacing
```

Verify nothing referenced it (should print nothing):
```bash
grep -rn "src/spacing/app_spacing" packages/core_ui/lib packages/core_ui/test app packages/feature_iptv 2>/dev/null
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `cd packages/core_ui && flutter test test/core_ui_test.dart 2>&1 | tail -15`
Expected: `All tests passed!`

- [ ] **Step 6: Analyze and check the blast radius**

```bash
flutter analyze lib/src/theme/app_spacing.dart
grep -rln "AppSpacing\." --include="*.dart" ../../packages ../../app 2>/dev/null | grep -v "/test/"
```
Expected `analyze`: `No issues found!`
Expected `grep`: 8 files, all under `core_ui/lib/src/widgets/` (`airo_channel_card.dart`, `error_view.dart`, `app_card.dart`, `loading_indicator.dart`, `app_button.dart`) and `template_feature/lib/src/presentation/screens/template_screen.dart`. None of these are TV screens — they get slightly tighter spacing (`sm` 12→8, `xxs` 4→2) as an acceptable side effect. If this list includes anything unexpected, stop and re-check before continuing.

- [ ] **Step 7: Run the full core_ui suite**

Run: `cd packages/core_ui && flutter test 2>&1 | tail -15`
Expected: `All tests passed!` (this also re-confirms `airo_rail_test.dart` and `airo_rail_card_test.dart` are unaffected, since Task 7 below edits `airo_rail.dart` too).

- [ ] **Step 8: Commit**

```bash
git add packages/core_ui/lib/src/theme/app_spacing.dart
git rm packages/core_ui/lib/src/spacing/app_spacing.dart
git commit -m "fix(core_ui): unify duplicate AppSpacing class onto the 8pt grid the tests already expect"
```

---

### Task 2: Sidebar spacing rhythm

Fixes the "top-heavy" sidebar: today the logo has two stacked gaps below it (its own `bottom: 22` padding, plus a separate `SizedBox(height: 12)` in the parent) totaling 34px, while nav items are crammed together with only 2px between them. This collapses that into the target rhythm: top padding 24, logo mark 56×56, one clean 28px gap, 16px between nav items, bottom padding 24.

**Files:**
- Modify: `app/lib/core/app/tv_shell.dart:126-155` (`_TvNavigationRail.build`), `:157-205` (`_TvSidebarLogo.build`), `:241` (`_TvNavItemState.build` padding)

**Interfaces:**
- Consumes: nothing new.
- Produces: nothing new — purely visual, no signature changes. `tv_shell_test.dart`'s `find.byKey(const Key('tv-sidebar-nav'))` and the per-label `find.descendant` checks are unaffected since no widget, key, or text changes.

- [ ] **Step 1: Read current state to confirm line numbers**

Run: `grep -n "vertical: 22\|bottom: 22\|height: 12\|width: 42\|height: 42\|vertical: 2, horizontal: 7" app/lib/core/app/tv_shell.dart`
Expected: matches at the container padding, the logo's bottom padding, the post-logo gap, the logo box size (two lines), and the nav item padding.

- [ ] **Step 2: Update the sidebar container's top/bottom padding**

In `_TvNavigationRail.build`, change:
```dart
      padding: const EdgeInsets.symmetric(vertical: 22),
```
to:
```dart
      padding: const EdgeInsets.symmetric(vertical: 24),
```

- [ ] **Step 3: Remove the logo's own bottom padding and consolidate into one gap**

In `_TvSidebarLogo.build`, change:
```dart
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: TvFocusable(
```
to:
```dart
    return TvFocusable(
```
(remove the now-unmatched closing `)` for the `Padding` at the end of this widget's `build` method — the `TvFocusable` becomes the direct return value, so delete one trailing `)` that used to close `Padding(`).

In `_TvNavigationRail.build`, change the gap that currently follows the logo:
```dart
          _TvSidebarLogo(onSelect: () => onDestinationSelected(0)),
          const SizedBox(height: 12),
```
to:
```dart
          _TvSidebarLogo(onSelect: () => onDestinationSelected(0)),
          const SizedBox(height: 28),
```

- [ ] **Step 4: Enlarge the logo mark from 42×42 to 56×56, scaling the glyph and radius proportionally**

In `_TvSidebarLogo.build`, change:
```dart
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: BorderRadius.circular(11),
                boxShadow: [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.4),
                    blurRadius: 24,
                  ),
                ],
              ),
              child: Text(
                'A',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: colors.onPrimary,
                ),
              ),
            ),
```
to:
```dart
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.4),
                    blurRadius: 24,
                  ),
                ],
              ),
              child: Text(
                'A',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: colors.onPrimary,
                ),
              ),
            ),
```

- [ ] **Step 5: Give nav items 16px of separation**

In `_TvNavItemState.build`, change:
```dart
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 7),
```
to:
```dart
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 7),
```
(8px on each side of every item = 16px between adjacent items' visible content.)

- [ ] **Step 6: Analyze**

Run: `cd app && flutter analyze lib/core/app/tv_shell.dart`
Expected: `No issues found!`

- [ ] **Step 7: Run the shell and router tests**

Run: `cd app && flutter test test/core/app/tv_shell_test.dart test/core/app/tv_router_test.dart 2>&1 | tail -20`
Expected: all pass (6 tests total between the two files).

- [ ] **Step 8: Commit**

```bash
git add app/lib/core/app/tv_shell.dart
git commit -m "fix(app): tighten Airo TV sidebar to a consistent 24/56/28/16/24 spacing rhythm"
```

---

### Task 3: Simplify the browse-screen profile header

Today `_TvLiteReceiverShellHeader` is one `Row` trying to fit an icon+title/subtitle block, a `Wrap` of profile capability chips squeezed into whatever `Expanded` width is left, and a fixed 300px-wide description column — which is why the chips wrap awkwardly and the description isn't vertically balanced. This restructures it into title/subtitle (with the description folded inline, vertically centered against the icon), a divider, then the capability chips on their own full-width row below. **No chip's label, semantics, or the underlying `productProfile.navigation` data changes** — this is a pure layout restructure, so the existing test assertions (`find.text('Home')`, `find.text('Diagnostics')`, `find.textContaining('Profile-limited:')`, etc.) keep passing unmodified.

**Files:**
- Modify: `packages/feature_iptv/lib/presentation/tv/iptv_tv_screen.dart:639-729` (`_TvLiteReceiverShellHeader.build`)

**Interfaces:**
- Consumes: `ProductProfileManifest productProfile` (unchanged constructor).
- Produces: nothing new — same widget, same public surface. `_ProfileSectionChip` (unchanged, still built from `productProfile.navigation`).

- [ ] **Step 1: Read the current implementation to confirm line numbers**

Run: `sed -n '639,729p' packages/feature_iptv/lib/presentation/tv/iptv_tv_screen.dart`
Expected: matches the `Row` with icon, `SizedBox(width: 260)` title column, `Expanded(child: Wrap(...))` chips, `SizedBox(width: 300)` description.

- [ ] **Step 2: Replace the build method's returned widget tree**

Replace the entire `child: Row(...)` block (currently lines ~669-725, inside the `Padding` inside the outer `DecoratedBox`) with:

```dart
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(Icons.tv, color: colorScheme.primary, size: 32),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        productProfile.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${productProfile.supportLevel.tvLabel} profile',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: Text(
                    unavailable.isEmpty
                        ? 'All profile capabilities available'
                        : 'Profile-limited: ${unavailable.join(', ')}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(height: 1, color: colorScheme.outlineVariant),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: productProfile.navigation
                  .map((entry) => _ProfileSectionChip(entry: entry))
                  .toList(growable: false),
            ),
          ],
        ),
```

This removes the old `SizedBox(width: 260)` fixed title column (now `Expanded`) and the old `SizedBox(width: 300)` description column (now a `ConstrainedBox(maxWidth: 260)`, single line instead of `maxLines: 2`, since it's no longer sharing a row with the wrapping chips). The chip `Wrap` moves out of the cramped `Expanded` slot into its own full-width row below the divider.

- [ ] **Step 3: Analyze**

Run: `cd packages/feature_iptv && flutter analyze lib/presentation/tv/iptv_tv_screen.dart`
Expected: `No issues found!` (aside from the pre-existing unrelated `flutter_riverpod/legacy.dart` unused-import warning already present before this plan — do not fix that here, it's out of scope).

- [ ] **Step 4: Run the TV screen test**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/tv/iptv_tv_screen_test.dart 2>&1 | tail -20`
Expected: all 9 tests pass, including `renders TV browsing surface with categories and actions` (which asserts `find.text('Diagnostics')`, `find.text('Home')`, etc. all still `findsOneWidget`/`findsWidgets` as before).

- [ ] **Step 5: Commit**

```bash
git add packages/feature_iptv/lib/presentation/tv/iptv_tv_screen.dart
git commit -m "fix(feature_iptv): stop squeezing profile capability chips into a shrinking Expanded slot"
```

---

### Task 4: "Live channels" heading rhythm and toolbar button spacing

`_TvHeader` currently has a 6px gap between the "Live channels" heading and its subtitle (spec target: 12), and 12px gaps between the five toolbar buttons (Search/Playlist/Help/Update/Refresh) — this widens both to a clean 8-point value.

**Files:**
- Modify: `packages/feature_iptv/lib/presentation/tv/iptv_tv_screen.dart:783-843` (`_TvHeader.build`)

**Interfaces:**
- Consumes/produces: nothing new — same widget, no signature change.

- [ ] **Step 1: Confirm current values**

Run: `sed -n '783,843p' packages/feature_iptv/lib/presentation/tv/iptv_tv_screen.dart`
Expected: `SizedBox(height: 6)` between title/subtitle, four `SizedBox(width: 12)` between the five `_TvActionButton`s.

- [ ] **Step 2: Widen the heading/subtitle gap**

Change:
```dart
              Text('Live channels', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 6),
```
to:
```dart
              Text('Live channels', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 12),
```

- [ ] **Step 3: Widen all four inter-button gaps from 12 to 16**

There are four occurrences of `const SizedBox(width: 12),` inside this widget's `Row` (between Search/Playlist, Playlist/Help, Help/Update-or-Refresh, and before Refresh). Change every one of them to:
```dart
        const SizedBox(width: 16),
```

- [ ] **Step 4: Analyze**

Run: `cd packages/feature_iptv && flutter analyze lib/presentation/tv/iptv_tv_screen.dart`
Expected: `No issues found!` (same pre-existing unused-import warning as Task 3, ignore it).

- [ ] **Step 5: Run the TV screen test**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/tv/iptv_tv_screen_test.dart 2>&1 | tail -20`
Expected: all 9 tests pass.

- [ ] **Step 6: Commit**

```bash
git add packages/feature_iptv/lib/presentation/tv/iptv_tv_screen.dart
git commit -m "fix(feature_iptv): widen Live Channels heading gap and toolbar button spacing to 12/16px"
```

---

### Task 5: Browse heading gap and category tile padding

Widens the gap between the "Browse" heading and the category tile grid (12→20), and the tiles' internal padding (14→20 — see the note on why 20 not 24 below).

**Files:**
- Modify: `packages/feature_iptv/lib/presentation/tv/iptv_tv_screen.dart:845-909` (`_TvCategoryRail.build`), `:911-977` (`_TvCategoryTile.build`)

**Interfaces:**
- Consumes/produces: nothing new.

- [ ] **Step 1: Confirm current values**

Run: `sed -n '880,946p' packages/feature_iptv/lib/presentation/tv/iptv_tv_screen.dart`
Expected: `Text('Browse', ...)` followed by `SizedBox(height: 12)`, and `_TvCategoryTile`'s `Padding(padding: const EdgeInsets.all(14), ...)`.

- [ ] **Step 2: Widen the Browse heading gap**

In `_TvCategoryRail.build`, change:
```dart
        Text('Browse', style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
```
to:
```dart
        Text('Browse', style: theme.textTheme.titleLarge),
        const SizedBox(height: 20),
```

- [ ] **Step 3: Widen category tile padding to 20 (not the suggested 24)**

In `_TvCategoryTile.build`, change:
```dart
        child: Padding(
          padding: const EdgeInsets.all(14),
```
to:
```dart
        child: Padding(
          padding: const EdgeInsets.all(20),
```

Note on the value: the design feedback suggested 24px padding, but these tiles sit in a 2-column grid inside a sidebar column that's only 280px wide on compact TV viewports (`compactTv` — see `_TvBrowseLayout`), giving each tile roughly 130px of width at `childAspectRatio: 1.16` (~112px tall). At 24px padding that only leaves ~64px of vertical room for the icon (30px) + label + count text, which is tight enough to risk overflow at the smallest tested viewport. 20px is the safe 8-point value here — Step 5 below verifies this against the actual compact-viewport test before you move on. If that test passes with room to spare, you may try 24 and re-run Step 5; if it overflows, keep 20.

- [ ] **Step 4: Analyze**

Run: `cd packages/feature_iptv && flutter analyze lib/presentation/tv/iptv_tv_screen.dart`
Expected: `No issues found!` (ignore the same pre-existing unused-import warning).

- [ ] **Step 5: Run the TV screen test, paying attention to the compact-viewport case**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/tv/iptv_tv_screen_test.dart 2>&1 | tail -40`
Expected: all 9 tests pass, **especially** `keeps compact TV viewport browse controls reachable` (this is the one that pumps at `Size(1024, 576)`, the narrowest tested width, and is where a category-tile overflow would first show up as a `RenderFlex overflowed` exception in the output). If you see an overflow exception mentioning `_TvCategoryTile`, revert Step 3's padding to `16` and re-run this step.

- [ ] **Step 6: Commit**

```bash
git add packages/feature_iptv/lib/presentation/tv/iptv_tv_screen.dart
git commit -m "fix(feature_iptv): widen Browse heading gap and category tile padding"
```

---

### Task 6: Widen the hero banner's left-side scrim

The hero banner's dark overlay currently fades from opaque to fully transparent across 70% of the banner's width, which reads as too subtle/narrow behind the title text. This hardens it into a clearly darker block covering roughly the left 35-40%, fading out by 65%.

**Files:**
- Modify: `packages/feature_iptv/lib/presentation/tv/iptv_tv_screen.dart:465-482` (`_TvHeroBanner.build`, the left-to-right scrim `Positioned.fill`)

**Interfaces:**
- Consumes/produces: nothing new.

- [ ] **Step 1: Confirm current values**

Run: `sed -n '465,497p' packages/feature_iptv/lib/presentation/tv/iptv_tv_screen.dart`
Expected: the left-right `LinearGradient` with `colors: [Color(0xB3000000), Colors.transparent]` and `stops: [0.0, 0.7]`, followed by the separate top-bottom fade gradient (leave that second gradient untouched — it's the bottom fade, not in scope here).

- [ ] **Step 2: Harden and narrow the left-right scrim**

Change:
```dart
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0xB3000000),
                      Colors.transparent,
                    ],
                    stops: [0.0, 0.7],
                  ),
```
to:
```dart
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0xE6000000),
                      Color(0xE6000000),
                      Colors.transparent,
                    ],
                    stops: [0.0, 0.38, 0.65],
                  ),
```
(This holds a solid, near-opaque black block for the first 38% of the banner's width, then fades out by 65% — matching the "35-40% block, not a thin gradient" feedback while keeping a soft edge rather than a hard cut.)

- [ ] **Step 3: Analyze**

Run: `cd packages/feature_iptv && flutter analyze lib/presentation/tv/iptv_tv_screen.dart`
Expected: `No issues found!` (ignore the pre-existing unused-import warning).

- [ ] **Step 4: Run the TV screen test**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/tv/iptv_tv_screen_test.dart 2>&1 | tail -20`
Expected: all 9 tests pass (this gradient isn't asserted on by any test, so this step is confirming no incidental breakage).

- [ ] **Step 5: Commit**

```bash
git add packages/feature_iptv/lib/presentation/tv/iptv_tv_screen.dart
git commit -m "fix(feature_iptv): widen hero banner's left scrim so title text has a solid dark block behind it"
```

---

### Task 7: Widen the channel-rail heading gap (platform-wide)

`AiroRail` (the shared horizontal-rail component used by both the Home hero's rail and every future rail) has only 11px between its title and the card row. This is a `core_ui` platform component, so this fix applies everywhere `AiroRail` is used, not just this one screen.

**Files:**
- Modify: `packages/core_ui/lib/src/widgets/airo_rail.dart:37-42`

**Interfaces:**
- Consumes/produces: nothing new — `AiroRail`'s constructor and public fields are unchanged.

- [ ] **Step 1: Confirm current value**

Run: `grep -n "bottom: 11" packages/core_ui/lib/src/widgets/airo_rail.dart`
Expected: one match, inside the `Padding` that wraps the title/subtitle `Row`.

- [ ] **Step 2: Widen the header-to-cards gap**

Change:
```dart
          Padding(
            padding: EdgeInsets.only(
              left: padding.left,
              right: padding.right,
              bottom: 11,
            ),
```
to:
```dart
          Padding(
            padding: EdgeInsets.only(
              left: padding.left,
              right: padding.right,
              bottom: 16,
            ),
```

- [ ] **Step 3: Analyze**

Run: `cd packages/core_ui && flutter analyze lib/src/widgets/airo_rail.dart`
Expected: `No issues found!`

- [ ] **Step 4: Run core_ui and feature_iptv tests**

Run: `cd packages/core_ui && flutter test test/widgets/airo_rail_test.dart 2>&1 | tail -10`
Expected: pass (no pixel-position assertions in this test — confirmed during planning).

Run: `cd ../feature_iptv && flutter test test/iptv/presentation/tv/iptv_tv_screen_test.dart 2>&1 | tail -20`
Expected: all 9 tests pass (this screen's `_TvChannelRailsSection` and `_TvHeroRailsPanel` both use `AiroRail`, so this confirms no downstream overflow from the extra 5px).

- [ ] **Step 5: Commit**

```bash
git add packages/core_ui/lib/src/widgets/airo_rail.dart
git commit -m "fix(core_ui): widen AiroRail's title-to-cards gap from 11px to 16px"
```

---

### Task 8: Content-column vertical rhythm and scrollbar breathing room

Widens the gap between the toolbar (filter chips + grid/list toggle — already on one row, see note below) and the grid/list below it, and gives the grid/list's trailing edge room so the scrollbar thumb doesn't sit flush against the panel border.

**Note on scope:** the design feedback also asked to "move the grid/list toggle onto the same baseline as the filter chips." Checking `_TvChannelToolbar`'s current implementation: it's already a single `Row` with `_TvFilterChip`s on the left, a `Spacer()`, and the `_TvIconToggle`s on the right — they're already on one baseline. No change needed there; this task only touches the vertical gap before/after this toolbar and the grid's edge padding.

**Files:**
- Modify: `packages/feature_iptv/lib/presentation/tv/iptv_tv_screen.dart:322` (gap before toolbar in `_TvBrowseLayout`), `:1270-1299` (`_TvChannelGridViewState.build`), `:1340-1362` (`_TvChannelListViewState.build`)

**Interfaces:**
- Consumes/produces: nothing new.

- [ ] **Step 1: Confirm current values**

Run: `grep -n "compactTv ? 10 : 16\|padding: const EdgeInsets.all(16)" packages/feature_iptv/lib/presentation/tv/iptv_tv_screen.dart`
Expected: one match for the gap (in `_TvBrowseLayout`), two matches for `EdgeInsets.all(16)` (grid view and list view padding).

- [ ] **Step 2: Widen the toolbar-to-grid gap**

In `_TvBrowseLayout.build`, change:
```dart
                      SizedBox(height: compactTv ? 10 : 16),
```
(the one immediately after `_TvChannelToolbar(...)`, **not** the one after `_TvHeroRailsPanel`/`_TvPlayerPanel` earlier in the same method — confirm with the surrounding `_TvChannelToolbar(` call a few lines above it) to:
```dart
                      SizedBox(height: compactTv ? 16 : 20),
```

- [ ] **Step 3: Give the grid view breathing room on its trailing edge**

In `_TvChannelGridViewState.build`, change:
```dart
        padding: const EdgeInsets.all(16),
```
to:
```dart
        padding: const EdgeInsets.fromLTRB(16, 16, 24, 16),
```

- [ ] **Step 4: Give the list view the same treatment**

In `_TvChannelListViewState.build`, change:
```dart
        padding: const EdgeInsets.all(16),
```
to:
```dart
        padding: const EdgeInsets.fromLTRB(16, 16, 24, 16),
```

- [ ] **Step 5: Analyze**

Run: `cd packages/feature_iptv && flutter analyze lib/presentation/tv/iptv_tv_screen.dart`
Expected: `No issues found!` (ignore the pre-existing unused-import warning).

- [ ] **Step 6: Run the TV screen test**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/tv/iptv_tv_screen_test.dart 2>&1 | tail -20`
Expected: all 9 tests pass.

- [ ] **Step 7: Commit**

```bash
git add packages/feature_iptv/lib/presentation/tv/iptv_tv_screen.dart
git commit -m "fix(feature_iptv): widen toolbar-to-grid gap and give grid/list scrollbars edge breathing room"
```

---

### Task 9: Typography hierarchy for section headings

Gives "Live channels" and "Browse" distinct, larger weights so the page's hierarchy reads clearly, per the suggested scale (section headline ~32px/700, section label ~18px/600) — applied as direct style overrides on these two specific `Text` widgets, **not** by changing the shared `headlineMedium`/`titleLarge` theme styles (those are used by many other screens across the app; changing them globally is out of this plan's scope and would need its own audit).

**Files:**
- Modify: `packages/feature_iptv/lib/presentation/tv/iptv_tv_screen.dart` (the `Text('Live channels', ...)` in `_TvHeader.build`, and `Text('Browse', ...)` in `_TvCategoryRail.build`)

**Interfaces:**
- Consumes/produces: nothing new.

- [ ] **Step 1: Confirm current styles**

Run: `grep -n "Text('Live channels'\|Text('Browse'" packages/feature_iptv/lib/presentation/tv/iptv_tv_screen.dart`
Expected: `Text('Live channels', style: theme.textTheme.headlineMedium)` and `Text('Browse', style: theme.textTheme.titleLarge)`.

- [ ] **Step 2: Give "Live channels" an explicit 32px/700 style**

Change:
```dart
              Text('Live channels', style: theme.textTheme.headlineMedium),
```
to:
```dart
              Text(
                'Live channels',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                ),
              ),
```

- [ ] **Step 3: Give "Browse" an explicit 18px/600 style**

Change:
```dart
        Text('Browse', style: theme.textTheme.titleLarge),
```
to:
```dart
        Text(
          'Browse',
          style: theme.textTheme.titleLarge?.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
```

- [ ] **Step 4: Analyze**

Run: `cd packages/feature_iptv && flutter analyze lib/presentation/tv/iptv_tv_screen.dart`
Expected: `No issues found!` (ignore the pre-existing unused-import warning).

- [ ] **Step 5: Run the TV screen test**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/tv/iptv_tv_screen_test.dart 2>&1 | tail -20`
Expected: all 9 tests pass — `find.text('Live channels')` and `find.text('Browse')` match on text content, not style, so these assertions are unaffected.

- [ ] **Step 6: Commit**

```bash
git add packages/feature_iptv/lib/presentation/tv/iptv_tv_screen.dart
git commit -m "fix(feature_iptv): give Live Channels and Browse headings distinct type weights"
```

---

### Task 10: Full-suite regression pass and macOS visual verification

Runs every test suite touched by this plan one more time in combination (not just per-task in isolation), then launches the real macOS build to eyeball the cumulative effect — catching anything that only shows up when all nine tasks' changes are stacked together.

**Files:** none (verification only).

- [ ] **Step 1: Run the full core_ui suite**

Run: `cd packages/core_ui && flutter test 2>&1 | tail -15`
Expected: `All tests passed!`

- [ ] **Step 2: Run the full feature_iptv suite**

Run: `cd packages/feature_iptv && flutter test 2>&1 | tail -20`
Expected: `All tests passed!` (this is the full ~213-test suite, not just the one TV screen test file — confirms nothing else in the package regressed).

- [ ] **Step 3: Run the app package's core/app tests**

Run: `cd app && flutter test test/core/app/ 2>&1 | tail -20`
Expected: `All tests passed!`

- [ ] **Step 4: Launch the macOS build**

```bash
cd app
nohup flutter run -d macos -t lib/main_tv.dart --dart-define=APP_VARIANT=tv --dart-define=APP_PLATFORM=androidTv > /tmp/airo_tv_p0_verify.log 2>&1 &
disown
```
Wait for `✓ Built build/macos/Build/Products/Debug/Airo TV.app` to appear in the log (poll with `tail -5 /tmp/airo_tv_p0_verify.log`), typically 60-120 seconds.

- [ ] **Step 5: Activate, resize, and screenshot the window**

```bash
osascript -e 'tell application "Airo TV" to activate'
sleep 1.5
osascript -e '
tell application "System Events"
  tell process "Airo TV"
    set position of window 1 to {0, 30}
    set size of window 1 to {1440, 870}
  end tell
end tell
'
sleep 1
screencapture -x -R0,30,1440,870 /tmp/airo_tv_p0_verify.png
```

- [ ] **Step 6: Visually check against this plan's targets**

Open `/tmp/airo_tv_p0_verify.png` and confirm:
- Sidebar: clear, even gap between logo and "Home"; nav items no longer feel cramped together.
- Header: title/subtitle/description on one line, capability chips on a clean full-width row below a divider, nothing wrapping awkwardly.
- "Live channels" heading is visibly bolder/larger than the subtitle beneath it.
- "Browse" heading has clear air before the category tiles; tile numbers align under their titles with comfortable padding.
- Hero banner's left side is a solid dark block, not a thin fade — title text is clearly legible against it.
- Toolbar (filter chips + grid/list toggle) still reads as one row, with more breathing room around the grid below it.
- Grid's right edge (and its scrollbar) no longer touches the panel's border.

- [ ] **Step 7: Clean up the running app**

```bash
pkill -9 -f "Airo TV"
pkill -9 -f "flutter run.*main_tv"
```

No commit for this task — it's verification only. If Step 6 reveals anything off, go back to the relevant task above, fix it, and re-run that task's own test step before returning here.

---

## Self-Review Notes

- **Spec coverage:** items 1 (sidebar), 3 (toolbar spacing), 4 (Live Channels heading), 5 (Browse heading gap), 6 (category tile padding/alignment — already left-aligned in code, padding bump covers the "looks lower than expected" complaint), 7 (hero scrim width), 8 (carousel heading gap), 11 (grid top padding), 12 (right-edge scrollbar gutter), 14 (typography hierarchy), 15 (8-point spacing system) are all covered by Tasks 1-9. Item 2 (header restructure) is covered by Task 3, adapted to the header's actual data-driven nature (see that task's note — "Diagnostics" isn't a hardcoded nav item, it's one entry in a profile-driven list, so it can't be literally "moved to Settings" without breaking the generic manifest-driven design; the layout restructure achieves the same visual goal). Item 9 (filter chips floating, disconnected from grid/list toggle) turned out to already be correct in the current code — see Task 8's note; only the vertical gap around that row needed widening. Item 10 (grid/list toggle onto the filter baseline) — same, already true. Item 13 (single left-edge across Live Channels/Browse/Hero/Carousel/Grid) does **not** apply as literally stated: the current layout is a two-column split (a fixed-width category-rail sidebar next to an `Expanded` hero/toolbar/grid column), not a single stacked column, so those two groups have two different — but each internally consistent — left edges by design. Collapsing them to one shared edge would mean removing the category-rail-as-sidebar structure, which is a P1 structural change, not a P0 spacing fix; flagged as out of scope for this plan.
- **Placeholder scan:** every step has literal before/after code, exact file paths, and exact shell commands with expected output. No TBDs.
- **Type/value consistency:** all spacing values across tasks are 8-point-grid-clean (8, 12, 16, 20, 24, 28, 32) except where explicitly justified (Task 5's 20-vs-24 tradeoff, Task 6's gradient stops). `AppSpacing` constant names introduced in Task 1 (`xxs`/`xs`/`sm`/`md`/`lg`/`xl`/`xxl`) are not referenced by name in Tasks 2-9 — those tasks use raw literals consistent with this codebase's existing convention in `iptv_tv_screen.dart` and `tv_shell.dart` (verified during planning: neither file references `AppSpacing` today).
