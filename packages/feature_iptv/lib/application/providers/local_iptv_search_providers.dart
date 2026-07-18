import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:platform_epg/platform_epg.dart';

import '../../domain/local_iptv_search.dart';
import 'guide_providers.dart';
import 'iptv_providers.dart';

/// Combines channels, EPG program titles, favorites, and recents into a
/// searchable [LocalIptvSearchIndex] (CV-006, #810).
///
/// EPG coverage is bounded to the currently-loaded guide window
/// ([guideEpgWindowProvider]), not the full XMLTV timetable -- no repository
/// currently exposes the full per-channel program list, and expanding EPG
/// coverage beyond the guide window is tracked as a follow-up rather than
/// growing this slice's scope.
final localIptvSearchIndexProvider = FutureProvider<LocalIptvSearchIndex>((
  ref,
) async {
  final channels = await ref.watch(iptvChannelsProvider.future);
  final favoriteIds = await ref.watch(favoriteChannelIdsProvider.future);
  final recentChannels = await ref.watch(
    recentlyWatchedChannelsProvider.future,
  );
  final hiddenGroupIds = await ref.watch(hiddenGroupIdsProvider.future);

  // No EPG source configured falls back to EmptyCompactEpgRepository
  // (compactEpgRepositoryProvider's default), which resolves an empty
  // window rather than throwing -- search still works over channels alone.
  final epgWindow = await ref.watch(guideEpgWindowProvider.future);

  final programsByChannelId = <String, List<CompactEpgProgram>>{
    for (final entry in epgWindow.entries) entry.channelId: entry.programs,
  };

  return LocalIptvSearchIndex.build(
    channels: channels,
    programsByChannelId: programsByChannelId,
    favoriteChannelIds: favoriteIds,
    recentChannelIds: [for (final channel in recentChannels) channel.id],
    hiddenGroupIds: hiddenGroupIds,
  );
});

/// The search screen's query text. Independent of [channelSearchQueryProvider]
/// (the Live TV grid's quick-filter) -- opening search must not perturb the
/// grid, matching [guideSearchQueryProvider]'s existing independence pattern.
final localIptvSearchQueryProvider = StateProvider<String>((ref) => '');

/// Ranked results for the current [localIptvSearchQueryProvider] value.
final localIptvSearchResultsProvider =
    FutureProvider<List<LocalIptvSearchResult>>((ref) async {
      final query = ref.watch(localIptvSearchQueryProvider);
      if (query.trim().isEmpty) return const [];

      final index = await ref.watch(localIptvSearchIndexProvider.future);
      return index.search(query);
    });
