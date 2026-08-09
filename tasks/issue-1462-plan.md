# Plan: #1462 — Foldable crease rule in RESPONSIVE_STANDARDS

## Context
Greenfield: no `MediaQuery.displayFeatures`/`DisplayFeature` usage anywhere in the
repo. `ResponsiveBreakpoints`/`AdaptiveLayout` are pure width-based and actually
live in `app/lib/shared/widgets/responsive_center.dart:41-210` — the doc's claim
that they live in `core_ui` is stale. Player layout decisions
(`video_player_widget.dart:_usesCompactInlinePlayer`,
`iptv_tv_screen.dart` compactTv/denseTv) key off `MediaQuery.sizeOf(context)`
only.

## Dependency graph
```
1. FoldPosture helper (responsive_center.dart)
        │
        ├──> 2. Widget test for helper (independent of consumer)
        │
        └──> 3. Wire into video_player_widget._usesCompactInlinePlayer
                    │
                    └──> 4. Widget test: player avoids straddling hinge
5. Docs section + stale-reference fix (independent, can run parallel to 1-4)
```
Vertical slices: task 1+2 is one complete path (helper, proven in isolation).
Task 3+4 is the second complete path (consumer, proven against the helper).
Task 5 stands alone.

## Tasks

### Task 1 — FoldPosture helper
**File:** `app/lib/shared/widgets/responsive_center.dart`
Add:
- `enum FoldPosture { none, halfOpened, tabletop }`
- `class FoldInfo { final FoldPosture posture; final Rect? hingeBounds; }`
- `FoldInfo AiroFold.of(BuildContext context)` (or static method on
  `ResponsiveBreakpoints` to match existing static-helper convention) —
  reads `MediaQuery.of(context).displayFeatures`, filters for
  `DisplayFeatureType.hinge`/`fold`, maps `DisplayFeatureState.postureFlat`
  → `none`, `postureHalfOpened` → `halfOpened`; a fold with `bounds.width ==
  0` treated as `tabletop` (vertical hinge) vs horizontal — keep the mapping
  simple, only what's needed by task 3.
- `bool AiroFold.straddles(Rect contentBounds, FoldInfo fold)` — true if
  `fold.hingeBounds` intersects `contentBounds` with nonzero overlap on both
  sides.

**Acceptance:** compiles, exported alongside `ResponsiveBreakpoints` (no new
public export surface beyond this file — it's already imported directly by
consumers per existing pattern).

### Task 2 — Helper widget test
**File:** `app/test/shared/widgets/responsive_center_fold_test.dart` (new)
Cases:
- No `displayFeatures` → `FoldPosture.none`, `hingeBounds == null`.
- Simulated hinge `DisplayFeature` at screen center with
  `state: DisplayFeatureState.postureHalfOpened` → `FoldPosture.halfOpened`,
  `straddles()` true for a full-width content rect, false for a rect
  confined to one side of the hinge.

**Acceptance:** `flutter test app/test/shared/widgets/responsive_center_fold_test.dart` green.

### Task 3 — Wire into `_usesCompactInlinePlayer`
**File:** `packages/feature_iptv/lib/presentation/widgets/video_player_widget.dart:2253-2255`
Change signature logic: also force compact layout when the fold straddles
the player's candidate bounds (use `MediaQuery.sizeOf(context)` full rect at
origin as the candidate, since actual render bounds aren't known pre-layout —
document this as an approximation in a one-line comment).

```dart
bool _usesCompactInlinePlayer(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  if (!_isFullscreen && size.shortestSide < 600) return true;
  final fold = AiroFold.of(context);
  if (fold.posture != FoldPosture.none &&
      AiroFold.straddles(Offset.zero & size, fold)) {
    return true;
  }
  return false;
}
```

**Acceptance:** existing compact-player tests still pass; behavior unchanged
when no fold is present (default `MediaQueryData.displayFeatures` is empty in
all existing tests, so no test churn expected).

### Task 4 — Consumer widget test
**File:** `packages/feature_iptv/test/presentation/widgets/video_player_widget_fold_test.dart` (new)
Pump `VideoPlayerWidget` at a fullscreen-capable width (e.g. 900px, would
normally NOT be compact) wrapped in `MediaQuery` with a simulated hinge
`DisplayFeature` straddling center. Assert the widget renders in its compact
layout path (reuse whatever observable signal `_usesCompactInlinePlayer`
already drives — check existing compact-layout tests for the assertion
pattern before inventing a new one).

**Acceptance:** test passes; without the task-3 change it must fail (write
test first per TDD, confirm red, then apply task 3, confirm green).

### Task 5 — Docs
**File:** `docs/ui/RESPONSIVE_STANDARDS.md`
- Fix stale reference: `ResponsiveBreakpoints`/`AdaptiveLayout` live in
  `app/lib/shared/widgets/responsive_center.dart`, not `core_ui` — one-line
  correction near the top, not a rewrite.
- New section "Foldable / crease rule": one paragraph rule (never let
  primary content — video, forms, grids — straddle a hinge in `halfOpened`
  posture; prefer single-pane/compact layout on that side) + the
  `AiroFold.of` / `straddles` snippet from task 1.

**Acceptance:** doc reads correctly, code snippet matches actual API from
task 1 (no copy-paste drift).

## Checkpoints
- After task 1+2: helper is proven correct in isolation before touching the
  consumer — stop and run `flutter test` for task 2 alone.
- After task 3+4: run full `feature_iptv` test suite (not just the new file)
  to catch any regression in existing compact-layout tests.
- After task 5: `flutter analyze` on all touched files, then commit.

## Explicitly out of scope
- `iptv_tv_screen.dart` compactTv/denseTv (TV never folds — no value here).
- Any other RESPONSIVE_STANDARDS.md section.
- New pub dependency — `displayFeatures` is core Flutter (`dart:ui`
  `DisplayFeature`, exposed via `MediaQueryData`), no package needed.
