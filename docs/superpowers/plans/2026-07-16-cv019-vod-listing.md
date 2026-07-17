# CV-019 VOD Listing Over BYOC Sources Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** List VOD (movies/series) entries already present in the user's M3U/Xtream sources in a browsable UI, with best-effort series/episode grouping and a "continue watching" row backed by the existing `platform_history` storage mechanism — no third-party metadata, no new persistence engine.

**Architecture:** A new `VodItem` domain model lives in `platform_channels` (Platform Architect's package) alongside the existing `IPTVChannel` — same tier, same role: the canonical provider-agnostic content shape. `platform_playlist` (from CV-018) gets two small adapter functions that map `XtreamClient.getVodStreams()` and M3U-parsed `IPTVChannel`s into `List<VodItem>` — no new HTTP surface, both just re-shape data the adapters already fetch. `platform_history` is refactored to extract its bounded-list/dedupe/trim/JSON-codec logic into a generic `BoundedRecentListStore<T>`, with the existing `RecentlyWatchedStorage` becoming a behavior-preserving thin wrapper over `BoundedRecentListStore<IPTVChannel>` (zero call-site changes, zero regression risk to the 6 existing live-TV consumers) and a new `VodWatchHistoryStorage` wrapping `BoundedRecentListStore<VodItem>` under a separate storage key. `feature_iptv` gets the series/episode grouping heuristic, Riverpod providers, and two new screens (TV + phone), wired into the app-level routers.

**Tech Stack:** Dart 3 classes + `equatable` (matches `IPTVChannel`/CV-018 conventions), Riverpod (matches `iptv_providers.dart`), `core_ui`'s `TvFocusable`/`TvUiDimensions`/`TvInputHandler` (existing TV navigation primitives, reused directly rather than forking `TvChannelGrid`'s more complex preloading/debounce logic — VOD lists are smaller and don't need that).

## Global Constraints

- Dart SDK `^3.12.2`, Flutter `>=1.17.0` (match sibling packages).
- No new codegen tooling — plain Dart classes + `equatable`, per repo-wide precedent.
- No third-party metadata calls of any kind (no TMDB, no poster/synopsis enrichment). VOD listing is limited to whatever the source itself supplies (title, category, stream URL, source-provided poster URL only).
- No offline downloads — VOD streams the same way live channels do.
- No cloud-synced watch progress — local-only, via `platform_history`'s existing `SharedPreferences`-backed mechanism. **No new persistence system**: `BoundedRecentListStore` reuses the exact same storage engine (`KeyValueStore`/`SharedPreferences`) `RecentlyWatchedStorage` already uses, just generalized to avoid duplicating logic across a second concrete class.
- `RecentlyWatchedStorage`'s existing public API (`addToRecent(IPTVChannel)`, `getRecentlyWatched({int? limit})`, `clearRecent()`, `removeFromRecent(String)`, `hasRecentlyWatched()`, `getRecentCount()`) and its storage key (`'iptv_recently_watched'`) and max size (20) must not change — 6 existing call sites in `feature_iptv` depend on this exact shape and must show zero behavior change.
- `VodItem` lives in `packages/platform_channels` (leaf package, `allowed_dependencies: []`), exported from `platform_channels.dart` alongside `IPTVChannel`.
- New `platform_playlist` dependency direction unchanged (still `core_data, platform_channels, platform_epg, platform_playlist_import` — VOD adapters live inside the package's existing `xtream/` folder and a new top-level file, no new package dependency needed).
- `platform_history`'s `module.yaml`/`pubspec.yaml` dependencies (`core_data`, `platform_channels`) are unchanged — `VodItem` is already reachable via the existing `platform_channels` dependency.
- Series/episode grouping is a feature-layer (business logic) concern — lives in `feature_iptv`, not `platform_channels`/`platform_playlist` (those stay provider-agnostic content models/adapters, no grouping heuristics).
- Tests required per issue #824: VOD parsing from fixture playlists, continue-watching state, empty-state when a source has no VOD entries.

---

## File Structure

```
packages/platform_channels/
  lib/src/models/vod_item.dart                          [new]
  lib/platform_channels.dart                             [modify — add export]
  test/models/vod_item_test.dart                          [new]

packages/platform_history/
  lib/src/bounded_recent_list_store.dart                  [new]
  lib/src/recently_watched_storage.dart                   [modify — delegate to BoundedRecentListStore]
  lib/src/vod_watch_history_storage.dart                  [new]
  lib/platform_history.dart                               [modify — add exports]
  test/bounded_recent_list_store_test.dart                 [new]
  test/recently_watched_storage_test.dart                  [existing — must still pass unchanged]
  test/vod_watch_history_storage_test.dart                 [new]

packages/platform_playlist/
  lib/src/xtream/xtream_vod_adapter.dart                   [new]
  lib/src/m3u_vod_adapter.dart                              [new]
  lib/platform_playlist.dart                                [modify — add exports]
  test/xtream/xtream_vod_adapter_test.dart                  [new]
  test/m3u_vod_adapter_test.dart                             [new]

packages/feature_iptv/
  lib/domain/vod_series_grouping.dart                       [new]
  lib/application/providers/vod_providers.dart               [new]
  lib/presentation/widgets/vod_grid.dart                      [new]
  lib/presentation/widgets/vod_list_widget.dart                [new]
  lib/presentation/tv/vod_tv_screen.dart                        [new]
  lib/presentation/screens/vod_screen.dart                       [new]
  lib/feature_iptv.dart                                          [modify — export new screens]
  test/iptv/domain/vod_series_grouping_test.dart                  [new]
  test/iptv/application/providers/vod_providers_test.dart          [new]
  test/iptv/presentation/widgets/vod_grid_test.dart                 [new]
  test/iptv/presentation/tv/vod_tv_screen_test.dart                  [new]

app/
  lib/core/app/tv_router.dart                                 [modify — add VOD route]
  lib/core/app/tv_shell.dart                                   [modify — add VOD nav destination]
  lib/core/routing/app_router.dart                              [modify — add VOD route]
```

---

### Task 1: `VodItem` domain model

**Files:**
- Create: `packages/platform_channels/lib/src/models/vod_item.dart`
- Modify: `packages/platform_channels/lib/platform_channels.dart`
- Test: `packages/platform_channels/test/models/vod_item_test.dart`

**Interfaces:**
- Produces: `enum VodContentKind { movie, episode }`; `class VodSeriesRef { String seriesId, String seriesTitle, int? seasonNumber, int? episodeNumber }`; `class VodItem extends Equatable { String id, String title, String streamUrl, String? posterUrl, String group, VodContentKind kind, VodSeriesRef? seriesRef, String? containerExtension }`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';

void main() {
  group('VodSeriesRef', () {
    test('equality is field-based', () {
      const a = VodSeriesRef(
        seriesId: 'series-1',
        seriesTitle: 'Example Show',
        seasonNumber: 1,
        episodeNumber: 2,
      );
      const b = VodSeriesRef(
        seriesId: 'series-1',
        seriesTitle: 'Example Show',
        seasonNumber: 1,
        episodeNumber: 2,
      );
      expect(a, b);
    });
  });

  group('VodItem', () {
    test('a movie has no seriesRef', () {
      const item = VodItem(
        id: 'xtream-vod-1',
        title: 'Example Movie',
        streamUrl: 'https://example.com/movie/1.mp4',
        group: 'Movies',
        kind: VodContentKind.movie,
      );

      expect(item.kind, VodContentKind.movie);
      expect(item.seriesRef, isNull);
    });

    test('an episode carries its seriesRef', () {
      const item = VodItem(
        id: 'xtream-vod-2',
        title: 'Example Show S01E02',
        streamUrl: 'https://example.com/series/2.mp4',
        group: 'Series',
        kind: VodContentKind.episode,
        seriesRef: VodSeriesRef(
          seriesId: 'example-show',
          seriesTitle: 'Example Show',
          seasonNumber: 1,
          episodeNumber: 2,
        ),
      );

      expect(item.seriesRef?.seasonNumber, 1);
      expect(item.seriesRef?.episodeNumber, 2);
    });

    test('toJson/fromJson round-trips all fields', () {
      const item = VodItem(
        id: 'xtream-vod-3',
        title: 'Example Show S02E05',
        streamUrl: 'https://example.com/series/5.mp4',
        posterUrl: 'https://example.com/poster.jpg',
        group: 'Series',
        kind: VodContentKind.episode,
        containerExtension: 'mp4',
        seriesRef: VodSeriesRef(
          seriesId: 'example-show',
          seriesTitle: 'Example Show',
          seasonNumber: 2,
          episodeNumber: 5,
        ),
      );

      final decoded = VodItem.fromJson(item.toJson());

      expect(decoded, item);
    });

    test('toJson/fromJson round-trips a movie with no seriesRef', () {
      const item = VodItem(
        id: 'm3u-vod-1',
        title: 'Example Movie',
        streamUrl: 'https://example.com/movie.mp4',
        group: 'Movies',
        kind: VodContentKind.movie,
      );

      final decoded = VodItem.fromJson(item.toJson());

      expect(decoded, item);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/platform_channels && flutter test test/models/vod_item_test.dart`
Expected: FAIL — `VodItem`/`VodSeriesRef`/`VodContentKind` undefined.

- [ ] **Step 3: Write `lib/src/models/vod_item.dart`**

```dart
import 'package:equatable/equatable.dart';

/// Whether a [VodItem] is a standalone movie or one episode of a series.
enum VodContentKind {
  movie('movie'),
  episode('episode');

  const VodContentKind(this.stableId);

  final String stableId;

  static VodContentKind fromStableId(String value) {
    return VodContentKind.values.firstWhere(
      (kind) => kind.stableId == value,
      orElse: () => VodContentKind.movie,
    );
  }
}

/// Groups a [VodItem] of kind [VodContentKind.episode] under its parent
/// series. [seriesId] is a stable grouping key (not necessarily a
/// source-provided id) — see `feature_iptv`'s series/episode grouping
/// heuristic for how this gets derived from source titles.
class VodSeriesRef extends Equatable {
  const VodSeriesRef({
    required this.seriesId,
    required this.seriesTitle,
    this.seasonNumber,
    this.episodeNumber,
  });

  final String seriesId;
  final String seriesTitle;
  final int? seasonNumber;
  final int? episodeNumber;

  factory VodSeriesRef.fromJson(Map<String, dynamic> json) {
    return VodSeriesRef(
      seriesId: json['seriesId'] as String,
      seriesTitle: json['seriesTitle'] as String,
      seasonNumber: json['seasonNumber'] as int?,
      episodeNumber: json['episodeNumber'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
    'seriesId': seriesId,
    'seriesTitle': seriesTitle,
    if (seasonNumber != null) 'seasonNumber': seasonNumber,
    if (episodeNumber != null) 'episodeNumber': episodeNumber,
  };

  @override
  List<Object?> get props => [seriesId, seriesTitle, seasonNumber, episodeNumber];
}

/// A single on-demand content entry (movie or episode) surfaced from a
/// BYOC source (M3U or Xtream). Provider-agnostic — mirrors [IPTVChannel]'s
/// role for live channels, deliberately with no third-party metadata
/// fields (no synopsis, no rating, no cast — see CV-019 non-goals).
class VodItem extends Equatable {
  const VodItem({
    required this.id,
    required this.title,
    required this.streamUrl,
    required this.group,
    required this.kind,
    this.posterUrl,
    this.containerExtension,
    this.seriesRef,
  });

  final String id;
  final String title;
  final String streamUrl;
  final String? posterUrl;
  final String group;
  final VodContentKind kind;
  final String? containerExtension;
  final VodSeriesRef? seriesRef;

  factory VodItem.fromJson(Map<String, dynamic> json) {
    return VodItem(
      id: json['id'] as String,
      title: json['title'] as String,
      streamUrl: json['streamUrl'] as String,
      posterUrl: json['posterUrl'] as String?,
      group: json['group'] as String,
      kind: VodContentKind.fromStableId(json['kind'] as String),
      containerExtension: json['containerExtension'] as String?,
      seriesRef: json['seriesRef'] != null
          ? VodSeriesRef.fromJson(json['seriesRef'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'streamUrl': streamUrl,
    if (posterUrl != null) 'posterUrl': posterUrl,
    'group': group,
    'kind': kind.stableId,
    if (containerExtension != null) 'containerExtension': containerExtension,
    if (seriesRef != null) 'seriesRef': seriesRef!.toJson(),
  };

  @override
  List<Object?> get props => [
    id,
    title,
    streamUrl,
    posterUrl,
    group,
    kind,
    containerExtension,
    seriesRef,
  ];
}
```

- [ ] **Step 4: Export from the barrel**

Add to `packages/platform_channels/lib/platform_channels.dart`:

```dart
export "src/models/vod_item.dart";
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd packages/platform_channels && flutter test test/models/vod_item_test.dart`
Expected: `00:00 +5: All tests passed!`

- [ ] **Step 6: Run the full `platform_channels` suite**

Run: `cd packages/platform_channels && flutter test`
Expected: all tests pass, no regressions.

- [ ] **Step 7: Commit**

```bash
git add packages/platform_channels
git commit -m "feat(platform_channels): add VodItem domain model"
```

---

### Task 2: Generalize `platform_history` storage — `BoundedRecentListStore<T>` + `VodWatchHistoryStorage`

**Files:**
- Create: `packages/platform_history/lib/src/bounded_recent_list_store.dart`
- Modify: `packages/platform_history/lib/src/recently_watched_storage.dart`
- Create: `packages/platform_history/lib/src/vod_watch_history_storage.dart`
- Modify: `packages/platform_history/lib/platform_history.dart`
- Test: `packages/platform_history/test/bounded_recent_list_store_test.dart`
- Test: `packages/platform_history/test/vod_watch_history_storage_test.dart`

**Interfaces:**
- Consumes: `KeyValueStore` (`package:core_data/core_data.dart`), `IPTVChannel`/`VodItem` (`package:platform_channels/platform_channels.dart`).
- Produces: `class BoundedRecentListStore<T> { BoundedRecentListStore(KeyValueStore store, {required String storageKey, required int maxSize, required String Function(T) idOf, required Map<String, dynamic> Function(T) toJson, required T Function(Map<String, dynamic>) fromJson}); Future<void> addToRecent(T item); Future<List<T>> getRecent({int? limit}); Future<void> clearRecent(); Future<void> removeFromRecent(String id); bool hasRecent(); Future<int> getRecentCount(); }`; `class VodWatchHistoryStorage { VodWatchHistoryStorage(SharedPreferences prefs, {KeyValueStore? store}); Future<void> addToRecent(VodItem item); Future<List<VodItem>> getRecentlyWatched({int? limit}); Future<void> clearRecent(); Future<void> removeFromRecent(String id); bool hasRecentlyWatched(); Future<int> getRecentCount(); }`.

`RecentlyWatchedStorage`'s public surface (method names, parameter names, storage key `'iptv_recently_watched'`, max size 20) does not change — it becomes a thin wrapper delegating every method to an internal `BoundedRecentListStore<IPTVChannel>`.

- [ ] **Step 1: Write the failing test for `BoundedRecentListStore`**

```dart
import 'package:core_data/core_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_history/platform_history.dart';

class _Item {
  const _Item(this.id, this.name);
  final String id;
  final String name;

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  factory _Item.fromJson(Map<String, dynamic> json) =>
      _Item(json['id'] as String, json['name'] as String);
}

void main() {
  late KeyValueStore store;
  late BoundedRecentListStore<_Item> boundedStore;

  setUp(() {
    store = InMemoryKeyValueStore();
    boundedStore = BoundedRecentListStore<_Item>(
      store,
      storageKey: 'test_recent',
      maxSize: 3,
      idOf: (item) => item.id,
      toJson: (item) => item.toJson(),
      fromJson: _Item.fromJson,
    );
  });

  test('addToRecent then getRecent round-trips', () async {
    await boundedStore.addToRecent(const _Item('1', 'first'));

    final result = await boundedStore.getRecent();

    expect(result, [const _Item('1', 'first')]);
  });

  test('re-adding an existing id moves it to the top, no duplicate', () async {
    await boundedStore.addToRecent(const _Item('1', 'first'));
    await boundedStore.addToRecent(const _Item('2', 'second'));
    await boundedStore.addToRecent(const _Item('1', 'first'));

    final result = await boundedStore.getRecent();

    expect(result.map((i) => i.id), ['1', '2']);
  });

  test('trims to maxSize, dropping the oldest', () async {
    await boundedStore.addToRecent(const _Item('1', 'a'));
    await boundedStore.addToRecent(const _Item('2', 'b'));
    await boundedStore.addToRecent(const _Item('3', 'c'));
    await boundedStore.addToRecent(const _Item('4', 'd'));

    final result = await boundedStore.getRecent();

    expect(result.map((i) => i.id), ['4', '3', '2']);
  });

  test('getRecent respects limit', () async {
    await boundedStore.addToRecent(const _Item('1', 'a'));
    await boundedStore.addToRecent(const _Item('2', 'b'));

    final result = await boundedStore.getRecent(limit: 1);

    expect(result, [const _Item('2', 'b')]);
  });

  test('removeFromRecent removes by id', () async {
    await boundedStore.addToRecent(const _Item('1', 'a'));
    await boundedStore.addToRecent(const _Item('2', 'b'));

    await boundedStore.removeFromRecent('1');
    final result = await boundedStore.getRecent();

    expect(result.map((i) => i.id), ['2']);
  });

  test('clearRecent empties the list', () async {
    await boundedStore.addToRecent(const _Item('1', 'a'));

    await boundedStore.clearRecent();
    final result = await boundedStore.getRecent();

    expect(result, isEmpty);
  });

  test('hasRecent is false before any add, true after', () async {
    expect(boundedStore.hasRecent(), isFalse);

    await boundedStore.addToRecent(const _Item('1', 'a'));

    expect(boundedStore.hasRecent(), isTrue);
  });

  test('getRecentCount reflects the current list size', () async {
    await boundedStore.addToRecent(const _Item('1', 'a'));
    await boundedStore.addToRecent(const _Item('2', 'b'));

    expect(await boundedStore.getRecentCount(), 2);
  });

  test('two stores with different storageKeys do not collide', () async {
    final otherStore = BoundedRecentListStore<_Item>(
      store,
      storageKey: 'other_recent',
      maxSize: 3,
      idOf: (item) => item.id,
      toJson: (item) => item.toJson(),
      fromJson: _Item.fromJson,
    );

    await boundedStore.addToRecent(const _Item('1', 'a'));
    await otherStore.addToRecent(const _Item('2', 'b'));

    expect((await boundedStore.getRecent()).map((i) => i.id), ['1']);
    expect((await otherStore.getRecent()).map((i) => i.id), ['2']);
  });
}
```

Note: `InMemoryKeyValueStore` may not exist yet — check `package:core_data/core_data.dart` first (`grep -rn "class.*KeyValueStore" packages/core_data/lib/`). If no in-memory test double exists, use a real `SharedPreferences.setMockInitialValues({})` + `SharedPreferences.getInstance()` + `PreferencesStore(prefs)` instead (the same pattern `packages/platform_playlist_import`'s tests already use for `KeyValueStore`-backed classes) — adjust `setUp` to be `async` and use that instead of inventing a new fake.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/platform_history && flutter test test/bounded_recent_list_store_test.dart`
Expected: FAIL — `BoundedRecentListStore` undefined.

- [ ] **Step 3: Write `lib/src/bounded_recent_list_store.dart`**

```dart
import 'dart:convert';

import 'package:core_data/core_data.dart';
import 'package:flutter/foundation.dart';

/// Generic bounded, deduped, most-recent-first list backed by
/// [KeyValueStore] — the storage engine [RecentlyWatchedStorage] already
/// used for live channels, extracted so a second content type (VOD) can
/// reuse the same mechanism under a different [storageKey] without
/// duplicating the add/dedupe/trim/JSON logic.
class BoundedRecentListStore<T> {
  BoundedRecentListStore(
    this._store, {
    required this.storageKey,
    required this.maxSize,
    required this.idOf,
    required this.toJson,
    required this.fromJson,
  });

  final KeyValueStore _store;
  final String storageKey;
  final int maxSize;
  final String Function(T item) idOf;
  final Map<String, dynamic> Function(T item) toJson;
  final T Function(Map<String, dynamic> json) fromJson;

  Future<void> addToRecent(T item) async {
    try {
      final recent = await getRecent();

      recent.removeWhere((existing) => idOf(existing) == idOf(item));
      recent.insert(0, item);

      while (recent.length > maxSize) {
        recent.removeLast();
      }

      await _saveRecent(recent);
    } catch (e) {
      debugPrint('[BoundedRecentListStore:$storageKey] Error adding: $e');
    }
  }

  Future<List<T>> getRecent({int? limit}) async {
    try {
      final json = await _store.getString(storageKey);
      if (json == null) return [];

      final list = jsonDecode(json) as List;
      final items = list
          .map((item) => fromJson(item as Map<String, dynamic>))
          .toList();

      if (limit != null && items.length > limit) {
        return items.take(limit).toList();
      }
      return items;
    } catch (e) {
      debugPrint('[BoundedRecentListStore:$storageKey] Error loading: $e');
      return [];
    }
  }

  Future<void> clearRecent() async {
    await _store.remove(storageKey);
  }

  Future<void> removeFromRecent(String id) async {
    try {
      final recent = await getRecent();
      recent.removeWhere((item) => idOf(item) == id);
      await _saveRecent(recent);
    } catch (e) {
      debugPrint('[BoundedRecentListStore:$storageKey] Error removing: $e');
    }
  }

  bool hasRecent() => _store.containsKey(storageKey);

  Future<int> getRecentCount() async {
    final recent = await getRecent();
    return recent.length;
  }

  Future<void> _saveRecent(List<T> items) async {
    final json = jsonEncode(items.map(toJson).toList());
    await _store.setString(storageKey, json);
  }
}
```

Note: check `KeyValueStore`'s exact method for a synchronous existence check (`hasRecent()` above assumes `containsKey` is synchronous/bool per `RecentlyWatchedStorage`'s existing `hasRecentlyWatched()` which uses `_prefs.containsKey(_recentKey)` directly on `SharedPreferences`, not `_store`). If `KeyValueStore.containsKey` is actually `Future<bool>`, change `hasRecent()` to `Future<bool> hasRecent()` and update the test's `expect(boundedStore.hasRecent(), isFalse)` calls to `expect(await boundedStore.hasRecent(), isFalse)` — check `packages/core_data/lib/src/storage/key_value_store.dart` for the real signature before writing this method, don't guess.

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd packages/platform_history && flutter test test/bounded_recent_list_store_test.dart`
Expected: `00:00 +9: All tests passed!`

- [ ] **Step 5: Refactor `RecentlyWatchedStorage` to delegate, behavior-preserving**

Replace the body of `packages/platform_history/lib/src/recently_watched_storage.dart` with:

```dart
import 'package:core_data/core_data.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:platform_channels/platform_channels.dart';

import 'bounded_recent_list_store.dart';

/// Storage service for persisting recently watched IPTV channels.
///
/// Uses the platform key-value preference guard for local device storage.
/// Maintains privacy by storing data only on device.
///
/// Delegates to [BoundedRecentListStore] — the underlying storage key
/// (`iptv_recently_watched`), max size (20), and every method's behavior
/// are unchanged from before this delegation; this is a pure refactor.
class RecentlyWatchedStorage {
  static const String _recentKey = 'iptv_recently_watched';
  static const int _maxRecentSize = 20;

  final SharedPreferences _prefs;
  final BoundedRecentListStore<IPTVChannel> _store;

  RecentlyWatchedStorage(
    this._prefs, {
    KeyValueStore? store,
    int maxPreferenceValueBytes = kKeyValueStorePreferenceMaxValueBytes,
  }) : _store = BoundedRecentListStore<IPTVChannel>(
         store ??
             PreferencesStore(_prefs, maxValueBytes: maxPreferenceValueBytes),
         storageKey: _recentKey,
         maxSize: _maxRecentSize,
         idOf: (channel) => channel.id,
         toJson: (channel) => channel.toJson(),
         fromJson: IPTVChannel.fromJson,
       );

  /// Add channel to recently watched list.
  ///
  /// If channel already exists, moves it to the top.
  /// Maintains max size of [_maxRecentSize] channels.
  Future<void> addToRecent(IPTVChannel channel) => _store.addToRecent(channel);

  /// Get list of recently watched channels, most recently watched first.
  Future<List<IPTVChannel>> getRecentlyWatched({int? limit}) =>
      _store.getRecent(limit: limit);

  /// Clear all recently watched history.
  Future<void> clearRecent() => _store.clearRecent();

  /// Remove a specific channel from recently watched.
  Future<void> removeFromRecent(String channelId) =>
      _store.removeFromRecent(channelId);

  /// Check if there are any recently watched channels.
  bool hasRecentlyWatched() => _prefs.containsKey(_recentKey);

  /// Get the count of recently watched channels.
  Future<int> getRecentCount() => _store.getRecentCount();
}
```

(Keep `hasRecentlyWatched()` reading `_prefs.containsKey` directly, exactly as the original did, rather than routing through `_store.hasRecent()` — this avoids any risk from the `hasRecent()` signature question raised in Step 3, and preserves the original implementation's exact behavior.)

- [ ] **Step 6: Run the existing `RecentlyWatchedStorage` test suite — must pass unchanged**

Run: `cd packages/platform_history && flutter test test/recently_watched_storage_test.dart`
Expected: all existing tests pass with zero modifications to that test file. If any fail, the refactor broke behavior — stop and fix `recently_watched_storage.dart`, do not edit the test file to make it pass.

- [ ] **Step 7: Write the failing test for `VodWatchHistoryStorage`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_history/platform_history.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;
  late VodWatchHistoryStorage storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    storage = VodWatchHistoryStorage(prefs);
  });

  const movie = VodItem(
    id: 'xtream-vod-1',
    title: 'Example Movie',
    streamUrl: 'https://example.com/movie.mp4',
    group: 'Movies',
    kind: VodContentKind.movie,
  );

  test('addToRecent then getRecentlyWatched round-trips', () async {
    await storage.addToRecent(movie);

    final result = await storage.getRecentlyWatched();

    expect(result, [movie]);
  });

  test('does not collide with RecentlyWatchedStorage\'s storage key', () async {
    final liveHistory = RecentlyWatchedStorage(prefs);

    await storage.addToRecent(movie);

    final liveResult = await liveHistory.getRecentlyWatched();
    expect(liveResult, isEmpty);
  });

  test('hasRecentlyWatched is false before any add, true after', () async {
    expect(storage.hasRecentlyWatched(), isFalse);

    await storage.addToRecent(movie);

    expect(storage.hasRecentlyWatched(), isTrue);
  });

  test('removeFromRecent removes by id', () async {
    await storage.addToRecent(movie);

    await storage.removeFromRecent(movie.id);
    final result = await storage.getRecentlyWatched();

    expect(result, isEmpty);
  });

  test('clearRecent empties the list', () async {
    await storage.addToRecent(movie);

    await storage.clearRecent();
    final result = await storage.getRecentlyWatched();

    expect(result, isEmpty);
  });
}
```

- [ ] **Step 8: Run test to verify it fails**

Run: `cd packages/platform_history && flutter test test/vod_watch_history_storage_test.dart`
Expected: FAIL — `VodWatchHistoryStorage` undefined.

- [ ] **Step 9: Write `lib/src/vod_watch_history_storage.dart`**

```dart
import 'package:core_data/core_data.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:platform_channels/platform_channels.dart';

import 'bounded_recent_list_store.dart';

/// Storage service for a "continue watching" / recently-opened VOD list.
///
/// Same storage engine as [RecentlyWatchedStorage] (device-local
/// [SharedPreferences] via [KeyValueStore]), under a separate storage key
/// so live-channel and VOD history never collide. There is no
/// resume-position/progress field — like [RecentlyWatchedStorage], this
/// tracks "recently opened," not "resume playback at timestamp X."
class VodWatchHistoryStorage {
  static const String _recentKey = 'vod_recently_watched';
  static const int _maxRecentSize = 20;

  final BoundedRecentListStore<VodItem> _store;

  VodWatchHistoryStorage(
    SharedPreferences prefs, {
    KeyValueStore? store,
    int maxPreferenceValueBytes = kKeyValueStorePreferenceMaxValueBytes,
  }) : _store = BoundedRecentListStore<VodItem>(
         store ??
             PreferencesStore(prefs, maxValueBytes: maxPreferenceValueBytes),
         storageKey: _recentKey,
         maxSize: _maxRecentSize,
         idOf: (item) => item.id,
         toJson: (item) => item.toJson(),
         fromJson: VodItem.fromJson,
       );

  Future<void> addToRecent(VodItem item) => _store.addToRecent(item);

  Future<List<VodItem>> getRecentlyWatched({int? limit}) =>
      _store.getRecent(limit: limit);

  Future<void> clearRecent() => _store.clearRecent();

  Future<void> removeFromRecent(String id) => _store.removeFromRecent(id);

  bool hasRecentlyWatched() => _store.hasRecent();

  Future<int> getRecentCount() => _store.getRecentCount();
}
```

(If Step 3's `hasRecent()` ended up `Future<bool>`, make `hasRecentlyWatched()` here `Future<bool>` too and update the Step 7 test's assertions to `await`.)

- [ ] **Step 10: Export new files from the barrel**

Add to `packages/platform_history/lib/platform_history.dart`:

```dart
export "src/bounded_recent_list_store.dart";
export "src/vod_watch_history_storage.dart";
```

- [ ] **Step 11: Run the full `platform_history` suite**

Run: `cd packages/platform_history && flutter test`
Expected: all tests pass (existing `recently_watched_storage_test.dart` unmodified and green, plus new `bounded_recent_list_store_test.dart` and `vod_watch_history_storage_test.dart`), zero regressions.

- [ ] **Step 12: Commit**

```bash
git add packages/platform_history
git commit -m "refactor(platform_history): extract BoundedRecentListStore, add VodWatchHistoryStorage"
```

---

### Task 3: VOD adapters — Xtream and M3U

**Files:**
- Create: `packages/platform_playlist/lib/src/xtream/xtream_vod_adapter.dart`
- Create: `packages/platform_playlist/lib/src/m3u_vod_adapter.dart`
- Modify: `packages/platform_playlist/lib/platform_playlist.dart`
- Test: `packages/platform_playlist/test/xtream/xtream_vod_adapter_test.dart`
- Test: `packages/platform_playlist/test/m3u_vod_adapter_test.dart`

**Interfaces:**
- Consumes: `XtreamClient.getVodStreams()` (`Future<List<XtreamVodStream>>`, already exists — fields `streamId, name, streamIcon, categoryId, containerExtension`), `XtreamClient.vodStreamUrl(int streamId, String containerExtension)` (check this exists on `XtreamClient` from CV-018 — if not, use the same URL-building convention as `liveStreamUrl`: `'$_serverUrl/movie/$_username/$_password/$streamId.$containerExtension'`, already present per CV-018's plan as `vodStreamUrl`), `IPTVChannel` (`package:platform_channels/platform_channels.dart`), `VodItem`/`VodContentKind` (Task 1).
- Produces: `class XtreamVodAdapter { XtreamVodAdapter(this._client); Future<List<VodItem>> loadVodItems(); }`; `class M3uVodAdapter { List<VodItem> extractVodItems(List<IPTVChannel> channels); }`.

**M3U VOD detection heuristic:** M3U has no VOD/live distinction (confirmed — `IPTVChannel.fromM3U`'s `_inferCategory` only keyword-matches `ChannelCategory.movies` from group/name text, with no on-demand signal). `M3uVodAdapter.extractVodItems` treats a parsed `IPTVChannel` as VOD when its `category == ChannelCategory.movies` OR its `group` (case-insensitively) contains `'vod'` or `'series'` — this is a best-effort heuristic consistent with the issue's framing ("M3U sources already carry VOD entries" via group-title convention, not a formal on-demand flag).

- [ ] **Step 1: Write the failing test for `XtreamVodAdapter`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_playlist/platform_playlist.dart';

class _FakeXtreamClient implements XtreamClient {
  _FakeXtreamClient(this._streams);
  final List<XtreamVodStream> _streams;

  @override
  Future<List<XtreamVodStream>> getVodStreams() async => _streams;

  @override
  String vodStreamUrl(int streamId, String containerExtension) =>
      'https://xtream.example.com/movie/u/p/$streamId.$containerExtension';

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

void main() {
  test('maps XtreamVodStream into VodItem with movie kind, no seriesRef', () async {
    final fakeClient = _FakeXtreamClient([
      const XtreamVodStream(
        streamId: 501,
        name: 'Example Movie',
        streamIcon: 'https://xtream.example.com/poster.jpg',
        categoryId: '10',
        containerExtension: 'mp4',
      ),
    ]);
    final adapter = XtreamVodAdapter(fakeClient);

    final items = await adapter.loadVodItems();

    expect(items, hasLength(1));
    expect(items.single.id, 'xtream-vod-501');
    expect(items.single.title, 'Example Movie');
    expect(items.single.streamUrl, 'https://xtream.example.com/movie/u/p/501.mp4');
    expect(items.single.posterUrl, 'https://xtream.example.com/poster.jpg');
    expect(items.single.kind, VodContentKind.movie);
    expect(items.single.seriesRef, isNull);
    expect(items.single.containerExtension, 'mp4');
  });

  test('defaults containerExtension to mp4 when the source omits it', () async {
    final fakeClient = _FakeXtreamClient([
      const XtreamVodStream(streamId: 502, name: 'No Extension Movie'),
    ]);
    final adapter = XtreamVodAdapter(fakeClient);

    final items = await adapter.loadVodItems();

    expect(items.single.streamUrl, 'https://xtream.example.com/movie/u/p/502.mp4');
    expect(items.single.containerExtension, 'mp4');
  });

  test('empty VOD list from source yields empty result', () async {
    final adapter = XtreamVodAdapter(_FakeXtreamClient(const []));

    final items = await adapter.loadVodItems();

    expect(items, isEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/platform_playlist && flutter test test/xtream/xtream_vod_adapter_test.dart`
Expected: FAIL — `XtreamVodAdapter` undefined.

- [ ] **Step 3: Write `lib/src/xtream/xtream_vod_adapter.dart`**

Before writing this file, check `packages/platform_playlist/lib/src/xtream/xtream_client.dart` for the exact `vodStreamUrl` signature — if it doesn't already exist on `XtreamClient` (CV-018's plan specified it but verify it landed), add it there following `liveStreamUrl`'s exact pattern: `String vodStreamUrl(int streamId, String containerExtension) => '$_serverUrl/movie/$_username/$_password/$streamId.$containerExtension';`.

```dart
import 'package:platform_channels/platform_channels.dart';

import 'xtream_client.dart';

/// Maps Xtream VOD streams into [VodItem]s. All Xtream VOD entries are
/// standalone movies from this adapter's perspective — Xtream's separate
/// series API (`get_series`) is out of scope for this issue; series
/// grouping for Xtream sources happens via the same title-parsing
/// heuristic `feature_iptv` applies to M3U (see CV-019's series/episode
/// grouping step), not a second Xtream-specific code path.
class XtreamVodAdapter {
  XtreamVodAdapter(this._client);

  final XtreamClient _client;

  Future<List<VodItem>> loadVodItems() async {
    final streams = await _client.getVodStreams();
    return [
      for (final stream in streams)
        VodItem(
          id: 'xtream-vod-${stream.streamId}',
          title: stream.name,
          streamUrl: _client.vodStreamUrl(
            stream.streamId,
            stream.containerExtension ?? 'mp4',
          ),
          posterUrl: stream.streamIcon,
          group: stream.categoryId ?? 'Uncategorized',
          kind: VodContentKind.movie,
          containerExtension: stream.containerExtension ?? 'mp4',
        ),
    ];
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd packages/platform_playlist && flutter test test/xtream/xtream_vod_adapter_test.dart`
Expected: `00:00 +3: All tests passed!`

- [ ] **Step 5: Write the failing test for `M3uVodAdapter`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_playlist/platform_playlist.dart';

void main() {
  final adapter = M3uVodAdapter();

  test('a channel categorized as movies is extracted as a VodItem', () {
    final channel = IPTVChannel.fromM3U(
      name: 'Example Movie',
      url: 'https://example.com/movie.mp4',
      group: 'Movies',
    );

    final items = adapter.extractVodItems([channel]);

    expect(items, hasLength(1));
    expect(items.single.id, channel.id);
    expect(items.single.title, 'Example Movie');
    expect(items.single.streamUrl, channel.streamUrl);
    expect(items.single.kind, VodContentKind.movie);
  });

  test('a channel whose group contains "VOD" is extracted', () {
    final channel = IPTVChannel.fromM3U(
      name: 'Some Title',
      url: 'https://example.com/vod-item.mp4',
      group: 'US VOD',
    );

    final items = adapter.extractVodItems([channel]);

    expect(items, hasLength(1));
  });

  test('a channel whose group contains "Series" is extracted', () {
    final channel = IPTVChannel.fromM3U(
      name: 'Example Show S01E01',
      url: 'https://example.com/series/1.mp4',
      group: 'TV Series',
    );

    final items = adapter.extractVodItems([channel]);

    expect(items, hasLength(1));
  });

  test('a live news channel is not extracted', () {
    final channel = IPTVChannel.fromM3U(
      name: 'Example News',
      url: 'https://example.com/news.m3u8',
      group: 'News',
    );

    final items = adapter.extractVodItems([channel]);

    expect(items, isEmpty);
  });

  test('empty source list yields empty result', () {
    expect(adapter.extractVodItems(const []), isEmpty);
  });
}
```

- [ ] **Step 6: Run test to verify it fails**

Run: `cd packages/platform_playlist && flutter test test/m3u_vod_adapter_test.dart`
Expected: FAIL — `M3uVodAdapter` undefined.

- [ ] **Step 7: Write `lib/src/m3u_vod_adapter.dart`**

```dart
import 'package:platform_channels/platform_channels.dart';

/// Best-effort extraction of VOD-shaped entries from an M3U-parsed channel
/// list. M3U has no formal on-demand/live distinction (see CV-019's plan
/// notes) — this treats a channel as VOD when [IPTVChannel.category] is
/// already inferred as [ChannelCategory.movies], or its [IPTVChannel.group]
/// mentions "vod" or "series" (case-insensitive), matching the group-title
/// convention BYOC M3U providers commonly use to mark on-demand content.
class M3uVodAdapter {
  List<VodItem> extractVodItems(List<IPTVChannel> channels) {
    return [
      for (final channel in channels)
        if (_isVodShaped(channel))
          VodItem(
            id: channel.id,
            title: channel.name,
            streamUrl: channel.streamUrl,
            posterUrl: channel.logoUrl,
            group: channel.group,
            kind: VodContentKind.movie,
          ),
    ];
  }

  bool _isVodShaped(IPTVChannel channel) {
    if (channel.category == ChannelCategory.movies) return true;
    final group = channel.group.toLowerCase();
    return group.contains('vod') || group.contains('series');
  }
}
```

- [ ] **Step 8: Run tests to verify they pass**

Run: `cd packages/platform_playlist && flutter test test/m3u_vod_adapter_test.dart`
Expected: `00:00 +5: All tests passed!`

- [ ] **Step 9: Export new files from the barrel**

Add to `packages/platform_playlist/lib/platform_playlist.dart`:

```dart
export 'src/xtream/xtream_vod_adapter.dart';
export 'src/m3u_vod_adapter.dart';
```

- [ ] **Step 10: Run the full `platform_playlist` suite**

Run: `cd packages/platform_playlist && flutter test`
Expected: all tests pass, no regressions.

- [ ] **Step 11: Commit**

```bash
git add packages/platform_playlist
git commit -m "feat(platform_playlist): add Xtream and M3U VOD adapters"
```

---

### Task 4: Series/episode grouping heuristic

**Files:**
- Create: `packages/feature_iptv/lib/domain/vod_series_grouping.dart`
- Test: `packages/feature_iptv/test/iptv/domain/vod_series_grouping_test.dart`

**Interfaces:**
- Consumes: `VodItem` (`package:platform_channels/platform_channels.dart`).
- Produces: `class VodSeriesGrouper { VodItem applySeriesRef(VodItem item); List<VodItem> applySeriesRefs(List<VodItem> items); }`; `class VodSeriesGroup { String seriesId, String seriesTitle, List<VodItem> episodes }`; a top-level `List<VodSeriesGroup> groupVodItemsBySeries(List<VodItem> items)` that partitions a flat item list into series groups plus standalone movies (movies stay as individual `VodItem`s, not wrapped in a group — the provider layer, Task 5, handles presenting both kinds together).

**Grouping heuristic:** parse `VodItem.title` for a `S<season>E<episode>` pattern (case-insensitive, e.g. `"Example Show S01E02"`, `"Example Show S1E2"`, `"Example Show - S01E02 - Episode Title"`). When matched: `seriesTitle` is everything before the `S..E..` marker (trimmed of trailing punctuation/whitespace), `seriesId` is a normalized slug of `seriesTitle` (lowercase, non-alphanumeric collapsed to `-`), and the item becomes `VodContentKind.episode` with a populated `seriesRef`. Unmatched titles stay `VodContentKind.movie` with no `seriesRef`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:feature_iptv/domain/vod_series_grouping.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';

void main() {
  group('VodSeriesGrouper.applySeriesRef', () {
    final grouper = VodSeriesGrouper();

    test('parses "Show Name S01E02"', () {
      const item = VodItem(
        id: '1',
        title: 'Example Show S01E02',
        streamUrl: 'https://example.com/1.mp4',
        group: 'Series',
        kind: VodContentKind.movie,
      );

      final result = grouper.applySeriesRef(item);

      expect(result.kind, VodContentKind.episode);
      expect(result.seriesRef?.seriesTitle, 'Example Show');
      expect(result.seriesRef?.seriesId, 'example-show');
      expect(result.seriesRef?.seasonNumber, 1);
      expect(result.seriesRef?.episodeNumber, 2);
    });

    test('parses single-digit "Show Name S1E2"', () {
      const item = VodItem(
        id: '2',
        title: 'Example Show S1E2',
        streamUrl: 'https://example.com/2.mp4',
        group: 'Series',
        kind: VodContentKind.movie,
      );

      final result = grouper.applySeriesRef(item);

      expect(result.seriesRef?.seasonNumber, 1);
      expect(result.seriesRef?.episodeNumber, 2);
    });

    test('parses "Show Name - S01E02 - Episode Title", trimming trailing punctuation', () {
      const item = VodItem(
        id: '3',
        title: 'Example Show - S01E02 - The Big One',
        streamUrl: 'https://example.com/3.mp4',
        group: 'Series',
        kind: VodContentKind.movie,
      );

      final result = grouper.applySeriesRef(item);

      expect(result.seriesRef?.seriesTitle, 'Example Show');
    });

    test('a title with no S00E00 pattern stays a movie with no seriesRef', () {
      const item = VodItem(
        id: '4',
        title: 'Example Movie',
        streamUrl: 'https://example.com/4.mp4',
        group: 'Movies',
        kind: VodContentKind.movie,
      );

      final result = grouper.applySeriesRef(item);

      expect(result.kind, VodContentKind.movie);
      expect(result.seriesRef, isNull);
      expect(result.title, 'Example Movie');
    });

    test('same series title always yields the same seriesId', () {
      const a = VodItem(
        id: '5',
        title: 'Example Show S01E01',
        streamUrl: 'https://example.com/5.mp4',
        group: 'Series',
        kind: VodContentKind.movie,
      );
      const b = VodItem(
        id: '6',
        title: 'Example Show S02E10',
        streamUrl: 'https://example.com/6.mp4',
        group: 'Series',
        kind: VodContentKind.movie,
      );

      final resultA = grouper.applySeriesRef(a);
      final resultB = grouper.applySeriesRef(b);

      expect(resultA.seriesRef?.seriesId, resultB.seriesRef?.seriesId);
    });
  });

  group('groupVodItemsBySeries', () {
    test('partitions episodes into series groups and leaves movies standalone', () {
      final items = [
        const VodItem(
          id: '1',
          title: 'Example Show S01E01',
          streamUrl: 'https://example.com/1.mp4',
          group: 'Series',
          kind: VodContentKind.episode,
          seriesRef: VodSeriesRef(
            seriesId: 'example-show',
            seriesTitle: 'Example Show',
            seasonNumber: 1,
            episodeNumber: 1,
          ),
        ),
        const VodItem(
          id: '2',
          title: 'Example Show S01E02',
          streamUrl: 'https://example.com/2.mp4',
          group: 'Series',
          kind: VodContentKind.episode,
          seriesRef: VodSeriesRef(
            seriesId: 'example-show',
            seriesTitle: 'Example Show',
            seasonNumber: 1,
            episodeNumber: 2,
          ),
        ),
        const VodItem(
          id: '3',
          title: 'Example Movie',
          streamUrl: 'https://example.com/3.mp4',
          group: 'Movies',
          kind: VodContentKind.movie,
        ),
      ];

      final groups = groupVodItemsBySeries(items);

      expect(groups, hasLength(1));
      expect(groups.single.seriesId, 'example-show');
      expect(groups.single.episodes, hasLength(2));
    });

    test('episodes within a group are sorted by season then episode number', () {
      final items = [
        const VodItem(
          id: '1',
          title: 'Example Show S01E02',
          streamUrl: 'https://example.com/1.mp4',
          group: 'Series',
          kind: VodContentKind.episode,
          seriesRef: VodSeriesRef(
            seriesId: 'example-show',
            seriesTitle: 'Example Show',
            seasonNumber: 1,
            episodeNumber: 2,
          ),
        ),
        const VodItem(
          id: '2',
          title: 'Example Show S01E01',
          streamUrl: 'https://example.com/2.mp4',
          group: 'Series',
          kind: VodContentKind.episode,
          seriesRef: VodSeriesRef(
            seriesId: 'example-show',
            seriesTitle: 'Example Show',
            seasonNumber: 1,
            episodeNumber: 1,
          ),
        ),
      ];

      final groups = groupVodItemsBySeries(items);

      expect(groups.single.episodes.map((e) => e.id), ['2', '1']);
    });

    test('empty input yields empty output', () {
      expect(groupVodItemsBySeries(const []), isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/feature_iptv && flutter test test/iptv/domain/vod_series_grouping_test.dart`
Expected: FAIL — `vod_series_grouping.dart` does not exist.

- [ ] **Step 3: Write `lib/domain/vod_series_grouping.dart`**

```dart
import 'package:platform_channels/platform_channels.dart';

/// Detects a "Show Name S01E02" / "Show Name S1E2" pattern anywhere in a
/// title, capturing season and episode numbers.
final RegExp _seasonEpisodePattern = RegExp(
  r'^(.*?)[\s\-]*S(\d{1,2})E(\d{1,2})\b',
  caseSensitive: false,
);

/// Applies a best-effort series/episode grouping heuristic to [VodItem]s
/// parsed from BYOC sources with no formal series metadata. See CV-019:
/// no third-party lookup, title-pattern matching only.
class VodSeriesGrouper {
  /// Returns [item] unchanged if its title doesn't match a season/episode
  /// pattern, or a copy with [VodContentKind.episode] and a populated
  /// [VodItem.seriesRef] if it does.
  VodItem applySeriesRef(VodItem item) {
    final match = _seasonEpisodePattern.firstMatch(item.title);
    if (match == null) return item;

    final seriesTitle = match.group(1)!.trim();
    if (seriesTitle.isEmpty) return item;

    final seasonNumber = int.parse(match.group(2)!);
    final episodeNumber = int.parse(match.group(3)!);

    return VodItem(
      id: item.id,
      title: item.title,
      streamUrl: item.streamUrl,
      posterUrl: item.posterUrl,
      group: item.group,
      kind: VodContentKind.episode,
      containerExtension: item.containerExtension,
      seriesRef: VodSeriesRef(
        seriesId: _slugify(seriesTitle),
        seriesTitle: seriesTitle,
        seasonNumber: seasonNumber,
        episodeNumber: episodeNumber,
      ),
    );
  }

  List<VodItem> applySeriesRefs(List<VodItem> items) =>
      items.map(applySeriesRef).toList();

  String _slugify(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }
}

/// One series and its episodes, sorted by season then episode number.
class VodSeriesGroup {
  const VodSeriesGroup({
    required this.seriesId,
    required this.seriesTitle,
    required this.episodes,
  });

  final String seriesId;
  final String seriesTitle;
  final List<VodItem> episodes;
}

/// Partitions [items] (already passed through [VodSeriesGrouper]) into
/// series groups. Items with [VodContentKind.movie] (no [VodItem.seriesRef])
/// are not included — the caller presents movies and series groups
/// side by side, not nested.
List<VodSeriesGroup> groupVodItemsBySeries(List<VodItem> items) {
  final bySeriesId = <String, List<VodItem>>{};
  final seriesTitleById = <String, String>{};

  for (final item in items) {
    final ref = item.seriesRef;
    if (ref == null) continue;
    (bySeriesId[ref.seriesId] ??= []).add(item);
    seriesTitleById[ref.seriesId] = ref.seriesTitle;
  }

  final groups = [
    for (final entry in bySeriesId.entries)
      VodSeriesGroup(
        seriesId: entry.key,
        seriesTitle: seriesTitleById[entry.key]!,
        episodes: entry.value
          ..sort((a, b) {
            final seasonCompare = (a.seriesRef!.seasonNumber ?? 0)
                .compareTo(b.seriesRef!.seasonNumber ?? 0);
            if (seasonCompare != 0) return seasonCompare;
            return (a.seriesRef!.episodeNumber ?? 0)
                .compareTo(b.seriesRef!.episodeNumber ?? 0);
          }),
      ),
  ];

  return groups;
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd packages/feature_iptv && flutter test test/iptv/domain/vod_series_grouping_test.dart`
Expected: `00:00 +9: All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add packages/feature_iptv/lib/domain packages/feature_iptv/test/iptv/domain
git commit -m "feat(feature_iptv): add VOD series/episode grouping heuristic"
```

---

### Task 5: VOD Riverpod providers

**Files:**
- Create: `packages/feature_iptv/lib/application/providers/vod_providers.dart`
- Test: `packages/feature_iptv/test/iptv/application/providers/vod_providers_test.dart`

**Interfaces:**
- Consumes: `VodItem`, `M3uVodAdapter`, `XtreamVodAdapter`, `VodWatchHistoryStorage` (Tasks 1-3), `VodSeriesGrouper`/`groupVodItemsBySeries`/`VodSeriesGroup` (Task 4), `dioProvider`/`sharedPreferencesProvider`/`m3uParserProvider`/`iptvChannelsProvider` (existing, `iptv_providers.dart` — **read-only reuse, this task does not modify `iptv_providers.dart`**).
- Produces: `vodWatchHistoryStorageProvider = Provider<VodWatchHistoryStorage>`; `rawVodItemsProvider = FutureProvider<List<VodItem>>` (aggregates M3U-derived VOD items from the already-fetched `iptvChannelsProvider` list, via `M3uVodAdapter` — no separate HTTP fetch, reuses data already in memory); `vodItemsProvider = Provider<List<VodItem>>` (applies `VodSeriesGrouper` to `rawVodItemsProvider`'s data, returns `[]` while loading/on error); `vodSeriesGroupsProvider = Provider<List<VodSeriesGroup>>`; `vodStandaloneMoviesProvider = Provider<List<VodItem>>` (items with no `seriesRef`); `vodSearchQueryProvider = StateProvider<String>('')`; `filteredVodMoviesProvider = Provider<List<VodItem>>`; `filteredVodSeriesGroupsProvider = Provider<List<VodSeriesGroup>>`; `vodContinueWatchingProvider = FutureProvider<List<VodItem>>`; `addToVodWatchHistoryProvider = FutureProvider.family<void, VodItem>`.

**Scope note:** this task wires the M3U path (VOD items already present in `iptvChannelsProvider`'s fetched list — no new network call) fully. Wiring a live `XtreamVodAdapter` call requires an active, user-configured `XtreamContentSource` with credentials, which CV-022 (TV settings/provider management) is the first issue to actually let a user configure — until then there's no `XtreamContentSource` instance anywhere in the running app to call `XtreamVodAdapter` against. `rawVodItemsProvider` is written so wiring in a live Xtream source later is additive (append its adapter's output to the list), not a rewrite — but no such wiring happens in this task. Note this explicitly in the task's self-review.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:feature_iptv/application/providers/iptv_providers.dart';
import 'package:feature_iptv/application/providers/vod_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const movieChannel = IPTVChannel(
    id: 'm3u-1',
    name: 'Example Movie',
    streamUrl: 'https://example.com/movie.mp4',
    group: 'Movies',
    category: ChannelCategory.movies,
  );
  const seriesChannel = IPTVChannel(
    id: 'm3u-2',
    name: 'Example Show S01E01',
    streamUrl: 'https://example.com/1.mp4',
    group: 'TV Series',
    category: ChannelCategory.all,
  );
  const liveChannel = IPTVChannel(
    id: 'm3u-3',
    name: 'Example News',
    streamUrl: 'https://example.com/news.m3u8',
    group: 'News',
    category: ChannelCategory.news,
  );

  ProviderContainer buildContainer(List<IPTVChannel> channels) {
    final prefs = SharedPreferences.getInstance();
    return ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(
          // ignore: invalid_use_of_visible_for_testing_member
          prefs as SharedPreferences,
        ),
        iptvChannelsProvider.overrideWith((ref) async => channels),
      ],
    );
  }

  test('vodItemsProvider extracts and groups VOD entries from iptvChannelsProvider', () async {
    final container = buildContainer([movieChannel, seriesChannel, liveChannel]);
    addTearDown(container.dispose);

    await container.read(rawVodItemsProvider.future);
    final items = container.read(vodItemsProvider);

    expect(items.map((i) => i.id), containsAll(['m3u-1', 'm3u-2']));
    expect(items.any((i) => i.id == 'm3u-3'), isFalse);
  });

  test('vodStandaloneMoviesProvider excludes grouped episodes', () async {
    final container = buildContainer([movieChannel, seriesChannel]);
    addTearDown(container.dispose);

    await container.read(rawVodItemsProvider.future);
    final movies = container.read(vodStandaloneMoviesProvider);

    expect(movies.map((i) => i.id), ['m3u-1']);
  });

  test('vodSeriesGroupsProvider groups the series episode', () async {
    final container = buildContainer([movieChannel, seriesChannel]);
    addTearDown(container.dispose);

    await container.read(rawVodItemsProvider.future);
    final groups = container.read(vodSeriesGroupsProvider);

    expect(groups, hasLength(1));
    expect(groups.single.seriesTitle, 'Example Show');
  });

  test('empty source yields empty vodItemsProvider (empty-state case)', () async {
    final container = buildContainer([liveChannel]);
    addTearDown(container.dispose);

    await container.read(rawVodItemsProvider.future);
    final items = container.read(vodItemsProvider);

    expect(items, isEmpty);
  });

  test('filteredVodMoviesProvider filters standalone movies by search query', () async {
    const anotherMovie = IPTVChannel(
      id: 'm3u-4',
      name: 'Second Feature',
      streamUrl: 'https://example.com/second.mp4',
      group: 'Movies',
      category: ChannelCategory.movies,
    );
    final container = buildContainer([movieChannel, anotherMovie]);
    addTearDown(container.dispose);

    await container.read(rawVodItemsProvider.future);
    container.read(vodSearchQueryProvider.notifier).state = 'second';
    final filtered = container.read(filteredVodMoviesProvider);

    expect(filtered.map((i) => i.id), ['m3u-4']);
  });

  test('addToVodWatchHistoryProvider then vodContinueWatchingProvider round-trips', () async {
    final container = buildContainer([movieChannel]);
    addTearDown(container.dispose);

    await container.read(rawVodItemsProvider.future);
    final item = container.read(vodItemsProvider).single;

    await container.read(addToVodWatchHistoryProvider(item).future);
    final history = await container.read(vodContinueWatchingProvider.future);

    expect(history.map((i) => i.id), [item.id]);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/feature_iptv && flutter test test/iptv/application/providers/vod_providers_test.dart`
Expected: FAIL — `vod_providers.dart` does not exist.

- [ ] **Step 3: Write `lib/application/providers/vod_providers.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_history/platform_history.dart';
import 'package:platform_playlist/platform_playlist.dart';

import '../../domain/vod_series_grouping.dart';
import 'iptv_providers.dart';

final vodWatchHistoryStorageProvider = Provider<VodWatchHistoryStorage>((ref) {
  return VodWatchHistoryStorage(ref.watch(sharedPreferencesProvider));
});

final _m3uVodAdapterProvider = Provider<M3uVodAdapter>((ref) => M3uVodAdapter());

/// VOD entries extracted from the M3U channel list `iptvChannelsProvider`
/// has already fetched — no separate network call. A live Xtream source's
/// `XtreamVodAdapter` output can be appended here once CV-022 lets a user
/// configure one; until then this is M3U-only.
final rawVodItemsProvider = FutureProvider<List<VodItem>>((ref) async {
  final channels = await ref.watch(iptvChannelsProvider.future);
  final adapter = ref.watch(_m3uVodAdapterProvider);
  return adapter.extractVodItems(channels);
});

final _vodSeriesGrouperProvider = Provider<VodSeriesGrouper>(
  (ref) => VodSeriesGrouper(),
);

/// All VOD items with the series/episode grouping heuristic applied.
/// Empty while [rawVodItemsProvider] is loading or has errored.
final vodItemsProvider = Provider<List<VodItem>>((ref) {
  final raw = ref.watch(rawVodItemsProvider).valueOrNull ?? const [];
  final grouper = ref.watch(_vodSeriesGrouperProvider);
  return grouper.applySeriesRefs(raw);
});

final vodSeriesGroupsProvider = Provider<List<VodSeriesGroup>>((ref) {
  return groupVodItemsBySeries(ref.watch(vodItemsProvider));
});

final vodStandaloneMoviesProvider = Provider<List<VodItem>>((ref) {
  return [
    for (final item in ref.watch(vodItemsProvider))
      if (item.seriesRef == null) item,
  ];
});

final vodSearchQueryProvider = StateProvider<String>((ref) => '');

final filteredVodMoviesProvider = Provider<List<VodItem>>((ref) {
  final query = ref.watch(vodSearchQueryProvider).trim().toLowerCase();
  final movies = ref.watch(vodStandaloneMoviesProvider);
  if (query.isEmpty) return movies;
  return [
    for (final item in movies)
      if (item.title.toLowerCase().contains(query)) item,
  ];
});

final filteredVodSeriesGroupsProvider = Provider<List<VodSeriesGroup>>((ref) {
  final query = ref.watch(vodSearchQueryProvider).trim().toLowerCase();
  final groups = ref.watch(vodSeriesGroupsProvider);
  if (query.isEmpty) return groups;
  return [
    for (final group in groups)
      if (group.seriesTitle.toLowerCase().contains(query)) group,
  ];
});

final vodContinueWatchingProvider = FutureProvider<List<VodItem>>((ref) async {
  final storage = ref.watch(vodWatchHistoryStorageProvider);
  return storage.getRecentlyWatched(limit: 10);
});

final addToVodWatchHistoryProvider = FutureProvider.family<void, VodItem>((
  ref,
  item,
) async {
  final storage = ref.watch(vodWatchHistoryStorageProvider);
  await storage.addToRecent(item);
  ref.invalidate(vodContinueWatchingProvider);
});
```

Check `sharedPreferencesProvider`'s exact name/location in `iptv_providers.dart` before writing the import (per earlier exploration it's `Provider<SharedPreferences>` in that same file) — reuse it as-is, don't redeclare it.

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd packages/feature_iptv && flutter test test/iptv/application/providers/vod_providers_test.dart`
Expected: `00:00 +6: All tests passed!`

- [ ] **Step 5: Run the full `feature_iptv` suite — confirm zero regressions**

Run: `cd packages/feature_iptv && flutter test`
Expected: all existing tests still pass (130/130 baseline from CV-018), plus the 6 new VOD provider tests.

- [ ] **Step 6: Commit**

```bash
git add packages/feature_iptv/lib/application/providers/vod_providers.dart packages/feature_iptv/test/iptv/application/providers/vod_providers_test.dart
git commit -m "feat(feature_iptv): add VOD Riverpod providers (aggregation, grouping, search, continue-watching)"
```

---

### Task 6: VOD grid (TV) and list (phone) widgets

**Files:**
- Create: `packages/feature_iptv/lib/presentation/widgets/vod_grid.dart`
- Create: `packages/feature_iptv/lib/presentation/widgets/vod_list_widget.dart`
- Test: `packages/feature_iptv/test/iptv/presentation/widgets/vod_grid_test.dart`

**Interfaces:**
- Consumes: `VodItem`, `filteredVodMoviesProvider`, `filteredVodSeriesGroupsProvider`, `vodSearchQueryProvider` (Task 5), `tvDimensionsProvider` (`package:feature_iptv/presentation/tv/iptv_tv.dart`, existing), `TvFocusable`/`TvFocusConstants` (`package:core_ui/core_ui.dart`).
- Produces: `class VodGrid extends ConsumerWidget { VodGrid({required void Function(VodItem) onItemSelect}); }` (renders standalone movies and series groups — a group tile opens to its episode list via `onItemSelect`'s caller, see Task 7's screen for the two-level navigation); `class VodListWidget extends ConsumerWidget { VodListWidget({required void Function(VodItem) onItemTap}); }` (phone-oriented list, mirrors `ChannelListWidget`'s search-bar pattern).

`VodGrid` is a deliberately simpler sibling of `TvChannelGrid` — same `TvFocusable`/`TvUiDimensions`/`GridView.builder` shape, no thumbnail preloading or D-pad channel-up/down debounce logic (VOD lists don't need Fire TV channel-key handling, and are typically much shorter than full channel lists).

- [ ] **Step 1: Write the failing widget test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feature_iptv/application/providers/iptv_providers.dart';
import 'package:feature_iptv/application/providers/vod_providers.dart';
import 'package:feature_iptv/presentation/widgets/vod_grid.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const movie = IPTVChannel(
    id: 'm3u-1',
    name: 'Example Movie',
    streamUrl: 'https://example.com/movie.mp4',
    group: 'Movies',
    category: ChannelCategory.movies,
  );

  testWidgets('renders a card per standalone VOD movie', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    VodItem? selected;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          iptvChannelsProvider.overrideWith((ref) async => [movie]),
        ],
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(1280, 720),
              navigationMode: NavigationMode.directional,
            ),
            child: Scaffold(
              body: SizedBox(
                width: 1280,
                height: 720,
                child: VodGrid(onItemSelect: (item) => selected = item),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Example Movie'), findsOneWidget);
  });

  testWidgets('shows empty state when there are no VOD entries', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    const liveOnly = IPTVChannel(
      id: 'm3u-2',
      name: 'Example News',
      streamUrl: 'https://example.com/news.m3u8',
      group: 'News',
      category: ChannelCategory.news,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          iptvChannelsProvider.overrideWith((ref) async => [liveOnly]),
        ],
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(1280, 720),
              navigationMode: NavigationMode.directional,
            ),
            child: Scaffold(
              body: SizedBox(width: 1280, height: 720, child: VodGrid()),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('No movies or shows found'), findsOneWidget);
  });
}
```

(`VodGrid()` in the second test omits `onItemSelect` — check whether the constructor should make it optional/nullable or the test should always pass a no-op callback; prefer making `onItemSelect` `void Function(VodItem)?` with a nullable default so the empty-state test doesn't need a callback it never triggers — simpler than forcing every test to supply one.)

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/widgets/vod_grid_test.dart`
Expected: FAIL — `vod_grid.dart` does not exist.

- [ ] **Step 3: Write `lib/presentation/widgets/vod_grid.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core_ui/core_ui.dart';
import 'package:platform_channels/platform_channels.dart';

import '../../application/providers/vod_providers.dart';
import '../../domain/vod_series_grouping.dart';
import '../tv/iptv_tv.dart';

/// TV-optimized grid of VOD movies and series groups. A series group card
/// carries its first episode's [VodItem] in [onItemSelect] for now — full
/// per-episode selection (opening an episode list) is presentation-layer
/// work the screen (not this widget) composes on top, per this issue's
/// scope (no per-title detail page, see CV-019 non-goals).
class VodGrid extends ConsumerWidget {
  const VodGrid({super.key, this.onItemSelect});

  final void Function(VodItem item)? onItemSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movies = ref.watch(filteredVodMoviesProvider);
    final seriesGroups = ref.watch(filteredVodSeriesGroupsProvider);
    final dimensions = ref.watch(tvDimensionsProvider(context));

    if (movies.isEmpty && seriesGroups.isEmpty) {
      return const Center(
        child: Text(
          'No movies or shows found',
          style: TextStyle(color: Colors.white70, fontSize: 18),
        ),
      );
    }

    final tileCount = movies.length + seriesGroups.length;
    final padding = EdgeInsets.all(dimensions.gridSpacing) + dimensions.safeZone;

    return GridView.builder(
      padding: padding,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _crossAxisCount(context, dimensions),
        childAspectRatio: dimensions.channelCardWidth / dimensions.channelCardHeight,
        mainAxisSpacing: dimensions.gridSpacing,
        crossAxisSpacing: dimensions.gridSpacing,
      ),
      itemCount: tileCount,
      itemBuilder: (context, index) {
        if (index < movies.length) {
          final movie = movies[index];
          return _VodCard(
            key: ValueKey('vod_movie_card_${movie.id}'),
            title: movie.title,
            posterUrl: movie.posterUrl,
            dimensions: dimensions,
            autofocus: index == 0,
            onSelect: () => onItemSelect?.call(movie),
          );
        }
        final group = seriesGroups[index - movies.length];
        return _VodCard(
          key: ValueKey('vod_series_card_${group.seriesId}'),
          title: group.seriesTitle,
          posterUrl: group.episodes.first.posterUrl,
          dimensions: dimensions,
          autofocus: movies.isEmpty && index == movies.length,
          onSelect: () => onItemSelect?.call(group.episodes.first),
        );
      },
    );
  }

  int _crossAxisCount(BuildContext context, TvUiDimensions dimensions) {
    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = screenWidth - (dimensions.gridSpacing * 2);
    final cardWidth = dimensions.channelCardWidth + dimensions.gridSpacing;
    return (availableWidth / cardWidth).floor().clamp(3, 8);
  }
}

class _VodCard extends StatelessWidget {
  const _VodCard({
    super.key,
    required this.title,
    required this.posterUrl,
    required this.dimensions,
    required this.autofocus,
    required this.onSelect,
  });

  final String title;
  final String? posterUrl;
  final TvUiDimensions dimensions;
  final bool autofocus;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: TvFocusable(
        onSelect: onSelect,
        autofocus: autofocus,
        semanticLabel: title,
        semanticHint: 'Press OK to open',
        semanticButton: true,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey[850],
            borderRadius: BorderRadius.circular(TvFocusConstants.focusBorderRadius),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                flex: 3,
                child: Padding(
                  padding: EdgeInsets.all(dimensions.cardPadding),
                  child: posterUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: AiroNetworkImage(
                            url: posterUrl!,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.movie, color: Colors.white54, size: 48),
                          ),
                        )
                      : const Icon(Icons.movie, color: Colors.white54, size: 48),
                ),
              ),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: dimensions.cardPadding),
                  child: Text(
                    title,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14 * dimensions.textScaleFactor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

Check `AiroNetworkImage`'s exact import path (`package:core_ui/core_ui.dart` per `tv_channel_grid.dart`'s usage) before writing — reuse the same widget, don't invent a new image loader.

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/widgets/vod_grid_test.dart`
Expected: `00:00 +2: All tests passed!`

- [ ] **Step 5: Write `lib/presentation/widgets/vod_list_widget.dart`** (phone-oriented, mirrors `ChannelListWidget`'s structure)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core_ui/core_ui.dart';
import 'package:platform_channels/platform_channels.dart';

import '../../application/providers/vod_providers.dart';

/// Phone-oriented VOD list: a search bar plus a scrollable list of movies
/// and series groups, mirroring [ChannelListWidget]'s layout pattern for
/// live channels.
class VodListWidget extends ConsumerWidget {
  const VodListWidget({super.key, this.onItemTap});

  final void Function(VodItem item)? onItemTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movies = ref.watch(filteredVodMoviesProvider);
    final seriesGroups = ref.watch(filteredVodSeriesGroupsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search movies and shows',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (value) =>
                ref.read(vodSearchQueryProvider.notifier).state = value,
          ),
        ),
        if (movies.isEmpty && seriesGroups.isEmpty)
          const Expanded(
            child: Center(child: Text('No movies or shows found')),
          )
        else
          Expanded(
            child: ListView(
              children: [
                for (final movie in movies)
                  ListTile(
                    key: ValueKey('vod_movie_tile_${movie.id}'),
                    leading: movie.posterUrl != null
                        ? AiroNetworkImage(url: movie.posterUrl!, width: 48)
                        : const Icon(Icons.movie),
                    title: Text(movie.title),
                    onTap: () => onItemTap?.call(movie),
                  ),
                for (final group in seriesGroups)
                  ListTile(
                    key: ValueKey('vod_series_tile_${group.seriesId}'),
                    leading: group.episodes.first.posterUrl != null
                        ? AiroNetworkImage(
                            url: group.episodes.first.posterUrl!,
                            width: 48,
                          )
                        : const Icon(Icons.video_library),
                    title: Text(group.seriesTitle),
                    subtitle: Text('${group.episodes.length} episodes'),
                    onTap: () => onItemTap?.call(group.episodes.first),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
```

- [ ] **Step 6: Run analyzer to confirm no compile errors**

Run: `cd packages/feature_iptv && flutter analyze lib/presentation/widgets/vod_list_widget.dart`
Expected: no errors.

- [ ] **Step 7: Commit**

```bash
git add packages/feature_iptv/lib/presentation/widgets/vod_grid.dart packages/feature_iptv/lib/presentation/widgets/vod_list_widget.dart packages/feature_iptv/test/iptv/presentation/widgets/vod_grid_test.dart
git commit -m "feat(feature_iptv): add VOD grid (TV) and list (phone) widgets"
```

---

### Task 7: VOD screens (TV + phone) with continue-watching row

**Files:**
- Create: `packages/feature_iptv/lib/presentation/tv/vod_tv_screen.dart`
- Create: `packages/feature_iptv/lib/presentation/screens/vod_screen.dart`
- Modify: `packages/feature_iptv/lib/feature_iptv.dart`
- Test: `packages/feature_iptv/test/iptv/presentation/tv/vod_tv_screen_test.dart`

**Interfaces:**
- Consumes: `VodGrid`, `VodListWidget` (Task 6), `vodContinueWatchingProvider`, `addToVodWatchHistoryProvider` (Task 5).
- Produces: `class VodTvScreen extends ConsumerWidget` (TV screen: continue-watching row at top when non-empty, `VodGrid` below, empty state when the source has no VOD at all); `class VodScreen extends ConsumerWidget` (phone screen: `VodListWidget` plus a continue-watching horizontal row above it, same empty-state text).

Selecting a `VodItem` in either screen calls `ref.read(addToVodWatchHistoryProvider(item).future)` (fire-and-forget is fine here, matching `IptvTvScreen._playChannel`'s existing pattern for live channels) then hands off to playback — this plan does **not** build a VOD player screen; per the issue, VOD streams the same way live channels do, so both screens' item-select callback should reuse whatever playback launch mechanism `IptvTvScreen`/`IPTVScreen` already use for a raw stream URL (check `IptvTvScreen._playChannel`/`IPTVScreen`'s player-launch call before writing this — likely `iptvStreamingServiceProvider` or navigating to the existing player route with the URL). If no such generic "play this URL" entry point exists and only channel-object-shaped playback exists, report this to the controller as **BLOCKED** rather than inventing a parallel player — that decision needs the controller/user, not a unilateral new player stack.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feature_iptv/application/providers/iptv_providers.dart';
import 'package:feature_iptv/presentation/tv/vod_tv_screen.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const movie = IPTVChannel(
    id: 'm3u-1',
    name: 'Example Movie',
    streamUrl: 'https://example.com/movie.mp4',
    group: 'Movies',
    category: ChannelCategory.movies,
  );

  testWidgets('shows VOD grid content when the source has VOD entries', (tester) async {
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          iptvChannelsProvider.overrideWith((ref) async => [movie]),
        ],
        child: const MaterialApp(home: VodTvScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Example Movie'), findsOneWidget);
  });

  testWidgets('shows empty state when the source has no VOD entries', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    const liveOnly = IPTVChannel(
      id: 'm3u-2',
      name: 'Example News',
      streamUrl: 'https://example.com/news.m3u8',
      group: 'News',
      category: ChannelCategory.news,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          iptvChannelsProvider.overrideWith((ref) async => [liveOnly]),
        ],
        child: const MaterialApp(home: VodTvScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('No movies or shows found'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/tv/vod_tv_screen_test.dart`
Expected: FAIL — `vod_tv_screen.dart` does not exist.

- [ ] **Step 3: Investigate the existing playback launch mechanism before writing screens**

Read `packages/feature_iptv/lib/presentation/tv/iptv_tv_screen.dart`'s `_playChannel` method (and `IPTVScreen`'s equivalent) in full. If it takes an `IPTVChannel` specifically (not just a URL) because it reads multiple channel fields (headers, quality URLs, etc.) beyond just `streamUrl`, the cleanest fix consistent with existing patterns is to construct a minimal synthetic `IPTVChannel` from the `VodItem` purely for the player call (`IPTVChannel(id: item.id, name: item.title, streamUrl: item.streamUrl, logoUrl: item.posterUrl, group: item.group)`) — this is different from Task 2's rejected "synthetic IPTVChannel for storage" pattern (that was rejected because it corrupted a *shared, persisted, cross-content-type* history list); a same-request, non-persisted, player-launch-only conversion is a normal adapter-at-the-boundary pattern, not the same risk. Confirm this reasoning holds by reading the actual player call site before writing the screens — if `_playChannel` does something VOD-incompatible (e.g. assumes live-only headers/DRM), report BLOCKED with specifics instead of guessing.

- [ ] **Step 4: Write `lib/presentation/tv/vod_tv_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_channels/platform_channels.dart';

import '../../application/providers/vod_providers.dart';
import '../widgets/vod_grid.dart';

class VodTvScreen extends ConsumerWidget {
  const VodTvScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final continueWatching = ref.watch(vodContinueWatchingProvider).valueOrNull ?? const [];

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (continueWatching.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Text(
                  'Continue Watching',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(
                height: 150,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: continueWatching.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 16),
                  itemBuilder: (context, index) {
                    final item = continueWatching[index];
                    return SizedBox(
                      width: 200,
                      child: _ContinueWatchingTile(
                        item: item,
                        onSelect: () => _selectItem(ref, item),
                      ),
                    );
                  },
                ),
              ),
            ],
            Expanded(
              child: VodGrid(onItemSelect: (item) => _selectItem(ref, item)),
            ),
          ],
        ),
      ),
    );
  }

  void _selectItem(WidgetRef ref, VodItem item) {
    ref.read(addToVodWatchHistoryProvider(item).future);
    // TODO(CV-019 follow-up): hand off to playback. See Task 7 Step 3's
    // investigation note for the actual player launch call to wire here.
  }
}

class _ContinueWatchingTile extends StatelessWidget {
  const _ContinueWatchingTile({required this.item, required this.onSelect});

  final VodItem item;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelect,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[850],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            item.title,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}
```

**Do not leave the `TODO` above as final** — Step 3's investigation must resolve it to a real call before this task is done. It's shown here only because the exact call depends on what Step 3 finds; replace it with the actual playback hand-off (or escalate BLOCKED) before writing tests/committing.

- [ ] **Step 5: Write `lib/presentation/screens/vod_screen.dart`** (phone), following the same pattern as Step 4 but using `VodListWidget` and a vertical continue-watching row, matching `IPTVScreen`'s phone layout conventions (check that file for its `Scaffold`/`AppBar` structure before writing, to stay visually consistent).

- [ ] **Step 6: Resolve the playback hand-off and re-run the widget test**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/tv/vod_tv_screen_test.dart`
Expected: `00:00 +2: All tests passed!`

- [ ] **Step 7: Export new screens from the barrel**

Add to `packages/feature_iptv/lib/feature_iptv.dart`:

```dart
export 'presentation/tv/vod_tv_screen.dart';
export 'presentation/screens/vod_screen.dart';
```

- [ ] **Step 8: Run the full `feature_iptv` suite**

Run: `cd packages/feature_iptv && flutter test`
Expected: all tests pass, zero regressions.

- [ ] **Step 9: Commit**

```bash
git add packages/feature_iptv/lib/presentation/tv/vod_tv_screen.dart packages/feature_iptv/lib/presentation/screens/vod_screen.dart packages/feature_iptv/lib/feature_iptv.dart packages/feature_iptv/test/iptv/presentation/tv/vod_tv_screen_test.dart
git commit -m "feat(feature_iptv): add VOD TV and phone screens with continue-watching row"
```

---

### Task 8: App-level routing + nav rail wiring + full regression

**Files:**
- Modify: `app/lib/core/app/tv_router.dart`
- Modify: `app/lib/core/app/tv_shell.dart`
- Modify: `app/lib/core/routing/app_router.dart`

**Interfaces:**
- Consumes: `VodTvScreen`, `VodScreen` (Task 7, via `package:feature_iptv/feature_iptv.dart`).

- [ ] **Step 1: Add a VOD route name and route to `tv_router.dart`**

In `TvRouteNames`, add after `guide`:

```dart
static const String vod = '/vod';
```

In the `ShellRoute`'s `routes` list, add a new `GoRoute` after the `guide` route (before `favorites`):

```dart
// VOD (movies/shows) route
GoRoute(
  path: TvRouteNames.vod,
  name: 'tv_vod',
  builder: (context, state) => const VodTvScreen(),
),
```

- [ ] **Step 2: Add a nav rail destination in `tv_shell.dart`**

The existing `_TvNavigationRail` has 5 destinations at indices 0-4 (Home, Live TV, Guide, Favorites, Settings) via a hand-rolled `switch` in `_navigateToIndex`. Insert "Movies & Shows" at index 3 (after Guide, before Favorites), shifting Favorites to 4 and Settings to 5:

```dart
void _navigateToIndex(BuildContext context, int index) {
  switch (index) {
    case 0:
      context.go(TvRouteNames.live);
      break;
    case 1:
      context.go(TvRouteNames.live);
      break;
    case 2:
      context.go(TvRouteNames.guide);
      break;
    case 3:
      context.go(TvRouteNames.vod);
      break;
    case 4:
      context.go(TvRouteNames.favorites);
      break;
    case 5:
      context.go(TvRouteNames.settings);
      break;
  }
}
```

And in `_TvNavigationRail.build`'s `destinations` list, insert a new `NavigationRailDestination` after the Guide entry (index 2) and before Favorites, then renumber Favorites'/Settings' `currentIndex ==` checks and `onSelect`/`onDestinationSelected` calls from 3/4 to 4/5:

```dart
NavigationRailDestination(
  icon: TvFocusable(
    onSelect: () => onDestinationSelected(3),
    child: Icon(
      Icons.movie_outlined,
      color: currentIndex == 3 ? theme.colorScheme.primary : null,
    ),
  ),
  selectedIcon: const Icon(Icons.movie),
  label: const Text('Movies & Shows'),
),
```

(Favorites' and Settings' `onDestinationSelected(3)`/`onDestinationSelected(4)` calls and `currentIndex == 3`/`currentIndex == 4` checks become `onDestinationSelected(4)`/`onDestinationSelected(5)` and `currentIndex == 4`/`currentIndex == 5` respectively — renumber both, don't just insert and leave the old indices colliding.)

- [ ] **Step 3: Add a phone route in `app_router.dart`**

Following the existing `GoRoute(path: '/iptv', name: 'Stream', ...)` pattern, add (adjust exact placement/shell-branch nesting to match the surrounding `StatefulShellBranch` structure — read the file's full `routes` list first):

```dart
GoRoute(
  path: '/vod',
  name: 'VOD',
  builder: (context, state) => const VodScreen(),
),
```

- [ ] **Step 4: Manual verification — run the TV app and check the new route**

Run: `cd app && flutter run -d macos --dart-define=FLAVOR=tv` (or whatever this repo's existing TV-flavor run command is — check `README`/`melos.yaml` scripts first) and navigate to the new "Movies & Shows" rail destination. Confirm the grid renders (or the empty state, if the current playlist has no VOD-shaped entries) and no exception is thrown. If a real TV run isn't feasible in this environment, at minimum confirm `flutter analyze` is clean on the touched app files and note in the report that manual verification was not possible here.

- [ ] **Step 5: Run analyzer across all touched packages**

Run: `cd /Users/udaychauhan/workspace/airo && for p in platform_channels platform_history platform_playlist feature_iptv; do (cd packages/$p && flutter analyze); done`
Expected: no new errors in any touched file.

- [ ] **Step 6: Run the full test suite across all touched packages**

Run:
```bash
cd packages/platform_channels && flutter test
cd ../platform_history && flutter test
cd ../platform_playlist && flutter test
cd ../feature_iptv && flutter test
```
Expected: all green, zero regressions anywhere (in particular `platform_history`'s `recently_watched_storage_test.dart` and `platform_playlist`'s CV-018 suite must be untouched-green, proving Task 2's refactor and Task 3's additive adapters didn't regress prior work).

- [ ] **Step 7: Commit**

```bash
git add app/lib/core/app/tv_router.dart app/lib/core/app/tv_shell.dart app/lib/core/routing/app_router.dart
git commit -m "feat(app): wire VOD screen into TV and phone routers"
```

---

## Self-Review

**Spec coverage against issue #824 acceptance criteria:**
- VOD entries from M3U/Xtream sources listed in a browsable UI → Tasks 3 (adapters), 5 (providers), 6-7 (UI). Xtream is adapter-complete (Task 3) but not live-wired into the running provider graph in this plan (Task 5's scope note) — flagged explicitly, not silently dropped; wiring it is additive once CV-022 exists.
- Continue-watching reuses existing local history, no new persistence system → Task 2 (`BoundedRecentListStore` reuses the exact `KeyValueStore`/`SharedPreferences` engine, zero behavior change to the existing live-channel history).
- Series/episode grouping where source data supports it → Task 4.
- No network calls to third-party metadata → verified by construction: no adapter in Task 3, no provider in Task 5, and no widget in Tasks 6-7 calls anything other than the user's own configured source or local storage.
- Tests: VOD parsing from fixture playlists (Task 3's M3U/Xtream adapter tests), continue-watching state (Task 2's `VodWatchHistoryStorage` tests, Task 5's `addToVodWatchHistoryProvider`/`vodContinueWatchingProvider` round-trip test), empty-state when source has no VOD (Task 5's "empty source" test, Task 6/7's empty-state widget tests).

**Placeholder scan:** every step has complete code except Task 7 Step 4's explicitly-flagged `TODO`, which Step 3 requires resolving before the task is done (not a plan placeholder left for "later" — it's a controller-visible checkpoint because the actual playback call site is unknown until an implementer reads it, and guessing wrong risks building a parallel, VOD-incompatible player path).

**Type consistency:** `VodItem`/`VodSeriesRef`/`VodContentKind` (Task 1) field names match exactly across Tasks 3-7 (`id, title, streamUrl, posterUrl, group, kind, containerExtension, seriesRef`; `seriesId, seriesTitle, seasonNumber, episodeNumber`). `BoundedRecentListStore<T>`'s constructor signature (Task 2) matches both its `RecentlyWatchedStorage`/`VodWatchHistoryStorage` consumers exactly. Provider names introduced in Task 5 (`vodItemsProvider`, `filteredVodMoviesProvider`, `filteredVodSeriesGroupsProvider`, `vodContinueWatchingProvider`, `addToVodWatchHistoryProvider`) are used identically in Tasks 6-7.

**Known open risk flagged for the assigned engineer:** `KeyValueStore.containsKey`'s exact sync/async signature is unconfirmed in this plan (Task 2 Step 3 note) — check it against `packages/core_data/lib/src/storage/key_value_store.dart` before writing `BoundedRecentListStore.hasRecent()`, don't guess between the two shapes shown.
