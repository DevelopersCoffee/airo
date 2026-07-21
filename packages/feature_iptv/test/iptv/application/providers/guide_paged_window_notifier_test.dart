import 'dart:async';

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

  Future<GuidePagedWindowState> settleInitial(
    ProviderContainer container,
  ) async {
    container
        .read(guidePagedWindowProvider.notifier)
        .debugSetNow(() => fixedNow);
    final initial = container.read(guidePagedWindowProvider);
    if (!initial.isLoadingForward || initial.forwardLoadFailed) return initial;

    final completer = Completer<GuidePagedWindowState>();
    final subscription = container.listen<GuidePagedWindowState>(
      guidePagedWindowProvider,
      (_, next) {
        if ((!next.isLoadingForward || next.forwardLoadFailed) &&
            !completer.isCompleted) {
          completer.complete(next);
        }
      },
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    return completer.future.timeout(const Duration(seconds: 5));
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

    expect(state.window!.entryForChannel('channel-1')?.programs, isNotEmpty);
  });

  test('reloads when guide EPG overrides are invalidated', () async {
    CompactEpgProgram titled(String id, String title) {
      return CompactEpgProgram(
        programId: id,
        title: title,
        startsAt: fixedNow.subtract(const Duration(minutes: 5)),
        endsAt: fixedNow.add(const Duration(minutes: 25)),
      );
    }

    final repository = InMemoryCompactEpgRepository(
      seed: CompactEpgSlice(
        entries: [
          CompactEpgEntry(
            channelId: 'channel-1',
            channelName: 'Example Channel',
            current: titled('raw', 'Raw Match Show'),
          ),
          CompactEpgEntry(
            channelId: 'overridden.epg.id',
            channelName: 'Example Channel EPG',
            current: titled('override', 'Override Match Show'),
          ),
        ],
        generatedAt: fixedNow,
        expiresAt: fixedNow.add(const Duration(hours: 24)),
        source: CompactEpgSliceSource.localCache,
      ),
    );
    final container = await buildContainer(repository: repository);

    final before = await settleInitial(container);
    expect(
      before.window!.entryForChannel('channel-1')!.programs.single.title,
      'Raw Match Show',
    );

    await container
        .read(epgChannelMatchOverrideStoreProvider)
        .setOverride(channelId: 'channel-1', epgChannelId: 'overridden.epg.id');
    container.invalidate(guideEpgOverridesProvider);

    final after = await settleInitial(container);
    expect(
      after.window!.entryForChannel('channel-1')!.programs.single.title,
      'Override Match Show',
    );
    expect(after.window!.entryForChannel('overridden.epg.id'), isNull);
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

  test(
    'a failing page keeps loaded pages and sets forwardLoadFailed',
    () async {
      final container = await buildContainer(
        repository: _FailAfterInitialLoadRepository(buildRepo()),
      );
      await settleInitial(container);
      final loadedWindow = container.read(guidePagedWindowProvider).window;

      await container.read(guidePagedWindowProvider.notifier).extendForward();
      final state = container.read(guidePagedWindowProvider);

      expect(state.forwardLoadFailed, isTrue);
      expect(state.window, same(loadedWindow));
    },
  );

  test('retryForward clears the failure and loads the page', () async {
    final failing = _FailAfterInitialLoadRepository(buildRepo());
    final container = await buildContainer(repository: failing);
    await settleInitial(container);
    await container.read(guidePagedWindowProvider.notifier).extendForward();
    expect(container.read(guidePagedWindowProvider).forwardLoadFailed, isTrue);

    failing.failNext = false;
    await container.read(guidePagedWindowProvider.notifier).retryForward();
    final state = container.read(guidePagedWindowProvider);

    expect(state.forwardLoadFailed, isFalse);
  });

  test('invalidation schedules a fresh initial load', () async {
    final repo = _CountingRepository(buildRepo());
    final container = await buildContainer(repository: repo);

    await settleInitial(container);
    expect(repo.loadWindowCalls, 3);

    container.invalidate(guidePagedWindowProvider);
    await settleInitial(container);

    expect(repo.loadWindowCalls, 6);
    expect(container.read(guidePagedWindowProvider).window, isNotNull);
  });

  test('nowTickerProvider emits UTC instants', () async {
    final container = await buildContainer();

    // A bare `read(nowTickerProvider.future)` never completes: with no active
    // listener Riverpod pauses the upstream stream subscription, so keep a
    // listener (as a watching widget would) and pump the event queue.
    final sub = container.listen(nowTickerProvider, (_, _) {});
    addTearDown(sub.close);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(sub.read().value!.isUtc, isTrue);
  });
}

/// Fails [loadWindow] once [failNext] is true, but only after the initial
/// pages have loaded: the initial load from a floored 30min start covers
/// now+6h in three 3h page loads, so calls 1-3 succeed and later calls throw.
class _FailAfterInitialLoadRepository implements CompactEpgRepository {
  _FailAfterInitialLoadRepository(this._inner);

  final CompactEpgRepository _inner;
  bool failNext = true;
  var _calls = 0;

  @override
  Future<CompactEpgSlice> loadCurrentNext({
    required Iterable<String> channelIds,
    required DateTime now,
  }) => _inner.loadCurrentNext(channelIds: channelIds, now: now);

  @override
  Future<CompactEpgWindow> loadWindow(GuideWindowQuery query) async {
    _calls++;
    if (failNext && _calls > 3) {
      throw StateError('simulated page load failure');
    }
    return _inner.loadWindow(query);
  }
}

class _CountingRepository implements CompactEpgRepository {
  _CountingRepository(this._inner);

  final CompactEpgRepository _inner;
  var loadWindowCalls = 0;

  @override
  Future<CompactEpgSlice> loadCurrentNext({
    required Iterable<String> channelIds,
    required DateTime now,
  }) => _inner.loadCurrentNext(channelIds: channelIds, now: now);

  @override
  Future<CompactEpgWindow> loadWindow(GuideWindowQuery query) {
    loadWindowCalls++;
    return _inner.loadWindow(query);
  }
}
