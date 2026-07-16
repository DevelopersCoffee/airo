import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
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
  final raw = ref.watch(rawVodItemsProvider).value ?? const [];
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
