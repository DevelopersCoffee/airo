import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import "package:platform_favorites/platform_favorites.dart";
import "package:platform_history/platform_history.dart";
import "package:platform_channels/platform_channels.dart";
import "package:platform_epg/platform_epg.dart";
import "package:platform_player/platform_player.dart";
import "package:platform_media/platform_media.dart";
import "package:platform_playlist_import/platform_playlist_import.dart";
import '../../domain/favorite_reimport_coordinator.dart';
import '../../domain/vod_resume_coordinator.dart';

export 'iptv_cast_providers.dart';
export 'airo_tv_profile_provider.dart';
export 'edge_intelligence_providers.dart';
export 'iptv_navigation_provider.dart';
export 'voice_search_provider.dart';

/// Shared preferences provider
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'Override in main with SharedPreferences.getInstance()',
  );
});

/// Global fullscreen mode provider - when true, hides bottom navigation and app bar
final isFullscreenModeProvider = StateProvider<bool>((ref) => false);

/// Dio HTTP client provider
final dioProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );
});

/// M3U Parser service provider (legacy - for backward compatibility)
final m3uParserProvider = Provider<M3UParserService>((ref) {
  return M3UParserService(
    dio: ref.watch(dioProvider),
    prefs: ref.watch(sharedPreferencesProvider),
  );
});

/// User-supplied playlist URL.
final userPlaylistUrlProvider = FutureProvider<String?>((ref) async {
  return ref.watch(m3uParserProvider).getPlaylistUrl();
});

/// Channel data service provider (new - fetches preprocessed JSON)
final channelDataServiceProvider = Provider<ChannelDataService>((ref) {
  return ChannelDataService(
    dio: ref.watch(dioProvider),
    prefs: ref.watch(sharedPreferencesProvider),
  );
});

/// IPTV Streaming service provider
final iptvStreamingServiceProvider = Provider<VideoPlayerStreamingService>((
  ref,
) {
  final service = VideoPlayerStreamingService(config: StreamingConfig.youtube);
  ref.onDispose(() => service.dispose());
  return service;
});

/// OS media-session delegate supplied by the host application (e.g. the
/// Airo TV shell overrides this with its `audio_service`-backed
/// `TvAudioHandler`). Null on hosts without a media session (web, mobile,
/// tests) — the streaming service treats that as "nothing to report to".
final tvMediaSessionDelegateProvider = Provider<StreamingMediaSessionDelegate?>(
  (ref) => null,
);

/// TV IPTV Streaming service integration provider
///
/// This provider integrates the IPTV streaming service with the host app's
/// media-session delegate (see [tvMediaSessionDelegateProvider]) for
/// background playback on Android TV/Fire TV platforms.
///
/// Aligns with acceptance test [AND-PB-004]: Background Audio Foreground Service
/// - When user switches to another app (home button), audio continues
/// - Notification controls available for play/pause/stop
///
/// The delegate is attached via the service's setter (not a constructor
/// rebuild) so overriding [tvMediaSessionDelegateProvider] never tears down
/// in-flight playback. Something in the widget tree must watch this provider
/// for the wiring to stay live (`IPTVScreen` does).
///
/// Usage:
/// ```dart
/// // On TV platforms, connect streaming service to TV audio handler
/// ref.watch(tvIptvIntegrationProvider);
///
/// // Then use streaming service normally
/// final streamingService = ref.watch(iptvStreamingServiceProvider);
/// await streamingService.playChannel(channel);
/// ```
final tvIptvIntegrationProvider = Provider<void>((ref) {
  final delegate = ref.watch(tvMediaSessionDelegateProvider);
  ref.watch(iptvStreamingServiceProvider).mediaSessionDelegate = delegate;
});

/// All channels provider - fetches preprocessed channels from IPTV Sanity Agent
/// Falls back to M3U parser if preprocessed data is unavailable
final iptvChannelsProvider = FutureProvider<List<IPTVChannel>>((ref) async {
  final channelDataService = ref.watch(channelDataServiceProvider);
  try {
    final channels = await channelDataService.fetchChannels();
    if (channels.isNotEmpty) {
      return channels;
    }
  } catch (e) {
    debugPrint('[Provider] ChannelDataService failed, falling back to M3U: $e');
  }

  // Fallback to legacy M3U parser
  final parser = ref.watch(m3uParserProvider);
  return parser.fetchPlaylist();
});

/// Refresh channels provider
final refreshChannelsProvider = FutureProvider.family<List<IPTVChannel>, bool>((
  ref,
  forceRefresh,
) async {
  // Snapshot before the refresh so CV-017's favorite remap has an "old"
  // list to diff the freshly re-imported one against. Reads whatever is
  // already cached without forcing a fetch -- null/absent on the very
  // first import, which applyFavoriteRemapOnReimport treats as a no-op.
  final oldChannels = ref.read(iptvChannelsProvider).value ?? const [];

  List<IPTVChannel> newChannels;
  final channelDataService = ref.watch(channelDataServiceProvider);
  try {
    final channels = await channelDataService.fetchChannels(
      forceRefresh: forceRefresh,
    );
    newChannels = channels.isNotEmpty
        ? channels
        : await ref
              .watch(m3uParserProvider)
              .fetchPlaylist(forceRefresh: forceRefresh);
  } catch (e) {
    debugPrint(
      '[Provider] ChannelDataService refresh failed, falling back to M3U: $e',
    );
    newChannels = await ref
        .watch(m3uParserProvider)
        .fetchPlaylist(forceRefresh: forceRefresh);
  }

  final needsReview = await applyFavoriteRemapOnReimport(
    favoriteStorage: ref.read(favoriteChannelsStorageProvider),
    coordinator: ref.read(favoriteReimportCoordinatorProvider),
    oldChannels: oldChannels,
    newChannels: newChannels,
  );
  if (needsReview.isNotEmpty) {
    ref.read(favoriteReimportReviewCandidatesProvider.notifier).state =
        needsReview;
  }
  ref.invalidate(favoriteChannelIdsProvider);

  return newChannels;
});

/// Current category filter
final selectedCategoryProvider = StateProvider<ChannelCategory>((ref) {
  return ChannelCategory.all;
});

/// Current flavor filter (taste-based filtering)
final selectedFlavorProvider = StateProvider<ChannelFlavor?>((ref) {
  return null; // null means no flavor filter
});

/// Search query provider
final channelSearchQueryProvider = StateProvider<String>((ref) => '');

/// User preference keywords for channel sorting
final preferenceKeywordsProvider = StateProvider<List<String>>((ref) {
  return const [
    'news',
    'music',
    'sports',
    'radio',
    'local',
    'public',
    'education',
  ];
});

/// Reusable platform search index for the loaded channel list.
final channelSearchIndexProvider = Provider<AiroChannelSearchIndex?>((ref) {
  final channelsAsync = ref.watch(iptvChannelsProvider);
  return channelsAsync.when(
    data: AiroChannelSearchIndex.new,
    loading: () => null,
    error: (_, _) => null,
  );
});

/// Filtered and sorted channels
final filteredChannelsProvider = Provider<List<IPTVChannel>>((ref) {
  final searchIndex = ref.watch(channelSearchIndexProvider);
  final category = ref.watch(selectedCategoryProvider);
  final flavor = ref.watch(selectedFlavorProvider);
  final searchQuery = ref.watch(channelSearchQueryProvider);
  final preferences = ref.watch(preferenceKeywordsProvider);
  // CV-021: hidden groups are excluded from browse by default, not just
  // visually skipped. `.value` is null while the async read is still in
  // flight, which is treated the same as "nothing hidden yet" rather than
  // blocking the whole browse list on it.
  final hiddenGroupIds =
      ref.watch(hiddenGroupIdsProvider).value ?? const <String>{};

  final channels =
      searchIndex?.filterAndSort(
        category: category,
        flavor: flavor,
        query: searchQuery,
        preferenceKeywords: preferences,
      ) ??
      const [];

  if (hiddenGroupIds.isEmpty) return channels;
  return channels
      .where((channel) => !hiddenGroupIds.contains(channel.group))
      .toList(growable: false);
});

/// Channels filtered by specific flavor
final channelsByFlavorProvider =
    Provider.family<List<IPTVChannel>, ChannelFlavor>((ref, flavor) {
      final searchIndex = ref.watch(channelSearchIndexProvider);
      return searchIndex?.channelsByFlavor(flavor) ?? const [];
    });

/// Hindi music channels provider (convenience)
final hindiMusicChannelsProvider = Provider<List<IPTVChannel>>((ref) {
  return ref.watch(channelsByFlavorProvider(ChannelFlavor.hindiMusic));
});

/// English music channels provider (convenience)
final englishMusicChannelsProvider = Provider<List<IPTVChannel>>((ref) {
  return ref.watch(channelsByFlavorProvider(ChannelFlavor.englishMusic));
});

/// Hindi news channels provider (convenience)
final hindiNewsChannelsProvider = Provider<List<IPTVChannel>>((ref) {
  return ref.watch(channelsByFlavorProvider(ChannelFlavor.hindiNews));
});

/// English news channels provider (convenience)
final englishNewsChannelsProvider = Provider<List<IPTVChannel>>((ref) {
  return ref.watch(channelsByFlavorProvider(ChannelFlavor.englishNews));
});

/// Category counts provider - shows how many channels in each category
final categoryCounts = Provider<Map<ChannelCategory, int>>((ref) {
  final searchIndex = ref.watch(channelSearchIndexProvider);
  return searchIndex?.categoryCounts ?? const {};
});

/// Check if any filter is active (category, flavor, or search)
final hasActiveFilterProvider = Provider<bool>((ref) {
  final category = ref.watch(selectedCategoryProvider);
  final flavor = ref.watch(selectedFlavorProvider);
  final searchQuery = ref.watch(channelSearchQueryProvider);
  return category != ChannelCategory.all ||
      flavor != null ||
      searchQuery.isNotEmpty;
});

/// Flavor counts provider - shows how many channels in each flavor
final flavorCounts = Provider<Map<ChannelFlavor, int>>((ref) {
  final searchIndex = ref.watch(channelSearchIndexProvider);
  return searchIndex?.flavorCounts ?? const {};
});

class CompactEpgChannelQuery {
  const CompactEpgChannelQuery({required this.channelIds, required this.now});

  final List<String> channelIds;
  final DateTime now;

  @override
  bool operator ==(Object other) {
    return other is CompactEpgChannelQuery &&
        listEquals(other.channelIds, channelIds) &&
        other.now == now;
  }

  @override
  int get hashCode => Object.hash(Object.hashAll(channelIds), now);
}

/// Platform compact EPG repository consumed by Airo TV.
///
/// Apps can override this with `XmltvCompactEpgRepository`, a storage-backed
/// repository, or a delegated compact EPG source. The default keeps guide UI
/// unavailable without parsing XMLTV in presentation code.
final compactEpgRepositoryProvider = Provider<CompactEpgRepository>((ref) {
  return const EmptyCompactEpgRepository();
});

/// Reference time for current/next guide queries.
final compactEpgReferenceTimeProvider = Provider<DateTime>((ref) {
  return DateTime.now().toUtc();
});

final compactEpgSliceForChannelsProvider =
    FutureProvider.family<CompactEpgSlice, CompactEpgChannelQuery>((
      ref,
      query,
    ) async {
      final repository = ref.watch(compactEpgRepositoryProvider);
      return repository.loadCurrentNext(
        channelIds: query.channelIds,
        now: query.now,
      );
    });

/// Bounded guide-window lookup (CV-015): programmes intersecting
/// [GuideWindowQuery]'s time range, per channel — never the full timetable.
final compactEpgWindowProvider =
    FutureProvider.family<CompactEpgWindow, GuideWindowQuery>((
      ref,
      query,
    ) async {
      final repository = ref.watch(compactEpgRepositoryProvider);
      return repository.loadWindow(query);
    });

/// Streaming state provider
final streamingStateProvider = StreamProvider<StreamingState>((ref) {
  final service = ref.watch(iptvStreamingServiceProvider);
  return service.stateStream;
});

/// Current app lifecycle state, updated by a `WidgetsBindingObserver` in
/// `IPTVScreen`. Drives [PlayerBackgroundingCoordinator]'s PiP / audio-only
/// backgrounding decision.
final appLifecycleStateProvider = StateProvider<AppLifecycleState>(
  (ref) => AppLifecycleState.resumed,
);

/// Current channel provider
final currentChannelProvider = Provider<IPTVChannel?>((ref) {
  final state = ref.watch(streamingStateProvider);
  return state.when(
    data: (s) => s.currentChannel,
    loading: () => null,
    error: (_, _) => null,
  );
});

/// Current channel index in filtered list
final currentChannelIndexProvider = Provider<int>((ref) {
  final currentChannel = ref.watch(currentChannelProvider);
  final filteredChannels = ref.watch(filteredChannelsProvider);
  if (currentChannel == null) return -1;
  return filteredChannels.indexWhere(
    (c) => c.streamUrl == currentChannel.streamUrl,
  );
});

/// Next channel provider - returns the next channel in the filtered list
final nextChannelProvider = Provider<IPTVChannel?>((ref) {
  final currentIndex = ref.watch(currentChannelIndexProvider);
  final filteredChannels = ref.watch(filteredChannelsProvider);
  if (currentIndex < 0 || filteredChannels.isEmpty) return null;
  final nextIndex = (currentIndex + 1) % filteredChannels.length;
  return filteredChannels[nextIndex];
});

/// Previous channel provider - returns the previous channel in the filtered list
final previousChannelProvider = Provider<IPTVChannel?>((ref) {
  final currentIndex = ref.watch(currentChannelIndexProvider);
  final filteredChannels = ref.watch(filteredChannelsProvider);
  if (currentIndex < 0 || filteredChannels.isEmpty) return null;
  final prevIndex = currentIndex == 0
      ? filteredChannels.length - 1
      : currentIndex - 1;
  return filteredChannels[prevIndex];
});

/// Playback state provider
final playbackStateProvider = Provider<PlaybackState>((ref) {
  final state = ref.watch(streamingStateProvider);
  return state.when(
    data: (s) => s.playbackState,
    loading: () => PlaybackState.idle,
    error: (_, _) => PlaybackState.error,
  );
});

/// Buffer status provider
final bufferStatusProvider = Provider<BufferStatus>((ref) {
  final state = ref.watch(streamingStateProvider);
  return state.when(
    data: (s) => s.bufferStatus,
    loading: () => const BufferStatus(),
    error: (_, _) => const BufferStatus(),
  );
});

/// Current quality provider
final currentQualityProvider = Provider<VideoQuality>((ref) {
  final state = ref.watch(streamingStateProvider);
  return state.when(
    data: (s) => s.currentQuality,
    loading: () => VideoQuality.auto,
    error: (_, _) => VideoQuality.auto,
  );
});

/// Network quality provider
final networkQualityProvider = Provider<NetworkQuality>((ref) {
  final state = ref.watch(streamingStateProvider);
  return state.when(
    data: (s) => s.metrics?.networkQuality ?? NetworkQuality.good,
    loading: () => NetworkQuality.good,
    error: (_, _) => NetworkQuality.offline,
  );
});

// =============================================================================
// Recently Watched Channels Providers
// =============================================================================

/// Recently watched channels storage provider
final recentlyWatchedStorageProvider = Provider<RecentlyWatchedStorage>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return RecentlyWatchedStorage(prefs);
});

/// Recently watched channels provider
/// Returns the list of recently watched channels (most recent first)
final recentlyWatchedChannelsProvider = FutureProvider<List<IPTVChannel>>((
  ref,
) async {
  final storage = ref.watch(recentlyWatchedStorageProvider);
  return storage.getRecentlyWatched(limit: 10);
});

/// Clear recently watched channels
/// Call this to clear the viewing history for privacy
final clearRecentlyWatchedProvider = FutureProvider.family<void, void>((
  ref,
  _,
) async {
  final storage = ref.watch(recentlyWatchedStorageProvider);
  await storage.clearRecent();
  ref.invalidate(recentlyWatchedChannelsProvider);
});

/// Add channel to recently watched
/// Use this when a channel starts playing
final addToRecentlyWatchedProvider = FutureProvider.family<void, IPTVChannel>((
  ref,
  channel,
) async {
  final storage = ref.watch(recentlyWatchedStorageProvider);
  await storage.addToRecent(channel);
  ref.invalidate(recentlyWatchedChannelsProvider);
});

// =============================================================================
// Favorite Channels Providers
// =============================================================================

/// Favorite channels storage provider
final favoriteChannelsStorageProvider = Provider<FavoriteChannelsStorage>((
  ref,
) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return FavoriteChannelsStorage(prefs);
});

/// The set of favorited channel ids.
final favoriteChannelIdsProvider = FutureProvider<Set<String>>((ref) async {
  final storage = ref.watch(favoriteChannelsStorageProvider);
  return storage.getFavoriteChannelIds();
});

/// Whether a specific channel is favorited.
final isChannelFavoriteProvider = Provider.family<bool, String>((
  ref,
  channelId,
) {
  final favoriteIds = ref.watch(favoriteChannelIdsProvider);
  return favoriteIds.value?.contains(channelId) ?? false;
});

/// The list of favorited channels, most-recently-added first.
final favoriteChannelsProvider = FutureProvider<List<IPTVChannel>>((ref) async {
  final favoriteIds = await ref.watch(favoriteChannelIdsProvider.future);
  if (favoriteIds.isEmpty) return const [];

  final allChannels = await ref.watch(iptvChannelsProvider.future);
  return allChannels
      .where((channel) => favoriteIds.contains(channel.id))
      .toList(growable: false);
});

/// Toggles a channel's favorite state and returns the new state.
///
/// A plain callable rather than a FutureProvider.family: a family instance
/// caches its first result, so a second toggle of the same channel would
/// silently no-op.
final channelFavoriteTogglerProvider = Provider<Future<bool> Function(String)>((
  ref,
) {
  return (channelId) async {
    final storage = ref.read(favoriteChannelsStorageProvider);
    final isNowFavorite = await storage.toggleFavorite(channelId);
    ref.invalidate(favoriteChannelIdsProvider);
    return isNowFavorite;
  };
});

/// Coordinator for CV-017's favorites-survive-reimport behavior.
final favoriteReimportCoordinatorProvider =
    Provider<FavoriteReimportCoordinator>(
      (ref) => FavoriteReimportCoordinator(),
    );

/// Applies [FavoriteReimportCoordinator]'s decisions to real storage: writes
/// high-confidence remaps directly, drops favorites with no match at all,
/// and leaves name-only matches untouched in storage -- returning them so
/// the caller can surface a review prompt (CV-017, #821).
///
/// A no-op when there's nothing to compare against (first import, before
/// any channel list has ever been loaded) or no favorites exist yet.
Future<List<FavoriteReviewCandidate>> applyFavoriteRemapOnReimport({
  required FavoriteChannelsStorage favoriteStorage,
  required FavoriteReimportCoordinator coordinator,
  required List<IPTVChannel> oldChannels,
  required List<IPTVChannel> newChannels,
}) async {
  if (oldChannels.isEmpty) return const [];

  final favoriteIds = await favoriteStorage.getFavoriteChannelIds();
  if (favoriteIds.isEmpty) return const [];

  final result = coordinator.remapFavorites(
    favoriteChannelIds: favoriteIds,
    oldChannels: oldChannels,
    newChannels: newChannels,
  );

  // Ids pending review must stay in storage untouched -- only a true
  // no-match (neither remapped nor flagged for review) gets dropped.
  final reviewIds = result.needsReview
      .map((candidate) => candidate.oldChannel.id)
      .toSet();
  final toDrop = favoriteIds
      .difference(result.remappedFavoriteIds)
      .difference(reviewIds);
  for (final droppedId in toDrop) {
    await favoriteStorage.removeFavorite(droppedId);
  }
  for (final newId in result.remappedFavoriteIds.difference(favoriteIds)) {
    await favoriteStorage.addFavorite(newId);
  }

  return result.needsReview;
}

/// Favorite matches from the most recent re-import that need explicit user
/// confirmation before being applied (CV-017). Cleared by whatever UI
/// eventually consumes and resolves them; empty until then.
final favoriteReimportReviewCandidatesProvider =
    StateProvider<List<FavoriteReviewCandidate>>((ref) => const []);

// =============================================================================
// Hidden Groups Providers (CV-021, #826)
// =============================================================================

/// Hidden groups storage provider.
final hiddenGroupsStorageProvider = Provider<HiddenGroupsStorage>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return HiddenGroupsStorage(prefs);
});

/// The set of hidden group/category ids. Consumed by search (CV-006) and,
/// once it exists, the smart-playlist rule engine (CV-017) so hidden
/// channels are excluded by default rather than just visually skipped.
final hiddenGroupIdsProvider = FutureProvider<Set<String>>((ref) async {
  final storage = ref.watch(hiddenGroupsStorageProvider);
  return storage.getHiddenGroupIds();
});

/// Toggle a group's hidden state. Returns the new state.
final toggleGroupHiddenProvider = FutureProvider.family<bool, String>((
  ref,
  groupId,
) async {
  final storage = ref.watch(hiddenGroupsStorageProvider);
  final nowHidden = await storage.toggleHidden(groupId);
  ref.invalidate(hiddenGroupIdsProvider);
  return nowHidden;
});

// =============================================================================
// VOD Resume Position (CV-016)
// =============================================================================

/// VOD resume-position storage provider.
final vodResumePositionStorageProvider = Provider<VodResumePositionStorage>((
  ref,
) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return VodResumePositionStorage(prefs);
});

/// Drives VOD resume-seek/save decisions for [VideoPlayerWidget]. Kept alive
/// for the app's lifetime (not per-screen) so [VodResumeCoordinator]'s
/// per-channel "already checked this session" bookkeeping survives
/// navigating away from and back to the player.
final vodResumeCoordinatorProvider = Provider<VodResumeCoordinator>((ref) {
  return VodResumeCoordinator(
    storage: ref.watch(vodResumePositionStorageProvider),
  );
});
