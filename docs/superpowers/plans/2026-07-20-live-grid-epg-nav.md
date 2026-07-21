# Live Grid Navigation (EPG) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the Live Grid Navigation EPG: a touch/drag-scrollable 24h-paginated timeline grid on phone with a "Jump to Present" anchor, live progress tickers, and OS-notification program reminders, while the existing TV D-pad grid gains the same now-anchor and progress tickers — all over one shared paged EPG data path.

**Architecture:** `platform_epg` stays untouched. `feature_iptv/application` gains an extracted shared window-query helper (`queryGuideWindowWithOverrides`), a `GuidePagedWindowNotifier` (3h pages, `[now-30min, now+24h]`), a shared `nowTickerProvider`, and a reminder trio (`EpgReminder`/`EpgReminderStore`/`EpgReminderScheduler` behind an `EpgReminderNotificationGateway` interface so `feature_iptv` takes no new package dependency). `feature_iptv/presentation` gains `EpgTouchTimelineGrid` (phone: drag scroll, tap current→play, tap future→remind, now-anchor FAB, progress tickers) and additive changes to `EpgTimelineGrid` (TV: progress tickers, focusable "Jump to Present"). `app/` wires a `flutter_local_notifications`-backed gateway (plugin + `timezone` already in `app/pubspec.yaml`) and routes notification taps through the existing `/iptv?channel=<id>` deep link from the Immediate Action Player feature.

**Tech Stack:** Flutter/Dart (SDK `^3.12.2`), Riverpod 3 (`Notifier`/`NotifierProvider` from `flutter_riverpod`; `StateProvider` only via `flutter_riverpod/legacy.dart`), `flutter_local_notifications` ^22 + `timezone` (app only), `core_data` `KeyValueStore`/`PreferencesStore`, existing `platform_epg` `CompactEpgRepository`/`InMemoryCompactEpgRepository`.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-07-20-live-grid-epg-nav-design.md`. Read it first.
- No new package dependencies in `feature_iptv` (CV-015 precedent). `flutter_local_notifications` is an `app`-only dependency; `feature_iptv` sees only the `EpgReminderNotificationGateway` interface.
- `packages/platform_epg` is not modified.
- TV is receiver-only: no reminder/notification UI on TV (`iptv_tv_screen.dart` untouched). TV grid changes are additive — `NeverScrollableScrollPhysics` and focus-follow-scroll behavior must not change; all existing `epg_timeline_grid_test.dart` tests must keep passing (updated only where Task 8's provider migration requires).
- Shared `ScrollController` multi-attachment rule (CV-015): never read `.position` on a controller with multiple attachments; use `.positions.first`. This applies to both grids.
- One data path: `guideEpgWindowProvider` is removed in Task 8 after both grids and the availability banner migrate to `guidePagedWindowProvider`.
- Add `[skip ci]` to every commit (repo CI cost rule).
- Reminder scheduling uses `AndroidScheduleMode.inexactAllowWhileIdle` — no `SCHEDULE_EXACT_ALARM`/`USE_EXACT_ALARM` manifest permission, no Play declaration. Program reminders don't need second precision.
- Manual QA gate before merge: OS notification delivery + deep-link tap on physical iOS and Android hardware (not automatable in CI, same gate as the Player feature).
- Validate locally per package: `cd packages/feature_iptv && flutter test` (and `cd app && flutter test` for Task 9-10 changes) — do not push for CI.

---

## File Structure

```
packages/feature_iptv/
  lib/application/
    guide_window_query.dart                            [new — Task 1]
    epg_reminder_store.dart                            [new — Task 3]
    epg_reminder_scheduler.dart                        [new — Task 4]
    providers/guide_providers.dart                     [modify — Tasks 1, 2, 8]
    providers/epg_reminder_providers.dart              [new — Task 4]
  lib/presentation/widgets/
    epg_program_progress.dart                          [new — Task 5]
    epg_touch_timeline_grid.dart                       [new — Tasks 5, 6]
    epg_timeline_grid.dart                             [modify — Task 7]
  lib/presentation/tv/iptv_guide_screen.dart           [modify — Task 8]
  lib/feature_iptv.dart                                [modify — Task 8]
  test/iptv/application/
    guide_window_query_test.dart                       [new — Task 1]
    epg_reminder_store_test.dart                       [new — Task 3]
    epg_reminder_scheduler_test.dart                   [new — Task 4]
    providers/guide_paged_window_notifier_test.dart    [new — Task 2]
    providers/guide_providers_test.dart                [modify — Task 8]
  test/iptv/presentation/
    widgets/epg_touch_timeline_grid_test.dart          [new — Tasks 5, 6]
    widgets/epg_timeline_grid_test.dart                [modify — Tasks 7, 8]
    tv/iptv_guide_screen_test.dart                     [modify — Task 8]

app/
  lib/features/iptv/epg_reminder_notification_gateway.dart  [new — Task 9]
  lib/main.dart                                             [modify — Task 9]
  test/features/iptv/epg_reminder_notification_gateway_test.dart [new — Task 9]
  test/core/routing/guide_back_behavior_test.dart           [new — Task 10]
```

---

### Task 1: Shared guide-window query helper + merge function

**Files:**
- Create: `packages/feature_iptv/lib/application/guide_window_query.dart`
- Test: `packages/feature_iptv/test/iptv/application/guide_window_query_test.dart`
- Modify: `packages/feature_iptv/lib/application/providers/guide_providers.dart`

**Interfaces:**
- Consumes: `IPTVChannel` (`package:platform_channels/platform_channels.dart`), `CompactEpgRepository`/`CompactEpgWindow`/`CompactEpgWindowEntry`/`CompactEpgProgram`/`GuideWindowQuery` (`package:platform_epg/platform_epg.dart`).
- Produces: `Future<CompactEpgWindow> queryGuideWindowWithOverrides({required List<IPTVChannel> channels, required Map<String, String> overrides, required Set<String> hiddenGroupIds, required CompactEpgRepository repository, required DateTime windowStart, required DateTime windowEnd, required DateTime now})`; `CompactEpgWindow mergeGuideWindowPage(CompactEpgWindow? base, CompactEpgWindow page)`.

- [ ] **Step 1: Write the failing tests**

```dart
// packages/feature_iptv/test/iptv/application/guide_window_query_test.dart
import 'package:feature_iptv/application/guide_window_query.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_epg/platform_epg.dart';

void main() {
  final now = DateTime.utc(2026, 7, 20, 12);

  const channel = IPTVChannel(
    id: 'channel-1',
    name: 'Example Channel',
    streamUrl: 'https://example.com/stream.m3u8',
    group: 'News',
  );

  CompactEpgProgram program(String id, String title, int startHour, int endHour) {
    return CompactEpgProgram(
      programId: id,
      title: title,
      startsAt: DateTime.utc(2026, 7, 20, startHour),
      endsAt: DateTime.utc(2026, 7, 20, endHour),
    );
  }

  InMemoryCompactEpgRepository repoWith(List<CompactEpgEntry> entries) {
    return InMemoryCompactEpgRepository(
      seed: CompactEpgSlice(
        entries: entries,
        generatedAt: now,
        expiresAt: now.add(const Duration(hours: 24)),
        source: CompactEpgSliceSource.localCache,
      ),
    );
  }

  group('queryGuideWindowWithOverrides', () {
    test('queries with the raw channel id when no override is set', () async {
      final repo = repoWith([
        CompactEpgEntry(
          channelId: 'channel-1',
          channelName: 'Example Channel',
          current: program('p1', 'Now Showing', 11, 13),
        ),
      ]);

      final window = await queryGuideWindowWithOverrides(
        channels: const [channel],
        overrides: const {},
        hiddenGroupIds: const {},
        repository: repo,
        windowStart: now.subtract(const Duration(hours: 1)),
        windowEnd: now.add(const Duration(hours: 2)),
        now: now,
      );

      expect(window.entryForChannel('channel-1')?.programs, isNotEmpty);
    });

    test('queries with the override EPG id and remaps to the channel id', () async {
      final repo = repoWith([
        CompactEpgEntry(
          channelId: 'overridden.epg.id',
          channelName: 'Example Channel (EPG)',
          current: program('p1', 'Now Showing', 11, 13),
        ),
      ]);

      final window = await queryGuideWindowWithOverrides(
        channels: const [channel],
        overrides: const {'channel-1': 'overridden.epg.id'},
        hiddenGroupIds: const {},
        repository: repo,
        windowStart: now.subtract(const Duration(hours: 1)),
        windowEnd: now.add(const Duration(hours: 2)),
        now: now,
      );

      expect(window.entryForChannel('channel-1')?.programs, isNotEmpty);
      expect(window.entryForChannel('overridden.epg.id'), isNull);
    });

    test('excludes channels in hidden groups from the query (CV-021)', () async {
      var queriedIds = <String>[];
      final repo = _RecordingRepository(
        onQuery: (ids) => queriedIds = List.of(ids),
        now: now,
      );

      final window = await queryGuideWindowWithOverrides(
        channels: const [channel],
        overrides: const {},
        hiddenGroupIds: const {'News'},
        repository: repo,
        windowStart: now,
        windowEnd: now.add(const Duration(hours: 1)),
        now: now,
      );

      expect(queriedIds, isEmpty);
      expect(window.entries, isEmpty);
    });
  });

  group('mergeGuideWindowPage', () {
    CompactEpgWindow windowFor(
      List<CompactEpgProgram> programs,
      DateTime start,
      DateTime end,
    ) {
      return CompactEpgWindow(
        entries: [
          CompactEpgWindowEntry(
            channelId: 'channel-1',
            channelName: 'Example Channel',
            programs: programs,
          ),
        ],
        windowStart: start,
        windowEnd: end,
        generatedAt: now,
        expiresAt: now.add(const Duration(hours: 24)),
        source: CompactEpgSliceSource.localCache,
      );
    }

    test('null base returns the page unchanged', () {
      final page = windowFor([program('p1', 'A', 12, 13)], now, now.add(const Duration(hours: 3)));

      expect(mergeGuideWindowPage(null, page), same(page));
    });

    test('concatenates programs per channel, sorted by startsAt', () {
      final base = windowFor([program('p2', 'B', 13, 14)], now, now.add(const Duration(hours: 1)));
      final page = windowFor(
        [program('p1', 'A', 14, 15)],
        now.add(const Duration(hours: 1)),
        now.add(const Duration(hours: 2)),
      );

      final merged = mergeGuideWindowPage(base, page);
      final titles = merged.entryForChannel('channel-1')!.programs.map((p) => p.title);

      expect(titles, ['B', 'A']);
      expect(merged.windowStart, now);
      expect(merged.windowEnd, now.add(const Duration(hours: 2)));
    });

    test('dedupes programs by programId when pages overlap', () {
      final shared = program('p1', 'Shared', 13, 14);
      final base = windowFor([shared], now, now.add(const Duration(hours: 2)));
      final page = windowFor(
        [shared, program('p2', 'New', 14, 15)],
        now.add(const Duration(hours: 2)),
        now.add(const Duration(hours: 4)),
      );

      final merged = mergeGuideWindowPage(base, page);

      expect(merged.entryForChannel('channel-1')!.programs, hasLength(2));
    });
  });
}

class _RecordingRepository implements CompactEpgRepository {
  _RecordingRepository({required this.onQuery, required this.now});

  final void Function(Iterable<String> channelIds) onQuery;
  final DateTime now;

  @override
  Future<CompactEpgSlice> loadCurrentNext({
    required Iterable<String> channelIds,
    required DateTime now,
  }) async {
    return CompactEpgSlice(
      entries: const [],
      generatedAt: now,
      expiresAt: now,
      source: CompactEpgSliceSource.unavailable,
    );
  }

  @override
  Future<CompactEpgWindow> loadWindow(GuideWindowQuery query) async {
    onQuery(query.channelIds);
    return CompactEpgWindow(
      entries: const [],
      windowStart: query.windowStart,
      windowEnd: query.windowEnd,
      generatedAt: now,
      expiresAt: now.add(const Duration(hours: 1)),
      source: CompactEpgSliceSource.unavailable,
    );
  }
}
```

Check before writing: `CompactEpgWindowEntry` may not have a `programs` positional/named constructor param named exactly `programs` and may require `sourceRef` — read `packages/platform_epg/lib/src/` models (`compact_epg_window*.dart` or similar; grep `class CompactEpgWindowEntry`) and adjust the constructor calls above to match the real signature. Same for `CompactEpgWindow` (`schemaVersion` was used in the existing remap code — keep whatever the real constructor requires) and `CompactEpgSlice`/`CompactEpgEntry` (the existing `guide_providers_test.dart` shows working construction patterns — copy them).

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd packages/feature_iptv && flutter test test/iptv/application/guide_window_query_test.dart`
Expected: FAIL — `guide_window_query.dart` does not exist.

- [ ] **Step 3: Write `lib/application/guide_window_query.dart`**

```dart
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_epg/platform_epg.dart';

/// Shared bounded guide-window query with CV-015 match-override semantics:
/// each channel is queried under its override EPG id if one is set, hidden
/// groups are excluded (CV-021), and results are remapped back to the
/// original [IPTVChannel.id] so callers never need to know an override was
/// involved. Extracted from the former `guideEpgWindowProvider` body so the
/// paged guide window (Live Grid Navigation) shares one query path.
Future<CompactEpgWindow> queryGuideWindowWithOverrides({
  required List<IPTVChannel> channels,
  required Map<String, String> overrides,
  required Set<String> hiddenGroupIds,
  required CompactEpgRepository repository,
  required DateTime windowStart,
  required DateTime windowEnd,
  required DateTime now,
}) async {
  final epgIdToChannelId = <String, String>{};
  final queryIds = <String>[];
  for (final channel in channels) {
    if (hiddenGroupIds.contains(channel.group)) continue;
    final epgId = overrides[channel.id] ?? channel.id;
    epgIdToChannelId[epgId] = channel.id;
    queryIds.add(epgId);
  }

  final rawWindow = await repository.loadWindow(
    GuideWindowQuery(
      channelIds: queryIds,
      windowStart: windowStart,
      windowEnd: windowEnd,
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
}

/// Merges a freshly loaded page into the accumulated paged window: programs
/// are concatenated per channel, deduped by `programId` (pages can straddle
/// a program), and sorted by `startsAt`. The merged window spans
/// `[base.windowStart, page.windowEnd)`.
CompactEpgWindow mergeGuideWindowPage(
  CompactEpgWindow? base,
  CompactEpgWindow page,
) {
  if (base == null) return page;

  final programsByChannel = <String, Map<String, CompactEpgProgram>>{};
  final metaByChannel = <String, CompactEpgWindowEntry>{};
  for (final entry in [...base.entries, ...page.entries]) {
    metaByChannel[entry.channelId] = entry;
    final programs = programsByChannel.putIfAbsent(
      entry.channelId,
      () => <String, CompactEpgProgram>{},
    );
    for (final program in entry.programs) {
      programs[program.programId] = program;
    }
  }

  final mergedEntries = [
    for (final channelId in programsByChannel.keys)
      CompactEpgWindowEntry(
        channelId: channelId,
        channelName: metaByChannel[channelId]!.channelName,
        channelNumber: metaByChannel[channelId]!.channelNumber,
        programs: programsByChannel[channelId]!.values.toList()
          ..sort((a, b) => a.startsAt.compareTo(b.startsAt)),
        sourceRef: metaByChannel[channelId]!.sourceRef,
      ),
  ];

  return CompactEpgWindow(
    entries: mergedEntries,
    windowStart: base.windowStart,
    windowEnd: page.windowEnd,
    generatedAt: page.generatedAt,
    expiresAt: page.expiresAt,
    source: page.source,
    schemaVersion: page.schemaVersion,
  );
}
```

- [ ] **Step 4: Rewire `guideEpgWindowProvider` through the helper**

In `packages/feature_iptv/lib/application/providers/guide_providers.dart`, replace the entire body of `guideEpgWindowProvider` (the inline query+remap logic) with a call to the helper, and add the import:

```dart
import '../guide_window_query.dart';

/// Bounded guide-window query (CV-015) — thin wrapper over
/// [queryGuideWindowWithOverrides] until Task 8 removes this provider in
/// favor of [guidePagedWindowProvider].
final guideEpgWindowProvider = FutureProvider<CompactEpgWindow>((ref) async {
  final channels = await ref.watch(iptvChannelsProvider.future);
  final overrides = await ref.watch(guideEpgOverridesProvider.future);
  final hiddenGroupIds = await ref.watch(hiddenGroupIdsProvider.future);
  final windowStart = ref.watch(guideWindowStartProvider);
  final windowDuration = ref.watch(guideWindowDurationProvider);

  return queryGuideWindowWithOverrides(
    channels: channels,
    overrides: overrides,
    hiddenGroupIds: hiddenGroupIds,
    repository: ref.watch(compactEpgRepositoryProvider),
    windowStart: windowStart,
    windowEnd: windowStart.add(windowDuration),
    now: DateTime.now().toUtc(),
  );
});
```

Check `hiddenGroupIdsProvider`'s type first — `grep -n "hiddenGroupIdsProvider" packages/feature_iptv/lib/application/providers/iptv_providers.dart`. If it is a plain `Provider<Set<String>>` rather than a `FutureProvider`, drop the `.future`/`await` accordingly (its usage at `iptv_providers.dart:225` reads `.value`, which implies a FutureProvider — confirm).

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd packages/feature_iptv && flutter test test/iptv/application/guide_window_query_test.dart test/iptv/application/providers/guide_providers_test.dart`
Expected: all PASS — new helper tests pass, existing provider tests unchanged in behavior.

- [ ] **Step 6: Commit**

```bash
git add packages/feature_iptv/lib/application/guide_window_query.dart \
        packages/feature_iptv/lib/application/providers/guide_providers.dart \
        packages/feature_iptv/test/iptv/application/guide_window_query_test.dart
git commit -m "refactor(feature_iptv): extract shared guide-window query helper [skip ci]"
```

---

### Task 2: `GuidePagedWindowNotifier` + `nowTickerProvider`

**Files:**
- Modify: `packages/feature_iptv/lib/application/providers/guide_providers.dart`
- Test: `packages/feature_iptv/test/iptv/application/providers/guide_paged_window_notifier_test.dart`

**Interfaces:**
- Consumes: `queryGuideWindowWithOverrides`/`mergeGuideWindowPage` (Task 1), `iptvChannelsProvider`, `guideEpgOverridesProvider`, `hiddenGroupIdsProvider`, `compactEpgRepositoryProvider` (existing).
- Produces: `class GuidePagedWindowState { DateTime earliestStart; DateTime loadedThrough; CompactEpgWindow? window; bool isLoadingForward; bool forwardLoadFailed; }`; `class GuidePagedWindowNotifier extends Notifier<GuidePagedWindowState> { Future<void> extendForward(); Future<void> retryForward(); void debugSetNow(DateTime Function() now); }`; `final guidePagedWindowProvider = NotifierProvider<GuidePagedWindowNotifier, GuidePagedWindowState>(GuidePagedWindowNotifier.new)`; `final nowTickerProvider = StreamProvider<DateTime>`.

- [ ] **Step 1: Write the failing tests**

```dart
// packages/feature_iptv/test/iptv/application/providers/guide_paged_window_notifier_test.dart
import 'package:feature_iptv/application/providers/guide_providers.dart';
import 'package:feature_iptv/application/providers/iptv_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_epg/platform_epg.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final fixedNow = DateTime.utc(2026, 7, 20, 12, 10);

  const channel = IPTVChannel(
    id: 'channel-1',
    name: 'Example Channel',
    streamUrl: 'https://example.com/stream.m3u8',
    group: 'News',
  );

  CompactEpgProgram programAt(String id, int startHour) {
    return CompactEpgProgram(
      programId: id,
      title: 'Show $id',
      startsAt: DateTime.utc(2026, 7, 20, startHour),
      endsAt: DateTime.utc(2026, 7, 20, startHour + 1),
    );
  }

  InMemoryCompactEpgRepository buildRepo() {
    return InMemoryCompactEpgRepository(
      seed: CompactEpgSlice(
        entries: [
          CompactEpgEntry(
            channelId: 'channel-1',
            channelName: 'Example Channel',
            current: programAt('p-noon', 12),
          ),
        ],
        generatedAt: fixedNow,
        expiresAt: fixedNow.add(const Duration(hours: 24)),
        source: CompactEpgSliceSource.localCache,
      ),
    );
  }

  Future<ProviderContainer> buildContainer({
    CompactEpgRepository? repository,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        iptvChannelsProvider.overrideWith((ref) async => [channel]),
        compactEpgRepositoryProvider.overrideWithValue(
          repository ?? buildRepo(),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<GuidePagedWindowState> settleInitial(ProviderContainer container) async {
    container
        .read(guidePagedWindowProvider.notifier)
        .debugSetNow(() => fixedNow);
    // Read the provider to trigger build, then let the microtask chain run.
    container.read(guidePagedWindowProvider);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    return container.read(guidePagedWindowProvider);
  }

  test('initial load covers [now-30min floored, at least now+6h)', () async {
    final container = await buildContainer();

    final state = await settleInitial(container);

    // now-30min = 11:40, floored to 11:30.
    expect(state.earliestStart, DateTime.utc(2026, 7, 20, 11, 30));
    expect(
      state.loadedThrough.isBefore(fixedNow.add(const Duration(hours: 6))),
      isFalse,
      reason: 'initial pages must cover at least now+6h',
    );
    expect(state.forwardLoadFailed, isFalse);
    expect(state.window, isNotNull);
  });

  test('initial window contains the seeded program', () async {
    final container = await buildContainer();

    final state = await settleInitial(container);

    expect(
      state.window!.entryForChannel('channel-1')?.programs,
      isNotEmpty,
    );
  });

  test('extendForward advances loadedThrough by one 3h page', () async {
    final container = await buildContainer();
    final before = await settleInitial(container);

    await container.read(guidePagedWindowProvider.notifier).extendForward();
    final after = container.read(guidePagedWindowProvider);

    expect(
      after.loadedThrough.difference(before.loadedThrough),
      const Duration(hours: 3),
    );
  });

  test('extendForward stops at the now+24h cap', () async {
    final container = await buildContainer();
    await settleInitial(container);
    final notifier = container.read(guidePagedWindowProvider.notifier);

    for (var i = 0; i < 12; i++) {
      await notifier.extendForward();
    }
    final state = container.read(guidePagedWindowProvider);

    expect(
      state.loadedThrough.isAfter(fixedNow.add(const Duration(hours: 24))),
      isFalse,
      reason: 'loadedThrough must never exceed now+24h',
    );
  });

  test('a failing page keeps loaded pages and sets forwardLoadFailed', () async {
    final container = await buildContainer(
      repository: _FailAfterFirstLoadRepository(buildRepo(), fixedNow),
    );
    await settleInitial(container);
    final loadedWindow = container.read(guidePagedWindowProvider).window;

    await container.read(guidePagedWindowProvider.notifier).extendForward();
    final state = container.read(guidePagedWindowProvider);

    expect(state.forwardLoadFailed, isTrue);
    expect(state.window, same(loadedWindow));
  });

  test('retryForward clears the failure and loads the page', () async {
    final failing = _FailAfterFirstLoadRepository(buildRepo(), fixedNow);
    final container = await buildContainer(repository: failing);
    await settleInitial(container);
    await container.read(guidePagedWindowProvider.notifier).extendForward();
    expect(container.read(guidePagedWindowProvider).forwardLoadFailed, isTrue);

    failing.failNext = false;
    await container.read(guidePagedWindowProvider.notifier).retryForward();
    final state = container.read(guidePagedWindowProvider);

    expect(state.forwardLoadFailed, isFalse);
  });

  test('nowTickerProvider emits UTC instants', () async {
    final container = await buildContainer();

    final value = await container.read(nowTickerProvider.future);

    expect(value.isUtc, isTrue);
  });
}

/// Fails [loadWindow] once [failNext] is true (after the initial pages have
/// loaded — the test flips it by loading through the cap of initial pages
/// first; the simplest deterministic hook is: first N calls succeed).
class _FailAfterFirstLoadRepository implements CompactEpgRepository {
  _FailAfterFirstLoadRepository(this._inner, this._now);

  final CompactEpgRepository _inner;
  final DateTime _now;
  bool failNext = true;
  var _calls = 0;

  @override
  Future<CompactEpgSlice> loadCurrentNext({
    required Iterable<String> channelIds,
    required DateTime now,
  }) =>
      _inner.loadCurrentNext(channelIds: channelIds, now: now);

  @override
  Future<CompactEpgWindow> loadWindow(GuideWindowQuery query) async {
    _calls++;
    // Initial load issues 2-3 sequential page loads (to cover now+6h from a
    // floored start); fail only once those have completed.
    if (failNext && _calls > 3) {
      throw StateError('simulated page load failure');
    }
    return _inner.loadWindow(query);
  }
}
```

If `InMemoryCompactEpgRepository.loadWindow` turns out NOT to filter/slice seeded programs into the requested window (check `packages/platform_epg/lib/src/` implementation first), the "initial window contains the seeded program" test still holds (the seeded current program intersects the initial window) but be careful that later-page assertions don't depend on filtering. Adjust expectations to the real repository behavior — read, don't guess.

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd packages/feature_iptv && flutter test test/iptv/application/providers/guide_paged_window_notifier_test.dart`
Expected: FAIL — `GuidePagedWindowNotifier`/`guidePagedWindowProvider`/`nowTickerProvider` undefined.

- [ ] **Step 3: Add the notifier, state, and ticker to `guide_providers.dart`**

Append to `packages/feature_iptv/lib/application/providers/guide_providers.dart` (imports for `equatable` and `guide_window_query.dart` — the latter added in Task 1; add `package:equatable/equatable.dart` and `package:flutter/foundation.dart` for `visibleForTesting`):

```dart
/// How far ahead one guide page spans.
const Duration guidePageDuration = Duration(hours: 3);

/// How far ahead the initial load covers.
const Duration guideInitialForward = Duration(hours: 6);

/// Hard cap on forward paging.
const Duration guideMaxForward = Duration(hours: 24);

/// How far into the past the timeline reaches (past blocks render dimmed).
const Duration guideBackward = Duration(minutes: 30);

/// Accumulated state for the paged guide window (Live Grid Navigation): a
/// merged [window] spanning `[earliestStart, loadedThrough)`, grown in
/// [guidePageDuration] pages toward the [guideMaxForward] cap as the user
/// scrolls forward.
class GuidePagedWindowState extends Equatable {
  const GuidePagedWindowState({
    required this.earliestStart,
    required this.loadedThrough,
    this.window,
    this.isLoadingForward = false,
    this.forwardLoadFailed = false,
  });

  /// Fixed lower bound of the timeline: now minus [guideBackward], floored
  /// to the nearest 30 minutes so it doesn't shift on rebuilds.
  final DateTime earliestStart;

  /// Forward edge of loaded guide data; grows via `extendForward()`.
  final DateTime loadedThrough;

  /// Merged window across all loaded pages; null until the first page lands.
  final CompactEpgWindow? window;

  final bool isLoadingForward;
  final bool forwardLoadFailed;

  GuidePagedWindowState copyWith({
    DateTime? earliestStart,
    DateTime? loadedThrough,
    CompactEpgWindow? Function()? window,
    bool? isLoadingForward,
    bool? forwardLoadFailed,
  }) {
    return GuidePagedWindowState(
      earliestStart: earliestStart ?? this.earliestStart,
      loadedThrough: loadedThrough ?? this.loadedThrough,
      window: window != null ? window() : this.window,
      isLoadingForward: isLoadingForward ?? this.isLoadingForward,
      forwardLoadFailed: forwardLoadFailed ?? this.forwardLoadFailed,
    );
  }

  @override
  List<Object?> get props => [
    earliestStart,
    loadedThrough,
    window,
    isLoadingForward,
    forwardLoadFailed,
  ];
}

/// Paged guide-window provider backing both guide grids (Live Grid
/// Navigation). The phone grid drives [extendForward] from its scroll-edge
/// listener; the TV grid renders its fixed 3h viewport from the initially
/// loaded pages and never pages.
class GuidePagedWindowNotifier extends Notifier<GuidePagedWindowState> {
  DateTime Function()? _nowOverride;
  bool _initialLoadScheduled = false;
  Future<void>? _inFlight;

  DateTime _now() => _nowOverride?.call() ?? DateTime.now().toUtc();

  @visibleForTesting
  void debugSetNow(DateTime Function() now) => _nowOverride = now;

  static DateTime _floorToThirtyMinutes(DateTime value) {
    final flooredMinute = value.minute < 30 ? 0 : 30;
    return DateTime.utc(
      value.year,
      value.month,
      value.day,
      value.hour,
      flooredMinute,
    );
  }

  @override
  GuidePagedWindowState build() {
    final earliest = _floorToThirtyMinutes(_now().subtract(guideBackward));
    if (!_initialLoadScheduled) {
      _initialLoadScheduled = true;
      Future.microtask(_loadInitialPages);
    }
    return GuidePagedWindowState(
      earliestStart: earliest,
      loadedThrough: earliest,
      isLoadingForward: true,
    );
  }

  Future<void> _loadPage({
    required DateTime windowStart,
    required DateTime windowEnd,
  }) async {
    final channels = await ref.read(iptvChannelsProvider.future);
    final overrides = await ref.read(guideEpgOverridesProvider.future);
    final hiddenGroupIds = await ref.read(hiddenGroupIdsProvider.future);
    final repository = ref.read(compactEpgRepositoryProvider);
    final page = await queryGuideWindowWithOverrides(
      channels: channels,
      overrides: overrides,
      hiddenGroupIds: hiddenGroupIds,
      repository: repository,
      windowStart: windowStart,
      windowEnd: windowEnd,
      now: _now(),
    );
    state = state.copyWith(
      window: () => mergeGuideWindowPage(state.window, page),
      loadedThrough: windowEnd,
    );
  }

  Future<void> _loadInitialPages() async {
    final target = _now().add(guideInitialForward);
    try {
      while (state.loadedThrough.isBefore(target)) {
        await _loadPage(
          windowStart: state.loadedThrough,
          windowEnd: state.loadedThrough.add(guidePageDuration),
        );
      }
      state = state.copyWith(isLoadingForward: false);
    } catch (_) {
      state = state.copyWith(isLoadingForward: false, forwardLoadFailed: true);
    }
  }

  /// Loads the next forward page, unless the [guideMaxForward] cap is
  /// reached or a load is already in flight. No-op while
  /// [GuidePagedWindowState.forwardLoadFailed] is set — the UI must call
  /// [retryForward] explicitly so a flaky source isn't hammered on every
  /// scroll event.
  Future<void> extendForward() {
    if (state.forwardLoadFailed) return Future.value();
    return _inFlight ??= _extendForwardOnce().whenComplete(
      () => _inFlight = null,
    );
  }

  Future<void> _extendForwardOnce() async {
    if (state.isLoadingForward) return;
    final cap = _now().add(guideMaxForward);
    if (!state.loadedThrough.isBefore(cap)) return;

    state = state.copyWith(isLoadingForward: true);
    try {
      final pageEnd = state.loadedThrough.add(guidePageDuration);
      await _loadPage(
        windowStart: state.loadedThrough,
        windowEnd: pageEnd.isAfter(cap) ? cap : pageEnd,
      );
      state = state.copyWith(isLoadingForward: false);
    } catch (_) {
      state = state.copyWith(isLoadingForward: false, forwardLoadFailed: true);
    }
  }

  /// Retries the forward page after a failure (inline retry cell).
  Future<void> retryForward() async {
    if (!state.forwardLoadFailed) return;
    state = state.copyWith(forwardLoadFailed: false);
    await extendForward();
  }
}

final guidePagedWindowProvider =
    NotifierProvider<GuidePagedWindowNotifier, GuidePagedWindowState>(
      GuidePagedWindowNotifier.new,
    );

/// Shared 30s UTC clock for the now-line, progress fills, and "N min left"
/// labels on both guide grids (Live Grid Navigation). Consumers read
/// `.value ?? DateTime.now().toUtc()` so first-frame renders don't wait for
/// the first tick.
final nowTickerProvider = StreamProvider<DateTime>((ref) {
  return Stream.periodic(
    const Duration(seconds: 30),
    (_) => DateTime.now().toUtc(),
  );
});
```

Note on the failing-page test interplay: `_loadInitialPages` loops until `loadedThrough >= now+6h`; from a floored start that is 2–3 page loads. The test's `_FailAfterFirstLoadRepository` allows the first 3 calls, so initial load succeeds and the first `extendForward` (4th call) fails. If the floored start arithmetic yields a different call count in practice, adjust the `> 3` threshold after observing the actual failure — do not change production code to fit the test.

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd packages/feature_iptv && flutter test test/iptv/application/providers/guide_paged_window_notifier_test.dart`
Expected: PASS (7 tests).

- [ ] **Step 5: Run the full feature_iptv suite**

Run: `cd packages/feature_iptv && flutter test`
Expected: PASS, no regressions.

- [ ] **Step 6: Commit**

```bash
git add packages/feature_iptv/lib/application/providers/guide_providers.dart \
        packages/feature_iptv/test/iptv/application/providers/guide_paged_window_notifier_test.dart
git commit -m "feat(feature_iptv): add paged guide window provider and shared now ticker [skip ci]"
```

---

### Task 3: `EpgReminder` model + `EpgReminderStore`

**Files:**
- Create: `packages/feature_iptv/lib/application/epg_reminder_store.dart`
- Test: `packages/feature_iptv/test/iptv/application/epg_reminder_store_test.dart`

**Interfaces:**
- Consumes: `KeyValueStore` (`package:core_data/core_data.dart` — `Future<String?> getString(String key)`, `Future<bool> setString(String key, String value)`).
- Produces: `class EpgReminder extends Equatable { String channelId; String channelName; String programId; String programTitle; DateTime startsAt; DateTime endsAt; int notificationId; }` (+`fromJson`/`toJson`); `class EpgReminderStore { EpgReminderStore(KeyValueStore store); Future<List<EpgReminder>> list(); Future<void> save(EpgReminder reminder); Future<void> remove(String programId); Future<bool> contains(String programId); Future<List<EpgReminder>> pruneElapsed(DateTime now); }`.

- [ ] **Step 1: Write the failing tests**

```dart
// packages/feature_iptv/test/iptv/application/epg_reminder_store_test.dart
import 'package:core_data/core_data.dart';
import 'package:feature_iptv/application/epg_reminder_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late EpgReminderStore store;

  EpgReminder reminder(String programId, DateTime startsAt) => EpgReminder(
    channelId: 'channel-1',
    channelName: 'Example Channel',
    programId: programId,
    programTitle: 'Show $programId',
    startsAt: startsAt,
    endsAt: startsAt.add(const Duration(hours: 1)),
    notificationId: programId.hashCode & 0x7fffffff,
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    store = EpgReminderStore(PreferencesStore(prefs));
  });

  test('list is empty when nothing is stored', () async {
    expect(await store.list(), isEmpty);
  });

  test('save then list round-trips the reminder', () async {
    final r = reminder('p1', DateTime.utc(2026, 7, 20, 18));

    await store.save(r);
    final list = await store.list();

    expect(list, hasLength(1));
    expect(list.single, r);
  });

  test('save upserts by programId', () async {
    await store.save(reminder('p1', DateTime.utc(2026, 7, 20, 18)));
    await store.save(reminder('p1', DateTime.utc(2026, 7, 20, 19)));

    final list = await store.list();

    expect(list, hasLength(1));
    expect(list.single.startsAt, DateTime.utc(2026, 7, 20, 19));
  });

  test('contains reflects saved program ids', () async {
    await store.save(reminder('p1', DateTime.utc(2026, 7, 20, 18)));

    expect(await store.contains('p1'), isTrue);
    expect(await store.contains('p2'), isFalse);
  });

  test('remove deletes only the targeted reminder', () async {
    await store.save(reminder('p1', DateTime.utc(2026, 7, 20, 18)));
    await store.save(reminder('p2', DateTime.utc(2026, 7, 20, 20)));

    await store.remove('p1');

    expect(await store.contains('p1'), isFalse);
    expect(await store.contains('p2'), isTrue);
  });

  test('pruneElapsed removes and returns reminders whose program has ended', () async {
    final now = DateTime.utc(2026, 7, 20, 21);
    await store.save(reminder('past', DateTime.utc(2026, 7, 20, 19)));
    await store.save(reminder('future', DateTime.utc(2026, 7, 20, 22)));

    final removed = await store.pruneElapsed(now);

    expect(removed.map((r) => r.programId), ['past']);
    expect(await store.contains('past'), isFalse);
    expect(await store.contains('future'), isTrue);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd packages/feature_iptv && flutter test test/iptv/application/epg_reminder_store_test.dart`
Expected: FAIL — `EpgReminderStore`/`EpgReminder` undefined.

- [ ] **Step 3: Write `lib/application/epg_reminder_store.dart`**

```dart
import 'dart:convert';

import 'package:core_data/core_data.dart';
import 'package:equatable/equatable.dart';

/// A scheduled reminder for an upcoming live program (Live Grid
/// Navigation). Persisted as a JSON list (counts are small — mirrors
/// `XmltvSourceStore`'s single-blob approach). [notificationId] is the OS
/// notification id derived from [programId] at schedule time, stored so
/// cancellation works across app restarts.
class EpgReminder extends Equatable {
  const EpgReminder({
    required this.channelId,
    required this.channelName,
    required this.programId,
    required this.programTitle,
    required this.startsAt,
    required this.endsAt,
    required this.notificationId,
  });

  final String channelId;
  final String channelName;
  final String programId;
  final String programTitle;
  final DateTime startsAt;
  final DateTime endsAt;
  final int notificationId;

  factory EpgReminder.fromJson(Map<String, dynamic> json) {
    return EpgReminder(
      channelId: json['channelId'] as String,
      channelName: json['channelName'] as String,
      programId: json['programId'] as String,
      programTitle: json['programTitle'] as String,
      startsAt: DateTime.parse(json['startsAt'] as String),
      endsAt: DateTime.parse(json['endsAt'] as String),
      notificationId: json['notificationId'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
    'channelId': channelId,
    'channelName': channelName,
    'programId': programId,
    'programTitle': programTitle,
    'startsAt': startsAt.toIso8601String(),
    'endsAt': endsAt.toIso8601String(),
    'notificationId': notificationId,
  };

  @override
  List<Object?> get props => [
    channelId,
    channelName,
    programId,
    programTitle,
    startsAt,
    endsAt,
    notificationId,
  ];
}

class EpgReminderStore {
  EpgReminderStore(this._store);

  static const String _storageKey = 'epg_program_reminders';

  final KeyValueStore _store;

  Future<List<EpgReminder>> list() async {
    final json = await _store.getString(_storageKey);
    if (json == null) return const [];
    final decoded = jsonDecode(json) as List<dynamic>;
    return decoded
        .map((e) => EpgReminder.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Upserts by `programId` — re-tapping a block replaces the old record.
  Future<void> save(EpgReminder reminder) async {
    final reminders = await list();
    reminders.removeWhere((r) => r.programId == reminder.programId);
    reminders.add(reminder);
    await _saveAll(reminders);
  }

  Future<void> remove(String programId) async {
    final reminders = await list();
    reminders.removeWhere((r) => r.programId == programId);
    await _saveAll(reminders);
  }

  Future<bool> contains(String programId) async {
    final reminders = await list();
    return reminders.any((r) => r.programId == programId);
  }

  /// Removes reminders whose program has ended (`endsAt <= now`) and
  /// returns them so the caller can cancel their OS notifications.
  Future<List<EpgReminder>> pruneElapsed(DateTime now) async {
    final reminders = await list();
    final elapsed = reminders
        .where((r) => !r.endsAt.isAfter(now))
        .toList();
    if (elapsed.isEmpty) return const [];
    reminders.removeWhere((r) => !r.endsAt.isAfter(now));
    await _saveAll(reminders);
    return elapsed;
  }

  Future<void> _saveAll(List<EpgReminder> reminders) async {
    await _store.setString(
      _storageKey,
      jsonEncode(reminders.map((r) => r.toJson()).toList()),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd packages/feature_iptv && flutter test test/iptv/application/epg_reminder_store_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add packages/feature_iptv/lib/application/epg_reminder_store.dart \
        packages/feature_iptv/test/iptv/application/epg_reminder_store_test.dart
git commit -m "feat(feature_iptv): add EpgReminder model and persisted store [skip ci]"
```

---

### Task 4: `EpgReminderNotificationGateway` interface + `EpgReminderScheduler` + providers

**Files:**
- Create: `packages/feature_iptv/lib/application/epg_reminder_scheduler.dart`
- Create: `packages/feature_iptv/lib/application/providers/epg_reminder_providers.dart`
- Test: `packages/feature_iptv/test/iptv/application/epg_reminder_scheduler_test.dart`

**Interfaces:**
- Consumes: `EpgReminder`/`EpgReminderStore` (Task 3), `IPTVChannel` (`package:platform_channels/platform_channels.dart`), `CompactEpgProgram` (`package:platform_epg/platform_epg.dart`).
- Produces: `abstract interface class EpgReminderNotificationGateway { bool get isAvailable; Future<bool> requestPermission(); Future<void> schedule({required int notificationId, required String title, required String body, required DateTime at, required String payloadChannelId}); Future<void> cancel(int notificationId); }`; `class UnavailableEpgReminderNotificationGateway implements EpgReminderNotificationGateway`; `enum EpgReminderOutcome { scheduled, scheduledInAppOnly, unavailable }`; `class EpgReminderScheduler { Future<EpgReminderOutcome> scheduleReminder({required IPTVChannel channel, required CompactEpgProgram program}); Future<void> cancelReminder(String programId); Future<bool> isReminded(String programId); Future<void> pruneElapsed(); }`; providers `epgReminderStoreProvider`, `epgReminderNotificationGatewayProvider` (defaults to unavailable — the app overrides it in Task 9), `epgReminderSchedulerProvider`, `epgRemindersProvider` (`FutureProvider<List<EpgReminder>>`).

- [ ] **Step 1: Write the failing tests**

```dart
// packages/feature_iptv/test/iptv/application/epg_reminder_scheduler_test.dart
import 'package:core_data/core_data.dart';
import 'package:feature_iptv/application/epg_reminder_scheduler.dart';
import 'package:feature_iptv/application/epg_reminder_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_epg/platform_epg.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late EpgReminderStore store;
  late _FakeGateway gateway;
  late EpgReminderScheduler scheduler;

  final now = DateTime.utc(2026, 7, 20, 12);

  const channel = IPTVChannel(
    id: 'channel-1',
    name: 'Example Channel',
    streamUrl: 'https://example.com/stream.m3u8',
  );

  CompactEpgProgram futureProgram([String id = 'p1']) => CompactEpgProgram(
    programId: id,
    title: 'Evening Show',
    startsAt: now.add(const Duration(hours: 3)),
    endsAt: now.add(const Duration(hours: 4)),
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    store = EpgReminderStore(PreferencesStore(prefs));
    gateway = _FakeGateway();
    scheduler = EpgReminderScheduler(
      store: store,
      gateway: gateway,
      now: () => now,
    );
  });

  test('scheduleReminder persists and schedules via the gateway', () async {
    final outcome = await scheduler.scheduleReminder(
      channel: channel,
      program: futureProgram(),
    );

    expect(outcome, EpgReminderOutcome.scheduled);
    expect(gateway.scheduled, hasLength(1));
    expect(gateway.scheduled.single.payloadChannelId, 'channel-1');
    expect(await store.contains('p1'), isTrue);
  });

  test('permission denied persists the reminder but skips OS scheduling', () async {
    gateway.permissionGranted = false;

    final outcome = await scheduler.scheduleReminder(
      channel: channel,
      program: futureProgram(),
    );

    expect(outcome, EpgReminderOutcome.scheduledInAppOnly);
    expect(gateway.scheduled, isEmpty);
    expect(await store.contains('p1'), isTrue);
  });

  test('unavailable gateway does nothing and reports unavailable', () async {
    gateway.isAvailableValue = false;

    final outcome = await scheduler.scheduleReminder(
      channel: channel,
      program: futureProgram(),
    );

    expect(outcome, EpgReminderOutcome.unavailable);
    expect(await store.contains('p1'), isFalse);
  });

  test('cancelReminder cancels the OS notification and removes the record', () async {
    await scheduler.scheduleReminder(channel: channel, program: futureProgram());
    final notificationId = gateway.scheduled.single.notificationId;

    await scheduler.cancelReminder('p1');

    expect(gateway.canceled, [notificationId]);
    expect(await store.contains('p1'), isFalse);
  });

  test('isReminded reflects the store', () async {
    expect(await scheduler.isReminded('p1'), isFalse);
    await scheduler.scheduleReminder(channel: channel, program: futureProgram());
    expect(await scheduler.isReminded('p1'), isTrue);
  });

  test('pruneElapsed cancels OS notifications for elapsed reminders', () async {
    await scheduler.scheduleReminder(channel: channel, program: futureProgram('past'));
    // Force the reminder into the past by re-saving with elapsed times.
    await store.remove('past');
    await store.save(
      EpgReminder(
        channelId: 'channel-1',
        channelName: 'Example Channel',
        programId: 'past',
        programTitle: 'Past Show',
        startsAt: now.subtract(const Duration(hours: 2)),
        endsAt: now.subtract(const Duration(hours: 1)),
        notificationId: 42,
      ),
    );

    await scheduler.pruneElapsed();

    expect(gateway.canceled, contains(42));
    expect(await store.contains('past'), isFalse);
  });

  test('UnavailableEpgReminderNotificationGateway is never available', () {
    const gateway = UnavailableEpgReminderNotificationGateway();
    expect(gateway.isAvailable, isFalse);
  });
}

class _ScheduledCall {
  _ScheduledCall(this.notificationId, this.payloadChannelId);
  final int notificationId;
  final String payloadChannelId;
}

class _FakeGateway implements EpgReminderNotificationGateway {
  bool isAvailableValue = true;
  bool permissionGranted = true;
  final scheduled = <_ScheduledCall>[];
  final canceled = <int>[];

  @override
  bool get isAvailable => isAvailableValue;

  @override
  Future<bool> requestPermission() async => permissionGranted;

  @override
  Future<void> schedule({
    required int notificationId,
    required String title,
    required String body,
    required DateTime at,
    required String payloadChannelId,
  }) async {
    scheduled.add(_ScheduledCall(notificationId, payloadChannelId));
  }

  @override
  Future<void> cancel(int notificationId) async {
    canceled.add(notificationId);
  }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd packages/feature_iptv && flutter test test/iptv/application/epg_reminder_scheduler_test.dart`
Expected: FAIL — `epg_reminder_scheduler.dart` does not exist.

- [ ] **Step 3: Write `lib/application/epg_reminder_scheduler.dart`**

```dart
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_epg/platform_epg.dart';

import 'epg_reminder_store.dart';

/// Host-provided bridge to OS local notifications (Live Grid Navigation).
/// `feature_iptv` deliberately takes no `flutter_local_notifications`
/// dependency (CV-015 no-new-deps precedent) — the app wires a
/// `flutter_local_notifications`-backed implementation over
/// `epgReminderNotificationGatewayProvider`.
abstract interface class EpgReminderNotificationGateway {
  /// False on hosts without a notification implementation (macOS/web/debug
  /// builds) — the UI hides the reminder affordance entirely.
  bool get isAvailable;

  /// Requests the OS notification permission; returns whether scheduling
  /// will actually deliver.
  Future<bool> requestPermission();

  Future<void> schedule({
    required int notificationId,
    required String title,
    required String body,
    required DateTime at,
    required String payloadChannelId,
  });

  Future<void> cancel(int notificationId);
}

/// Default gateway when the host app hasn't wired one.
class UnavailableEpgReminderNotificationGateway
    implements EpgReminderNotificationGateway {
  const UnavailableEpgReminderNotificationGateway();

  @override
  bool get isAvailable => false;

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> schedule({
    required int notificationId,
    required String title,
    required String body,
    required DateTime at,
    required String payloadChannelId,
  }) async {}

  @override
  Future<void> cancel(int notificationId) async {}
}

/// Outcome of [EpgReminderScheduler.scheduleReminder]:
/// - [scheduled]: OS notification scheduled and record persisted.
/// - [scheduledInAppOnly]: permission denied — record persisted, no OS
///   notification; the UI explains the reminder will only show in-app.
/// - [unavailable]: no gateway on this host — nothing persisted.
enum EpgReminderOutcome { scheduled, scheduledInAppOnly, unavailable }

/// Orchestrates reminder persistence ([EpgReminderStore]) and OS
/// notification delivery ([EpgReminderNotificationGateway]).
class EpgReminderScheduler {
  EpgReminderScheduler({
    required EpgReminderStore store,
    required EpgReminderNotificationGateway gateway,
    DateTime Function()? now,
  }) : _store = store,
       _gateway = gateway,
       _now = now ?? DateTime.now;

  final EpgReminderStore _store;
  final EpgReminderNotificationGateway _gateway;
  final DateTime Function() _now;

  Future<EpgReminderOutcome> scheduleReminder({
    required IPTVChannel channel,
    required CompactEpgProgram program,
  }) async {
    if (!_gateway.isAvailable) return EpgReminderOutcome.unavailable;

    final reminder = EpgReminder(
      channelId: channel.id,
      channelName: channel.name,
      programId: program.programId,
      programTitle: program.title,
      startsAt: program.startsAt,
      endsAt: program.endsAt,
      notificationId: program.programId.hashCode & 0x7fffffff,
    );
    await _store.save(reminder);

    final granted = await _gateway.requestPermission();
    if (!granted) return EpgReminderOutcome.scheduledInAppOnly;

    await _gateway.schedule(
      notificationId: reminder.notificationId,
      title: program.title,
      body: 'Starting now on ${channel.name}',
      at: program.startsAt,
      payloadChannelId: channel.id,
    );
    return EpgReminderOutcome.scheduled;
  }

  Future<void> cancelReminder(String programId) async {
    final reminders = await _store.list();
    for (final r in reminders.where((r) => r.programId == programId)) {
      await _gateway.cancel(r.notificationId);
    }
    await _store.remove(programId);
  }

  Future<bool> isReminded(String programId) => _store.contains(programId);

  /// Drops elapsed reminders and cancels their OS notifications. Called on
  /// guide open (phone grid initState) and on app resume (app wiring).
  Future<void> pruneElapsed() async {
    final removed = await _store.pruneElapsed(_now().toUtc());
    for (final r in removed) {
      await _gateway.cancel(r.notificationId);
    }
  }
}
```

- [ ] **Step 4: Write `lib/application/providers/epg_reminder_providers.dart`**

```dart
import 'package:core_data/core_data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../epg_reminder_scheduler.dart';
import '../epg_reminder_store.dart';
import 'iptv_providers.dart';

final epgReminderStoreProvider = Provider<EpgReminderStore>((ref) {
  return EpgReminderStore(
    PreferencesStore(ref.watch(sharedPreferencesProvider)),
  );
});

/// Defaults to unavailable; the app overrides this with a
/// `flutter_local_notifications`-backed gateway on iOS/Android.
final epgReminderNotificationGatewayProvider =
    Provider<EpgReminderNotificationGateway>((ref) {
      return const UnavailableEpgReminderNotificationGateway();
    });

final epgReminderSchedulerProvider = Provider<EpgReminderScheduler>((ref) {
  return EpgReminderScheduler(
    store: ref.watch(epgReminderStoreProvider),
    gateway: ref.watch(epgReminderNotificationGatewayProvider),
  );
});

/// Current reminders for UI indicators (bell icon on reminded blocks).
/// Invalidate after schedule/cancel operations.
final epgRemindersProvider = FutureProvider<List<EpgReminder>>((ref) async {
  return ref.watch(epgReminderStoreProvider).list();
});
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd packages/feature_iptv && flutter test test/iptv/application/epg_reminder_scheduler_test.dart`
Expected: PASS (7 tests).

- [ ] **Step 6: Commit**

```bash
git add packages/feature_iptv/lib/application/epg_reminder_scheduler.dart \
        packages/feature_iptv/lib/application/providers/epg_reminder_providers.dart \
        packages/feature_iptv/test/iptv/application/epg_reminder_scheduler_test.dart
git commit -m "feat(feature_iptv): add EpgReminderScheduler behind a notification gateway interface [skip ci]"
```

---

### Task 5: `EpgTouchTimelineGrid` core — drag scroll, rows, time axis, progress, pagination

**Files:**
- Create: `packages/feature_iptv/lib/presentation/widgets/epg_program_progress.dart`
- Create: `packages/feature_iptv/lib/presentation/widgets/epg_touch_timeline_grid.dart`
- Test: `packages/feature_iptv/test/iptv/presentation/widgets/epg_touch_timeline_grid_test.dart`

**Interfaces:**
- Consumes: `guidePagedWindowProvider`, `nowTickerProvider`, `guideFilteredChannelsProvider` (Task 2 + existing), `epgRemindersProvider`, `epgReminderNotificationGatewayProvider` (Task 4), `IPTVChannel`, `CompactEpgProgram`, `CompactEpgWindowEntry`.
- Produces: `double epgProgramProgress({required DateTime startsAt, required DateTime endsAt, required DateTime now})`; `bool epgProgramIsAiring({required DateTime startsAt, required DateTime endsAt, required DateTime now})`; `int epgProgramMinutesLeft({required DateTime endsAt, required DateTime now})`; `class EpgTouchTimelineGrid extends ConsumerStatefulWidget { EpgTouchTimelineGrid({this.onChannelSelect, this.onReminderToggle}); static const double pxPerMinute = 6.0; static const double rowHeight = 64.0; static const double channelLabelWidth = 120.0; static const double timeAxisHeight = 28.0; }`.

- [ ] **Step 1: Write the failing tests**

```dart
// packages/feature_iptv/test/iptv/presentation/widgets/epg_touch_timeline_grid_test.dart
import 'package:feature_iptv/application/providers/epg_reminder_providers.dart';
import 'package:feature_iptv/application/providers/guide_providers.dart';
import 'package:feature_iptv/application/providers/iptv_providers.dart';
import 'package:feature_iptv/presentation/widgets/epg_program_progress.dart';
import 'package:feature_iptv/presentation/widgets/epg_touch_timeline_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_epg/platform_epg.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final fixedNow = DateTime.utc(2026, 7, 20, 12, 10);

  const channel = IPTVChannel(
    id: 'channel-1',
    name: 'Example Channel',
    streamUrl: 'https://example.com/stream.m3u8',
    group: 'News',
  );

  CompactEpgProgram program(String id, String title, DateTime start, DateTime end) {
    return CompactEpgProgram(
      programId: id,
      title: title,
      startsAt: start,
      endsAt: end,
    );
  }

  GuidePagedWindowState fixedState(List<CompactEpgProgram> programs) {
    final earliest = DateTime.utc(2026, 7, 20, 11, 30);
    final through = DateTime.utc(2026, 7, 20, 18, 30);
    return GuidePagedWindowState(
      earliestStart: earliest,
      loadedThrough: through,
      window: CompactEpgWindow(
        entries: [
          CompactEpgWindowEntry(
            channelId: 'channel-1',
            channelName: 'Example Channel',
            programs: programs,
          ),
        ],
        windowStart: earliest,
        windowEnd: through,
        generatedAt: fixedNow,
        expiresAt: fixedNow.add(const Duration(hours: 24)),
        source: CompactEpgSliceSource.localCache,
      ),
    );
  }

  Future<void> pumpGrid(
    WidgetTester tester, {
    required GuidePagedWindowState state,
    void Function(IPTVChannel)? onChannelSelect,
    void Function(IPTVChannel, CompactEpgProgram)? onReminderToggle,
    List<EpgReminder> reminders = const [],
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          iptvChannelsProvider.overrideWith((ref) async => [channel]),
          guidePagedWindowProvider.overrideWith(
            () => _FakePagedNotifier(state),
          ),
          nowTickerProvider.overrideWith((ref) => Stream.value(fixedNow)),
          epgRemindersProvider.overrideWith((ref) async => reminders),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: EpgTouchTimelineGrid(
              onChannelSelect: onChannelSelect,
              onReminderToggle: onReminderToggle,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('epgProgramProgress', () {
    test('is 0 at start, 0.5 midway, clamps to 1 after end', () {
      final start = DateTime.utc(2026, 7, 20, 12);
      final end = DateTime.utc(2026, 7, 20, 13);
      expect(epgProgramProgress(startsAt: start, endsAt: end, now: start), 0);
      expect(
        epgProgramProgress(
          startsAt: start,
          endsAt: end,
          now: DateTime.utc(2026, 7, 20, 12, 30),
        ),
        0.5,
      );
      expect(
        epgProgramProgress(
          startsAt: start,
          endsAt: end,
          now: DateTime.utc(2026, 7, 20, 14),
        ),
        1,
      );
    });

    test('zero-duration program returns 0 (no division by zero)', () {
      final at = DateTime.utc(2026, 7, 20, 12);
      expect(epgProgramProgress(startsAt: at, endsAt: at, now: at), 0);
    });
  });

  testWidgets('renders channel label, program blocks, and progress on the airing block', (tester) async {
    await pumpGrid(
      tester,
      state: fixedState([
        program('past', 'Past Show', DateTime.utc(2026, 7, 20, 11, 30), DateTime.utc(2026, 7, 20, 12)),
        program('now', 'Now Show', DateTime.utc(2026, 7, 20, 12), DateTime.utc(2026, 7, 20, 13)),
        program('future', 'Future Show', DateTime.utc(2026, 7, 20, 13), DateTime.utc(2026, 7, 20, 14)),
      ]),
    );

    expect(find.text('Example Channel'), findsOneWidget);
    expect(find.text('Now Show'), findsOneWidget);
    // The airing block shows a live progress indicator...
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    // ...and a minutes-left label.
    expect(find.textContaining('min left'), findsOneWidget);
  });

  testWidgets('horizontal drag reveals later programs and the time axis stays in sync', (tester) async {
    await pumpGrid(
      tester,
      state: fixedState([
        program('late', 'Late Show', DateTime.utc(2026, 7, 20, 17), DateTime.utc(2026, 7, 20, 18)),
      ]),
    );
    expect(find.text('Late Show'), findsNothing);

    await tester.drag(
      find.byKey(const ValueKey('epg_touch_row_channel-1')),
      const Offset(-600, 0),
    );
    await tester.pumpAndSettle();

    expect(find.text('Late Show'), findsOneWidget);
  });

  testWidgets('tapping the airing block selects the channel', (tester) async {
    IPTVChannel? selected;
    await pumpGrid(
      tester,
      state: fixedState([
        program('now', 'Now Show', DateTime.utc(2026, 7, 20, 12), DateTime.utc(2026, 7, 20, 13)),
      ]),
      onChannelSelect: (c) => selected = c,
    );

    await tester.tap(find.text('Now Show'));
    await tester.pump();

    expect(selected?.id, 'channel-1');
  });

  testWidgets('tapping a future block toggles a reminder for it', (tester) async {
    CompactEpgProgram? reminded;
    await pumpGrid(
      tester,
      state: fixedState([
        program('future', 'Future Show', DateTime.utc(2026, 7, 20, 13), DateTime.utc(2026, 7, 20, 14)),
      ]),
      onReminderToggle: (c, p) => reminded = p,
    );

    await tester.tap(find.text('Future Show'));
    await tester.pump();

    expect(reminded?.programId, 'future');
  });

  testWidgets('past blocks are dimmed and non-interactive', (tester) async {
    var tapped = false;
    await pumpGrid(
      tester,
      state: fixedState([
        program('past', 'Past Show', DateTime.utc(2026, 7, 20, 11, 30), DateTime.utc(2026, 7, 20, 12)),
      ]),
      onChannelSelect: (_) => tapped = true,
      onReminderToggle: (_, __) => tapped = true,
    );

    await tester.tap(find.text('Past Show'), warnIfMissed: false);
    await tester.pump();

    expect(tapped, isFalse);
  });

  testWidgets('reminded future blocks show a bell indicator', (tester) async {
    final r = EpgReminder(
      channelId: 'channel-1',
      channelName: 'Example Channel',
      programId: 'future',
      programTitle: 'Future Show',
      startsAt: DateTime.utc(2026, 7, 20, 13),
      endsAt: DateTime.utc(2026, 7, 20, 14),
      notificationId: 7,
    );
    await pumpGrid(
      tester,
      state: fixedState([
        program('future', 'Future Show', DateTime.utc(2026, 7, 20, 13), DateTime.utc(2026, 7, 20, 14)),
      ]),
      reminders: [r],
    );

    expect(find.byIcon(Icons.notifications_active), findsOneWidget);
  });

  testWidgets('forwardLoadFailed shows an inline retry that calls retryForward', (tester) async {
    final failing = _FakePagedNotifier(
      fixedState(const []).copyWith(forwardLoadFailed: true),
    );
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          iptvChannelsProvider.overrideWith((ref) async => [channel]),
          guidePagedWindowProvider.overrideWith(() => failing),
          nowTickerProvider.overrideWith((ref) => Stream.value(fixedNow)),
        ],
        child: const MaterialApp(home: Scaffold(body: EpgTouchTimelineGrid())),
      ),
    );
    await tester.pump();

    expect(find.textContaining("Couldn't load more guide data"), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();

    expect(failing.retryCalls, 1);
  });
}

class _FakePagedNotifier extends GuidePagedWindowNotifier {
  _FakePagedNotifier(this._state);

  GuidePagedWindowState _state;
  var retryCalls = 0;

  @override
  GuidePagedWindowState build() => _state;

  @override
  Future<void> retryForward() async {
    retryCalls++;
  }
}
```

Check the `EpgReminder` import in the test — it lives in `epg_reminder_store.dart`; add `import 'package:feature_iptv/application/epg_reminder_store.dart';`.

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/widgets/epg_touch_timeline_grid_test.dart`
Expected: FAIL — `epg_program_progress.dart`/`epg_touch_timeline_grid.dart` do not exist.

- [ ] **Step 3: Write `lib/presentation/widgets/epg_program_progress.dart`**

```dart
/// Pure progress math for guide program blocks (Live Grid Navigation),
/// shared by the phone and TV grids.

/// Progress of a program as a fraction in [0, 1]. Zero-duration programs
/// return 0 (no division by zero).
double epgProgramProgress({
  required DateTime startsAt,
  required DateTime endsAt,
  required DateTime now,
}) {
  final total = endsAt.difference(startsAt).inMilliseconds;
  if (total <= 0) return 0;
  final elapsed = now.difference(startsAt).inMilliseconds;
  return (elapsed / total).clamp(0.0, 1.0);
}

/// Whether [now] falls inside `[startsAt, endsAt)`.
bool epgProgramIsAiring({
  required DateTime startsAt,
  required DateTime endsAt,
  required DateTime now,
}) {
  return !now.isBefore(startsAt) && now.isBefore(endsAt);
}

/// Whole minutes remaining, clamped at 0.
int epgProgramMinutesLeft({required DateTime endsAt, required DateTime now}) {
  final minutes = endsAt.difference(now).inMinutes;
  return minutes < 0 ? 0 : minutes;
}
```

- [ ] **Step 4: Write `lib/presentation/widgets/epg_touch_timeline_grid.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_epg/platform_epg.dart';

import '../../application/providers/epg_reminder_providers.dart';
import '../../application/providers/guide_providers.dart';
import 'epg_program_progress.dart';

/// Phone interaction implementation of the Live Grid Navigation EPG:
/// free two-axis drag scroll over the paged guide window
/// (`guidePagedWindowProvider`), a sticky channel-label column, per-block
/// live progress, tap-to-play on the airing block, tap-to-remind on future
/// blocks, and a "Jump to Present" anchor (Task 6). The TV surface uses the
/// focus-driven `EpgTimelineGrid` instead — one data path, two interaction
/// models.
///
/// Horizontal drag sync is hand-rolled (CV-015's no-`linked_scroll_controller`
/// constraint): header + each visible row own a `ScrollController`, and a
/// scroll listener on any of them `jumpTo`s the others behind a re-entrancy
/// guard. Do NOT share one controller across drag-enabled scrollables — a
/// drag on one row would only move that row's position (the TV grid avoids
/// this by using `NeverScrollableScrollPhysics` + programmatic scroll).
class EpgTouchTimelineGrid extends ConsumerStatefulWidget {
  const EpgTouchTimelineGrid({
    super.key,
    this.onChannelSelect,
    this.onReminderToggle,
  });

  /// Invoked when the user taps the currently-airing block of a channel —
  /// the caller plays the channel immediately (Immediate Action Player: no
  /// interstitial).
  final void Function(IPTVChannel channel)? onChannelSelect;

  /// Invoked when the user taps a future block — the caller toggles a
  /// reminder for the program via `EpgReminderScheduler`.
  final void Function(IPTVChannel channel, CompactEpgProgram program)?
  onReminderToggle;

  static const double pxPerMinute = 6.0;
  static const double rowHeight = 64.0;
  static const double channelLabelWidth = 120.0;
  static const double timeAxisHeight = 28.0;

  @override
  ConsumerState<EpgTouchTimelineGrid> createState() =>
      _EpgTouchTimelineGridState();
}

class _EpgTouchTimelineGridState extends ConsumerState<EpgTouchTimelineGrid> {
  final ScrollController _headerController = ScrollController();
  final Map<String, ScrollController> _rowControllers = {};
  bool _isSyncing = false;
  bool _didInitialJump = false;

  @override
  void initState() {
    super.initState();
    _headerController.addListener(() => _syncFrom(_headerController));
    // Prune elapsed reminders on guide open (spec Data Flow step 7).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(epgReminderSchedulerProvider).pruneElapsed();
    });
  }

  @override
  void dispose() {
    _headerController.dispose();
    for (final c in _rowControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  ScrollController _rowControllerFor(String channelId) {
    return _rowControllers.putIfAbsent(channelId, () {
      final c = ScrollController();
      c.addListener(() => _syncFrom(c));
      return c;
    });
  }

  void _syncFrom(ScrollController source) {
    if (_isSyncing || !source.hasClients) return;
    _isSyncing = true;
    final offset = source.offset;
    for (final c in [_headerController, ..._rowControllers.values]) {
      if (identical(c, source) || !c.hasClients) continue;
      if ((c.offset - offset).abs() > 0.5) c.jumpTo(offset);
    }
    _isSyncing = false;
    _maybeExtendForward(source);
  }

  void _maybeExtendForward(ScrollController source) {
    if (!source.hasClients) return;
    // Each row/header controller here has exactly ONE attachment (unlike
    // the TV grid's shared controller), so `.position` is safe.
    if (source.position.maxScrollExtent - source.offset < 240) {
      ref.read(guidePagedWindowProvider.notifier).extendForward();
    }
  }

  double _nowOffsetPx(DateTime earliestStart) {
    final now = DateTime.now().toUtc();
    return now.difference(earliestStart).inMinutes *
        EpgTouchTimelineGrid.pxPerMinute;
  }

  void _jumpToNow(GuidePagedWindowState paged) {
    final target = (_nowOffsetPx(paged.earliestStart) - 40).clamp(
      0.0,
      double.infinity,
    );
    for (final c in [_headerController, ..._rowControllers.values]) {
      if (!c.hasClients) continue;
      c.animateTo(
        target.clamp(0.0, c.position.maxScrollExtent),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final channels = ref.watch(guideFilteredChannelsProvider);
    final paged = ref.watch(guidePagedWindowProvider);
    final reminders =
        ref.watch(epgRemindersProvider).value ?? const <EpgReminder>[];
    final remindedIds = {for (final r in reminders) r.programId};
    final gatewayAvailable = ref
        .watch(epgReminderNotificationGatewayProvider)
        .isAvailable;

    if (channels.isEmpty) {
      return const Center(child: Text('No channels to show yet.'));
    }

    final window = paged.window;
    final entriesByChannel = <String, CompactEpgWindowEntry>{
      for (final entry in window?.entries ?? const <CompactEpgWindowEntry>[])
        entry.channelId: entry,
    };
    final timelineDuration = paged.loadedThrough.difference(
      paged.earliestStart,
    );
    final timelineWidth =
        timelineDuration.inMinutes * EpgTouchTimelineGrid.pxPerMinute;

    // Snap to "now" once the first page has landed.
    if (!_didInitialJump && window != null) {
      _didInitialJump = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _jumpToNow(paged);
      });
    }

    return Column(
      children: [
        SizedBox(
          height: EpgTouchTimelineGrid.timeAxisHeight,
          child: Row(
            children: [
              const SizedBox(width: EpgTouchTimelineGrid.channelLabelWidth),
              Expanded(
                child: SingleChildScrollView(
                  controller: _headerController,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: timelineWidth,
                    child: _TouchTimeAxis(
                      windowStart: paged.earliestStart,
                      windowDuration: timelineDuration,
                      pxPerMinute: EpgTouchTimelineGrid.pxPerMinute,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemExtent: EpgTouchTimelineGrid.rowHeight,
            itemCount: channels.length,
            itemBuilder: (context, index) {
              final channel = channels[index];
              final entry = entriesByChannel[channel.id];
              return _TouchChannelRow(
                key: ValueKey('epg_touch_row_${channel.id}'),
                channel: channel,
                entry: entry,
                windowStart: paged.earliestStart,
                windowDuration: timelineDuration,
                scrollController: _rowControllerFor(channel.id),
                timelineWidth: timelineWidth,
                remindedIds: remindedIds,
                remindersAvailable: gatewayAvailable,
                onChannelSelect: widget.onChannelSelect,
                onReminderToggle: widget.onReminderToggle,
              );
            },
          ),
        ),
        if (paged.forwardLoadFailed)
          Material(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      "Couldn't load more guide data.",
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                  TextButton(
                    key: const ValueKey('epg_touch_retry'),
                    onPressed: () => ref
                        .read(guidePagedWindowProvider.notifier)
                        .retryForward(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _TouchTimeAxis extends StatelessWidget {
  const _TouchTimeAxis({
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
    final baseStyle = Theme.of(context).textTheme.labelSmall;
    return Stack(
      children: [
        for (var i = 0; i <= hourCount; i++)
          Positioned(
            left: i * 60 * pxPerMinute,
            child: Text(
              TimeOfDay.fromDateTime(
                // windowStart is UTC; labels show the viewer's clock.
                windowStart.add(Duration(hours: i)).toLocal(),
              ).format(context),
              style: baseStyle,
            ),
          ),
      ],
    );
  }
}

class _TouchChannelRow extends ConsumerWidget {
  const _TouchChannelRow({
    super.key,
    required this.channel,
    required this.entry,
    required this.windowStart,
    required this.windowDuration,
    required this.scrollController,
    required this.timelineWidth,
    required this.remindedIds,
    required this.remindersAvailable,
    required this.onChannelSelect,
    required this.onReminderToggle,
  });

  final IPTVChannel channel;
  final CompactEpgWindowEntry? entry;
  final DateTime windowStart;
  final Duration windowDuration;
  final ScrollController scrollController;
  final double timelineWidth;
  final Set<String> remindedIds;
  final bool remindersAvailable;
  final void Function(IPTVChannel channel)? onChannelSelect;
  final void Function(IPTVChannel channel, CompactEpgProgram program)?
  onReminderToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final programs = entry?.programs ?? const <CompactEpgProgram>[];
    return SizedBox(
      height: EpgTouchTimelineGrid.rowHeight,
      child: Row(
        children: [
          SizedBox(
            width: EpgTouchTimelineGrid.channelLabelWidth,
            child: InkWell(
              // The label plays the channel even with no EPG data —
              // selection must not depend on guide data being present.
              onTap: () => onChannelSelect?.call(channel),
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
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: timelineWidth,
                child: Stack(
                  children: [
                    // Now-line segment (scrolls naturally with the row —
                    // no scroll-offset tracking needed).
                    const _TouchNowLine(),
                    for (final program in programs)
                      _TouchProgramBlock(
                        key: ValueKey(
                          'epg_touch_program_${channel.id}_${program.programId}',
                        ),
                        program: program,
                        windowStart: windowStart,
                        windowDuration: windowDuration,
                        isReminded: remindedIds.contains(program.programId),
                        remindersAvailable: remindersAvailable,
                        onPlay: () => onChannelSelect?.call(channel),
                        onRemind: () =>
                            onReminderToggle?.call(channel, program),
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

/// The now-line inside a row's scrollable content. [nowOffsetPx] is computed
/// by the parent block layout — see [_TouchProgramBlock] for the same
/// pattern. Rendered via a [Consumer] on `nowTickerProvider` so it updates
/// without rebuilding the row.
class _TouchNowLine extends ConsumerWidget {
  const _TouchNowLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Positioned by the parent's Stack via a computed left offset — the
    // parent passes windowStart through context; simplest correct approach:
    // compute from the ancestor row's windowStart using a inherited lookup
    // is overkill, so the parent wraps this in a [Positioned] instead. This
    // widget renders only the line itself.
    return IgnorePointer(
      child: Container(width: 2, color: Theme.of(context).colorScheme.error),
    );
  }
}

class _TouchProgramBlock extends ConsumerWidget {
  const _TouchProgramBlock({
    super.key,
    required this.program,
    required this.windowStart,
    required this.windowDuration,
    required this.isReminded,
    required this.remindersAvailable,
    required this.onPlay,
    required this.onRemind,
  });

  final CompactEpgProgram program;
  final DateTime windowStart;
  final Duration windowDuration;
  final bool isReminded;
  final bool remindersAvailable;
  final VoidCallback onPlay;
  final VoidCallback onRemind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(nowTickerProvider).value ?? DateTime.now().toUtc();
    final windowMinutes = windowDuration.inMinutes;
    final startOffsetMinutes = program.startsAt
        .difference(windowStart)
        .inMinutes
        .clamp(0, windowMinutes);
    final endOffsetMinutes = program.endsAt
        .difference(windowStart)
        .inMinutes
        .clamp(0, windowMinutes);
    final left = startOffsetMinutes * EpgTouchTimelineGrid.pxPerMinute;
    final width =
        ((endOffsetMinutes - startOffsetMinutes) *
                EpgTouchTimelineGrid.pxPerMinute)
            .clamp(40.0, double.infinity);

    final isAiring = epgProgramIsAiring(
      startsAt: program.startsAt,
      endsAt: program.endsAt,
      now: now,
    );
    final isPast = !now.isBefore(program.endsAt) && !isAiring;

    return Positioned(
      left: left,
      width: width,
      top: 4,
      bottom: 4,
      child: Opacity(
        opacity: isPast ? 0.45 : 1.0,
        child: IgnorePointer(
          ignoring: isPast,
          child: InkWell(
            onTap: isAiring
                ? onPlay
                : (remindersAvailable ? onRemind : null),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              decoration: BoxDecoration(
                color: isReminded
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            program.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        if (isReminded)
                          const Icon(Icons.notifications_active, size: 14),
                      ],
                    ),
                  ),
                  if (isAiring) ...[
                    Text(
                      '${epgProgramMinutesLeft(endsAt: program.endsAt, now: now)} min left',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    SizedBox(
                      height: 3,
                      child: LinearProgressIndicator(
                        value: epgProgramProgress(
                          startsAt: program.startsAt,
                          endsAt: program.endsAt,
                          now: now,
                        ),
                      ),
                    ),
                  ],
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

Note: `_TouchNowLine` as sketched needs a `Positioned` wrapper computed from `windowStart`. In `_TouchChannelRow`'s `Stack`, replace `const _TouchNowLine()` with:

```dart
Consumer(
  builder: (context, ref, _) {
    final now =
        ref.watch(nowTickerProvider).value ?? DateTime.now().toUtc();
    final minutes = now.difference(windowStart).inMinutes;
    if (minutes < 0 || minutes > windowDuration.inMinutes) {
      return const SizedBox.shrink();
    }
    return Positioned(
      left: minutes * EpgTouchTimelineGrid.pxPerMinute,
      top: 0,
      bottom: 0,
      child: IgnorePointer(
        child: Container(
          width: 2,
          color: Theme.of(context).colorScheme.error,
        ),
      ),
    );
  },
),
```

and delete the standalone `_TouchNowLine` class. (Write it this way directly — the standalone class sketch above is superseded.)

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/widgets/epg_touch_timeline_grid_test.dart`
Expected: PASS. If the drag test reveals rows don't sync (header stays put), the `_syncFrom` guard is dropping notifications during fling — read the actual failure and fix the guard, not the test.

- [ ] **Step 6: Commit**

```bash
git add packages/feature_iptv/lib/presentation/widgets/epg_program_progress.dart \
        packages/feature_iptv/lib/presentation/widgets/epg_touch_timeline_grid.dart \
        packages/feature_iptv/test/iptv/presentation/widgets/epg_touch_timeline_grid_test.dart
git commit -m "feat(feature_iptv): add touch EPG timeline grid with drag scroll and progress tickers [skip ci]"
```

---

### Task 6: Now-anchor FAB on the phone grid

**Files:**
- Modify: `packages/feature_iptv/lib/presentation/widgets/epg_touch_timeline_grid.dart`
- Test: `packages/feature_iptv/test/iptv/presentation/widgets/epg_touch_timeline_grid_test.dart`

**Interfaces:**
- Consumes: `_jumpToNow` (Task 5).
- Produces: a "Jump to Present" `FloatingActionButton.extended` overlay with `key: const ValueKey('epg_touch_jump_to_present')`, visible only when the now offset is outside the visible timeline viewport.

- [ ] **Step 1: Write the failing test**

Append to the `main()` in `epg_touch_timeline_grid_test.dart`:

```dart
  testWidgets('Jump to Present appears only when now is off-viewport and snaps back', (tester) async {
    await pumpGrid(
      tester,
      state: fixedState([
        program('now', 'Now Show', DateTime.utc(2026, 7, 20, 12), DateTime.utc(2026, 7, 20, 13)),
        program('late', 'Late Show', DateTime.utc(2026, 7, 20, 17), DateTime.utc(2026, 7, 20, 18)),
      ]),
    );

    // Grid jumps to now on first load — anchor hidden.
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('epg_touch_jump_to_present')), findsNothing);

    // Drag far forward: now scrolls out of view, anchor appears.
    await tester.drag(
      find.byKey(const ValueKey('epg_touch_row_channel-1')),
      const Offset(-1500, 0),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('epg_touch_jump_to_present')), findsOneWidget);

    // Tap it: grid returns to now, anchor hides again.
    await tester.tap(find.byKey(const ValueKey('epg_touch_jump_to_present')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('epg_touch_jump_to_present')), findsNothing);
    expect(find.text('Now Show'), findsOneWidget);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/widgets/epg_touch_timeline_grid_test.dart`
Expected: FAIL — no widget with key `epg_touch_jump_to_present`.

- [ ] **Step 3: Add the anchor to the grid**

In `_EpgTouchTimelineGridState`, add visibility tracking and the FAB overlay:

```dart
// New field:
  bool _nowOffViewport = false;

// Update _syncFrom to recompute visibility after syncing:
  void _syncFrom(ScrollController source) {
    if (_isSyncing || !source.hasClients) return;
    _isSyncing = true;
    final offset = source.offset;
    for (final c in [_headerController, ..._rowControllers.values]) {
      if (identical(c, source) || !c.hasClients) continue;
      if ((c.offset - offset).abs() > 0.5) c.jumpTo(offset);
    }
    _isSyncing = false;
    _maybeExtendForward(source);
    _updateNowVisibility();
  }

  void _updateNowVisibility() {
    final paged = ref.read(guidePagedWindowProvider);
    if (!_headerController.hasClients) return;
    final nowOffset = _nowOffsetPx(paged.earliestStart);
    final viewStart = _headerController.offset;
    final viewEnd = viewStart + _headerController.position.viewportDimension;
    final offViewport = nowOffset < viewStart || nowOffset > viewEnd;
    if (offViewport != _nowOffViewport && mounted) {
      setState(() => _nowOffViewport = offViewport);
    }
  }
```

Wrap the `Expanded(...)` that holds the row `ListView.builder` in a `Stack` and add the FAB:

```dart
        Expanded(
          child: Stack(
            children: [
              ListView.builder(/* unchanged */),
              if (_nowOffViewport)
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: FloatingActionButton.extended(
                    key: const ValueKey('epg_touch_jump_to_present'),
                    onPressed: () =>
                        _jumpToNow(ref.read(guidePagedWindowProvider)),
                    icon: const Icon(Icons.schedule),
                    label: const Text('Jump to Present'),
                  ),
                ),
            ],
          ),
        ),
```

Also call `_updateNowVisibility()` at the end of `_jumpToNow` (post-scroll) and after the initial jump — wrap: in `_jumpToNow`, after issuing the `animateTo` calls, schedule `Future.delayed(const Duration(milliseconds: 300), _updateNowVisibility)` so visibility settles after the animation (or make `_jumpToNow` await the animateTo futures and then call `_updateNowVisibility()` — prefer awaiting: collect the futures into a list and `await Future.wait(...)`; `_jumpToNow` becomes `Future<void>`).

- [ ] **Step 4: Run test to verify it passes**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/widgets/epg_touch_timeline_grid_test.dart`
Expected: PASS (all tests).

- [ ] **Step 5: Commit**

```bash
git add packages/feature_iptv/lib/presentation/widgets/epg_touch_timeline_grid.dart \
        packages/feature_iptv/test/iptv/presentation/widgets/epg_touch_timeline_grid_test.dart
git commit -m "feat(feature_iptv): add Jump to Present anchor to touch EPG grid [skip ci]"
```

---

### Task 7: TV grid additions — progress tickers + focusable "Jump to Present"

**Files:**
- Modify: `packages/feature_iptv/lib/presentation/widgets/epg_timeline_grid.dart`
- Test: `packages/feature_iptv/test/iptv/presentation/widgets/epg_timeline_grid_test.dart`

**Interfaces:**
- Consumes: `nowTickerProvider` (Task 2), `epgProgramProgress`/`epgProgramIsAiring`/`epgProgramMinutesLeft` (Task 5), existing `_scrollTimelineTo`.
- Produces: a focusable "Jump to Present" control with `key: const ValueKey('epg_jump_to_present')` in the grid header's label column; per-airing-block progress fill + "N min left" label. No physics/focus-traversal changes.

- [ ] **Step 1: Write the failing tests**

Read the existing `epg_timeline_grid_test.dart` setup first (container overrides, window fixture) and reuse its harness verbatim, adding:

```dart
  testWidgets('airing blocks show a progress fill and minutes-left label', (tester) async {
    // Reuse the existing fixture but with a program that straddles "now":
    final now = DateTime.now().toUtc();
    final window = CompactEpgWindow(
      entries: [
        CompactEpgWindowEntry(
          channelId: 'channel-1',
          channelName: 'Example Channel',
          programs: [
            CompactEpgProgram(
              programId: 'p-airing',
              title: 'Airing Now',
              startsAt: now.subtract(const Duration(minutes: 15)),
              endsAt: now.add(const Duration(minutes: 45)),
            ),
          ],
        ),
      ],
      windowStart: now.subtract(const Duration(minutes: 30)),
      windowEnd: now.add(const Duration(hours: 2, minutes: 30)),
      generatedAt: now,
      expiresAt: now.add(const Duration(hours: 1)),
      source: CompactEpgSliceSource.localCache,
    );
    // ... pump with the same harness as the existing tests, overriding
    // guidePagedWindowProvider with a fixed state whose window is `window`
    // (Task 8 migrates the harness; until then, override whatever window
    // provider the existing harness uses).
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.textContaining('min left'), findsOneWidget);
  });

  testWidgets('Jump to Present control re-scrolls the timeline to now', (tester) async {
    // Pump the existing fixture, scroll the timeline right by focusing a
    // later block (or by invoking the grid's internal controller via the
    // existing onProgramFocus path), then activate the Jump to Present
    // TvFocusable via a select key event and assert the scroll offset
    // returned to the now position (assert via the same mechanism the
    // existing focus tests use to observe _scrollTimelineTo — read them
    // first and mirror their observation strategy).
    expect(find.byKey(const ValueKey('epg_jump_to_present')), findsOneWidget);
  });
```

These two tests must be concretized against the real harness when writing them — read `epg_timeline_grid_test.dart` fully before finalizing this step. Do not weaken existing tests.

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/widgets/epg_timeline_grid_test.dart`
Expected: FAIL — no `epg_jump_to_present` key, no `LinearProgressIndicator`.

- [ ] **Step 3: Add the "Jump to Present" header control**

In `_EpgTimelineGridState.build`, replace the header row's `const SizedBox(width: EpgTimelineGrid.channelLabelWidth)` with:

```dart
                SizedBox(
                  width: EpgTimelineGrid.channelLabelWidth,
                  child: TvFocusable(
                    key: const ValueKey('epg_jump_to_present'),
                    onSelect: () {
                      final now = DateTime.now().toUtc();
                      final offset =
                          now.difference(windowStart).inMinutes *
                              EpgTimelineGrid.pxPerMinute -
                          60;
                      _scrollTimelineTo(offset < 0 ? 0 : offset);
                    },
                    semanticLabel: 'Jump to Present',
                    semanticHint: 'Press OK to jump the guide to now',
                    semanticButton: true,
                    showScaleEffect: false,
                    child: Center(
                      child: Text(
                        'Jump to Present',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                  ),
                ),
```

- [ ] **Step 4: Add the progress overlay to `_ProgramBlock`**

In `_ProgramBlock.build`, wrap the block content in a `Stack` with a bottom progress area, driven by `nowTickerProvider` (make `_ProgramBlock` a `ConsumerWidget`):

```dart
class _ProgramBlock extends ConsumerWidget {
  // ...fields unchanged...

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(nowTickerProvider).value ?? DateTime.now().toUtc();
    // ...existing left/width math unchanged...
    final isAiring = epgProgramIsAiring(
      startsAt: program.startsAt,
      endsAt: program.endsAt,
      now: now,
    );

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    program.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                if (isAiring) ...[
                  Text(
                    '${epgProgramMinutesLeft(endsAt: program.endsAt, now: now)} min left',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  SizedBox(
                    height: 3,
                    child: LinearProgressIndicator(
                      value: epgProgramProgress(
                        startsAt: program.startsAt,
                        endsAt: program.endsAt,
                        now: now,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

Also convert `_CurrentTimeIndicator` to consume `nowTickerProvider` instead of its private `Timer.periodic` (spec: one shared clock): make it a `ConsumerWidget`, drop `_CurrentTimeIndicatorState`/`Timer`, and read `ref.watch(nowTickerProvider).value ?? DateTime.now().toUtc()` in place of `_now`. Update its doc comment to remove the private-timer wording.

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/widgets/epg_timeline_grid_test.dart`
Expected: PASS — new tests pass, all pre-existing tests still pass.

- [ ] **Step 6: Commit**

```bash
git add packages/feature_iptv/lib/presentation/widgets/epg_timeline_grid.dart \
        packages/feature_iptv/test/iptv/presentation/widgets/epg_timeline_grid_test.dart
git commit -m "feat(feature_iptv): add progress tickers and Jump to Present to TV EPG grid [skip ci]"
```

---

### Task 8: Screen wiring — form-factor switch, banner migration, remove `guideEpgWindowProvider`

**Files:**
- Modify: `packages/feature_iptv/lib/presentation/tv/iptv_guide_screen.dart`
- Modify: `packages/feature_iptv/lib/presentation/widgets/epg_timeline_grid.dart` (window source migration)
- Modify: `packages/feature_iptv/lib/application/providers/guide_providers.dart` (remove `guideEpgWindowProvider`)
- Modify: `packages/feature_iptv/lib/feature_iptv.dart` (exports)
- Modify: `packages/feature_iptv/test/iptv/application/providers/guide_providers_test.dart`
- Modify: `packages/feature_iptv/test/iptv/presentation/widgets/epg_timeline_grid_test.dart`
- Modify: `packages/feature_iptv/test/iptv/presentation/tv/iptv_guide_screen_test.dart`

**Interfaces:**
- Consumes: everything from Tasks 1–7.
- Produces: `IptvGuideScreen` renders `EpgTouchTimelineGrid` unless `overrideFormFactor == AiroFormFactor.tv` (then `EpgTimelineGrid`); reminder toggle wiring with snackbar + Undo; one window provider (`guidePagedWindowProvider`) everywhere.

- [ ] **Step 1: Migrate `EpgTimelineGrid` and the banner to `guidePagedWindowProvider`**

In `epg_timeline_grid.dart`, replace `ref.watch(guideEpgWindowProvider)` with `ref.watch(guidePagedWindowProvider.select((s) => s.window))` (type becomes `CompactEpgWindow?` directly, not `AsyncValue` — drop the `.value` accordingly; keep `guideWindowStartProvider`/`guideWindowDurationProvider` for the TV viewport).

In `iptv_guide_screen.dart`'s `_GuideAvailabilityBanner`, replace `ref.watch(guideEpgWindowProvider)` with `ref.watch(guidePagedWindowProvider.select((s) => s.window))`.

- [ ] **Step 2: Form-factor switch + reminder wiring in `IptvGuideScreen`**

```dart
// packages/feature_iptv/lib/presentation/tv/iptv_guide_screen.dart
// Add imports:
import '../../application/epg_reminder_scheduler.dart';
import '../../application/providers/epg_reminder_providers.dart';
import '../widgets/epg_touch_timeline_grid.dart';
// `IPTVChannel` needs `package:platform_channels/platform_channels.dart` if
// not already imported in this file (CompactEpgProgram comes from the
// existing `platform_epg` import).

// In build(), replace the Expanded(child: EpgTimelineGrid(...)) block with:
                Expanded(
                  child: overrideFormFactor == AiroFormFactor.tv
                      ? EpgTimelineGrid(
                          onChannelSelect: (channel) {
                            ref
                                .read(iptvStreamingServiceProvider)
                                .playChannel(channel);
                            ref.read(addToRecentlyWatchedProvider(channel));
                            onChannelSelected();
                          },
                        )
                      : EpgTouchTimelineGrid(
                          onChannelSelect: (channel) {
                            ref
                                .read(iptvStreamingServiceProvider)
                                .playChannel(channel);
                            ref.read(addToRecentlyWatchedProvider(channel));
                            onChannelSelected();
                          },
                          onReminderToggle: (channel, program) =>
                              _toggleReminder(context, ref, channel, program),
                        ),
                ),

// Add to the class:
  static Future<void> _toggleReminder(
    BuildContext context,
    WidgetRef ref,
    IPTVChannel channel,
    CompactEpgProgram program,
  ) async {
    final scheduler = ref.read(epgReminderSchedulerProvider);
    final messenger = ScaffoldMessenger.of(context);

    if (await scheduler.isReminded(program.programId)) {
      await scheduler.cancelReminder(program.programId);
      ref.invalidate(epgRemindersProvider);
      messenger.showSnackBar(
        SnackBar(content: Text('Reminder canceled for ${program.title}')),
      );
      return;
    }

    final outcome = await scheduler.scheduleReminder(
      channel: channel,
      program: program,
    );
    ref.invalidate(epgRemindersProvider);
    switch (outcome) {
      case EpgReminderOutcome.scheduled:
        messenger.showSnackBar(
          SnackBar(
            content: Text('Reminder set for ${program.title}'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () async {
                await scheduler.cancelReminder(program.programId);
                ref.invalidate(epgRemindersProvider);
              },
            ),
          ),
        );
      case EpgReminderOutcome.scheduledInAppOnly:
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Notifications are off — reminder will only show in-app.',
            ),
          ),
        );
      case EpgReminderOutcome.unavailable:
        break; // affordance hidden; unreachable in practice
    }
  }
```

- [ ] **Step 3: Remove `guideEpgWindowProvider` and update exports**

Delete `guideEpgWindowProvider` from `guide_providers.dart`. In `feature_iptv.dart`, add exports:

```dart
export "application/guide_window_query.dart";
export "application/epg_reminder_store.dart";
export "application/epg_reminder_scheduler.dart";
export "application/providers/epg_reminder_providers.dart";
export "presentation/widgets/epg_touch_timeline_grid.dart";
```

- [ ] **Step 4: Update existing tests**

- `guide_providers_test.dart`: delete the tests targeting `guideEpgWindowProvider` (their override-remap coverage now lives in `guide_window_query_test.dart` from Task 1); keep the search/window-start tests passing.
- `epg_timeline_grid_test.dart`: replace `guideEpgWindowProvider.overrideWith(...)` with a `_FakePagedNotifier`-style override of `guidePagedWindowProvider` (same pattern as the touch grid tests in Task 5).
- `iptv_guide_screen_test.dart`: same provider migration; add a test that the screen renders `EpgTouchTimelineGrid` when `overrideFormFactor` is null and `EpgTimelineGrid` when `AiroFormFactor.tv`.

- [ ] **Step 5: Run the full feature_iptv suite**

Run: `cd packages/feature_iptv && flutter test`
Expected: PASS, no references to `guideEpgWindowProvider` remain (`grep -rn "guideEpgWindowProvider" packages/feature_iptv` returns nothing).

- [ ] **Step 6: Commit**

```bash
git add packages/feature_iptv/lib/presentation/tv/iptv_guide_screen.dart \
        packages/feature_iptv/lib/presentation/widgets/epg_timeline_grid.dart \
        packages/feature_iptv/lib/application/providers/guide_providers.dart \
        packages/feature_iptv/lib/feature_iptv.dart \
        packages/feature_iptv/test
git commit -m "feat(feature_iptv): wire guide screen to touch/TV grids over the paged window provider [skip ci]"
```

---

### Task 9: App-level notification gateway + deep-link wiring

**Files:**
- Create: `app/lib/features/iptv/epg_reminder_notification_gateway.dart`
- Modify: `app/lib/main.dart`
- Test: `app/test/features/iptv/epg_reminder_notification_gateway_test.dart`

**Interfaces:**
- Consumes: `EpgReminderNotificationGateway`/`epgReminderNotificationGatewayProvider` (Task 4), `flutter_local_notifications` ^22 + `timezone` (already in `app/pubspec.yaml`), `AppRouter.router` (static `GoRouter`, `app/lib/core/routing/app_router.dart:37`), the `/iptv?channel=<id>` deep link (Immediate Action Player).
- Produces: `class FlutterLocalNotificationsEpgReminderGateway implements EpgReminderNotificationGateway { FlutterLocalNotificationsEpgReminderGateway({void Function(String channelId)? onReminderTap}); Future<void> initialize(); }`.

- [ ] **Step 1: Write the failing test**

```dart
// app/test/features/iptv/epg_reminder_notification_gateway_test.dart
import 'package:airo_app/features/iptv/epg_reminder_notification_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('notification tap payload routes to the handler', () {
    final routed = <String>[];
    final gateway = FlutterLocalNotificationsEpgReminderGateway(
      onReminderTap: routed.add,
    );

    gateway.handleNotificationPayload('channel-1');
    gateway.handleNotificationPayload(null);
    gateway.handleNotificationPayload('');

    expect(routed, ['channel-1']);
  });
}
```

Check the app package name in `app/pubspec.yaml` (`name:` field) and adjust the import accordingly.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/features/iptv/epg_reminder_notification_gateway_test.dart`
Expected: FAIL — file/class undefined.

- [ ] **Step 3: Implement the gateway**

```dart
// app/lib/features/iptv/epg_reminder_notification_gateway.dart
import 'dart:io';

import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// `flutter_local_notifications`-backed [EpgReminderNotificationGateway]
/// (Live Grid Navigation). Lives in the app because the plugin is an
/// app-only dependency; `feature_iptv` sees only the interface.
///
/// Uses `inexactAllowWhileIdle`: program reminders don't need exact-alarm
/// precision, and exact modes require `SCHEDULE_EXACT_ALARM`/
/// `USE_EXACT_ALARM` manifest permissions (Play declaration for the latter).
class FlutterLocalNotificationsEpgReminderGateway
    implements EpgReminderNotificationGateway {
  FlutterLocalNotificationsEpgReminderGateway({
    void Function(String channelId)? onReminderTap,
  }) : _onReminderTap = onReminderTap;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final void Function(String channelId)? _onReminderTap;
  bool _initialized = false;

  static const String _notificationChannelId = 'epg_reminders';

  @override
  bool get isAvailable => !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  Future<void> initialize() async {
    if (_initialized || !isAvailable) return;
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) {
        handleNotificationPayload(response.payload);
      },
    );
    _initialized = true;
  }

  /// Routes a notification payload to [onReminderTap]; ignores null/empty.
  @visibleForTesting
  void handleNotificationPayload(String? payload) {
    if (payload != null && payload.isNotEmpty) {
      _onReminderTap?.call(payload);
    }
  }

  @override
  Future<bool> requestPermission() async {
    await initialize();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      return await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return false;
  }

  @override
  Future<void> schedule({
    required int notificationId,
    required String title,
    required String body,
    required DateTime at,
    required String payloadChannelId,
  }) async {
    await initialize();
    await _plugin.zonedSchedule(
      id: notificationId,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(at, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _notificationChannelId,
          'Program Reminders',
          channelDescription: 'Reminders for upcoming live programs',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payloadChannelId,
    );
  }

  @override
  Future<void> cancel(int notificationId) {
    return _plugin.cancel(id: notificationId);
  }
}
```

Verify the `zonedSchedule` named-parameter signature against the installed `flutter_local_notifications` ^22 (`grep -n "Future<void> zonedSchedule" ~/.pub-cache/hosted/pub.dev/flutter_local_notifications-22*/lib/flutter_local_notifications.dart` or via the quest `reminder_service.dart` precedent, which already uses this signature minus `payload`) before writing — adjust parameter names only if the installed version differs.

- [ ] **Step 4: Wire the gateway in `main.dart`**

```dart
// app/lib/main.dart
// Add imports:
import 'core/routing/app_router.dart';
import 'features/iptv/epg_reminder_notification_gateway.dart';

// In main(), after `final prefs = await SharedPreferences.getInstance();`
// and before runApp:
  final epgReminderGateway = FlutterLocalNotificationsEpgReminderGateway(
    onReminderTap: (channelId) =>
        AppRouter.router.go('/iptv?channel=$channelId'),
  );
  await epgReminderGateway.initialize();

// Extend the ProviderScope overrides:
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        epgReminderNotificationGatewayProvider.overrideWithValue(
          epgReminderGateway,
        ),
      ],

// After runApp(...), prune elapsed reminders on resume (spec Data Flow 7):
  AppLifecycleListener(
    onResume: () async {
      await EpgReminderScheduler(
        store: EpgReminderStore(PreferencesStore(prefs)),
        gateway: epgReminderGateway,
      ).pruneElapsed();
    },
  );
```

`AppLifecycleListener` comes from `package:flutter/widgets.dart` (already imported via material). `EpgReminderScheduler`/`EpgReminderStore`/`PreferencesStore` are exported through `feature_iptv.dart` (Task 8) / `core_data` — add imports as the analyzer requires.

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd app && flutter test test/features/iptv/epg_reminder_notification_gateway_test.dart`
Expected: PASS.

- [ ] **Step 6: Build to verify no compile errors**

Run: `cd app && flutter build apk --debug`
Expected: BUILD SUCCESSFUL.

- [ ] **Step 7: Commit**

```bash
git add app/lib/features/iptv/epg_reminder_notification_gateway.dart \
        app/lib/main.dart \
        app/test/features/iptv/epg_reminder_notification_gateway_test.dart
git commit -m "feat(app): wire EPG reminder notifications with deep-link tap handling [skip ci]"
```

---

### Task 10: Req 5 verification — Android back / iOS swipe-back from the guide

**Files:**
- Test: `app/test/core/routing/guide_back_behavior_test.dart`
- Modify (only if the tests expose breakage): `app/lib/core/routing/app_router.dart` or `app/lib/core/app/app_shell.dart`

**Interfaces:**
- Consumes: `AppRouter.router` (`StatefulShellRoute` with the `/guide` branch), `sharedPreferencesProvider` override pattern from `main.dart`.

- [ ] **Step 1: Write the verification tests**

```dart
// app/test/core/routing/guide_back_behavior_test.dart
import 'package:airo_app/core/routing/app_router.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp.router(routerConfig: AppRouter.router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('guide tab renders the guide screen', (tester) async {
    await pumpApp(tester);
    AppRouter.router.go('/guide');
    await tester.pumpAndSettle();

    // The guide screen is present (guide search field is its stable marker).
    expect(find.text('Search the guide'), findsOneWidget);
  });

  testWidgets('system back on the guide root tab does not strand the shell', (tester) async {
    await pumpApp(tester);
    AppRouter.router.go('/guide');
    await tester.pumpAndSettle();

    // Simulate Android hardware back at the tab root.
    final didPop = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    // Either the app handled the pop (route stack consumed it) or the
    // shell is still rendering the guide — never a blank/black screen.
    expect(find.byType(Scaffold), findsWidgets);
    expect(tester.takeException(), isNull);
    expect(didPop, isA<bool>());
  });

  testWidgets('back from a route pushed on top of the guide returns to the guide', (tester) async {
    await pumpApp(tester);
    AppRouter.router.go('/guide');
    await tester.pumpAndSettle();
    AppRouter.router.push('/mind/notifications');
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Search the guide'), findsOneWidget);
  });
}
```

Adjust the pushed route in the third test to any route that actually exists in `app_router.dart` as a push-able route (`/mind/notifications` is used by `app_shell.dart`'s `onNotificationsTap` — confirm via grep before finalizing). If the app requires auth gating that redirects to login in tests, follow whatever existing router tests do to bypass it — `ls app/test/core/routing/` and read an existing test first.

- [ ] **Step 2: Run the tests**

Run: `cd app && flutter test test/core/routing/guide_back_behavior_test.dart`
Expected: PASS. If the second test strands the shell on a blank screen, fix the root cause in `app_router.dart`/`app_shell.dart` (typical fix: the shell's root branches must not pop the last route into nothing — prefer `SystemNavigator.pop()` semantics via `onPopInvokedWithResult` or leave default behavior); do not weaken the test.

- [ ] **Step 3: Confirm iOS swipe-back is a no-op at tab roots (no code change expected)**

iOS back-swipe only affects pushed routes (`CupertinoPageRoute`/adaptive pages); the guide is a `StatefulShellRoute` tab root, so there is nothing to swipe back from — the third test covers the pushed-route case which is the only swipe-back path. Note the finding in the commit message; no iOS-specific code.

- [ ] **Step 4: Commit**

```bash
git add app/test/core/routing/guide_back_behavior_test.dart
# plus any router/shell fix from Step 2
git commit -m "test(app): verify guide back-button behavior (Android back, pushed-route pop) [skip ci]"
```

---

## Manual QA Gate (required before merge)

Same gate as the Immediate Action Player — not automatable in CI:

1. Physical iOS device: schedule a reminder for a program ~2 min ahead, background/kill the app, confirm the notification fires, tap it, confirm the app opens directly into playback of that channel.
2. Physical Android device: same flow. Also confirm the permission prompt appears on first schedule, and the `scheduledInAppOnly` snackbar appears when permission is denied (deny in system settings, retry).
3. Android hardware back from the guide tab on a physical device behaves per Task 10.
