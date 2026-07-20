import 'dart:io';

import 'package:core_data/core_data.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_epg/platform_epg.dart';

import '../epg_channel_match_override_store.dart';
import '../guide_window_query.dart';
import '../mutable_xmltv_compact_epg_repository.dart';
import '../xmltv_source_refresh_service.dart';
import '../xmltv_source_store.dart';
import 'iptv_providers.dart';

final epgChannelMatchOverrideStoreProvider =
    Provider<EpgChannelMatchOverrideStore>((ref) {
      return EpgChannelMatchOverrideStore(
        PreferencesStore(ref.watch(sharedPreferencesProvider)),
      );
    });

final xmltvSourceStoreProvider = Provider<XmltvSourceStore>((ref) {
  return XmltvSourceStore(
    PreferencesStore(ref.watch(sharedPreferencesProvider)),
  );
});

/// One app-lifetime instance — [XmltvSourceRefreshService] mutates it via
/// [MutableXmltvCompactEpgRepository.updateSource]; nothing re-creates it.
final mutableXmltvCompactEpgRepositoryProvider =
    Provider<MutableXmltvCompactEpgRepository>((ref) {
      return MutableXmltvCompactEpgRepository();
    });

final xmltvSourceRefreshServiceProvider = Provider<XmltvSourceRefreshService>((
  ref,
) {
  return XmltvSourceRefreshService(
    dio: ref.watch(dioProvider),
    sourceStore: ref.watch(xmltvSourceStoreProvider),
    repository: ref.watch(mutableXmltvCompactEpgRepositoryProvider),
    downloadDirectoryProvider: () async => Directory.systemTemp,
  );
});

final xmltvSourceConfigProvider = FutureProvider<XmltvSourceConfig?>((
  ref,
) async {
  return ref.watch(xmltvSourceStoreProvider).load();
});

final guideWindowDurationProvider = StateProvider<Duration>(
  (ref) => const Duration(hours: 3),
);

/// "Now," floored to the nearest 30 minutes, so the window doesn't shift on
/// every rebuild — matches the fixed-window UX competitive guides use.
final guideWindowStartProvider = Provider<DateTime>((ref) {
  final now = DateTime.now().toUtc();
  final flooredMinute = now.minute < 30 ? 0 : 30;
  return DateTime.utc(now.year, now.month, now.day, now.hour, flooredMinute);
});

final guideEpgOverridesProvider = FutureProvider<Map<String, String>>((
  ref,
) async {
  return ref.watch(epgChannelMatchOverrideStoreProvider).getOverrides();
});

/// Bounded guide-window query (CV-015) — thin wrapper over
/// [queryGuideWindowWithOverrides] until the paged window provider
/// (Live Grid Navigation) supersedes it.
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
    if (!_initialLoadScheduled) {
      _initialLoadScheduled = true;
      Future.microtask(_loadInitialPages);
    }
    final earliest = _floorToThirtyMinutes(_now().subtract(guideBackward));
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
    // Re-anchor here (not only in build) so tests can inject the clock via
    // [debugSetNow] after reading `.notifier` — that read already runs
    // build(), but this microtask only runs afterwards.
    final earliest = _floorToThirtyMinutes(_now().subtract(guideBackward));
    state = state.copyWith(earliestStart: earliest, loadedThrough: earliest);

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
/// labels on both guide grids (Live Grid Navigation). Emits the current
/// instant immediately, then every 30 seconds.
final nowTickerProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now().toUtc();
  yield* Stream.periodic(
    const Duration(seconds: 30),
    (_) => DateTime.now().toUtc(),
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
  final hiddenGroupIds =
      ref.watch(hiddenGroupIdsProvider).value ?? const <String>{};
  if (index == null) return const [];

  final channels = index.filterAndSort(query: query);
  if (hiddenGroupIds.isEmpty) return channels;
  return channels
      .where((channel) => !hiddenGroupIds.contains(channel.group))
      .toList(growable: false);
});
