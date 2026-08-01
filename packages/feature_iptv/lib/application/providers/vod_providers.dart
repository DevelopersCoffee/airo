import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:platform_history/platform_history.dart';
import 'package:platform_playlist/platform_playlist.dart';

import '../../domain/vod_series_grouping.dart';
import 'content_source_providers.dart';
import 'iptv_providers.dart';

final vodWatchHistoryStorageProvider = Provider<VodWatchHistoryStorage>((ref) {
  return VodWatchHistoryStorage(ref.watch(sharedPreferencesProvider));
});

final _m3uVodAdapterProvider = Provider<M3uVodAdapter>(
  (ref) => M3uVodAdapter(),
);

/// VOD entries for the exclusive active source. Xtream uses its provider VOD
/// endpoint; M3U/Stalker keep the existing channel-list extraction behavior.
final rawVodItemsProvider = FutureProvider<List<VodItem>>((ref) async {
  final active = await ref.watch(activeContentSourceProvider.future);
  if (active?.kind == ContentSourceKind.xtream) {
    final credential = await ref
        .read(contentSourceCredentialStoreProvider)
        .read(ContentSourceCredentialRef(active!.id));
    if (credential == null) {
      throw const ContentSourceRuntimeException(
        'Xtream credentials are unavailable. Reconnect the source.',
      );
    }
    try {
      final client = XtreamClient(
        dio: ref.read(dioProvider),
        serverUrl: active.url,
        username: credential.username,
        password: credential.password,
        sourceId: active.id,
      );
      return XtreamVodAdapter(client, sourceId: active.id).loadVodItems();
    } catch (_) {
      throw const ContentSourceRuntimeException(
        'Could not load Xtream VOD. Check the source and retry.',
      );
    }
  }
  final channels = await ref.watch(iptvChannelsProvider.future);
  final adapter = ref.watch(_m3uVodAdapterProvider);
  return adapter.extractVodItems(channels);
}, retry: surfaceChannelFailureInsteadOfRetrying);

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
