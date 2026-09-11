# Airo TV Player — Premium UX Revamp Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the 4 core phases of the TV player revamp — MultiView replace/remove flow, channel grid compaction + "not for me" preference, player chrome cleanup, and a phone-only bottom nav — as a merge-ready PR against `main`. The 2 optional extras (drag-to-reorder favorites, jump-back-in rail) and item 4 (unreproduced bug) are explicitly out of scope for this plan.

**Architecture:** All changes live in `packages/feature_iptv` (presentation + application layers), `packages/platform_favorites` (one widened storage class), and `packages/platform_player` is read-only (no changes needed — `AiroMultiviewPool.add()`'s existing capacity check already supports the remove-then-add sequencing Phase A needs). No new packages, no new native/FFI surface, no server calls. Just-in-time extraction: new UI pieces get their own widget files as they're built; `airo_tv_shell.dart` is edited in place, not rewritten wholesale.

**Tech Stack:** Flutter/Riverpod (`StateNotifierProvider`, plain `Provider`), `shared_preferences` via `core_data`'s `KeyValueStore`/`PreferencesStore`, existing `TvFocusable`/`MediaCard`/`AiroBadge` design-system widgets.

**Spec:** `docs/superpowers/specs/2026-09-11-tv-player-premium-revamp-design.md` (CEO + Eng + Design reviewed, all CLEARED — see its `GSTACK REVIEW REPORT` section, including a post-review correction on Phase D).

## Global constraints

- Branch from `origin/main`: `agent/iptv/tv-player-premium-revamp` (or your own naming — match repo convention `agent/<name>/<short-desc>`).
- Conventional commits, e.g. `feat(iptv): add MultiView replace-slot flow`.
- No new attack surface — everything here is local `SharedPreferences` state and existing IPTV playback. No new dependencies.
- `FavoriteChannelsStorage` keeps its class name (widened in place, not renamed) — it's referenced as a concrete type at 2+ sites beyond the provider layer.
- `MultiviewController.replace()` is remove-then-add, **not** a true atomic swap — matches the pool's real capacity-check ordering (verified in `airo_multiview_pool.dart`). Do not add locking/guard code for the toggle race — matches the existing `toggleFavorite` consistency model, which has never needed one.
- Favorite/not-for-me mutual exclusion is enforced **inside** `FavoriteChannelsStorage`'s `setFavorite`/`setNotForMe`, not in any widget's `onTap` — every call site (existing and new) inherits it for free.
- `AdaptiveNavigation` does **not** exist in this repo (verified by grep — zero matches). Phase D's bottom bar is new, bespoke code. `AdaptiveBottomSheet` (`app/lib/shared/widgets/adaptive_dialog.dart`) is real and is reused for "My Aika."
- No new palette — reuse `#020419` panel background, `Colors.black.withValues(alpha: 0.56/0.68)` scrims, `AiroBadge`/`AiroSpacing` tokens, exactly as used elsewhere in these files today.
- Prove each task with the narrowest local test run (`flutter test <specific file>` inside the owning package), not a full CI matrix. Run `flutter analyze` on any package you touch before considering a task done.
- No `dart:isolate`/`compute()` needed anywhere in this plan — nothing here parses >50KB of data.

## File map

```
packages/platform_favorites/lib/src/favorite_channels_storage.dart          [widen]
packages/platform_favorites/test/favorite_channels_storage_test.dart        [extend]
packages/feature_iptv/lib/application/providers/iptv_providers.dart         [modify: notForMe providers]
packages/feature_iptv/lib/application/providers/multiview_provider.dart     [modify: add replace()]
packages/feature_iptv/test/application/multiview_provider_test.dart         [extend]
packages/feature_iptv/lib/application/providers/channel_filters_provider.dart [modify: partition + cache key]
packages/feature_iptv/test/iptv/application/providers/channel_filters_provider_test.dart [extend]
packages/feature_iptv/lib/application/providers/control_row_visibility_provider.dart [modify: drop .channel]
packages/feature_iptv/lib/presentation/tv_ux/sections/multiview_stage.dart  [modify: dismiss control, tappable empty slot]
packages/feature_iptv/test/iptv/presentation/tv_ux/multiview_stage_test.dart [extend]
packages/feature_iptv/lib/presentation/tv_ux/sections/multiview_actions.dart [new: replace dialog + picker sheet]
packages/feature_iptv/test/iptv/presentation/tv_ux/multiview_actions_test.dart [new]
packages/feature_iptv/lib/presentation/tv_ux/sections/channel_library_grid.dart [modify: remove plus button, shrink card, not-for-me row]
packages/feature_iptv/test/iptv/presentation/tv_ux/channel_library_grid_test.dart [extend]
packages/feature_iptv/lib/presentation/tv_ux/sections/channel_name_overlay.dart [new]
packages/feature_iptv/test/iptv/presentation/tv_ux/channel_name_overlay_test.dart [new]
packages/feature_iptv/lib/presentation/tv_ux/tv_loading_screen.dart         [modify: logo + zoom-out]
packages/feature_iptv/test/iptv/presentation/tv_ux/tv_loading_screen_test.dart [new]
packages/feature_iptv/lib/presentation/tv_ux/sections/shell_settings_dialog.dart [modify: drop Channel row, add Playlist/Guide rows]
packages/feature_iptv/test/iptv/presentation/tv_ux/shell_settings_dialog_test.dart [extend]
packages/feature_iptv/lib/presentation/tv_ux/airo_tv_shell.dart             [modify: wire everything above]
packages/feature_iptv/test/iptv/presentation/tv_ux/airo_tv_shell_test.dart  [extend]
packages/feature_iptv/lib/presentation/tv_ux/sections/bottom_nav_bar.dart   [new]
packages/feature_iptv/test/iptv/presentation/tv_ux/bottom_nav_bar_test.dart [new]
packages/feature_iptv/lib/presentation/screens/iptv_screen.dart             [modify: drop drawer/AppBar row, mount bottom nav]
packages/feature_iptv/test/iptv/presentation/screens/iptv_screen_test.dart  [extend]
packages/feature_iptv/lib/presentation/widgets/iptv_navigation_drawer.dart  [delete, once confirmed unused]
```

---

### Task 1: Widen `FavoriteChannelsStorage` (not-for-me + ordered favorites + mutual exclusion)

**Files:**
- Modify: `packages/platform_favorites/lib/src/favorite_channels_storage.dart`
- Test: `packages/platform_favorites/test/favorite_channels_storage_test.dart`

**Interfaces:**
- Produces: `FavoriteChannelsStorage.getFavoriteChannelIds() → Future<List<String>>` (return type changes from `Set<String>` to ordered `List<String>` — callers using `.contains()` still work; callers relying on `Set` semantics are fixed in Task 2), `getNotForMeChannelIds() → Future<Set<String>>`, `setFavorite(String id) → Future<void>`, `setNotForMe(String id) → Future<void>`, `clearPreference(String id) → Future<void>`, `isFavorite(String id) → Future<bool>` (unchanged signature), `isNotForMe(String id) → Future<bool>` (new).

Read `packages/platform_favorites/lib/src/hidden_groups_storage.dart` first — mirror its exact style (constructor shape, `_save` helper pattern).

- [ ] **Step 1: Write the failing tests**

```dart
// Add to favorite_channels_storage_test.dart, alongside existing tests.
test('setFavorite clears an existing not-for-me flag on the same channel', () async {
  final storage = FavoriteChannelsStorage(await sharedPrefsInstance()); // match existing test setup helper
  await storage.setNotForMe('ch1');
  expect(await storage.isNotForMe('ch1'), isTrue);

  await storage.setFavorite('ch1');

  expect(await storage.isFavorite('ch1'), isTrue);
  expect(await storage.isNotForMe('ch1'), isFalse);
});

test('setNotForMe clears an existing favorite flag on the same channel', () async {
  final storage = FavoriteChannelsStorage(await sharedPrefsInstance());
  await storage.setFavorite('ch1');

  await storage.setNotForMe('ch1');

  expect(await storage.isNotForMe('ch1'), isTrue);
  expect(await storage.isFavorite('ch1'), isFalse);
});

test('getFavoriteChannelIds preserves insertion order', () async {
  final storage = FavoriteChannelsStorage(await sharedPrefsInstance());
  await storage.setFavorite('ch3');
  await storage.setFavorite('ch1');
  await storage.setFavorite('ch2');

  expect(await storage.getFavoriteChannelIds(), ['ch3', 'ch1', 'ch2']);
});

test('setFavorite is a no-op dedup when the channel is already favorited', () async {
  final storage = FavoriteChannelsStorage(await sharedPrefsInstance());
  await storage.setFavorite('ch1');
  await storage.setFavorite('ch1');

  expect(await storage.getFavoriteChannelIds(), ['ch1']);
});

test('replaceAll preserves the order of the provided iterable', () async {
  final storage = FavoriteChannelsStorage(await sharedPrefsInstance());
  await storage.replaceAll(['chB', 'chA', 'chC']);

  expect(await storage.getFavoriteChannelIds(), ['chB', 'chA', 'chC']);
});
```

Check the existing test file for its actual `SharedPreferences` setup helper (likely `SharedPreferences.setMockInitialValues({})` then `await SharedPreferences.getInstance()`) and match it — don't invent a new helper.

- [ ] **Step 2: Run tests, verify they fail**

Run: `cd packages/platform_favorites && flutter test test/favorite_channels_storage_test.dart`
Expected: FAIL — `setNotForMe`/`isNotForMe`/`setFavorite` (new signature) don't exist yet, `getFavoriteChannelIds` still returns `Set<String>`.

- [ ] **Step 3: Rewrite the class**

```dart
import 'package:core_data/core_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Storage for a user's favorited and "not for me" IPTV channel ids.
///
/// Local-only, matching the roadmap policy of no cloud sync for favorites.
/// Favorite and not-for-me are mutually exclusive by construction: setting
/// one always clears the other, enforced here (not by callers) so every
/// call site — the settings sheet, the LIVE bar's toggle, any future one —
/// inherits the invariant automatically.
class FavoriteChannelsStorage {
  static const String _favoritesKey = 'iptv_favorite_channel_ids';
  static const String _notForMeKey = 'iptv_not_for_me_channel_ids';

  final KeyValueStore _store;

  FavoriteChannelsStorage(
    SharedPreferences prefs, {
    KeyValueStore? store,
    int maxPreferenceValueBytes = kKeyValueStorePreferenceMaxValueBytes,
  }) : _store =
           store ??
           PreferencesStore(prefs, maxValueBytes: maxPreferenceValueBytes);

  /// Favorited channel ids, in the user's chosen order (append-on-favorite
  /// by default; a future manual-reorder feature can persist a new order
  /// through the same key without a format change).
  Future<List<String>> getFavoriteChannelIds() async {
    return await _store.getStringList(_favoritesKey) ?? const <String>[];
  }

  /// "Not for me" channel ids, in no particular order.
  Future<Set<String>> getNotForMeChannelIds() async {
    final ids = await _store.getStringList(_notForMeKey);
    return ids?.toSet() ?? <String>{};
  }

  Future<bool> isFavorite(String channelId) async {
    return (await getFavoriteChannelIds()).contains(channelId);
  }

  Future<bool> isNotForMe(String channelId) async {
    return (await getNotForMeChannelIds()).contains(channelId);
  }

  /// Favorite [channelId], clearing any existing not-for-me flag. No-op
  /// (beyond the exclusion clear) if already favorited.
  Future<void> setFavorite(String channelId) async {
    final favorites = await getFavoriteChannelIds();
    final notForMe = await getNotForMeChannelIds();
    final favoritesChanged = !favorites.contains(channelId);
    final notForMeChanged = notForMe.remove(channelId);
    if (favoritesChanged) favorites.add(channelId);
    if (favoritesChanged || notForMeChanged) {
      await Future.wait([
        if (favoritesChanged) _saveFavorites(favorites),
        if (notForMeChanged) _saveNotForMe(notForMe),
      ]);
    }
  }

  /// Marks [channelId] as not for me, clearing any existing favorite flag.
  Future<void> setNotForMe(String channelId) async {
    final favorites = await getFavoriteChannelIds();
    final notForMe = await getNotForMeChannelIds();
    final favoritesChanged = favorites.remove(channelId);
    final notForMeChanged = notForMe.add(channelId);
    if (favoritesChanged || notForMeChanged) {
      await Future.wait([
        if (favoritesChanged) _saveFavorites(favorites),
        if (notForMeChanged) _saveNotForMe(notForMe),
      ]);
    }
  }

  /// Clears both flags for [channelId]. No-op if neither was set.
  Future<void> clearPreference(String channelId) async {
    final favorites = await getFavoriteChannelIds();
    final notForMe = await getNotForMeChannelIds();
    final favoritesChanged = favorites.remove(channelId);
    final notForMeChanged = notForMe.remove(channelId);
    await Future.wait([
      if (favoritesChanged) _saveFavorites(favorites),
      if (notForMeChanged) _saveNotForMe(notForMe),
    ]);
  }

  /// Toggle [channelId]'s favorite state (clearing not-for-me if setting).
  /// Returns the new favorite state. Kept for existing call sites.
  Future<bool> toggleFavorite(String channelId) async {
    final isNowFavorite = !await isFavorite(channelId);
    if (isNowFavorite) {
      await setFavorite(channelId);
    } else {
      await clearPreference(channelId);
    }
    return isNowFavorite;
  }

  /// Replaces the complete favorite list for an import/restore operation,
  /// preserving the given order. Does not touch not-for-me state.
  Future<void> replaceAll(Iterable<String> channelIds) {
    final normalized = <String>[];
    final seen = <String>{};
    for (final id in channelIds) {
      final trimmed = id.trim();
      if (trimmed.isEmpty || !seen.add(trimmed)) continue;
      normalized.add(trimmed);
    }
    return _saveFavorites(normalized);
  }

  Future<void> _saveFavorites(List<String> ids) {
    return _store.setStringList(_favoritesKey, ids);
  }

  Future<void> _saveNotForMe(Set<String> ids) {
    return _store.setStringList(_notForMeKey, ids.toList(growable: false));
  }
}
```

- [ ] **Step 4: Run tests, verify they pass**

Run: `cd packages/platform_favorites && flutter test test/favorite_channels_storage_test.dart`
Expected: PASS, including every pre-existing test in the file (re-run the whole file, not just the new tests — `toggleFavorite`'s behavior changed subtly: it now routes through `setFavorite`/`clearPreference` instead of a raw `Set.add`/`remove`, verify no existing test asserted `Set` return-type behavior that no longer compiles).

- [ ] **Step 5: `flutter analyze`**

Run: `cd packages/platform_favorites && flutter analyze`
Expected: no new errors/warnings.

- [ ] **Step 6: Commit**

```bash
git add packages/platform_favorites/lib/src/favorite_channels_storage.dart packages/platform_favorites/test/favorite_channels_storage_test.dart
git commit -m "feat(favorites): widen FavoriteChannelsStorage with not-for-me + ordering"
```

---

### Task 2: Fix `FavoriteChannelsStorage` call sites for the `List` return type

**Files:**
- Modify (check each, fix only what fails to compile/type-check): `packages/feature_iptv/lib/application/providers/iptv_providers.dart`, `packages/feature_iptv/lib/presentation/tv_ux/airo_tv_shell.dart`, `packages/feature_iptv/lib/application/iptv_backup_state_store.dart`, any other call site `grep` finds.

**Interfaces:**
- Consumes: `FavoriteChannelsStorage` from Task 1.

- [ ] **Step 1: Find every call site**

```bash
grep -rln "FavoriteChannelsStorage\|favoriteChannelIdsProvider\|getFavoriteChannelIds" packages --include="*.dart" | grep -v /test/
```

This is the authoritative list — do not trust any enumeration in the spec, it's already been caught out of date twice. Read each hit.

- [ ] **Step 2: Fix each site**

Most sites only ever called `.contains()` on the result, which works identically on `List` — no change needed. Fix only sites that:
- Declared a `Set<String>` typed variable/field for the result (change to `List<String>`, or better, `Iterable<String>` if only iterated/checked).
- Did `Set`-specific operations (`.difference()`, `.intersection()`, `.union()`) — convert to `.toSet()` first, or rewrite using `List`/`Iterable` equivalents (`.where()`, etc.).
- `favoriteChannelIdsProvider` in `iptv_providers.dart` — update its declared type from `Provider<Set<String>>` (or whatever it currently is per `getFavoriteChannelIds`'s old signature) to match the new `List<String>` return.

- [ ] **Step 3: Add the new not-for-me providers to `iptv_providers.dart`**

Find where `favoriteChannelIdsProvider`/`isChannelFavoriteProvider`/`channelFavoriteTogglerProvider` are defined (around lines 950-997 per the spec's Investigation Notes) and add alongside them:

```dart
final notForMeChannelIdsProvider = FutureProvider<Set<String>>((ref) async {
  final storage = ref.watch(favoriteChannelsStorageProvider);
  return storage.getNotForMeChannelIds();
});

final isChannelNotForMeProvider = Provider.family<bool, String>((ref, channelId) {
  final notForMe = ref.watch(notForMeChannelIdsProvider).value ?? const <String>{};
  return notForMe.contains(channelId);
});

final channelNotForMeTogglerProvider = Provider<Future<void> Function(String)>((ref) {
  final storage = ref.watch(favoriteChannelsStorageProvider);
  return (channelId) async {
    if (await storage.isNotForMe(channelId)) {
      await storage.clearPreference(channelId);
    } else {
      await storage.setNotForMe(channelId);
    }
    ref.invalidate(notForMeChannelIdsProvider);
    ref.invalidate(favoriteChannelIdsProvider);
  };
});
```

Check the exact existing pattern `favoriteChannelIdsProvider`/`channelFavoriteTogglerProvider` use for invalidation (do they `ref.invalidate` after a toggle, or does `FutureProvider` auto-refresh via `ref.watch(favoriteChannelsStorageProvider)`'s own invalidation?) and match it exactly — don't invent a different refresh mechanism for the new providers.

- [ ] **Step 4: Run the full feature_iptv analyzer**

Run: `cd packages/feature_iptv && flutter analyze`
Expected: zero errors. This is the real verification for this task (it's a type-fixup task, not new behavior) — every call site must compile clean.

- [ ] **Step 5: Run existing tests to catch behavioral regressions**

Run: `cd packages/feature_iptv && flutter test test/favorite_reimport_coordinator_test.dart test/favorite_reimport_provider_test.dart test/iptv/presentation/tv/tv_favorites_screen_test.dart test/iptv/presentation/screens/mobile_favorites_screen_test.dart test/iptv/presentation/widgets/favorite_reimport_review_banner_test.dart`
Expected: PASS. These are exactly the sites the eng review flagged as needing the mutual-exclusion regression coverage (Task 3 adds the dedicated regression test; this step just confirms nothing here already broke).

- [ ] **Step 6: Commit**

```bash
git add -A  # review `git status` first — this task touches an open-ended set of files
git commit -m "fix(iptv): update FavoriteChannelsStorage call sites for List return type"
```

---

### Task 3: Provider-level regression test for favorite/not-for-me exclusivity

**Files:**
- Test: `packages/feature_iptv/test/application/iptv_providers_test.dart` (create if it doesn't exist — check first)

**Interfaces:**
- Consumes: `channelFavoriteTogglerProvider`, `channelNotForMeTogglerProvider` from Task 2.

This is the single test the eng review called mandatory (IRON RULE regression) — it covers every existing and future call site by testing the shared provider layer directly, not any one screen.

- [ ] **Step 1: Write the test**

```dart
testWidgets('favoriting a channel clears an existing not-for-me flag, at the provider level', (tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs), // match the real provider name
  ]);
  addTearDown(container.dispose);

  final storage = container.read(favoriteChannelsStorageProvider);
  await storage.setNotForMe('ch1');
  expect(await storage.isNotForMe('ch1'), isTrue);

  final favoriteToggler = container.read(channelFavoriteTogglerProvider);
  await favoriteToggler('ch1');

  expect(await storage.isFavorite('ch1'), isTrue);
  expect(await storage.isNotForMe('ch1'), isFalse);
});

testWidgets('marking not-for-me clears an existing favorite, at the provider level', (tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
  ]);
  addTearDown(container.dispose);

  final storage = container.read(favoriteChannelsStorageProvider);
  await storage.setFavorite('ch1');

  final notForMeToggler = container.read(channelNotForMeTogglerProvider);
  await notForMeToggler('ch1');

  expect(await storage.isNotForMe('ch1'), isTrue);
  expect(await storage.isFavorite('ch1'), isFalse);
});
```

Check `iptv_providers.dart` for the exact name of the SharedPreferences provider override point (`sharedPreferencesProvider` per `control_row_visibility_provider.dart`'s import) and `favoriteChannelsStorageProvider`'s exact provider type before writing the override — copy the pattern from an existing provider test in this package rather than guessing.

- [ ] **Step 2: Run and verify pass**

Run: `cd packages/feature_iptv && flutter test test/application/iptv_providers_test.dart`
Expected: PASS (this exercises Task 1 + Task 2's code, already correct if those tasks are done — this step is about locking the regression in, not discovering new bugs).

- [ ] **Step 3: Commit**

```bash
git add packages/feature_iptv/test/application/iptv_providers_test.dart
git commit -m "test(iptv): lock favorite/not-for-me exclusivity at the provider layer"
```

---

### Task 4: `ChannelBrowserSnapshotCache` 3-way partition + cache invalidation

**Files:**
- Modify: `packages/feature_iptv/lib/application/providers/channel_filters_provider.dart`
- Test: `packages/feature_iptv/test/iptv/application/providers/channel_filters_provider_test.dart`

**Interfaces:**
- Consumes: `FavoriteChannelsStorage.getFavoriteChannelIds() → Future<List<String>>`, `getNotForMeChannelIds() → Future<Set<String>>` (Task 1).
- Produces: `ChannelBrowserSnapshotCache.resolve()` gains two new required named params: `favoriteIds` (`List<String>`), `notForMeIds` (`Set<String>`).

- [ ] **Step 1: Write the failing tests**

```dart
test('resolve stable-partitions favorites first, not-for-me last, regardless of sort column', () {
  final cache = ChannelBrowserSnapshotCache();
  final channels = [chan('a'), chan('b'), chan('c'), chan('d')]; // existing test helper
  for (final column in ChannelSortColumn.values) {
    final snapshot = cache.resolve(
      channels: channels,
      metadataByChannelId: const {},
      filters: const ChannelFilters(),
      sort: ChannelSort(column: column),
      favoriteIds: const ['c'],
      notForMeIds: const {'a'},
    );
    final order = snapshot.visibleChannels.map((c) => c.id).toList();
    expect(order.first, 'c', reason: 'favorite must lead for sort column $column');
    expect(order.last, 'a', reason: 'not-for-me must trail for sort column $column');
  }
});

test('resolve returns a fresh snapshot when favoriteIds changes, even if filters/sort are unchanged', () {
  final cache = ChannelBrowserSnapshotCache();
  final channels = [chan('a'), chan('b')];
  const filters = ChannelFilters();
  const sort = ChannelSort();

  final first = cache.resolve(
    channels: channels, metadataByChannelId: const {}, filters: filters, sort: sort,
    favoriteIds: const [], notForMeIds: const {},
  );
  final second = cache.resolve(
    channels: channels, metadataByChannelId: const {}, filters: filters, sort: sort,
    favoriteIds: const ['b'], notForMeIds: const {},
  );

  expect(identical(first, second), isFalse);
  expect(second.visibleChannels.first.id, 'b');
});

test('resolve reuses the cached snapshot when favoriteIds/notForMeIds are unchanged', () {
  final cache = ChannelBrowserSnapshotCache();
  final channels = [chan('a'), chan('b')];
  const filters = ChannelFilters();
  const sort = ChannelSort();
  final ids = ['a']; // same list instance reused below

  final first = cache.resolve(
    channels: channels, metadataByChannelId: const {}, filters: filters, sort: sort,
    favoriteIds: ids, notForMeIds: const {},
  );
  final second = cache.resolve(
    channels: channels, metadataByChannelId: const {}, filters: filters, sort: sort,
    favoriteIds: ids, notForMeIds: const {},
  );

  expect(identical(first, second), isTrue);
});
```

Check the top of the existing test file for a `chan(String id)` helper or equivalent channel-builder — reuse it, don't build `IPTVChannel` inline.

- [ ] **Step 2: Run, verify failure**

Run: `cd packages/feature_iptv && flutter test test/iptv/application/providers/channel_filters_provider_test.dart`
Expected: FAIL — `resolve()` doesn't accept `favoriteIds`/`notForMeIds` yet.

- [ ] **Step 3: Implement**

```dart
class ChannelBrowserSnapshotCache {
  Iterable<IPTVChannel>? _channels;
  Map<String, ChannelBrowseMetadata>? _metadataByChannelId;
  ChannelFilters? _filters;
  ChannelSort? _sort;
  List<String>? _favoriteIds;
  Set<String>? _notForMeIds;
  ChannelBrowserSnapshot? _snapshot;

  ChannelBrowserSnapshot resolve({
    required Iterable<IPTVChannel> channels,
    required Map<String, ChannelBrowseMetadata> metadataByChannelId,
    required ChannelFilters filters,
    required ChannelSort sort,
    required List<String> favoriteIds,
    required Set<String> notForMeIds,
  }) {
    final previous = _snapshot;
    if (previous != null &&
        identical(_channels, channels) &&
        identical(_metadataByChannelId, metadataByChannelId) &&
        _filters == filters &&
        _sort == sort &&
        identical(_favoriteIds, favoriteIds) &&
        identical(_notForMeIds, notForMeIds)) {
      return previous;
    }

    final dimensions = channelFilterDimensions(
      channels: channels,
      metadataByChannelId: metadataByChannelId,
      country: filters.country,
    );
    final sorted = sortChannels(
      channels: applyChannelFilters(
        channels: channels,
        filters: filters,
        metadataByChannelId: metadataByChannelId,
      ),
      metadataByChannelId: metadataByChannelId,
      sort: sort,
    );
    final visibleChannels = _partitionByPreference(
      sorted,
      favoriteIds: favoriteIds.toSet(), // O(1) membership for the partition below
      notForMeIds: notForMeIds,
    );
    final next = ChannelBrowserSnapshot(
      dimensions: dimensions,
      visibleChannels: visibleChannels,
    );

    _channels = channels;
    _metadataByChannelId = metadataByChannelId;
    _filters = filters;
    _sort = sort;
    _favoriteIds = favoriteIds;
    _notForMeIds = notForMeIds;
    _snapshot = next;
    return next;
  }

  void clear() {
    _channels = null;
    _metadataByChannelId = null;
    _filters = null;
    _sort = null;
    _favoriteIds = null;
    _notForMeIds = null;
    _snapshot = null;
  }
}

/// Stable three-way partition: favorites first, normal middle, not-for-me
/// last — internal order within each group is whatever [sorted] already
/// has (the active sort column), untouched.
List<IPTVChannel> _partitionByPreference(
  List<IPTVChannel> sorted, {
  required Set<String> favoriteIds,
  required Set<String> notForMeIds,
}) {
  final favorites = <IPTVChannel>[];
  final normal = <IPTVChannel>[];
  final notForMe = <IPTVChannel>[];
  for (final channel in sorted) {
    if (favoriteIds.contains(channel.id)) {
      favorites.add(channel);
    } else if (notForMeIds.contains(channel.id)) {
      notForMe.add(channel);
    } else {
      normal.add(channel);
    }
  }
  return [...favorites, ...normal, ...notForMe];
}
```

Note the `_favoriteIds`/`_notForMeIds` cache-key check uses `identical()`, matching the existing `_channels`/`_metadataByChannelId` pattern — callers must pass the same list/set instance across rebuilds when nothing changed (Task 5 wires this from a provider `.watch()`, which already gives stable instances between rebuilds unless the underlying data changed).

- [ ] **Step 4: Run, verify pass**

Run: `cd packages/feature_iptv && flutter test test/iptv/application/providers/channel_filters_provider_test.dart`
Expected: PASS, including every pre-existing test (they'll now fail to compile until you also add `favoriteIds`/`notForMeIds` args to their `resolve()` calls — add `favoriteIds: const [], notForMeIds: const {}` to each one that doesn't care about ordering).

- [ ] **Step 5: `flutter analyze`**

Run: `cd packages/feature_iptv && flutter analyze`

- [ ] **Step 6: Commit**

```bash
git add packages/feature_iptv/lib/application/providers/channel_filters_provider.dart packages/feature_iptv/test/iptv/application/providers/channel_filters_provider_test.dart
git commit -m "feat(iptv): partition channel grid by favorite/not-for-me in snapshot cache"
```

---

### Task 5: Wire favorite/not-for-me partition + not-for-me toggle into the grid

**Files:**
- Modify: `packages/feature_iptv/lib/presentation/tv_ux/sections/channel_library_grid.dart`
- Modify: `packages/feature_iptv/lib/presentation/tv_ux/airo_tv_shell.dart` (the `snapshot = _snapshotCache.resolve(...)` call site and the `ChannelLibraryGrid` construction)
- Test: `packages/feature_iptv/test/iptv/presentation/tv_ux/channel_library_grid_test.dart`

**Interfaces:**
- Consumes: `notForMeChannelIdsProvider`, `channelNotForMeTogglerProvider` (Task 2), widened `resolve()` (Task 4).

- [ ] **Step 1: `airo_tv_shell.dart` — pass the new ids through**

Find the existing `snapshot = _snapshotCache.resolve(...)` call (per the spec, inside `build()`) and add:

```dart
final favoriteIds = ref.watch(favoriteChannelIdsProvider).value ?? const <String>[];
final notForMeIds = ref.watch(notForMeChannelIdsProvider).value ?? const <String>{};
// ... existing snapshot = _snapshotCache.resolve(..., add:
favoriteIds: favoriteIds,
notForMeIds: notForMeIds,
```

Add the same `notForMeIds`/toggler wiring the existing `favoriteChannelIds`/`onFavoriteToggle` params already get when constructing `ChannelLibraryGrid` — mirror that exact pattern (parameter name, callback shape) for the new `notForMeChannelIds`/`onNotForMeToggle` params added in Step 2.

- [ ] **Step 2: `channel_library_grid.dart` — remove the plus button, shrink cards, add not-for-me row**

Remove the `Positioned` block for `widget.onMultiviewToggle` at lines 597-624 (the always-visible add-to-queue icon on the tile corner) — multiview toggling stays reachable only via `_ChannelActionsSheet` (long-press), which already has it.

Change:
```dart
const _cardWidth = 172.0;
const _cardHeight = 169.0;
```
to:
```dart
const _cardWidth = 155.0;
const _cardHeight = 155.0; // MediaCard.railHeightFor at the smaller width — verify against MediaCard's actual height-for-width contract, adjust if it clips
```

Add `notForMeChannelIds`/`onNotForMeToggle` fields to `ChannelLibraryGrid`'s constructor (mirroring `favoriteChannelIds`/`onFavoriteToggle` exactly), thread them down to `_ChannelTile`, and add a row to `_ChannelActionsSheet`:

```dart
if (onNotForMeToggle != null)
  ListTile(
    key: const ValueKey('channel-actions-not-for-me'),
    leading: Icon(isNotForMe ? Icons.visibility_off : Icons.visibility_off_outlined),
    title: Text(isNotForMe ? 'Remove "not for me"' : 'Not for me'),
    onTap: () => act(onNotForMeToggle),
  ),
```

(Match the existing `onFavoriteToggle`/`isFavorite` row immediately above it for the exact `act(...)` wiring pattern.)

- [ ] **Step 2: Write/extend tests**

```dart
testWidgets('grid gains a column at a representative TV width after compaction', (tester) async {
  // Pick a width used by an existing column-count test in this file (or 1920 if none exists),
  // assert _columnCountFor-equivalent behavior via the rendered tile count per row —
  // read the existing test file first for how column count is currently asserted.
});

testWidgets('long-press sheet shows Not for me and toggling it calls onNotForMeToggle', (tester) async {
  // pump ChannelLibraryGrid with onNotForMeToggle set, long-press a tile,
  // tap the "Not for me" row, verify the callback fired with the right channel.
});

testWidgets('per-tile plus button is gone', (tester) async {
  expect(find.byIcon(Icons.add_to_queue), findsNothing);
});
```

- [ ] **Step 3: Run, verify pass**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/tv_ux/channel_library_grid_test.dart test/iptv/presentation/tv_ux/airo_tv_shell_test.dart`

- [ ] **Step 4: Commit**

```bash
git add packages/feature_iptv/lib/presentation/tv_ux/sections/channel_library_grid.dart packages/feature_iptv/lib/presentation/tv_ux/airo_tv_shell.dart packages/feature_iptv/test/iptv/presentation/tv_ux/channel_library_grid_test.dart
git commit -m "feat(iptv): compact channel grid, add not-for-me toggle, drop per-tile plus button"
```

---

### Task 6: `MultiviewController.replace()`

**Files:**
- Modify: `packages/feature_iptv/lib/application/providers/multiview_provider.dart`
- Test: `packages/feature_iptv/test/application/multiview_provider_test.dart`

**Interfaces:**
- Produces: `MultiviewController.replace(String oldChannelId, IPTVChannel newChannel) → Future<MultiviewToggleResult>`.

- [ ] **Step 1: Write the failing tests**

Read the existing test file first for how it mocks/stubs `_pool`/session factories (via `iptvMultiviewSessionFactoryProvider` override, most likely) — match that setup exactly.

```dart
test('replace tears down the old session then opens the new one', () async {
  // arrange: controller at capacity 2 with sessions for 'old1' and 'old2'
  final result = await controller.replace('old1', channel('newX'));
  expect(result, MultiviewToggleResult.added);
  expect(controller.currentState.sessions.map((s) => s.id), containsAll(['newX', 'old2']));
  expect(controller.currentState.sessions.map((s) => s.id), isNot(contains('old1')));
});

test('replace leaves the slot empty (not the old session) when the new stream fails', () async {
  // arrange: session factory throws for 'newX'
  final result = await controller.replace('old1', channel('newX'));
  expect(result, MultiviewToggleResult.failed);
  expect(controller.currentState.sessions.map((s) => s.id), isNot(contains('old1')));
  expect(controller.currentState.sessions.map((s) => s.id), isNot(contains('newX')));
  expect(controller.currentState.sessions.length, 1); // only 'old2' remains
});

test('replace is a no-op-safe if oldChannelId is not actually in the pool', () async {
  final result = await controller.replace('not-present', channel('newX'));
  // still attempts the add (capacity may now allow it) — assert whatever the pool's
  // real add() does when count < capacity; do not assume failure without checking.
});
```

- [ ] **Step 2: Run, verify failure**

Run: `cd packages/feature_iptv && flutter test test/application/multiview_provider_test.dart`
Expected: FAIL — `replace` doesn't exist on `MultiviewController`.

- [ ] **Step 3: Implement**

Add to `MultiviewController` in `multiview_provider.dart`, near `toggle()`:

```dart
Future<MultiviewToggleResult> replace(
  String oldChannelId,
  IPTVChannel newChannel,
) async {
  if (_pool.state.contains(oldChannelId)) {
    await _pool.remove(oldChannelId);
  }
  final result = await _pool.add(
    id: newChannel.id,
    openSession: () => _sessionFactory(newChannel),
  );
  return switch (result) {
    AiroMultiviewAddResult.added => MultiviewToggleResult.added,
    AiroMultiviewAddResult.capacityReached =>
      MultiviewToggleResult.capacityReached,
    AiroMultiviewAddResult.alreadyPresent ||
    AiroMultiviewAddResult.openFailed => MultiviewToggleResult.failed,
  };
}
```

This intentionally does not touch `_primaryPausedByMultiview` bookkeeping — `replace()` only ever runs when at least one multiview session is already active (that's how the capacity-reached dialog gets triggered in the first place), so the primary-pause-on-first-session logic `toggle()` has doesn't apply here.

- [ ] **Step 4: Run, verify pass**

Run: `cd packages/feature_iptv && flutter test test/application/multiview_provider_test.dart`

- [ ] **Step 5: Commit**

```bash
git add packages/feature_iptv/lib/application/providers/multiview_provider.dart packages/feature_iptv/test/application/multiview_provider_test.dart
git commit -m "feat(iptv): add MultiviewController.replace() for the capacity-reached flow"
```

---

### Task 7: MultiView stage — dismiss control, tappable empty slot, replace dialog + picker sheet

**Files:**
- Modify: `packages/feature_iptv/lib/presentation/tv_ux/sections/multiview_stage.dart`
- Create: `packages/feature_iptv/lib/presentation/tv_ux/sections/multiview_actions.dart`
- Modify: `packages/feature_iptv/lib/presentation/tv_ux/airo_tv_shell.dart` (wire capacity-reached → dialog; this replaces the existing `_toggleMultiview`'s `capacityReached` snackbar branch)
- Test: `packages/feature_iptv/test/iptv/presentation/tv_ux/multiview_stage_test.dart`, `packages/feature_iptv/test/iptv/presentation/tv_ux/multiview_actions_test.dart` (new)

**Interfaces:**
- Consumes: `MultiviewController.replace()` (Task 6), `multiviewProvider`, `MultiviewState.sessions`/`.capacity`.
- Produces: `multiview_actions.dart` exports `showMultiviewReplaceDialog(BuildContext, {required List<IptvMultiviewSession> sessions, required IPTVChannel newChannel}) → Future<void>` and `showMultiviewEmptySlotPicker(BuildContext, {required List<IPTVChannel> allChannels, required Set<String> excludeChannelIds, required ValueChanged<IPTVChannel> onSelected}) → Future<void>`.

- [ ] **Step 1: `multiview_stage.dart` — dismiss control on each active tile**

Find `_PromotableSurface` (the per-tile wrapper with the existing long-press `_showTileControls`). Add a small dismiss icon, visible on focus, in the tile's corner — mirror the existing `_StageAction` circular-scrim button style from `airo_tv_shell.dart` (`Material(color: Colors.black.withValues(alpha: 0.56), shape: CircleBorder(), child: IconButton(...))`). Wire its `onPressed` to a new callback param threaded down from `MultiviewStage` (e.g. `onDismiss(String channelId)`), which `airo_tv_shell.dart` wires to `ref.read(multiviewProvider.notifier).toggle(session.channel)` — same call `_toggleMultiview` already makes for the grid-tile path, just invoked from here too.

- [ ] **Step 2: `multiview_stage.dart` — tappable empty slot**

`_EmptySlot` currently renders a static bordered box (`multiview_stage.dart:156-179`). Wrap its content in `TvFocusable` with `semanticLabel: 'Add a channel to this slot'`, `onSelect` calling a new `onEmptySlotTap` callback threaded down the same way as `onDismiss`.

- [ ] **Step 3: Create `multiview_actions.dart`**

```dart
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_player/platform_player.dart';

import '../../../application/providers/multiview_provider.dart';

/// Shown when adding a channel to MultiView would exceed capacity — lets
/// the viewer pick which currently-open screen to replace instead of just
/// failing. See MultiviewController.replace() for the remove-then-add
/// sequencing this dialog triggers.
class MultiviewReplaceDialog extends StatelessWidget {
  const MultiviewReplaceDialog({
    super.key,
    required this.sessions,
    required this.onReplace,
  });

  final List<IptvMultiviewSession> sessions;
  final ValueChanged<String> onReplace; // old channel id to replace

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const ValueKey('airo-tv-multiview-replace-dialog'),
      title: const Text('Replace which screen?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < sessions.length; i++)
            TvFocusable(
              key: ValueKey('multiview-replace-slot-${sessions[i].id}'),
              semanticLabel: 'Screen ${i + 1}: ${sessions[i].channel.name}',
              onSelect: () {
                onReplace(sessions[i].id);
                Navigator.of(context).pop();
              },
              child: ListTile(
                title: Text('Screen ${i + 1}: ${sessions[i].channel.name}'),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

Future<void> showMultiviewReplaceDialog(
  BuildContext context, {
  required List<IptvMultiviewSession> sessions,
  required ValueChanged<String> onReplace,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => MultiviewReplaceDialog(sessions: sessions, onReplace: onReplace),
  );
}

/// Channel picker for filling a specific empty MultiView slot. Excludes
/// channels already open in another slot — toggle() would otherwise treat
/// picking one of those as "remove it," not "add it here."
Future<void> showMultiviewEmptySlotPicker(
  BuildContext context, {
  required List<IPTVChannel> allChannels,
  required Set<String> excludeChannelIds,
  required ValueChanged<IPTVChannel> onSelected,
}) {
  final pickable = allChannels
      .where((channel) => !excludeChannelIds.contains(channel.id))
      .toList(growable: false);
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    builder: (sheetContext) => SafeArea(
      child: pickable.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No other channels available to add here.'),
            )
          : ListView.builder(
              shrinkWrap: true,
              itemCount: pickable.length,
              itemBuilder: (context, index) {
                final channel = pickable[index];
                return ListTile(
                  key: ValueKey('multiview-picker-${channel.id}'),
                  title: Text(channel.name),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    onSelected(channel);
                  },
                );
              },
            ),
    ),
  );
}
```

- [ ] **Step 4: Wire into `airo_tv_shell.dart`**

In `_toggleMultiview`, find the `MultiviewToggleResult.capacityReached` branch (currently shows a snackbar) and replace it with:

```dart
if (result == MultiviewToggleResult.capacityReached) {
  if (!context.mounted) return;
  await showMultiviewReplaceDialog(
    context,
    sessions: ref.read(multiviewProvider).sessions,
    onReplace: (oldChannelId) async {
      final replaceResult = await ref
          .read(multiviewProvider.notifier)
          .replace(oldChannelId, channel);
      if (!context.mounted) return;
      final message = switch (replaceResult) {
        MultiviewToggleResult.added => '${channel.name} added to multiview',
        MultiviewToggleResult.failed =>
          '${channel.name} could not be opened in multiview.',
        _ => null, // added/failed are the only results replace() returns beyond capacityReached, which can't recur here
      };
      if (message != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      }
    },
  );
  return;
}
```

Wire `MultiviewStage`'s new `onEmptySlotTap` (from Step 2) to `showMultiviewEmptySlotPicker`, passing `excludeChannelIds: multiview.sessions.map((s) => s.id).toSet()` and `onSelected: (channel) => _toggleMultiview(context, channel)` (reuses the existing toggle path — the slot is empty, so `toggle()` naturally adds rather than removes).

- [ ] **Step 5: Write tests**

```dart
// multiview_actions_test.dart
testWidgets('replace dialog lists sessions by slot number and name', (tester) async { /* ... */ });
testWidgets('tapping a slot calls onReplace with that session id and closes the dialog', (tester) async { /* ... */ });
testWidgets('empty-slot picker excludes channels already in excludeChannelIds', (tester) async { /* ... */ });
testWidgets('empty-slot picker shows a message when nothing is pickable', (tester) async { /* ... */ });

// multiview_stage_test.dart additions
testWidgets('active tile shows a dismiss control on focus that calls onDismiss', (tester) async { /* ... */ });
testWidgets('empty slot is focusable and calls onEmptySlotTap when selected', (tester) async { /* ... */ });
```

- [ ] **Step 6: Run, verify pass**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/tv_ux/multiview_stage_test.dart test/iptv/presentation/tv_ux/multiview_actions_test.dart test/iptv/presentation/tv_ux/airo_tv_shell_test.dart`

- [ ] **Step 7: Commit**

```bash
git add packages/feature_iptv/lib/presentation/tv_ux/sections/multiview_stage.dart packages/feature_iptv/lib/presentation/tv_ux/sections/multiview_actions.dart packages/feature_iptv/lib/presentation/tv_ux/airo_tv_shell.dart packages/feature_iptv/test/iptv/presentation/tv_ux/multiview_stage_test.dart packages/feature_iptv/test/iptv/presentation/tv_ux/multiview_actions_test.dart
git commit -m "feat(iptv): MultiView dismiss control, tappable empty slot, replace dialog"
```

---

### Task 8: `channel_name_overlay.dart` — transient channel identity overlay

**Files:**
- Create: `packages/feature_iptv/lib/presentation/tv_ux/sections/channel_name_overlay.dart`
- Test: `packages/feature_iptv/test/iptv/presentation/tv_ux/channel_name_overlay_test.dart`
- Modify: `packages/feature_iptv/lib/presentation/tv_ux/airo_tv_shell.dart` (mount it, remove `ChannelInfoBar`'s always-visible row usage — see Task 10 for the settings-row removal)

**Interfaces:**
- Produces: `ChannelNameOverlay` widget — `{required IPTVChannel? channel, required bool dismissRequested}`. `dismissRequested` toggling to `true` (e.g. when the player-actions sheet opens) forces an immediate hide, same as idle timeout.

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('shows channel name and logo when a channel is set', (tester) async {
  await tester.pumpWidget(wrap(ChannelNameOverlay(channel: testChannel, dismissRequested: false)));
  expect(find.text(testChannel.name), findsOneWidget);
});

testWidgets('auto-hides after 5s of no input', (tester) async {
  await tester.pumpWidget(wrap(ChannelNameOverlay(channel: testChannel, dismissRequested: false)));
  expect(find.text(testChannel.name), findsOneWidget);
  await tester.pump(const Duration(seconds: 6));
  // assert opacity animates to 0 — check the AnimatedOpacity's opacity value, not findsNothing
  // (the widget stays mounted, just invisible, so find.text still finds it — assert the opacity instead)
});

testWidgets('reappears and resets its timer on synthetic input', (tester) async {
  // pump past auto-hide, then simulate a key event / tap, assert opacity back to 1
});

testWidgets('dismissRequested hides it immediately regardless of timer state', (tester) async {
  final key = GlobalKey();
  await tester.pumpWidget(wrap(ChannelNameOverlay(key: key, channel: testChannel, dismissRequested: false)));
  await tester.pumpWidget(wrap(ChannelNameOverlay(key: key, channel: testChannel, dismissRequested: true)));
  await tester.pump();
  // assert opacity is 0 immediately, no 5s wait needed
});
```

Use `tester.pump()` with explicit durations rather than a fake `Clock` package unless one is already a dependency — check `pubspec.yaml` for `fake_async`/`clock` first.

- [ ] **Step 2: Run, verify failure**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/tv_ux/channel_name_overlay_test.dart`

- [ ] **Step 3: Implement**

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:platform_channels/platform_channels.dart';

import '../../widgets/channel_logo.dart';

class ChannelNameOverlay extends StatefulWidget {
  const ChannelNameOverlay({
    super.key,
    required this.channel,
    required this.dismissRequested,
  });

  final IPTVChannel? channel;
  final bool dismissRequested;

  @override
  State<ChannelNameOverlay> createState() => _ChannelNameOverlayState();
}

class _ChannelNameOverlayState extends State<ChannelNameOverlay> {
  static const _idleTimeout = Duration(seconds: 5);
  bool _visible = true;
  Timer? _idleTimer;

  @override
  void initState() {
    super.initState();
    _scheduleHide();
  }

  @override
  void didUpdateWidget(covariant ChannelNameOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.dismissRequested && !oldWidget.dismissRequested) {
      _idleTimer?.cancel();
      setState(() => _visible = false);
      return;
    }
    if (oldWidget.channel?.id != widget.channel?.id) {
      _reveal();
    }
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    super.dispose();
  }

  void _scheduleHide() {
    _idleTimer?.cancel();
    _idleTimer = Timer(_idleTimeout, () {
      if (mounted) setState(() => _visible = false);
    });
  }

  /// Call on any remote/touch input reaching the stage.
  void _reveal() {
    if (widget.dismissRequested) return;
    setState(() => _visible = true);
    _scheduleHide();
  }

  @override
  Widget build(BuildContext context) {
    final channel = widget.channel;
    if (channel == null) return const SizedBox.shrink();
    return Positioned(
      top: 8,
      left: 8,
      child: GestureDetector(
        onTap: _reveal,
        behavior: HitTestBehavior.translucent,
        child: AnimatedOpacity(
          opacity: _visible ? 1 : 0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.56),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ChannelLogo(
                    logoUrl: channel.effectiveLogoUrl,
                    channelName: channel.name,
                    size: 28,
                    isAudioOnly: channel.isAudioOnly,
                  ),
                  const SizedBox(width: 8),
                  Text(channel.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  const Chip(label: Text('LIVE')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

The "reveal on any remote/touch input" requirement needs a real input signal, not just this widget's own `GestureDetector` (a D-pad key press elsewhere on the stage should also reveal it) — wire `_reveal()` via a `GlobalKey<_ChannelNameOverlayState>` or a small `ValueNotifier<int>` "activity tick" passed down from `airo_tv_shell.dart`'s existing key-event handling, whichever pattern the file already uses elsewhere for cross-widget signals. Check `_handleFullscreenKey`/`onKeyEvent` in `airo_tv_shell.dart` and `iptv_screen.dart` before picking — match the existing approach, don't invent a new one.

- [ ] **Step 4: Run, verify pass**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/tv_ux/channel_name_overlay_test.dart`

- [ ] **Step 5: Mount in `airo_tv_shell.dart`, remove old `ChannelInfoBar` row usage**

This is the trickiest edit in the whole plan — `showChannel`, `infoBarFor`, `infoBarAutofocus`, and `AiroTvControlRow.channel` are threaded through both the `chrome` (wide/ten-foot) and `compactChrome` (phone) lists, plus focus-seeding logic (`infoBarAutofocus = showChannel`). Read the full current `build()` method again before editing (this file was last touched in Task 5/7, re-read after those land). Steps:
1. Remove `AiroTvControlRow.channel` from the enum (`control_row_visibility_provider.dart`) — it becomes fully unused once this task lands.
2. Remove `showChannel`, `infoBarFor()`, and every reference to them in both `chrome`/`compactChrome` lists.
3. Fix `infoBarAutofocus`/`filterRowAutofocus` focus-seeding logic — it currently seeds focus on whichever chrome row is topmost, with `showChannel` as the first candidate. Since the channel row is gone, seed focus on the next-topmost surviving row (stats/hotbar/filter) instead — trace the existing fallback chain and just remove the `showChannel` branch from it, don't restructure the whole thing.
4. Mount `ChannelNameOverlay(channel: widget.currentChannel, dismissRequested: <player-actions-sheet-open-state>)` as a new `Positioned` layer inside the existing video-stage `Stack` (alongside `_VideoStageWithActions`'s own `Positioned` action row) — it needs to be part of the stage's `Stack`, not the `chrome`/`compactChrome` column, since it overlays the video itself.
5. Wire `dismissRequested`: `showAiroTvShellSettingsDialog`/`showAiroTvShellHelpDialog`/the MultiView layout picker are all invoked from `_VideoStageWithActions`'s action row — add a simple `bool _sheetOpen` field to `_AiroTvShellState`, set `true` before each `showDialog`/`showModalBottomSheet` call and `false` in a `.then()` after it closes, pass `_sheetOpen` as `dismissRequested`.

- [ ] **Step 6: Update/extend `airo_tv_shell_test.dart`**

```dart
testWidgets('channel name overlay is mounted with the current channel', (tester) async { /* ... */ });
testWidgets('Explorer rows settings no longer has a Channel toggle', (tester) async { /* ... */ });
testWidgets('opening the settings dialog dismisses the overlay immediately', (tester) async { /* ... */ });
```

- [ ] **Step 7: Run, verify pass**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/tv_ux/airo_tv_shell_test.dart test/iptv/presentation/tv_ux/channel_name_overlay_test.dart`

- [ ] **Step 8: `flutter analyze`, then commit**

```bash
cd packages/feature_iptv && flutter analyze
git add packages/feature_iptv/lib/presentation/tv_ux/sections/channel_name_overlay.dart packages/feature_iptv/lib/presentation/tv_ux/airo_tv_shell.dart packages/feature_iptv/lib/application/providers/control_row_visibility_provider.dart packages/feature_iptv/test/iptv/presentation/tv_ux/channel_name_overlay_test.dart packages/feature_iptv/test/iptv/presentation/tv_ux/airo_tv_shell_test.dart
git commit -m "feat(iptv): replace always-visible channel row with transient overlay"
```

---

### Task 9: Loading screen — channel logo + zoom-out completion transition

**Files:**
- Modify: `packages/feature_iptv/lib/presentation/tv_ux/tv_loading_screen.dart`
- Test: `packages/feature_iptv/test/iptv/presentation/tv_ux/tv_loading_screen_test.dart` (new — none exists today)

**Interfaces:**
- Produces: `TvLoadingScreen` gains `{IPTVChannel? channel, bool ready = false}` (or whatever the existing constructor's param style is — read the file's current signature first, this plan's earlier read of it showed just a spinner + message).

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('shows the channel logo when a channel is provided', (tester) async {
  await tester.pumpWidget(wrap(TvLoadingScreen(channel: testChannel)));
  expect(find.byType(ChannelLogo), findsOneWidget);
});

testWidgets('shows spinner-only (no crash) when channel is null', (tester) async {
  await tester.pumpWidget(wrap(const TvLoadingScreen(channel: null)));
  expect(find.byType(CircularProgressIndicator), findsOneWidget);
});

testWidgets('zoom-out sequence runs to completion when ready flips true', (tester) async {
  await tester.pumpWidget(wrap(TvLoadingScreen(channel: testChannel, ready: false)));
  await tester.pumpWidget(wrap(TvLoadingScreen(channel: testChannel, ready: true)));
  await tester.pump(const Duration(milliseconds: 175)); // mid-animation
  // assert intermediate scale/opacity state is between start and end, not yet 0/1
  await tester.pump(const Duration(milliseconds: 200)); // past the ~350ms total
  // assert final state
});

testWidgets('switching channel mid-animation does not leak the old AnimationController', (tester) async {
  await tester.pumpWidget(wrap(TvLoadingScreen(channel: testChannel, ready: true)));
  await tester.pump(const Duration(milliseconds: 100)); // interrupt mid-animation
  await tester.pumpWidget(wrap(TvLoadingScreen(channel: testChannel2, ready: false)));
  await tester.pumpAndSettle();
  // no exception thrown (tester.takeException() is null) is the actual assertion here
  expect(tester.takeException(), isNull);
});
```

- [ ] **Step 2: Run, verify failure**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/tv_ux/tv_loading_screen_test.dart`

- [ ] **Step 3: Implement**

Convert `TvLoadingScreen` to a `StatefulWidget` with a `SingleTickerProviderStateMixin`, an `AnimationController` (`duration: const Duration(milliseconds: 350)`), driving a `Tween<double>(begin: 1, end: 0.6)` for scale and `Tween<double>(begin: 1, end: 0)` for opacity on the logo, triggered in `didUpdateWidget` when `ready` flips `false → true`. Dispose the controller and, on `didUpdateWidget` when the channel identity changes mid-animation, `..reset()` it before starting a new one for the new channel — this is exactly the leak Task 9's own test (`switching channel mid-animation`) checks for. Keep the existing gradient background and message label; add `ChannelLogo` (same widget Task 8 uses) above/behind the spinner when `channel != null`.

- [ ] **Step 4: Find and update every call site**

```bash
grep -rn "TvLoadingScreen(" packages/feature_iptv/lib --include="*.dart"
```
Update each to pass `channel`/`ready` as available in that context (some call sites may not have a channel yet — `channel: null` is a valid, tested state per Step 1).

- [ ] **Step 5: Run, verify pass; `flutter analyze`**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/tv_ux/tv_loading_screen_test.dart && flutter analyze`

- [ ] **Step 6: Commit**

```bash
git add packages/feature_iptv/lib/presentation/tv_ux/tv_loading_screen.dart packages/feature_iptv/test/iptv/presentation/tv_ux/tv_loading_screen_test.dart
git commit -m "feat(iptv): loading screen shows channel logo, zoom-out on ready"
```

---

### Task 10: Settings sheet — drop Channel row, add Playlist source + Guide URL rows

**Files:**
- Modify: `packages/feature_iptv/lib/presentation/tv_ux/sections/shell_settings_dialog.dart`
- Modify: `packages/feature_iptv/lib/presentation/screens/iptv_screen.dart` (wire the two new rows' callbacks — `_showPlaylistSheet`, `_showGuideSourceSheet` already exist, per the spec's Investigation Notes at `iptv_screen.dart:1100,1105`)
- Test: `packages/feature_iptv/test/iptv/presentation/tv_ux/shell_settings_dialog_test.dart`

**Interfaces:**
- Consumes: `AiroTvControlRow` (Task 8 already dropped `.channel` from it — this task's loop over `.values` needs no special-casing since the enum itself shrank).
- Produces: `AiroTvShellSettingsDialog` gains `{VoidCallback? onPlaylistSourceTap, VoidCallback? onGuideSourceTap}` (nullable — hides the row when null, matching every other optional entry point convention in this codebase per `ChannelInfoBar`'s doc comments).

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('no Channel row exists in the dialog', (tester) async {
  await tester.pumpWidget(wrap(showDialogHost(AiroTvShellSettingsDialog())));
  expect(find.text('Channel'), findsNothing);
});

testWidgets('Playlist source row appears and calls onPlaylistSourceTap when provided', (tester) async {
  var tapped = false;
  await tester.pumpWidget(wrap(AiroTvShellSettingsDialog(onPlaylistSourceTap: () => tapped = true)));
  await tester.tap(find.text('Playlist source'));
  expect(tapped, isTrue);
});

testWidgets('Guide URL row is hidden when onGuideSourceTap is null', (tester) async {
  await tester.pumpWidget(wrap(const AiroTvShellSettingsDialog()));
  expect(find.text('Guide URL'), findsNothing);
});
```

- [ ] **Step 2: Run, verify failure**

- [ ] **Step 3: Implement**

Add the two new params to the constructor. After the existing `for (final row in AiroTvControlRow.values)` loop (line 49) and before the `Divider`, add:

```dart
if (onPlaylistSourceTap != null)
  TvFocusable(
    key: const ValueKey('shell-settings-playlist-source'),
    semanticLabel: 'Playlist source',
    onSelect: onPlaylistSourceTap,
    child: ListTile(
      leading: const Icon(Icons.link),
      title: const Text('Playlist source'),
      onTap: onPlaylistSourceTap,
    ),
  ),
if (onGuideSourceTap != null)
  TvFocusable(
    key: const ValueKey('shell-settings-guide-source'),
    semanticLabel: 'Guide URL',
    onSelect: onGuideSourceTap,
    child: ListTile(
      leading: const Icon(Icons.calendar_month_outlined),
      title: const Text('Guide URL'),
      onTap: onGuideSourceTap,
    ),
  ),
```

Update `showAiroTvShellSettingsDialog(...)`'s signature to accept and forward the two new callbacks.

- [ ] **Step 4: Wire from `iptv_screen.dart`**

Every `showAiroTvShellSettingsDialog(context)` call site in `iptv_screen.dart` gains `onPlaylistSourceTap: _showPlaylistSheet, onGuideSourceTap: _showGuideSourceSheet` (both methods already exist per the spec's Investigation Notes — verify their exact names with `grep -n "_showPlaylistSheet\|_showGuideSourceSheet" packages/feature_iptv/lib/presentation/screens/iptv_screen.dart` before wiring, in case the earlier research had a typo).

- [ ] **Step 5: Run, verify pass; `flutter analyze`**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/tv_ux/shell_settings_dialog_test.dart && flutter analyze`

- [ ] **Step 6: Commit**

```bash
git add packages/feature_iptv/lib/presentation/tv_ux/sections/shell_settings_dialog.dart packages/feature_iptv/lib/presentation/screens/iptv_screen.dart packages/feature_iptv/test/iptv/presentation/tv_ux/shell_settings_dialog_test.dart
git commit -m "feat(iptv): move Playlist source and Guide URL into settings sheet"
```

---

### Task 11: Phase C wrap-up — `flutter test` full package pass

**Files:** none new — verification-only task.

- [ ] **Step 1:** `cd packages/feature_iptv && flutter test`
- [ ] **Step 2:** `cd packages/feature_iptv && flutter analyze`
- [ ] **Step 3:** Fix anything either command surfaces that earlier tasks missed (cross-file breakage from Task 8's `airo_tv_shell.dart` edit is the most likely source).
- [ ] **Step 4: Commit** (only if Step 3 required changes): `git commit -m "fix(iptv): resolve full-package test/analyze fallout from chrome cleanup"`

---

### Task 12: Bespoke bottom nav bar

**Files:**
- Create: `packages/feature_iptv/lib/presentation/tv_ux/sections/bottom_nav_bar.dart`
- Test: `packages/feature_iptv/test/iptv/presentation/tv_ux/bottom_nav_bar_test.dart` (new)

**Interfaces:**
- Produces: `IptvBottomNavBar` widget — `{required VoidCallback onHome, required VoidCallback onSearch, required VoidCallback onMyAika}`.

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('renders Home, Search, My Aika destinations', (tester) async {
  await tester.pumpWidget(wrap(IptvBottomNavBar(onHome: () {}, onSearch: () {}, onMyAika: () {})));
  expect(find.text('Home'), findsOneWidget);
  expect(find.text('Search'), findsOneWidget);
  expect(find.text('My Aika'), findsOneWidget);
});

testWidgets('tapping each destination calls its callback', (tester) async {
  var home = false, search = false, myAika = false;
  await tester.pumpWidget(wrap(IptvBottomNavBar(
    onHome: () => home = true, onSearch: () => search = true, onMyAika: () => myAika = true,
  )));
  await tester.tap(find.text('Home'));
  await tester.tap(find.text('Search'));
  await tester.tap(find.text('My Aika'));
  expect(home, isTrue);
  expect(search, isTrue);
  expect(myAika, isTrue);
});
```

- [ ] **Step 2: Run, verify failure**

- [ ] **Step 3: Implement**

```dart
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

/// Phone/tablet-only floating bottom nav — replaces the hamburger drawer
/// and AppBar icon row. Styled as a premium floating pill, not the flat
/// Material default (there is no existing shared nav component to defer
/// to — verified `AdaptiveNavigation` does not exist in this repo).
class IptvBottomNavBar extends StatelessWidget {
  const IptvBottomNavBar({
    super.key,
    required this.onHome,
    required this.onSearch,
    required this.onMyAika,
  });

  final VoidCallback onHome;
  final VoidCallback onSearch;
  final VoidCallback onMyAika;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF020419).withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _Destination(icon: Icons.home_outlined, label: 'Home', onTap: onHome),
            _Destination(icon: Icons.search, label: 'Search', onTap: onSearch),
            _Destination(icon: Icons.auto_awesome_outlined, label: 'My Aika', onTap: onMyAika),
          ],
        ),
      ),
    );
  }
}

class _Destination extends StatelessWidget {
  const _Destination({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      semanticLabel: label,
      onSelect: onTap,
      borderRadius: 20,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(height: 2),
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run, verify pass**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/tv_ux/bottom_nav_bar_test.dart`

- [ ] **Step 5: Commit**

```bash
git add packages/feature_iptv/lib/presentation/tv_ux/sections/bottom_nav_bar.dart packages/feature_iptv/test/iptv/presentation/tv_ux/bottom_nav_bar_test.dart
git commit -m "feat(iptv): add bespoke floating bottom nav bar widget"
```

---

### Task 13: Wire bottom nav into `iptv_screen.dart`, remove drawer + AppBar row, delete `iptv_navigation_drawer.dart`

**Files:**
- Modify: `packages/feature_iptv/lib/presentation/screens/iptv_screen.dart`
- Delete: `packages/feature_iptv/lib/presentation/widgets/iptv_navigation_drawer.dart` (only after confirming zero remaining references)
- Test: `packages/feature_iptv/test/iptv/presentation/screens/iptv_screen_test.dart`

**Interfaces:**
- Consumes: `IptvBottomNavBar` (Task 12), `AdaptiveBottomSheet.show` (verified real, `app/lib/shared/widgets/adaptive_dialog.dart`).

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('phone width: no drawer, no Search/Movies/Playlist/Guide AppBar icons, Cast icon present if available', (tester) async {
  // pump IptvScreen at a phone-width test surface size
  expect(find.byType(Drawer), findsNothing); // or whatever the Scaffold.drawer renders as
  expect(find.byTooltip('Playlist source'), findsNothing);
  expect(find.byTooltip('Guide URL'), findsNothing);
  expect(find.byTooltip('Search channels'), findsNothing);
  expect(find.byTooltip('Movies & Shows'), findsNothing);
  expect(find.byType(IptvBottomNavBar), findsOneWidget);
});

testWidgets('ten-foot width: unchanged, no bottom nav, no regression to _TvNavigationRail', (tester) async {
  // pump at tenFootMode: true — assert IptvBottomNavBar is NOT present (it's phone/tablet only)
});

testWidgets('My Aika opens a sheet with Settings, Movies and Shows, Favorites, Play local file on TV', (tester) async {
  // tap My Aika, assert all four ListTiles/rows appear in the resulting AdaptiveBottomSheet content
});

testWidgets('Home resets scroll/filters to top', (tester) async {
  // assert onHome's wired behavior — whatever the real reset call ends up being (check
  // channelFiltersProvider.notifier.clear() or scroll-controller jumpTo(0), pick one that
  // matches an existing "reset" affordance already in this file, e.g. _NoMatchesView's onClearFilters)
});
```

- [ ] **Step 2: Run, verify failure**

- [ ] **Step 3: Implement**

In the non-ten-foot branch of `iptv_screen.dart`'s `build()`:
1. Remove `drawer: IptvNavigationDrawer(...)`.
2. Remove the `AppBar`'s `actions` list entries for Search, Movies & Shows, Playlist source, Guide URL — keep only the conditional Cast action.
3. Add `bottomNavigationBar: IptvBottomNavBar(onHome: _resetToTop, onSearch: _showSearchSheet, onMyAika: _showMyAikaSheet)` (or wherever this screen's `Scaffold`-equivalent — it's `AiroResponsiveScaffold` per the earlier grep — accepts a bottom widget; check that widget's API before assuming a literal `bottomNavigationBar` param name).
4. Implement `_resetToTop()`: give `onHome`'s no-op (`() {}`) real behavior — clear transient filters via the same provider Phase B/`_NoMatchesView`'s `onClearFilters` already calls, and if a `ScrollController` exists on the grid, scroll it to `0`.
5. Implement `_showMyAikaSheet()`:

```dart
Future<void> _showMyAikaSheet() {
  return AdaptiveBottomSheet.show(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Settings'),
            onTap: () { Navigator.of(context).pop(); widget.onSettings?.call(); },
          ),
          if (widget.onOpenVod != null)
            ListTile(
              leading: const Icon(Icons.movie_outlined),
              title: const Text('Movies & Shows'),
              onTap: () { Navigator.of(context).pop(); widget.onOpenVod?.call(); },
            ),
          ListTile(
            leading: const Icon(Icons.favorite_border),
            title: const Text('Favorites'),
            onTap: () { Navigator.of(context).pop(); _openFavorites(); },
          ),
          if (widget.onPickLocalMediaForTv != null)
            ListTile(
              leading: const Icon(Icons.folder_open_outlined),
              title: const Text('Play local file on TV'),
              onTap: () { Navigator.of(context).pop(); _playLocalFileOnTv(); },
            ),
        ],
      ),
    ),
  );
}
```

(`_openFavorites`, `_playLocalFileOnTv`, `widget.onSettings`, `widget.onOpenVod`, `widget.onPickLocalMediaForTv` all already exist — this is the same set `IptvNavigationDrawer` was wired with, just moved. Verify each name with `grep` before use, same caution as Task 10 Step 4.)

- [ ] **Step 4: Confirm `iptv_navigation_drawer.dart` is fully unused, then delete it**

```bash
grep -rln "IptvNavigationDrawer" packages --include="*.dart" | grep -v iptv_navigation_drawer
```
If this returns nothing (besides the drawer's own test file, which should also be deleted), remove both files:
```bash
git rm packages/feature_iptv/lib/presentation/widgets/iptv_navigation_drawer.dart
git rm packages/feature_iptv/test/iptv/presentation/widgets/iptv_navigation_drawer_test.dart  # if it exists — check first
```
If the grep returns other hits, stop and investigate before deleting — do not delete a file still referenced elsewhere.

- [ ] **Step 5: Run, verify pass; `flutter analyze`**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/screens/iptv_screen_test.dart && flutter analyze`

- [ ] **Step 6: Commit**

```bash
git add -A  # review `git status` — this task both adds and deletes files
git commit -m "feat(iptv): replace hamburger drawer + AppBar icons with bottom nav"
```

---

### Task 14: Full-suite verification + web build sanity check

**Files:** none new — final verification task before opening the PR.

- [ ] **Step 1:** `cd packages/feature_iptv && flutter test`
- [ ] **Step 2:** `cd packages/platform_favorites && flutter test`
- [ ] **Step 3:** `melos run analyze` from the repo root (or `flutter analyze` in each touched package if `melos` isn't set up in this environment) — zero errors across every touched package.
- [ ] **Step 4:** `cd app && flutter build web --release` — this plan doesn't touch any native path, but CLAUDE.md requires this check "before landing anything that touches a native path" and `platform_player`'s multiview pool is close enough to that boundary to be worth the sanity check. If it fails for reasons clearly unrelated to this plan's changes (e.g. a pre-existing web-only gap), note that in the PR description rather than trying to fix unrelated breakage.
- [ ] **Step 5:** `git log --oneline main..HEAD` — read through every commit message, confirm the sequence tells a coherent story for a PR description.
- [ ] **Step 6:** Push the branch and open the PR against `main` (per the "Get it merge-ready" scope — do not merge it yourself, do not touch any release-line branch, do not trigger signing/Play-upload workflows).

```bash
git push -u origin agent/iptv/tv-player-premium-revamp
gh pr create --title "feat(iptv): TV player premium UX revamp (Phases A-D)" --body "$(cat <<'EOF'
## Summary
Implements the 4 core phases from docs/superpowers/specs/2026-09-11-tv-player-premium-revamp-design.md
(CEO + Eng + Design reviewed, all CLEARED):
- Phase A: MultiView replace/remove flow, no more round-trip to the grid
- Phase B: compacted channel grid + "not for me" preference (unified with favorites, mutually exclusive)
- Phase C: transient channel-name overlay replaces the always-visible row; loading screen gets a channel logo + zoom-out transition; Playlist/Guide settings relocated
- Phase D: bespoke floating bottom nav (Home/Search/My Aika) replaces the hamburger drawer + AppBar icon row, phone/tablet only

Not included (explicitly deferred, see spec's "Optional extras" and "NOT in scope" sections):
drag-to-reorder favorites, jump-back-in rail, item 4 (unreproduced repro needed).

## Test plan
- [ ] flutter test passes in feature_iptv and platform_favorites
- [ ] flutter analyze clean across touched packages
- [ ] Manual: MultiView replace-slot flow on a device at capacity
- [ ] Manual: grid compaction + not-for-me toggle on TV width
- [ ] Manual: bottom nav + My Aika sheet on phone width
EOF
)"
```

---

## Self-review notes (from writing this plan)

- **Spec coverage:** every numbered item in Phases A-D (items 1,2,3,6,10,5,7,8,9,11) maps to a task above. Extras and item 4 are correctly excluded per the approved scope.
- **Two corrections made mid-plan, already applied to the spec file itself** (commits `e0da42ac` and `f480337a` on this branch): `AdaptiveNavigation` doesn't exist (Task 12 builds bespoke); the class is `MultiviewController` not `MultiviewNotifier` (Task 6/7 use the correct name).
- **Type consistency check:** `replace()` (Task 6) returns `MultiviewToggleResult`, matching `toggle()` — verified against the real enum, not assumed. `FavoriteChannelsStorage.getFavoriteChannelIds()` returns `List<String>` consistently across Tasks 1, 2, 4, 5 — no task uses the old `Set<String>` signature.
- **No placeholders:** every task has real Dart, not "add appropriate handling." The two spots asking the implementer to grep-and-verify (Task 2 Step 1's call-site list, Task 10/13's method-name checks) are deliberate — they're the exact places prior research was already caught wrong twice in this session, so re-verifying beats trusting a stale enumeration again.
