# CV-015 Slice 2 EPG Grid Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `IptvGuideScreen`'s vertical current/next list with a real horizontal-timeline EPG grid backed by `compactEpgWindowProvider`/`loadWindow()`, plus XMLTV source management (add/refresh a URL, stale-state UI) and manual channel-to-EPG-id match overrides — closing the gap both competitive analyses flagged.

**Architecture:** `packages/platform_epg` stays a pure data/model layer (zero I/O dependencies, per its `module.yaml`) — nothing in this plan touches it. All new orchestration (XMLTV fetch+parse, source persistence, match-override persistence, guide search) lives in `packages/feature_iptv/lib/application`, which already depends on `dio`, `core_data`, and `platform_epg`. A new `MutableXmltvCompactEpgRepository` implements `platform_epg`'s existing `CompactEpgRepository` interface and holds a swappable inner `XmltvCompactEpgRepository`; it becomes the `fallback` of the already-wired `SnapshotBackedCompactEpgRepository` in `app/lib/main_tv.dart`, so `compactEpgWindowProvider` — dead today because its fallback is `EmptyCompactEpgRepository` — starts returning real data the moment a user configures an XMLTV source. The grid UI is built from plain `ListView.builder` (vertical channel-row virtualization) + `SingleChildScrollView` rows sharing one horizontal `ScrollController` (a Flutter `ScrollController` natively supports multiple simultaneous attachments) — no `CustomPainter`/`RenderObject`, no new scroll-sync dependency, matching the issue's explicit non-goal and the existing `TvChannelGrid._ensureVisible` focus-follow-scroll idiom.

**Tech Stack:** Dart 3 classes + `equatable`, Riverpod, `core_data`'s `KeyValueStore`/`PreferencesStore` (same pattern as `platform_history`'s `RecentlyWatchedStorage`), `dio` (already a `feature_iptv` dependency), `XmltvCompactEpgRepository.fromXmltvFileNative` (existing native XMLTV parse binding, no native changes).

## Global Constraints

- Dart SDK `^3.12.2`, Flutter `>=1.17.0`.
- No new package dependencies anywhere (confirmed with Chief Architect: hand-rolled scroll sync, not `linked_scroll_controller`; XMLTV fetch orchestration in `feature_iptv`, not a new `dio` dependency on `platform_epg`).
- `packages/platform_epg` is not modified in this plan — it already has everything needed (`CompactEpgRepository`, `GuideWindowQuery`, `CompactEpgWindow`, `XmltvCompactEpgRepository`, `SnapshotBackedCompactEpgRepository`'s `fallback` param, `CompactEpgAvailability`).
- No custom `RenderObject`/`CustomPainter` — plain widgets only (issue's explicit non-goal, carried over from CV-015 slice 1).
- Guide search must reuse `AiroChannelSearchIndex`/`channelSearchIndexProvider` (already built, already used by the main channel list) — no second search-index implementation. Guide search state (`guideSearchQueryProvider`) is independent of the main screen's `channelSearchQueryProvider` so navigating to the guide doesn't perturb the live-channel screen's search box.
- No Xtream/Stalker EPG ingestion in this slice (non-goal — XMLTV only).
- No catch-up/timeshift playback from guide cells (non-goal).
- Tests required per issue #825: focus/navigation (D-pad), no overflow, bounded render count, search result correctness, stale-state rendering.
- `iptv_providers.dart`'s existing providers (`compactEpgRepositoryProvider`, `compactEpgReferenceTimeProvider`, `compactEpgSliceForChannelsProvider`, `compactEpgWindowProvider`, `iptvChannelsProvider`, `channelSearchIndexProvider`) are read-only reused, not modified — this plan only adds new provider files alongside them.

---

## File Structure

```
packages/feature_iptv/
  lib/application/
    epg_channel_match_override_store.dart        [new]
    xmltv_source_store.dart                        [new]
    xmltv_source_refresh_service.dart               [new]
    mutable_xmltv_compact_epg_repository.dart        [new]
    providers/guide_providers.dart                    [new]
  lib/presentation/tv/
    iptv_guide_screen.dart                              [rewrite]
  lib/presentation/widgets/
    epg_timeline_grid.dart                                [new]
    xmltv_source_sheet.dart                                [new]
    epg_match_override_sheet.dart                           [new]
  lib/feature_iptv.dart                                      [modify — export new public types]
  test/iptv/application/
    epg_channel_match_override_store_test.dart                [new]
    xmltv_source_store_test.dart                                [new]
    xmltv_source_refresh_service_test.dart                       [new]
    mutable_xmltv_compact_epg_repository_test.dart                [new]
    providers/guide_providers_test.dart                             [new]
  test/iptv/presentation/
    widgets/epg_timeline_grid_test.dart                               [new]
    tv/iptv_guide_screen_test.dart                                     [rewrite]
    widgets/xmltv_source_sheet_test.dart                                [new]
    widgets/epg_match_override_sheet_test.dart                           [new]

app/
  lib/main_tv.dart                                                        [modify]
  test/main_tv_test.dart                                                   [existing — must still pass]
```

---

### Task 1: Persisted stores — EPG match overrides + XMLTV source config

**Files:**
- Create: `packages/feature_iptv/lib/application/epg_channel_match_override_store.dart`
- Create: `packages/feature_iptv/lib/application/xmltv_source_store.dart`
- Test: `packages/feature_iptv/test/iptv/application/epg_channel_match_override_store_test.dart`
- Test: `packages/feature_iptv/test/iptv/application/xmltv_source_store_test.dart`

**Interfaces:**
- Consumes: `KeyValueStore`/`PreferencesStore` (`package:core_data/core_data.dart` — `Future<String?> getString(String key)`, `Future<bool> setString(String key, String value)`, `Future<bool> remove(String key)`).
- Produces: `class EpgChannelMatchOverrideStore { EpgChannelMatchOverrideStore(KeyValueStore store); Future<void> setOverride({required String channelId, required String epgChannelId}); Future<void> clearOverride(String channelId); Future<Map<String, String>> getOverrides(); Future<String?> resolveEpgChannelId(String channelId); }`; `class XmltvSourceConfig extends Equatable { String url; DateTime? lastRefreshedAt; String? lastError; }`; `class XmltvSourceStore { XmltvSourceStore(KeyValueStore store); Future<void> save(XmltvSourceConfig config); Future<XmltvSourceConfig?> load(); Future<void> clear(); Future<void> recordRefreshSuccess(DateTime refreshedAt); Future<void> recordRefreshError(String error); }`.

- [ ] **Step 1: Write the failing test for `EpgChannelMatchOverrideStore`**

```dart
import 'package:core_data/core_data.dart';
import 'package:feature_iptv/application/epg_channel_match_override_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late KeyValueStore store;
  late EpgChannelMatchOverrideStore overrideStore;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    store = PreferencesStore(prefs);
    overrideStore = EpgChannelMatchOverrideStore(store);
  });

  test('resolveEpgChannelId returns null when no override is set', () async {
    final result = await overrideStore.resolveEpgChannelId('channel-1');
    expect(result, isNull);
  });

  test('setOverride then resolveEpgChannelId returns the mapped id', () async {
    await overrideStore.setOverride(channelId: 'channel-1', epgChannelId: 'epg.example.tv');

    final result = await overrideStore.resolveEpgChannelId('channel-1');

    expect(result, 'epg.example.tv');
  });

  test('setOverride for one channel does not affect another', () async {
    await overrideStore.setOverride(channelId: 'channel-1', epgChannelId: 'epg-a');
    await overrideStore.setOverride(channelId: 'channel-2', epgChannelId: 'epg-b');

    expect(await overrideStore.resolveEpgChannelId('channel-1'), 'epg-a');
    expect(await overrideStore.resolveEpgChannelId('channel-2'), 'epg-b');
  });

  test('clearOverride removes only the targeted channel', () async {
    await overrideStore.setOverride(channelId: 'channel-1', epgChannelId: 'epg-a');
    await overrideStore.setOverride(channelId: 'channel-2', epgChannelId: 'epg-b');

    await overrideStore.clearOverride('channel-1');

    expect(await overrideStore.resolveEpgChannelId('channel-1'), isNull);
    expect(await overrideStore.resolveEpgChannelId('channel-2'), 'epg-b');
  });

  test('getOverrides returns the full map', () async {
    await overrideStore.setOverride(channelId: 'channel-1', epgChannelId: 'epg-a');
    await overrideStore.setOverride(channelId: 'channel-2', epgChannelId: 'epg-b');

    final overrides = await overrideStore.getOverrides();

    expect(overrides, {'channel-1': 'epg-a', 'channel-2': 'epg-b'});
  });

  test('re-setting an override for the same channel replaces the old value', () async {
    await overrideStore.setOverride(channelId: 'channel-1', epgChannelId: 'epg-a');
    await overrideStore.setOverride(channelId: 'channel-1', epgChannelId: 'epg-a-corrected');

    expect(await overrideStore.resolveEpgChannelId('channel-1'), 'epg-a-corrected');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/feature_iptv && flutter test test/iptv/application/epg_channel_match_override_store_test.dart`
Expected: FAIL — `EpgChannelMatchOverrideStore` undefined.

- [ ] **Step 3: Write `lib/application/epg_channel_match_override_store.dart`**

```dart
import 'dart:convert';

import 'package:core_data/core_data.dart';

/// Persists user-configured overrides mapping an [IPTVChannel.id] to the
/// EPG `channelId` that should be used when querying [CompactEpgRepository]
/// for that channel — for when tvg-id auto-matching fails (a common
/// real-world IPTV pain point per CV-015 slice 2's scope).
///
/// Stored as a single JSON map under one preference key — the whole map is
/// read/written together since override counts are small (dozens, not
/// thousands) and this mirrors the simplicity of other small preference
/// blobs in this codebase (e.g. `RecentlyWatchedStorage`'s single JSON list).
class EpgChannelMatchOverrideStore {
  EpgChannelMatchOverrideStore(this._store);

  static const String _storageKey = 'epg_channel_match_overrides';

  final KeyValueStore _store;

  Future<void> setOverride({
    required String channelId,
    required String epgChannelId,
  }) async {
    final overrides = await getOverrides();
    overrides[channelId] = epgChannelId;
    await _save(overrides);
  }

  Future<void> clearOverride(String channelId) async {
    final overrides = await getOverrides();
    overrides.remove(channelId);
    await _save(overrides);
  }

  Future<Map<String, String>> getOverrides() async {
    final json = await _store.getString(_storageKey);
    if (json == null) return {};
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    return decoded.map((key, value) => MapEntry(key, value as String));
  }

  Future<String?> resolveEpgChannelId(String channelId) async {
    final overrides = await getOverrides();
    return overrides[channelId];
  }

  Future<void> _save(Map<String, String> overrides) async {
    await _store.setString(_storageKey, jsonEncode(overrides));
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd packages/feature_iptv && flutter test test/iptv/application/epg_channel_match_override_store_test.dart`
Expected: `00:00 +6: All tests passed!`

- [ ] **Step 5: Write the failing test for `XmltvSourceStore`**

```dart
import 'package:core_data/core_data.dart';
import 'package:feature_iptv/application/xmltv_source_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late XmltvSourceStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    store = XmltvSourceStore(PreferencesStore(prefs));
  });

  test('load returns null when no source has been configured', () async {
    expect(await store.load(), isNull);
  });

  test('save then load round-trips the config', () async {
    final config = XmltvSourceConfig(url: 'https://example.com/guide.xml');

    await store.save(config);
    final loaded = await store.load();

    expect(loaded?.url, 'https://example.com/guide.xml');
    expect(loaded?.lastRefreshedAt, isNull);
    expect(loaded?.lastError, isNull);
  });

  test('recordRefreshSuccess sets lastRefreshedAt and clears lastError', () async {
    await store.save(const XmltvSourceConfig(url: 'https://example.com/guide.xml', lastError: 'timed out'));
    final refreshedAt = DateTime.utc(2026, 7, 17, 12);

    await store.recordRefreshSuccess(refreshedAt);
    final loaded = await store.load();

    expect(loaded?.lastRefreshedAt, refreshedAt);
    expect(loaded?.lastError, isNull);
  });

  test('recordRefreshError sets lastError, keeps prior lastRefreshedAt', () async {
    final refreshedAt = DateTime.utc(2026, 7, 17, 12);
    await store.save(XmltvSourceConfig(url: 'https://example.com/guide.xml', lastRefreshedAt: refreshedAt));

    await store.recordRefreshError('connection reset');
    final loaded = await store.load();

    expect(loaded?.lastError, 'connection reset');
    expect(loaded?.lastRefreshedAt, refreshedAt);
  });

  test('clear removes the configured source', () async {
    await store.save(const XmltvSourceConfig(url: 'https://example.com/guide.xml'));

    await store.clear();

    expect(await store.load(), isNull);
  });

  test('recordRefreshSuccess/Error is a no-op when no source is configured', () async {
    await store.recordRefreshSuccess(DateTime.utc(2026, 7, 17));

    expect(await store.load(), isNull);
  });
}
```

- [ ] **Step 6: Run test to verify it fails**

Run: `cd packages/feature_iptv && flutter test test/iptv/application/xmltv_source_store_test.dart`
Expected: FAIL — `XmltvSourceStore`/`XmltvSourceConfig` undefined.

- [ ] **Step 7: Write `lib/application/xmltv_source_store.dart`**

```dart
import 'dart:convert';

import 'package:core_data/core_data.dart';
import 'package:equatable/equatable.dart';

/// A user-configured XMLTV guide source: the URL, when it was last
/// successfully refreshed, and the last error (if any) — drives the
/// stale/unavailable UI state per CV-015 slice 2.
class XmltvSourceConfig extends Equatable {
  const XmltvSourceConfig({
    required this.url,
    this.lastRefreshedAt,
    this.lastError,
  });

  final String url;
  final DateTime? lastRefreshedAt;
  final String? lastError;

  XmltvSourceConfig copyWith({
    String? url,
    DateTime? Function()? lastRefreshedAt,
    String? Function()? lastError,
  }) {
    return XmltvSourceConfig(
      url: url ?? this.url,
      lastRefreshedAt: lastRefreshedAt != null
          ? lastRefreshedAt()
          : this.lastRefreshedAt,
      lastError: lastError != null ? lastError() : this.lastError,
    );
  }

  factory XmltvSourceConfig.fromJson(Map<String, dynamic> json) {
    return XmltvSourceConfig(
      url: json['url'] as String,
      lastRefreshedAt: json['lastRefreshedAt'] != null
          ? DateTime.parse(json['lastRefreshedAt'] as String)
          : null,
      lastError: json['lastError'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'url': url,
    if (lastRefreshedAt != null)
      'lastRefreshedAt': lastRefreshedAt!.toIso8601String(),
    if (lastError != null) 'lastError': lastError,
  };

  @override
  List<Object?> get props => [url, lastRefreshedAt, lastError];
}

/// Persists the single configured XMLTV source (this slice supports one
/// active source, matching the issue's "add/remove/refresh **an** XMLTV
/// URL" scope — not a multi-source list).
class XmltvSourceStore {
  XmltvSourceStore(this._store);

  static const String _storageKey = 'xmltv_source_config';

  final KeyValueStore _store;

  Future<void> save(XmltvSourceConfig config) async {
    await _store.setString(_storageKey, jsonEncode(config.toJson()));
  }

  Future<XmltvSourceConfig?> load() async {
    final json = await _store.getString(_storageKey);
    if (json == null) return null;
    return XmltvSourceConfig.fromJson(jsonDecode(json) as Map<String, dynamic>);
  }

  Future<void> clear() async {
    await _store.remove(_storageKey);
  }

  Future<void> recordRefreshSuccess(DateTime refreshedAt) async {
    final current = await load();
    if (current == null) return;
    await save(
      current.copyWith(lastRefreshedAt: () => refreshedAt, lastError: () => null),
    );
  }

  Future<void> recordRefreshError(String error) async {
    final current = await load();
    if (current == null) return;
    await save(current.copyWith(lastError: () => error));
  }
}
```

- [ ] **Step 8: Run tests to verify they pass**

Run: `cd packages/feature_iptv && flutter test test/iptv/application/xmltv_source_store_test.dart`
Expected: `00:00 +6: All tests passed!`

- [ ] **Step 9: Run the full `feature_iptv` suite**

Run: `cd packages/feature_iptv && flutter test`
Expected: all tests pass (baseline 150/150 + 12 new), no regressions.

- [ ] **Step 10: Commit**

```bash
git add packages/feature_iptv/lib/application/epg_channel_match_override_store.dart packages/feature_iptv/lib/application/xmltv_source_store.dart packages/feature_iptv/test/iptv/application/epg_channel_match_override_store_test.dart packages/feature_iptv/test/iptv/application/xmltv_source_store_test.dart
git commit -m "feat(feature_iptv): add EPG match override and XMLTV source persisted stores"
```

---

### Task 2: `MutableXmltvCompactEpgRepository` + `XmltvSourceRefreshService`

**Files:**
- Create: `packages/feature_iptv/lib/application/mutable_xmltv_compact_epg_repository.dart`
- Create: `packages/feature_iptv/lib/application/xmltv_source_refresh_service.dart`
- Test: `packages/feature_iptv/test/iptv/application/mutable_xmltv_compact_epg_repository_test.dart`
- Test: `packages/feature_iptv/test/iptv/application/xmltv_source_refresh_service_test.dart`

**Interfaces:**
- Consumes: `CompactEpgRepository`/`EmptyCompactEpgRepository`/`XmltvCompactEpgRepository`/`GuideWindowQuery`/`CompactEpgSlice`/`CompactEpgWindow` (`package:platform_epg/platform_epg.dart`), `Dio` (`package:dio/dio.dart`), `XmltvSourceStore`/`XmltvSourceConfig` (Task 1).
- Produces: `class MutableXmltvCompactEpgRepository implements CompactEpgRepository { void updateSource(CompactEpgRepository repository); Future<CompactEpgSlice> loadCurrentNext(...); Future<CompactEpgWindow> loadWindow(...); }`; `class XmltvSourceRefreshService { XmltvSourceRefreshService({required Dio dio, required XmltvSourceStore sourceStore, required MutableXmltvCompactEpgRepository repository, required Future<Directory> Function() downloadDirectoryProvider}); Future<void> refresh(String url); Future<void> refreshConfiguredSource(); }`.

- [ ] **Step 1: Write the failing test for `MutableXmltvCompactEpgRepository`**

```dart
import 'package:feature_iptv/application/mutable_xmltv_compact_epg_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_epg/platform_epg.dart';

void main() {
  test('defaults to unavailable when no source has been set', () async {
    final repository = MutableXmltvCompactEpgRepository();
    final now = DateTime.utc(2026, 7, 17, 12);

    final slice = await repository.loadCurrentNext(channelIds: ['chan-1'], now: now);

    expect(slice.availabilityAt(now), CompactEpgAvailability.unavailable);
  });

  test('updateSource swaps in a real repository, delegating loadWindow', () async {
    final repository = MutableXmltvCompactEpgRepository();
    final now = DateTime.utc(2026, 7, 17, 12);
    final fakeInner = InMemoryCompactEpgRepository(
      seed: CompactEpgSlice(
        entries: [
          CompactEpgEntry(
            channelId: 'chan-1',
            channelName: 'Channel 1',
            current: CompactEpgProgram(
              programId: 'p1',
              title: 'Now Showing',
              startsAt: now.subtract(const Duration(minutes: 10)),
              endsAt: now.add(const Duration(minutes: 20)),
            ),
          ),
        ],
        generatedAt: now,
        expiresAt: now.add(const Duration(hours: 1)),
        source: CompactEpgSliceSource.localCache,
      ),
    );

    repository.updateSource(fakeInner);
    final query = GuideWindowQuery(
      channelIds: ['chan-1'],
      windowStart: now.subtract(const Duration(hours: 1)),
      windowEnd: now.add(const Duration(hours: 1)),
      now: now,
    );
    final window = await repository.loadWindow(query);

    expect(window.entryForChannel('chan-1')?.programs, isNotEmpty);
  });

  test('updateSource(null) reverts to unavailable', () async {
    final repository = MutableXmltvCompactEpgRepository();
    final now = DateTime.utc(2026, 7, 17, 12);
    repository.updateSource(
      InMemoryCompactEpgRepository(
        seed: CompactEpgSlice(entries: const [], generatedAt: now, expiresAt: now, source: CompactEpgSliceSource.localCache),
      ),
    );

    repository.updateSource(null);
    final slice = await repository.loadCurrentNext(channelIds: ['chan-1'], now: now);

    expect(slice.availabilityAt(now), CompactEpgAvailability.unavailable);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/feature_iptv && flutter test test/iptv/application/mutable_xmltv_compact_epg_repository_test.dart`
Expected: FAIL — `MutableXmltvCompactEpgRepository` undefined.

- [ ] **Step 3: Write `lib/application/mutable_xmltv_compact_epg_repository.dart`**

```dart
import 'package:platform_epg/platform_epg.dart';

/// A [CompactEpgRepository] whose underlying data source can be swapped at
/// runtime. Used as the `fallback` of the app's [SnapshotBackedCompactEpgRepository]
/// in `main_tv.dart`: starts out delegating to [EmptyCompactEpgRepository]
/// (matching today's behavior, no regression), then [updateSource] is called
/// by [XmltvSourceRefreshService] once the user configures and successfully
/// refreshes an XMLTV source — no Riverpod provider re-override needed,
/// callers just re-query the same [compactEpgWindowProvider]/`.family`
/// instance after invalidation.
class MutableXmltvCompactEpgRepository implements CompactEpgRepository {
  MutableXmltvCompactEpgRepository({CompactEpgRepository? initial})
    : _inner = initial ?? const EmptyCompactEpgRepository();

  CompactEpgRepository _inner;

  /// Swaps the delegate. Pass `null` to revert to unavailable (e.g. when a
  /// source is removed).
  void updateSource(CompactEpgRepository? repository) {
    _inner = repository ?? const EmptyCompactEpgRepository();
  }

  @override
  Future<CompactEpgSlice> loadCurrentNext({
    required Iterable<String> channelIds,
    required DateTime now,
  }) => _inner.loadCurrentNext(channelIds: channelIds, now: now);

  @override
  Future<CompactEpgWindow> loadWindow(GuideWindowQuery query) =>
      _inner.loadWindow(query);
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd packages/feature_iptv && flutter test test/iptv/application/mutable_xmltv_compact_epg_repository_test.dart`
Expected: `00:00 +3: All tests passed!`

- [ ] **Step 5: Write the failing test for `XmltvSourceRefreshService`**

```dart
import 'dart:convert';
import 'dart:io';

import 'package:core_data/core_data.dart';
import 'package:dio/dio.dart';
import 'package:feature_iptv/application/mutable_xmltv_compact_epg_repository.dart';
import 'package:feature_iptv/application/xmltv_source_refresh_service.dart';
import 'package:feature_iptv/application/xmltv_source_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_epg/platform_epg.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _minimalXmltv = '''
<?xml version="1.0" encoding="UTF-8"?>
<tv>
  <channel id="chan-1"><display-name>Channel 1</display-name></channel>
  <programme start="20260717120000 +0000" stop="20260717123000 +0000" channel="chan-1">
    <title>Test Program</title>
  </programme>
</tv>
''';

void main() {
  late Directory tempDir;
  late XmltvSourceStore sourceStore;
  late MutableXmltvCompactEpgRepository repository;
  late XmltvSourceRefreshService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    sourceStore = XmltvSourceStore(PreferencesStore(prefs));
    repository = MutableXmltvCompactEpgRepository();
    tempDir = await Directory.systemTemp.createTemp('xmltv_refresh_test');

    final dio = Dio();
    dio.httpClientAdapter = _FakeXmltvAdapter(_minimalXmltv);

    service = XmltvSourceRefreshService(
      dio: dio,
      sourceStore: sourceStore,
      repository: repository,
      downloadDirectoryProvider: () async => tempDir,
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('refresh downloads, parses, updates the repository, and records success', () async {
    await service.refresh('https://example.com/guide.xml');

    final now = DateTime.utc(2026, 7, 17, 12, 10);
    final slice = await repository.loadCurrentNext(channelIds: ['chan-1'], now: now);
    expect(slice.entryForChannel('chan-1')?.current?.title, 'Test Program');

    final config = await sourceStore.load();
    expect(config?.url, 'https://example.com/guide.xml');
    expect(config?.lastRefreshedAt, isNotNull);
    expect(config?.lastError, isNull);
  });

  test('refresh with an invalid URL records an error, does not touch the repository', () async {
    await expectLater(
      () => service.refresh('not-a-url'),
      throwsA(isA<ArgumentError>()),
    );

    final config = await sourceStore.load();
    expect(config?.lastError, isNotNull);
  });

  test('refreshConfiguredSource is a no-op when nothing is configured', () async {
    await service.refreshConfiguredSource();

    final now = DateTime.utc(2026, 7, 17, 12);
    final slice = await repository.loadCurrentNext(channelIds: ['chan-1'], now: now);
    expect(slice.availabilityAt(now), CompactEpgAvailability.unavailable);
  });

  test('refreshConfiguredSource refreshes the already-saved source', () async {
    await sourceStore.save(const XmltvSourceConfig(url: 'https://example.com/guide.xml'));

    await service.refreshConfiguredSource();

    final now = DateTime.utc(2026, 7, 17, 12, 10);
    final slice = await repository.loadCurrentNext(channelIds: ['chan-1'], now: now);
    expect(slice.entryForChannel('chan-1')?.current?.title, 'Test Program');
  });
}

class _FakeXmltvAdapter implements HttpClientAdapter {
  _FakeXmltvAdapter(this._content);
  final String _content;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final bytes = utf8.encode(_content);
    return ResponseBody.fromBytes(bytes, 200);
  }

  @override
  void close({bool force = false}) {}
}
```

Note: check `HttpClientAdapter.fetch`'s exact signature against the `dio` version this package uses (CV-018's `platform_playlist` tests already built a `FakeHttpClientAdapter` at `packages/platform_playlist/test/test_support/fake_http_client_adapter.dart` handling JSON responses via `Response`-returning handlers — this test needs a *file download* response instead, since `dio.download()` is used, not `dio.get()`. If `Dio.download()`'s adapter contract differs from `.get()`'s in a way that makes this fake not work, write a minimal adapter that satisfies `Dio.download()` specifically — check by running the test and reading the failure, don't guess blindly).

- [ ] **Step 6: Run test to verify it fails**

Run: `cd packages/feature_iptv && flutter test test/iptv/application/xmltv_source_refresh_service_test.dart`
Expected: FAIL — `XmltvSourceRefreshService` undefined.

- [ ] **Step 7: Write `lib/application/xmltv_source_refresh_service.dart`**

```dart
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:platform_epg/platform_epg.dart';

import 'mutable_xmltv_compact_epg_repository.dart';
import 'xmltv_source_store.dart';

/// Downloads and parses a user-configured XMLTV URL, then swaps the result
/// into [MutableXmltvCompactEpgRepository] — the user-triggerable
/// counterpart to `main_tv.dart`'s existing debug-only
/// `warmTvDebugDefaultEpgCache`, but producing a full-timetable
/// [XmltvCompactEpgRepository] (via the native parse binding) rather than a
/// current/next-only snapshot.
class XmltvSourceRefreshService {
  XmltvSourceRefreshService({
    required Dio dio,
    required this.sourceStore,
    required this.repository,
    required this.downloadDirectoryProvider,
  }) : _dio = dio;

  final Dio _dio;
  final XmltvSourceStore sourceStore;
  final MutableXmltvCompactEpgRepository repository;
  final Future<Directory> Function() downloadDirectoryProvider;

  /// Downloads [url], parses it, and updates [repository]. Throws
  /// [ArgumentError] for an invalid URL (after recording the error to
  /// [sourceStore] so the UI can show it) and rethrows any download/parse
  /// failure after recording it — the caller decides how to surface it.
  Future<void> refresh(String url) async {
    final trimmedUrl = url.trim();
    final uri = Uri.tryParse(trimmedUrl);
    if (uri == null ||
        uri.host.isEmpty ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      await sourceStore.recordRefreshError('Enter a valid HTTP(S) XMLTV URL.');
      throw ArgumentError.value(url, 'url', 'Enter a valid HTTP(S) XMLTV URL.');
    }

    final existing = await sourceStore.load();
    if (existing == null || existing.url != trimmedUrl) {
      await sourceStore.save(XmltvSourceConfig(url: trimmedUrl));
    }

    final downloadDirectory = await downloadDirectoryProvider();
    await downloadDirectory.create(recursive: true);
    final guideFile = File(
      '${downloadDirectory.path}/xmltv_source_${DateTime.now().microsecondsSinceEpoch}.xml',
    );

    try {
      await _dio.download(
        trimmedUrl,
        guideFile.path,
        options: Options(
          responseType: ResponseType.stream,
          receiveTimeout: const Duration(seconds: 30),
          validateStatus: (status) => status != null && status >= 200 && status < 300,
        ),
      );

      if (!await guideFile.exists() || await guideFile.length() == 0) {
        throw StateError('Downloaded XMLTV file was empty.');
      }

      final parsed = await XmltvCompactEpgRepository.fromXmltvFileNative(
        path: guideFile.path,
        ingestedAt: DateTime.now().toUtc(),
      );

      repository.updateSource(parsed);
      await sourceStore.recordRefreshSuccess(DateTime.now().toUtc());
    } catch (e) {
      await sourceStore.recordRefreshError(e.toString());
      rethrow;
    } finally {
      if (await guideFile.exists()) {
        await guideFile.delete();
      }
    }
  }

  /// Refreshes whatever source is already saved in [sourceStore]. No-op if
  /// nothing is configured yet.
  Future<void> refreshConfiguredSource() async {
    final config = await sourceStore.load();
    if (config == null) return;
    await refresh(config.url);
  }
}
```

Check `XmltvCompactEpgRepository.fromXmltvFileNative`'s exact parameter list against `packages/platform_epg/lib/src/xmltv_compact_epg_repository.dart` before writing this call — the plan's earlier research confirmed the signature includes `required String path, required DateTime ingestedAt` plus optional tuning params (`maxProgrammes`, `maxAge`, `defaultProgrammeDuration`, `sourceRef`, `channelNamesById`, `channelNumbersById`) — use only the two required params unless a test needs more.

- [ ] **Step 8: Run tests to verify they pass**

Run: `cd packages/feature_iptv && flutter test test/iptv/application/xmltv_source_refresh_service_test.dart`
Expected: `00:00 +4: All tests passed!`

- [ ] **Step 9: Run the full `feature_iptv` suite**

Run: `cd packages/feature_iptv && flutter test`
Expected: all tests pass, no regressions.

- [ ] **Step 10: Commit**

```bash
git add packages/feature_iptv/lib/application/mutable_xmltv_compact_epg_repository.dart packages/feature_iptv/lib/application/xmltv_source_refresh_service.dart packages/feature_iptv/test/iptv/application/mutable_xmltv_compact_epg_repository_test.dart packages/feature_iptv/test/iptv/application/xmltv_source_refresh_service_test.dart
git commit -m "feat(feature_iptv): add MutableXmltvCompactEpgRepository and XmltvSourceRefreshService"
```

---

### Task 3: Guide Riverpod providers — window query, match overrides, search

**Files:**
- Create: `packages/feature_iptv/lib/application/providers/guide_providers.dart`
- Test: `packages/feature_iptv/test/iptv/application/providers/guide_providers_test.dart`

**Interfaces:**
- Consumes: `EpgChannelMatchOverrideStore`, `XmltvSourceStore`, `MutableXmltvCompactEpgRepository`, `XmltvSourceRefreshService` (Tasks 1-2), `sharedPreferencesProvider`, `iptvChannelsProvider`, `channelSearchIndexProvider`, `compactEpgWindowProvider` (existing, `iptv_providers.dart` — **read-only reuse, this task does not modify `iptv_providers.dart`**), `GuideWindowQuery` (`package:platform_epg/platform_epg.dart`).
- Produces: `epgChannelMatchOverrideStoreProvider = Provider<EpgChannelMatchOverrideStore>`; `xmltvSourceStoreProvider = Provider<XmltvSourceStore>`; `mutableXmltvCompactEpgRepositoryProvider = Provider<MutableXmltvCompactEpgRepository>` (a single app-lifetime instance); `xmltvSourceRefreshServiceProvider = Provider<XmltvSourceRefreshService>`; `xmltvSourceConfigProvider = FutureProvider<XmltvSourceConfig?>`; `guideWindowDurationProvider = StateProvider<Duration>(const Duration(hours: 3))`; `guideWindowStartProvider = Provider<DateTime>` (floors "now" to the nearest 30 minutes); `guideEpgOverridesProvider = FutureProvider<Map<String, String>>`; `guideEpgWindowProvider = FutureProvider<CompactEpgWindow>` (builds a `GuideWindowQuery` from `iptvChannelsProvider` + overrides, applying each channel's override before querying, mapping results back to the original channel id); `guideSearchQueryProvider = StateProvider<String>('')`; `guideFilteredChannelsProvider = Provider<List<IPTVChannel>>` (reuses `channelSearchIndexProvider.filterAndSort(query: guideSearchQueryProvider)`).

**Match-override application:** `CompactEpgWindowEntry.channelId` in the returned `CompactEpgWindow` reflects whatever id was queried (the *EPG* id when an override applies, not the original `IPTVChannel.id`). `guideEpgWindowProvider` must remap each returned entry back to the original channel id before returning, so the UI layer (Task 4-5) can key lookups on `IPTVChannel.id` uniformly regardless of whether an override applied.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:feature_iptv/application/epg_channel_match_override_store.dart';
import 'package:feature_iptv/application/providers/guide_providers.dart';
import 'package:feature_iptv/application/providers/iptv_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_epg/platform_epg.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  const channel = IPTVChannel(
    id: 'channel-1',
    name: 'Example Channel',
    streamUrl: 'https://example.com/stream.m3u8',
    group: 'News',
  );

  ProviderContainer buildContainer({
    List<IPTVChannel> channels = const [channel],
    CompactEpgRepository? epgRepository,
  }) {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        iptvChannelsProvider.overrideWith((ref) async => channels),
        if (epgRepository != null)
          compactEpgRepositoryProvider.overrideWithValue(epgRepository),
      ],
    );
    return container;
  }

  test('guideEpgWindowProvider queries using the raw channel id when no override is set', () async {
    final now = DateTime.utc(2026, 7, 17, 12);
    final inner = InMemoryCompactEpgRepository(
      seed: CompactEpgSlice(
        entries: [
          CompactEpgEntry(
            channelId: 'channel-1',
            channelName: 'Example Channel',
            current: CompactEpgProgram(
              programId: 'p1',
              title: 'Now Showing',
              startsAt: now.subtract(const Duration(minutes: 5)),
              endsAt: now.add(const Duration(minutes: 25)),
            ),
          ),
        ],
        generatedAt: now,
        expiresAt: now.add(const Duration(hours: 1)),
        source: CompactEpgSliceSource.localCache,
      ),
    );
    final container = buildContainer(epgRepository: inner);
    addTearDown(container.dispose);

    final window = await container.read(guideEpgWindowProvider.future);

    expect(window.entryForChannel('channel-1')?.programs, isNotEmpty);
  });

  test('guideEpgWindowProvider queries using the override EPG id, remaps result to the channel id', () async {
    final now = DateTime.utc(2026, 7, 17, 12);
    final inner = InMemoryCompactEpgRepository(
      seed: CompactEpgSlice(
        entries: [
          CompactEpgEntry(
            channelId: 'overridden.epg.id',
            channelName: 'Example Channel (EPG)',
            current: CompactEpgProgram(
              programId: 'p1',
              title: 'Now Showing',
              startsAt: now.subtract(const Duration(minutes: 5)),
              endsAt: now.add(const Duration(minutes: 25)),
            ),
          ),
        ],
        generatedAt: now,
        expiresAt: now.add(const Duration(hours: 1)),
        source: CompactEpgSliceSource.localCache,
      ),
    );
    final container = buildContainer(epgRepository: inner);
    addTearDown(container.dispose);

    final overrideStore = container.read(epgChannelMatchOverrideStoreProvider);
    await overrideStore.setOverride(channelId: 'channel-1', epgChannelId: 'overridden.epg.id');

    final window = await container.read(guideEpgWindowProvider.future);

    // Result is keyed back to the ORIGINAL channel id, not the EPG id.
    expect(window.entryForChannel('channel-1')?.programs, isNotEmpty);
    expect(window.entryForChannel('overridden.epg.id'), isNull);
  });

  test('guideFilteredChannelsProvider filters by guideSearchQueryProvider, independent of channelSearchQueryProvider', () async {
    const other = IPTVChannel(
      id: 'channel-2',
      name: 'Second Channel',
      streamUrl: 'https://example.com/2.m3u8',
      group: 'Sports',
    );
    final container = buildContainer(channels: const [channel, other]);
    addTearDown(container.dispose);

    container.read(guideSearchQueryProvider.notifier).state = 'second';
    final filtered = container.read(guideFilteredChannelsProvider);

    expect(filtered.map((c) => c.id), ['channel-2']);
    // The main screen's search query provider is untouched.
    expect(container.read(channelSearchQueryProvider), '');
  });

  test('guideWindowStartProvider floors to the nearest 30 minutes', () {
    final container = buildContainer();
    addTearDown(container.dispose);

    final start = container.read(guideWindowStartProvider);

    expect(start.minute == 0 || start.minute == 30, isTrue);
    expect(start.second, 0);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/feature_iptv && flutter test test/iptv/application/providers/guide_providers_test.dart`
Expected: FAIL — `guide_providers.dart` does not exist.

- [ ] **Step 3: Write `lib/application/providers/guide_providers.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_epg/platform_epg.dart';

import '../epg_channel_match_override_store.dart';
import '../mutable_xmltv_compact_epg_repository.dart';
import '../xmltv_source_refresh_service.dart';
import '../xmltv_source_store.dart';
import 'iptv_providers.dart';

final epgChannelMatchOverrideStoreProvider = Provider<EpgChannelMatchOverrideStore>((ref) {
  return EpgChannelMatchOverrideStore(PreferencesStore(ref.watch(sharedPreferencesProvider)));
});

final xmltvSourceStoreProvider = Provider<XmltvSourceStore>((ref) {
  return XmltvSourceStore(PreferencesStore(ref.watch(sharedPreferencesProvider)));
});

/// One app-lifetime instance — [XmltvSourceRefreshService] mutates it via
/// [MutableXmltvCompactEpgRepository.updateSource]; nothing re-creates it.
final mutableXmltvCompactEpgRepositoryProvider = Provider<MutableXmltvCompactEpgRepository>((ref) {
  return MutableXmltvCompactEpgRepository();
});

final xmltvSourceRefreshServiceProvider = Provider<XmltvSourceRefreshService>((ref) {
  return XmltvSourceRefreshService(
    dio: ref.watch(dioProvider),
    sourceStore: ref.watch(xmltvSourceStoreProvider),
    repository: ref.watch(mutableXmltvCompactEpgRepositoryProvider),
    downloadDirectoryProvider: () async {
      // ignore: deprecated_member_use
      return Directory.systemTemp;
    },
  );
});

final xmltvSourceConfigProvider = FutureProvider<XmltvSourceConfig?>((ref) async {
  return ref.watch(xmltvSourceStoreProvider).load();
});

final guideWindowDurationProvider = StateProvider<Duration>((ref) => const Duration(hours: 3));

/// "Now," floored to the nearest 30 minutes, so the window doesn't shift on
/// every rebuild — matches the fixed-window UX competitive guides use.
final guideWindowStartProvider = Provider<DateTime>((ref) {
  final now = DateTime.now().toUtc();
  final flooredMinute = now.minute < 30 ? 0 : 30;
  return DateTime.utc(now.year, now.month, now.day, now.hour, flooredMinute);
});

final guideEpgOverridesProvider = FutureProvider<Map<String, String>>((ref) async {
  return ref.watch(epgChannelMatchOverrideStoreProvider).getOverrides();
});

/// Bounded guide-window query (CV-015), with match overrides applied:
/// each channel is queried under its override EPG id if one is set, and
/// results are remapped back to the original [IPTVChannel.id] so callers
/// never need to know an override was involved.
final guideEpgWindowProvider = FutureProvider<CompactEpgWindow>((ref) async {
  final channels = await ref.watch(iptvChannelsProvider.future);
  final overrides = await ref.watch(guideEpgOverridesProvider.future);
  final windowStart = ref.watch(guideWindowStartProvider);
  final windowDuration = ref.watch(guideWindowDurationProvider);
  final now = DateTime.now().toUtc();

  final epgIdToChannelId = <String, String>{};
  final queryIds = <String>[];
  for (final channel in channels) {
    final epgId = overrides[channel.id] ?? channel.id;
    epgIdToChannelId[epgId] = channel.id;
    queryIds.add(epgId);
  }

  final repository = ref.watch(compactEpgRepositoryProvider);
  final rawWindow = await repository.loadWindow(
    GuideWindowQuery(
      channelIds: queryIds,
      windowStart: windowStart,
      windowEnd: windowStart.add(windowDuration),
      now: now,
    ),
  );

  final remappedEntries = [
    for (final entry in rawWindow.entries)
      CompactEpgWindowEntry(
        channelId: epgIdToChannelId[entry.channelId] ?? entry.channelId,
        channelName: entry.channelName,
        channelNumber: entry.channelNumber,
        programs: entry.programs,
        sourceRef: entry.sourceRef,
      ),
  ];

  return CompactEpgWindow(
    entries: remappedEntries,
    windowStart: rawWindow.windowStart,
    windowEnd: rawWindow.windowEnd,
    generatedAt: rawWindow.generatedAt,
    expiresAt: rawWindow.expiresAt,
    source: rawWindow.source,
    schemaVersion: rawWindow.schemaVersion,
  );
});

/// Independent of [channelSearchQueryProvider] (the main Live TV screen's
/// search state) — navigating to the guide must not perturb that screen.
final guideSearchQueryProvider = StateProvider<String>((ref) => '');

/// Reuses [channelSearchIndexProvider]/[AiroChannelSearchIndex] — the same
/// index/algorithm the main channel list uses (CV-006), per this issue's
/// "do not build a second search stack" constraint.
final guideFilteredChannelsProvider = Provider<List<IPTVChannel>>((ref) {
  final index = ref.watch(channelSearchIndexProvider);
  final query = ref.watch(guideSearchQueryProvider);
  if (index == null) return const [];
  return index.filterAndSort(query: query);
});
```

Check the exact import needed for `Directory` (`dart:io`) and add it. Check `dioProvider`'s exact name/location in `iptv_providers.dart` before writing the import — reuse it as-is (confirmed to exist from CV-018's exploration: `Provider<Dio>` built with a 10s connect / 30s receive timeout).

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd packages/feature_iptv && flutter test test/iptv/application/providers/guide_providers_test.dart`
Expected: `00:00 +4: All tests passed!`

- [ ] **Step 5: Run the full `feature_iptv` suite**

Run: `cd packages/feature_iptv && flutter test`
Expected: all tests pass, no regressions.

- [ ] **Step 6: Commit**

```bash
git add packages/feature_iptv/lib/application/providers/guide_providers.dart packages/feature_iptv/test/iptv/application/providers/guide_providers_test.dart
git commit -m "feat(feature_iptv): add guide providers (windowed EPG query with match overrides, guide search)"
```

---

### Task 4: EPG timeline grid widgets

**Files:**
- Create: `packages/feature_iptv/lib/presentation/widgets/epg_timeline_grid.dart`
- Test: `packages/feature_iptv/test/iptv/presentation/widgets/epg_timeline_grid_test.dart`

**Interfaces:**
- Consumes: `guideEpgWindowProvider`, `guideFilteredChannelsProvider`, `guideWindowStartProvider`, `guideWindowDurationProvider` (Task 3), `TvFocusable`/`TvUiDimensions` (`package:core_ui/core_ui.dart`), `CompactEpgWindowEntry`/`CompactEpgProgram` (`package:platform_epg/platform_epg.dart`).
- Produces: `class EpgTimelineGrid extends ConsumerStatefulWidget { EpgTimelineGrid({required void Function(IPTVChannel) onChannelSelect}); }` — vertical `ListView.builder` of channel rows (bounded render count via `itemExtent`), each row a `SingleChildScrollView(scrollDirection: horizontal)` of program blocks sized proportional to duration, sharing one `ScrollController` with a fixed time-axis header; a `_CurrentTimeIndicator` overlay updating on its own `Timer.periodic` without rebuilding rows.

**Sizing model:** `pxPerMinute = 4.0` (a `static const` on the widget, easy to tune later). A program block's width is `program.duration.inMinutes.clamp(1, windowDuration.inMinutes) * pxPerMinute`, and its horizontal offset within the row is `program.startsAt.difference(windowStart).inMinutes.clamp(0, windowDuration.inMinutes) * pxPerMinute` (programs starting before `windowStart` or ending after `windowEnd` are clipped to the window edges — `guideEpgWindowProvider`'s underlying `loadWindow` contract already only returns programmes intersecting the window, per `platform_epg`'s documented `[windowStart, windowEnd)` semantics, but a program can still straddle a boundary).

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feature_iptv/application/providers/guide_providers.dart';
import 'package:feature_iptv/application/providers/iptv_providers.dart';
import 'package:feature_iptv/presentation/widgets/epg_timeline_grid.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_epg/platform_epg.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const channel = IPTVChannel(
    id: 'channel-1',
    name: 'Example Channel',
    streamUrl: 'https://example.com/stream.m3u8',
    group: 'News',
  );

  Future<ProviderContainer> buildContainer(CompactEpgWindow window) async {
    final prefs = await SharedPreferences.getInstance();
    return ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        iptvChannelsProvider.overrideWith((ref) async => [channel]),
        guideEpgWindowProvider.overrideWith((ref) async => window),
      ],
    );
  }

  testWidgets('renders a row per channel with a program block for each programme', (tester) async {
    final now = DateTime.utc(2026, 7, 17, 12);
    final window = CompactEpgWindow(
      entries: [
        CompactEpgWindowEntry(
          channelId: 'channel-1',
          channelName: 'Example Channel',
          programs: [
            CompactEpgProgram(
              programId: 'p1',
              title: 'Morning Show',
              startsAt: now,
              endsAt: now.add(const Duration(hours: 1)),
            ),
          ],
        ),
      ],
      windowStart: now,
      windowEnd: now.add(const Duration(hours: 3)),
      generatedAt: now,
      expiresAt: now.add(const Duration(hours: 1)),
      source: CompactEpgSliceSource.localCache,
    );
    final container = await buildContainer(window);
    addTearDown(container.dispose);

    IPTVChannel? selected;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
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
                child: EpgTimelineGrid(onChannelSelect: (c) => selected = c),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Example Channel'), findsOneWidget);
    expect(find.text('Morning Show'), findsOneWidget);
  });

  testWidgets('shows empty state when there are no channels', (tester) async {
    final now = DateTime.utc(2026, 7, 17, 12);
    final window = CompactEpgWindow(
      entries: const [],
      windowStart: now,
      windowEnd: now.add(const Duration(hours: 3)),
      generatedAt: now,
      expiresAt: now.add(const Duration(hours: 1)),
      source: CompactEpgSliceSource.unavailable,
    );
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        iptvChannelsProvider.overrideWith((ref) async => const []),
        guideEpgWindowProvider.overrideWith((ref) async => window),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: Size(1280, 720), navigationMode: NavigationMode.directional),
            child: Scaffold(
              body: SizedBox(width: 1280, height: 720, child: EpgTimelineGrid()),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('No channels to show yet.'), findsOneWidget);
  });
}
```

(`EpgTimelineGrid()` in the second test omits `onChannelSelect` — make it `void Function(IPTVChannel)?` nullable, per CV-019's established pattern for exactly this situation.)

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/widgets/epg_timeline_grid_test.dart`
Expected: FAIL — `epg_timeline_grid.dart` does not exist.

- [ ] **Step 3: Write `lib/presentation/widgets/epg_timeline_grid.dart`**

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core_ui/core_ui.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_epg/platform_epg.dart';

import '../../application/providers/guide_providers.dart';
import '../tv/iptv_tv.dart';

/// Horizontal-timeline EPG grid (CV-015 slice 2): a vertically-virtualized
/// list of channel rows, each showing its programmes for the current guide
/// window as proportionally-sized blocks. Rows share one horizontal
/// [ScrollController] with the time-axis header (Flutter's [ScrollController]
/// natively supports multiple simultaneous attachments) — scroll is driven
/// by D-pad focus movement (see [_ProgramBlock]'s `onFocus`), not free drag,
/// so every row's [SingleChildScrollView] uses [NeverScrollableScrollPhysics].
class EpgTimelineGrid extends ConsumerStatefulWidget {
  const EpgTimelineGrid({super.key, this.onChannelSelect});

  final void Function(IPTVChannel channel)? onChannelSelect;

  static const double pxPerMinute = 4.0;
  static const double rowHeight = 88.0;
  static const double channelLabelWidth = 220.0;
  static const double timeAxisHeight = 32.0;

  @override
  ConsumerState<EpgTimelineGrid> createState() => _EpgTimelineGridState();
}

class _EpgTimelineGridState extends ConsumerState<EpgTimelineGrid> {
  final ScrollController _timelineController = ScrollController();

  @override
  void dispose() {
    _timelineController.dispose();
    super.dispose();
  }

  void _scrollTimelineTo(double offset) {
    if (!_timelineController.hasClients) return;
    _timelineController.animateTo(
      offset.clamp(0.0, _timelineController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final channels = ref.watch(guideFilteredChannelsProvider);
    final windowAsync = ref.watch(guideEpgWindowProvider);
    final windowStart = ref.watch(guideWindowStartProvider);
    final windowDuration = ref.watch(guideWindowDurationProvider);
    final dimensions = ref.watch(tvDimensionsProvider(context));

    if (channels.isEmpty) {
      return const Center(child: Text('No channels to show yet.'));
    }

    final window = windowAsync.valueOrNull;
    final entriesByChannel = <String, CompactEpgWindowEntry>{
      for (final entry in window?.entries ?? const <CompactEpgWindowEntry>[])
        entry.channelId: entry,
    };
    final timelineWidth = windowDuration.inMinutes * EpgTimelineGrid.pxPerMinute;

    return Column(
      children: [
        SizedBox(
          height: EpgTimelineGrid.timeAxisHeight,
          child: Row(
            children: [
              const SizedBox(width: EpgTimelineGrid.channelLabelWidth),
              Expanded(
                child: SingleChildScrollView(
                  controller: _timelineController,
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  child: SizedBox(
                    width: timelineWidth,
                    child: _TimeAxis(
                      windowStart: windowStart,
                      windowDuration: windowDuration,
                      pxPerMinute: EpgTimelineGrid.pxPerMinute,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              ListView.builder(
                itemExtent: EpgTimelineGrid.rowHeight,
                itemCount: channels.length,
                itemBuilder: (context, index) {
                  final channel = channels[index];
                  final entry = entriesByChannel[channel.id];
                  return _EpgChannelRow(
                    key: ValueKey('epg_row_${channel.id}'),
                    channel: channel,
                    entry: entry,
                    windowStart: windowStart,
                    windowDuration: windowDuration,
                    scrollController: _timelineController,
                    onProgramFocus: (offset) => _scrollTimelineTo(offset),
                    onSelect: () => widget.onChannelSelect?.call(channel),
                  );
                },
              ),
              _CurrentTimeIndicator(
                windowStart: windowStart,
                windowDuration: windowDuration,
                pxPerMinute: EpgTimelineGrid.pxPerMinute,
                leftInset: EpgTimelineGrid.channelLabelWidth,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TimeAxis extends StatelessWidget {
  const _TimeAxis({
    required this.windowStart,
    required this.windowDuration,
    required this.pxPerMinute,
  });

  final DateTime windowStart;
  final Duration windowDuration;
  final double pxPerMinute;

  @override
  Widget build(BuildContext context) {
    final hourCount = (windowDuration.inMinutes / 60).ceil();
    return Stack(
      children: [
        for (var i = 0; i <= hourCount; i++)
          Positioned(
            left: i * 60 * pxPerMinute,
            child: Text(
              TimeOfDay.fromDateTime(windowStart.add(Duration(hours: i))).format(context),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
      ],
    );
  }
}

class _EpgChannelRow extends StatelessWidget {
  const _EpgChannelRow({
    super.key,
    required this.channel,
    required this.entry,
    required this.windowStart,
    required this.windowDuration,
    required this.scrollController,
    required this.onProgramFocus,
    required this.onSelect,
  });

  final IPTVChannel channel;
  final CompactEpgWindowEntry? entry;
  final DateTime windowStart;
  final Duration windowDuration;
  final ScrollController scrollController;
  final void Function(double offset) onProgramFocus;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final programs = entry?.programs ?? const <CompactEpgProgram>[];
    return SizedBox(
      height: EpgTimelineGrid.rowHeight,
      child: Row(
        children: [
          SizedBox(
            width: EpgTimelineGrid.channelLabelWidth,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                channel.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              child: SizedBox(
                width: windowDuration.inMinutes * EpgTimelineGrid.pxPerMinute,
                child: Stack(
                  children: [
                    for (final program in programs)
                      _ProgramBlock(
                        key: ValueKey('epg_program_${channel.id}_${program.programId}'),
                        program: program,
                        windowStart: windowStart,
                        windowDuration: windowDuration,
                        onFocus: onProgramFocus,
                        onSelect: onSelect,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgramBlock extends StatelessWidget {
  const _ProgramBlock({
    super.key,
    required this.program,
    required this.windowStart,
    required this.windowDuration,
    required this.onFocus,
    required this.onSelect,
  });

  final CompactEpgProgram program;
  final DateTime windowStart;
  final Duration windowDuration;
  final void Function(double offset) onFocus;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final windowMinutes = windowDuration.inMinutes;
    final startOffsetMinutes = program.startsAt
        .difference(windowStart)
        .inMinutes
        .clamp(0, windowMinutes);
    final endOffsetMinutes = program.endsAt
        .difference(windowStart)
        .inMinutes
        .clamp(0, windowMinutes);
    final left = startOffsetMinutes * EpgTimelineGrid.pxPerMinute;
    final width = ((endOffsetMinutes - startOffsetMinutes) * EpgTimelineGrid.pxPerMinute)
        .clamp(24.0, double.infinity);

    return Positioned(
      left: left,
      width: width,
      top: 4,
      bottom: 4,
      child: TvFocusable(
        onSelect: onSelect,
        onFocus: () => onFocus(left),
        semanticLabel: program.title,
        semanticButton: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Text(
              program.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
      ),
    );
  }
}

/// Repaints its own position on a periodic timer — does NOT trigger a
/// rebuild of [_EpgChannelRow]/[_ProgramBlock] (CV-015 slice 2's explicit
/// "current-time indicator updates without full-row rebuilds" criterion).
class _CurrentTimeIndicator extends StatefulWidget {
  const _CurrentTimeIndicator({
    required this.windowStart,
    required this.windowDuration,
    required this.pxPerMinute,
    required this.leftInset,
  });

  final DateTime windowStart;
  final Duration windowDuration;
  final double pxPerMinute;
  final double leftInset;

  @override
  State<_CurrentTimeIndicator> createState() => _CurrentTimeIndicatorState();
}

class _CurrentTimeIndicatorState extends State<_CurrentTimeIndicator> {
  Timer? _timer;
  DateTime _now = DateTime.now().toUtc();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      setState(() => _now = DateTime.now().toUtc());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutesFromStart = _now.difference(widget.windowStart).inMinutes;
    if (minutesFromStart < 0 || minutesFromStart > widget.windowDuration.inMinutes) {
      return const SizedBox.shrink();
    }
    return Positioned(
      left: widget.leftInset + minutesFromStart * widget.pxPerMinute,
      top: 0,
      bottom: 0,
      child: IgnorePointer(
        child: Container(width: 2, color: Theme.of(context).colorScheme.error),
      ),
    );
  }
}
```

Note: `_CurrentTimeIndicator` is only correctly positioned relative to a horizontally-scrolled row if it accounts for the shared `_timelineController`'s current scroll offset — this first version deliberately does not (it's positioned against the un-scrolled row start, matching `leftInset` only). If a widget test or the task reviewer flags this as visually wrong once scrolled, that's an acceptable, disclosed limitation for this task (the acceptance criterion is "updates without full-row rebuilds," which this satisfies) — do not silently expand scope to fix scroll-offset tracking unless explicitly asked.

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/widgets/epg_timeline_grid_test.dart`
Expected: `00:00 +2: All tests passed!`

- [ ] **Step 5: Write a bounded-render-count test**

Add a third test to `epg_timeline_grid_test.dart` asserting that with e.g. 500 fixture channels, the number of `_EpgChannelRow` widgets actually built stays bounded (well under 500) — pump the widget inside a fixed-height `SizedBox`, then `find.byType` the row widget (exposed via a `Key` pattern, e.g. count `find.byWidgetPredicate((w) => w.key.toString().startsWith('[<epg_row_'))`) and assert the count is small (e.g. `lessThan(30)`), proving `ListView.builder`'s virtualization is actually in effect (this is the issue's explicit "virtualized channel rows; scrolling thousands of channels stays responsive" acceptance criterion — must be a real assertion, not just code review).

- [ ] **Step 6: Run tests to verify they pass**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/widgets/epg_timeline_grid_test.dart`
Expected: `00:00 +3: All tests passed!`

- [ ] **Step 7: Run the full `feature_iptv` suite**

Run: `cd packages/feature_iptv && flutter test`
Expected: all tests pass, no regressions.

- [ ] **Step 8: Commit**

```bash
git add packages/feature_iptv/lib/presentation/widgets/epg_timeline_grid.dart packages/feature_iptv/test/iptv/presentation/widgets/epg_timeline_grid_test.dart
git commit -m "feat(feature_iptv): add EpgTimelineGrid — virtualized horizontal-timeline EPG grid"
```

---

### Task 5: Rewire `IptvGuideScreen`

**Files:**
- Modify: `packages/feature_iptv/lib/presentation/tv/iptv_guide_screen.dart` (full rewrite)
- Modify: `packages/feature_iptv/test/iptv/presentation/tv/iptv_guide_screen_test.dart` (full rewrite)

**Interfaces:**
- Consumes: `EpgTimelineGrid` (Task 4), `guideSearchQueryProvider`, `xmltvSourceConfigProvider` (Task 3), `CompactEpgAvailability` (`package:platform_epg/platform_epg.dart`).
- Produces: `class IptvGuideScreen extends ConsumerWidget` — same public constructor shape as today (`{required VoidCallback onChannelSelected}`) so `app/lib/core/app/tv_router.dart`'s existing call site needs no change; adds a search field and a stale/unavailable banner atop `EpgTimelineGrid`.

- [ ] **Step 1: Write the failing test** (rewrite of the existing 3-test file, adapted for the new widget tree)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';
import 'package:feature_iptv/application/providers/guide_providers.dart';
import 'package:feature_iptv/application/providers/iptv_providers.dart';
import 'package:feature_iptv/presentation/tv/iptv_guide_screen.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_epg/platform_epg.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const newsChannel = IPTVChannel(
    id: 'news-1',
    name: 'City News Live',
    streamUrl: 'https://example.com/news.m3u8',
    group: 'News',
    category: ChannelCategory.news,
  );
  const sportsChannel = IPTVChannel(
    id: 'sports-1',
    name: 'Stadium Sports',
    streamUrl: 'https://example.com/sports.m3u8',
    group: 'Sports',
    category: ChannelCategory.sports,
  );

  Future<void> pumpScreen(
    WidgetTester tester, {
    List<IPTVChannel>? visibleChannels,
    bool called = false,
    void Function()? onSelectedCallback,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final channels = visibleChannels ?? [newsChannel, sportsChannel];
    final now = DateTime.utc(2026, 7, 17, 12);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          iptvChannelsProvider.overrideWith((ref) async => channels),
          streamingStateProvider.overrideWith(
            (ref) => Stream.value(
              const StreamingState(playbackState: PlaybackState.idle, isLiveStream: true),
            ),
          ),
          guideEpgWindowProvider.overrideWith(
            (ref) async => CompactEpgWindow(
              entries: const [],
              windowStart: now,
              windowEnd: now.add(const Duration(hours: 3)),
              generatedAt: now,
              expiresAt: now.add(const Duration(hours: 1)),
              source: CompactEpgSliceSource.unavailable,
            ),
          ),
        ],
        child: MaterialApp(
          home: IptvGuideScreen(onChannelSelected: onSelectedCallback ?? () {}),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('lists all channels with name and group', (tester) async {
    await pumpScreen(tester);

    expect(find.text('City News Live'), findsOneWidget);
    expect(find.text('Stadium Sports'), findsOneWidget);
  }, experimentalLeakTesting: LeakTesting.settings);

  testWidgets('shows empty state when there are no channels', (tester) async {
    await pumpScreen(tester, visibleChannels: const []);

    expect(find.text('No channels to show yet.'), findsOneWidget);
  }, experimentalLeakTesting: LeakTesting.settings);

  testWidgets('selecting a channel plays it and calls onChannelSelected', (tester) async {
    var selected = false;
    await pumpScreen(tester, onSelectedCallback: () => selected = true);

    await tester.tap(find.text('City News Live'));
    await tester.pump();

    expect(selected, isTrue);
  }, experimentalLeakTesting: LeakTesting.settings.withIgnored(notDisposed: {'VideoPlayerController': null}));

  testWidgets('typing in the search box filters the visible channels', (tester) async {
    await pumpScreen(tester);

    await tester.enterText(find.byType(TextField), 'sports');
    await tester.pump();

    expect(find.text('Stadium Sports'), findsOneWidget);
    expect(find.text('City News Live'), findsNothing);
  }, experimentalLeakTesting: LeakTesting.settings);

  testWidgets('shows a stale/unavailable banner when the EPG source is unavailable', (tester) async {
    await pumpScreen(tester);

    expect(find.textContaining('guide data'), findsOneWidget);
  }, experimentalLeakTesting: LeakTesting.settings);
}
```

Check `streamingStateProvider`'s exact type/import (already used by the prior test file per the plan's research — reuse it as-is). Verify `IptvGuideScreen`'s channel-select handler still calls `ref.read(iptvStreamingServiceProvider).playChannel(channel)` and `ref.read(addToRecentlyWatchedProvider(channel))` exactly as before (this is a **live-channel** guide, not VOD — must use `addToRecentlyWatchedProvider`, never `addToVodWatchHistoryProvider`).

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/tv/iptv_guide_screen_test.dart`
Expected: FAIL — old widget tree doesn't match new assertions.

- [ ] **Step 3: Rewrite `lib/presentation/tv/iptv_guide_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_epg/platform_epg.dart';

import '../../application/providers/guide_providers.dart';
import '../../application/providers/iptv_providers.dart';
import '../widgets/epg_timeline_grid.dart';

/// TV Guide: a virtualized horizontal-timeline EPG grid (CV-015 slice 2),
/// sourced from [guideEpgWindowProvider]. Selecting a channel plays it and
/// invokes [onChannelSelected] so the caller (the app shell, which owns
/// routing) can navigate to the live/player screen.
class IptvGuideScreen extends ConsumerWidget {
  const IptvGuideScreen({required this.onChannelSelected, super.key});

  final VoidCallback onChannelSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channelsAsync = ref.watch(iptvChannelsProvider);

    return channelsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text('Could not load the guide: $error', textAlign: TextAlign.center),
      ),
      data: (channels) {
        if (channels.isEmpty) {
          return const Center(child: Text('No channels to show yet.'));
        }
        return Column(
          children: [
            _GuideAvailabilityBanner(),
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Search the guide',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => ref.read(guideSearchQueryProvider.notifier).state = value,
              ),
            ),
            Expanded(
              child: EpgTimelineGrid(
                onChannelSelect: (channel) {
                  ref.read(iptvStreamingServiceProvider).playChannel(channel);
                  ref.read(addToRecentlyWatchedProvider(channel));
                  onChannelSelected();
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _GuideAvailabilityBanner extends ConsumerWidget {
  const _GuideAvailabilityBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final windowAsync = ref.watch(guideEpgWindowProvider);
    final window = windowAsync.valueOrNull;
    if (window == null) return const SizedBox.shrink();

    final availability = window.availabilityAt(DateTime.now().toUtc());
    if (availability == CompactEpgAvailability.available) {
      return const SizedBox.shrink();
    }

    final message = availability == CompactEpgAvailability.stale
        ? 'Guide data is out of date — refresh your XMLTV source in Settings.'
        : 'No guide data available yet — add an XMLTV source in Settings to see programme times.';

    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        message,
        style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/tv/iptv_guide_screen_test.dart`
Expected: `00:00 +5: All tests passed!`

- [ ] **Step 5: Run the full `feature_iptv` suite**

Run: `cd packages/feature_iptv && flutter test`
Expected: all tests pass, no regressions.

- [ ] **Step 6: Commit**

```bash
git add packages/feature_iptv/lib/presentation/tv/iptv_guide_screen.dart packages/feature_iptv/test/iptv/presentation/tv/iptv_guide_screen_test.dart
git commit -m "feat(feature_iptv): rewire IptvGuideScreen onto EpgTimelineGrid, add search and stale-state banner"
```

---

### Task 6: XMLTV source management UI

**Files:**
- Create: `packages/feature_iptv/lib/presentation/widgets/xmltv_source_sheet.dart`
- Test: `packages/feature_iptv/test/iptv/presentation/widgets/xmltv_source_sheet_test.dart`

**Interfaces:**
- Consumes: `xmltvSourceConfigProvider`, `xmltvSourceRefreshServiceProvider`, `xmltvSourceStoreProvider` (Task 3).
- Produces: `class XmltvSourceSheet extends ConsumerStatefulWidget` — a form with a URL text field, "Save & Refresh" button, current source's last-refreshed/last-error display, and a "Remove source" button. Meant to be shown via `showModalBottomSheet`/`showDialog` from a settings surface — this task builds the widget itself; wiring it into a real settings screen is CV-022's job (a separate, not-yet-built issue) — for now, expose it as a public, ready-to-use widget from the barrel so CV-022 can drop it in directly.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feature_iptv/application/providers/guide_providers.dart';
import 'package:feature_iptv/application/xmltv_source_store.dart';
import 'package:feature_iptv/presentation/widgets/xmltv_source_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<ProviderContainer> buildContainer() async {
    final prefs = await SharedPreferences.getInstance();
    return ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
  }

  testWidgets('shows "no source configured" when nothing is saved', (tester) async {
    final container = await buildContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: XmltvSourceSheet())),
      ),
    );
    await tester.pump();

    expect(find.textContaining('No XMLTV source configured'), findsOneWidget);
  });

  testWidgets('shows the saved source URL and last-refreshed state', (tester) async {
    final container = await buildContainer();
    addTearDown(container.dispose);
    await container.read(xmltvSourceStoreProvider).save(
      XmltvSourceConfig(
        url: 'https://example.com/guide.xml',
        lastRefreshedAt: DateTime.utc(2026, 7, 17, 10),
      ),
    );
    container.invalidate(xmltvSourceConfigProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: XmltvSourceSheet())),
      ),
    );
    await tester.pump();

    expect(find.textContaining('https://example.com/guide.xml'), findsOneWidget);
  });

  testWidgets('shows the last error when refresh failed', (tester) async {
    final container = await buildContainer();
    addTearDown(container.dispose);
    await container.read(xmltvSourceStoreProvider).save(
      const XmltvSourceConfig(url: 'https://example.com/guide.xml', lastError: 'Connection timed out'),
    );
    container.invalidate(xmltvSourceConfigProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: XmltvSourceSheet())),
      ),
    );
    await tester.pump();

    expect(find.textContaining('Connection timed out'), findsOneWidget);
  });

  testWidgets('Remove source button clears the saved config', (tester) async {
    final container = await buildContainer();
    addTearDown(container.dispose);
    await container.read(xmltvSourceStoreProvider).save(
      const XmltvSourceConfig(url: 'https://example.com/guide.xml'),
    );
    container.invalidate(xmltvSourceConfigProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: XmltvSourceSheet())),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Remove source'));
    await tester.pump();

    final config = await container.read(xmltvSourceStoreProvider).load();
    expect(config, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/widgets/xmltv_source_sheet_test.dart`
Expected: FAIL — `xmltv_source_sheet.dart` does not exist.

- [ ] **Step 3: Write `lib/presentation/widgets/xmltv_source_sheet.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/guide_providers.dart';

/// Lets the user add, refresh, or remove the single configured XMLTV
/// guide source. A ready-to-use widget — CV-022 (TV settings screen, not
/// yet built) is expected to present this via `showModalBottomSheet` or
/// embed it directly; this task only builds and tests the widget itself.
class XmltvSourceSheet extends ConsumerStatefulWidget {
  const XmltvSourceSheet({super.key});

  @override
  ConsumerState<XmltvSourceSheet> createState() => _XmltvSourceSheetState();
}

class _XmltvSourceSheetState extends ConsumerState<XmltvSourceSheet> {
  final _urlController = TextEditingController();
  bool _isRefreshing = false;
  String? _refreshFeedback;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _saveAndRefresh() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _isRefreshing = true;
      _refreshFeedback = null;
    });

    try {
      await ref.read(xmltvSourceRefreshServiceProvider).refresh(url);
      setState(() => _refreshFeedback = 'Guide refreshed.');
    } catch (e) {
      setState(() => _refreshFeedback = 'Refresh failed: $e');
    } finally {
      setState(() => _isRefreshing = false);
      ref.invalidate(xmltvSourceConfigProvider);
    }
  }

  Future<void> _removeSource() async {
    await ref.read(xmltvSourceStoreProvider).clear();
    ref.invalidate(xmltvSourceConfigProvider);
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(xmltvSourceConfigProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('XMLTV Guide Source', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          configAsync.when(
            loading: () => const CircularProgressIndicator(),
            error: (error, _) => Text('Could not load source config: $error'),
            data: (config) {
              if (config == null) {
                return const Text('No XMLTV source configured yet.');
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Current source: ${config.url}'),
                  const SizedBox(height: 4),
                  Text(
                    config.lastRefreshedAt != null
                        ? 'Last refreshed: ${config.lastRefreshedAt}'
                        : 'Never refreshed successfully.',
                  ),
                  if (config.lastError != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      config.lastError!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                  TextButton(onPressed: _removeSource, child: const Text('Remove source')),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: 'XMLTV URL',
              hintText: 'https://example.com/guide.xml',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _isRefreshing ? null : _saveAndRefresh,
            child: _isRefreshing
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save & Refresh'),
          ),
          if (_refreshFeedback != null) ...[
            const SizedBox(height: 8),
            Text(_refreshFeedback!),
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/widgets/xmltv_source_sheet_test.dart`
Expected: `00:00 +4: All tests passed!`

- [ ] **Step 5: Run the full `feature_iptv` suite**

Run: `cd packages/feature_iptv && flutter test`
Expected: all tests pass, no regressions.

- [ ] **Step 6: Commit**

```bash
git add packages/feature_iptv/lib/presentation/widgets/xmltv_source_sheet.dart packages/feature_iptv/test/iptv/presentation/widgets/xmltv_source_sheet_test.dart
git commit -m "feat(feature_iptv): add XmltvSourceSheet — add/refresh/remove XMLTV source UI"
```

---

### Task 7: Manual channel-to-EPG-id match override UI

**Files:**
- Create: `packages/feature_iptv/lib/presentation/widgets/epg_match_override_sheet.dart`
- Test: `packages/feature_iptv/test/iptv/presentation/widgets/epg_match_override_sheet_test.dart`

**Interfaces:**
- Consumes: `epgChannelMatchOverrideStoreProvider`, `guideEpgOverridesProvider` (Task 3), `IPTVChannel` (`package:platform_channels/platform_channels.dart`).
- Produces: `class EpgMatchOverrideSheet extends ConsumerStatefulWidget { EpgMatchOverrideSheet({required IPTVChannel channel}); }` — a small dialog/sheet showing the channel's current EPG match (its own id, or the override if one is set), a text field to enter a manual EPG channel id, and Save/Clear buttons.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feature_iptv/application/providers/guide_providers.dart';
import 'package:feature_iptv/presentation/widgets/epg_match_override_sheet.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const channel = IPTVChannel(
    id: 'channel-1',
    name: 'Example Channel',
    streamUrl: 'https://example.com/stream.m3u8',
    group: 'News',
  );

  Future<ProviderContainer> buildContainer() async {
    final prefs = await SharedPreferences.getInstance();
    return ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
  }

  testWidgets('shows the channel id as the default match when no override is set', (tester) async {
    final container = await buildContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: EpgMatchOverrideSheet(channel: channel))),
      ),
    );
    await tester.pump();

    expect(find.textContaining('channel-1'), findsWidgets);
  });

  testWidgets('entering an id and tapping Save persists the override', (tester) async {
    final container = await buildContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: EpgMatchOverrideSheet(channel: channel))),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'manual.epg.id');
    await tester.tap(find.text('Save'));
    await tester.pump();

    final resolved = await container
        .read(epgChannelMatchOverrideStoreProvider)
        .resolveEpgChannelId('channel-1');
    expect(resolved, 'manual.epg.id');
  });

  testWidgets('tapping Clear removes an existing override', (tester) async {
    final container = await buildContainer();
    addTearDown(container.dispose);
    await container.read(epgChannelMatchOverrideStoreProvider).setOverride(
      channelId: 'channel-1',
      epgChannelId: 'manual.epg.id',
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: EpgMatchOverrideSheet(channel: channel))),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Clear override'));
    await tester.pump();

    final resolved = await container
        .read(epgChannelMatchOverrideStoreProvider)
        .resolveEpgChannelId('channel-1');
    expect(resolved, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/widgets/epg_match_override_sheet_test.dart`
Expected: FAIL — `epg_match_override_sheet.dart` does not exist.

- [ ] **Step 3: Write `lib/presentation/widgets/epg_match_override_sheet.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_channels/platform_channels.dart';

import '../../application/providers/guide_providers.dart';

/// Lets the user manually set (or clear) which EPG channel id a specific
/// [IPTVChannel] should be matched against, for when tvg-id auto-matching
/// fails (CV-015 slice 2's explicit real-world IPTV pain point).
class EpgMatchOverrideSheet extends ConsumerStatefulWidget {
  const EpgMatchOverrideSheet({required this.channel, super.key});

  final IPTVChannel channel;

  @override
  ConsumerState<EpgMatchOverrideSheet> createState() => _EpgMatchOverrideSheetState();
}

class _EpgMatchOverrideSheetState extends ConsumerState<EpgMatchOverrideSheet> {
  final _idController = TextEditingController();
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    ref
        .read(epgChannelMatchOverrideStoreProvider)
        .resolveEpgChannelId(widget.channel.id)
        .then((existing) {
          if (mounted) {
            _idController.text = existing ?? widget.channel.id;
          }
        });
  }

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final id = _idController.text.trim();
    if (id.isEmpty) return;
    await ref.read(epgChannelMatchOverrideStoreProvider).setOverride(
      channelId: widget.channel.id,
      epgChannelId: id,
    );
    ref.invalidate(guideEpgOverridesProvider);
  }

  Future<void> _clear() async {
    await ref.read(epgChannelMatchOverrideStoreProvider).clearOverride(widget.channel.id);
    _idController.text = widget.channel.id;
    ref.invalidate(guideEpgOverridesProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Match "${widget.channel.name}" to EPG channel', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('Default (no override): ${widget.channel.id}', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          TextField(
            controller: _idController,
            decoration: const InputDecoration(labelText: 'EPG channel id', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              FilledButton(onPressed: _save, child: const Text('Save')),
              const SizedBox(width: 8),
              TextButton(onPressed: _clear, child: const Text('Clear override')),
            ],
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/widgets/epg_match_override_sheet_test.dart`
Expected: `00:00 +3: All tests passed!`

- [ ] **Step 5: Export new public widgets from the barrel**

Add to `packages/feature_iptv/lib/feature_iptv.dart`:

```dart
export 'presentation/widgets/xmltv_source_sheet.dart';
export 'presentation/widgets/epg_match_override_sheet.dart';
```

- [ ] **Step 6: Run the full `feature_iptv` suite**

Run: `cd packages/feature_iptv && flutter test`
Expected: all tests pass, no regressions.

- [ ] **Step 7: Commit**

```bash
git add packages/feature_iptv/lib/presentation/widgets/epg_match_override_sheet.dart packages/feature_iptv/test/iptv/presentation/widgets/epg_match_override_sheet_test.dart packages/feature_iptv/lib/feature_iptv.dart
git commit -m "feat(feature_iptv): add EpgMatchOverrideSheet — manual channel-to-EPG-id override UI"
```

---

### Task 8: App wiring + full regression

**Files:**
- Modify: `app/lib/main_tv.dart`

**Interfaces:**
- Consumes: `mutableXmltvCompactEpgRepositoryProvider`, `xmltvSourceRefreshServiceProvider` (Task 3, via `package:feature_iptv/feature_iptv.dart` — check these are exported from the barrel; if `guide_providers.dart`'s providers aren't yet in `feature_iptv.dart`'s export list, add them in this task).

**Wiring:** `main_tv.dart`'s `createTvCompactEpgRepository()` currently builds a `SnapshotBackedCompactEpgRepository` with no `fallback` (defaulting to `EmptyCompactEpgRepository`). This task passes the app's single `MutableXmltvCompactEpgRepository` instance (read once from a temporary `ProviderContainer` before `runApp`, matching the existing pattern where `compactEpgRepository` is built before `runApp` and passed via `overrideWithValue`) as that `fallback`, and schedules a deferred startup task to call `xmltvSourceRefreshService.refreshConfiguredSource()` (matching the existing `scheduleTvDebugDefaultEpgWarmup` deferred-task pattern) so a previously-configured XMLTV source refreshes automatically on app launch, not only when the user manually taps "Save & Refresh."

- [ ] **Step 1: Export `guide_providers.dart`'s providers from the barrel** (if not already done in Task 7)

Check `packages/feature_iptv/lib/feature_iptv.dart` — if `application/providers/guide_providers.dart` isn't exported, add:

```dart
export 'application/providers/guide_providers.dart';
```

- [ ] **Step 2: Modify `createTvCompactEpgRepository` and startup wiring in `app/lib/main_tv.dart`**

Read the full current `main()` and `createTvCompactEpgRepository` first (this plan's earlier research captured lines 50-100 and 262-276 — re-verify against the actual file since a concurrent unrelated branch may have touched this file). Change:

```dart
@visibleForTesting
SnapshotBackedCompactEpgRepository createTvCompactEpgRepository({
  Future<Directory> Function()? supportDirectoryProvider,
  CompactEpgRepository? fallback,
}) {
  final directoryProvider = supportDirectoryProvider ?? getApplicationSupportDirectory;
  return SnapshotBackedCompactEpgRepository(
    store: FileCompactEpgSnapshotStore(
      fileProvider: () async {
        final supportDir = await directoryProvider();
        return File('${supportDir.path}/epg/compact_epg_snapshot.json');
      },
    ),
    fallback: fallback ?? const EmptyCompactEpgRepository(),
  );
}
```

In `main()`, build the `MutableXmltvCompactEpgRepository` before `runApp` and thread it through:

```dart
final mutableXmltvRepository = MutableXmltvCompactEpgRepository();
final compactEpgRepository = createTvCompactEpgRepository(fallback: mutableXmltvRepository);
```

After `runApp(...)`, schedule the configured-source refresh (mirroring `scheduleTvDebugDefaultEpgWarmup`'s existing call site immediately below it):

```dart
scheduleDeferredStartupTask(
  debugName: 'xmltv_configured_source_refresh',
  task: () async {
    final refreshService = XmltvSourceRefreshService(
      dio: Dio(),
      sourceStore: XmltvSourceStore(PreferencesStore(prefs)),
      repository: mutableXmltvRepository,
      downloadDirectoryProvider: getTemporaryDirectory,
    );
    await refreshService.refreshConfiguredSource();
  },
);
```

Check `SnapshotBackedCompactEpgRepository`'s exact constructor parameter name for `fallback` against `packages/platform_epg/lib/src/compact_epg_snapshot_repository.dart` before writing this — the plan's earlier research confirmed a `fallback` param exists but didn't capture its exact name/default; verify, don't guess.

- [ ] **Step 3: Run `app`'s existing test suite**

Run: `cd app && flutter test test/main_tv_test.dart` (or whatever the actual test file covering `main_tv.dart` is named — locate it first with `find app/test -iname "*main_tv*"`)
Expected: all tests pass, no regressions. If `createTvCompactEpgRepository`'s test asserts its exact return type/behavior, it may need updating to account for the new `fallback` parameter (still `SnapshotBackedCompactEpgRepository`, so the type-level assertions shouldn't need to change, only maybe a new test case for the `fallback` param itself — read the existing test first).

- [ ] **Step 4: Run `flutter analyze` on `app`**

Run: `cd app && flutter analyze`
Expected: no new errors compared to the pre-existing baseline.

- [ ] **Step 5: Run the full test suite across all touched packages**

Run:
```bash
cd packages/feature_iptv && flutter test
cd ../platform_epg && flutter test
cd ../../app && flutter test
```
Expected: all green. `platform_epg`'s suite should be completely unaffected (this plan never modifies it) — this run is a sanity check, not expected to surface anything.

- [ ] **Step 6: Commit**

```bash
git add app/lib/main_tv.dart packages/feature_iptv/lib/feature_iptv.dart
git commit -m "feat(app): wire MutableXmltvCompactEpgRepository as the TV guide's EPG fallback"
```

---

## Self-Review

**Spec coverage against issue #825 acceptance criteria:**
- Guide UI consumes `compactEpgWindowProvider`, not just current/next → Task 3 (`guideEpgWindowProvider` wraps it with match-override remapping), Task 4-5 (UI consumes it).
- Virtualized channel rows → Task 4 (`ListView.builder` with `itemExtent`, plus an explicit bounded-render-count test with a 500-channel fixture).
- Program block width proportional to visible duration → Task 4 (`_ProgramBlock`'s width/left calculation).
- Current-time indicator updates without full-row rebuilds → Task 4 (`_CurrentTimeIndicator` is its own `StatefulWidget` with its own `Timer.periodic`, siblings of the row `ListView` inside a `Stack`, not inside any row).
- Guide search/filter reuses CV-006's index → Task 3 (`guideFilteredChannelsProvider` calls the existing `channelSearchIndexProvider`'s `AiroChannelSearchIndex.filterAndSort`, no second index built).
- XMLTV source add/remove/refresh with explicit stale/unavailable UI → Task 1 (`XmltvSourceStore`), Task 2 (`XmltvSourceRefreshService`), Task 6 (UI), Task 5 (`_GuideAvailabilityBanner` reading `CompactEpgWindow.availabilityAt`).
- Manual channel-to-EPG-id match override, persisted locally → Task 1 (`EpgChannelMatchOverrideStore`), Task 3 (applied in `guideEpgWindowProvider`), Task 7 (UI).
- Tests: focus/navigation (D-pad) → Task 4's `TvFocusable`-wrapped `_ProgramBlock`s inherit Flutter's default directional-focus traversal (confirmed this repo's existing pattern relies on this rather than custom focus code — no additional D-pad-specific test infrastructure needed beyond what `TvFocusable` already provides, though a reviewer may reasonably ask for an explicit focus-traversal widget test if none exists after Task 4). No overflow → standard widget-test practice (no `RenderFlex overflowed` assertion failures across any new widget test). Bounded render count → Task 4 Step 5's explicit test. Search result correctness → Task 3's `guideFilteredChannelsProvider` test, Task 5's search-box widget test. Stale-state rendering → Task 5's stale/unavailable banner test.

**Placeholder scan:** every step has complete, real code. The one disclosed, intentional limitation (Task 4's `_CurrentTimeIndicator` not accounting for horizontal scroll offset) is explicitly flagged as an acceptable v1 gap, not a placeholder — the acceptance criterion it must satisfy ("updates without full-row rebuilds") is fully met regardless.

**Type consistency:** `EpgChannelMatchOverrideStore`/`XmltvSourceStore`/`XmltvSourceConfig` (Task 1) are consumed identically in Tasks 2-3, 6-7. `MutableXmltvCompactEpgRepository`/`XmltvSourceRefreshService` (Task 2) match their usage in Task 3's providers and Task 8's app wiring exactly. `guideEpgWindowProvider`/`guideFilteredChannelsProvider`/`guideSearchQueryProvider` (Task 3) are consumed identically by Task 4's `EpgTimelineGrid` and Task 5's `IptvGuideScreen`.

**Known open items for the assigned engineer, flagged rather than guessed at:**
- Task 2's `Dio.download()` fake-adapter test may need adjustment once actually run (disclosed in Task 2 Step 5).
- Task 2's `XmltvCompactEpgRepository.fromXmltvFileNative` exact parameter list should be re-verified against the live source file before writing the call (disclosed in Task 2 Step 7).
- Task 8's `SnapshotBackedCompactEpgRepository`'s `fallback` constructor parameter name should be re-verified (disclosed in Task 8 Step 2) — this plan's research confirmed the parameter *exists* but a fresh read is cheap insurance before wiring it.
- `main_tv.dart` may have shifted since this plan's research (a concurrent unrelated branch was actively editing playback-engine code in the same file space at plan-writing time) — Task 8's implementer must re-read the live file rather than trusting this plan's line numbers.
