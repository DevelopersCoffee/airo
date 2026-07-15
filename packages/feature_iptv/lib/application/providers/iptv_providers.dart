import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import "package:platform_history/platform_history.dart";
import "package:platform_channels/platform_channels.dart";
import "package:platform_epg/platform_epg.dart";
import "package:platform_player/platform_player.dart";
import "package:platform_media/platform_media.dart";
import "package:platform_playlist_import/platform_playlist_import.dart";

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

/// TV IPTV Streaming service integration provider
///
/// This provider integrates the IPTV streaming service with TvAudioHandler
/// for background playback on Android TV/Fire TV platforms.
///
/// Aligns with acceptance test [AND-PB-004]: Background Audio Foreground Service
/// - When user switches to another app (home button), audio continues
/// - Notification controls available for play/pause/stop
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
  // Import TvAudioHandler from core/audio/tv_audio_service.dart
  // and connect it with VideoPlayerStreamingService
  //
  // The TvAudioHandler should be notified when:
  // - playChannel() is called -> handler.playChannel(name, url)
  // - pause() is called -> handler.pause()
  // - resume() is called -> handler.play()
  // - stop() is called -> handler.stop()
  //
  // This enables:
  // - Media session integration on Android TV
  // - Background audio when home button is pressed
  // - Notification controls (play/pause/stop)
  // - Audio focus handling (auto-pause on phone calls)
  //
  // Implementation note:
  // The actual integration requires modifying VideoPlayerStreamingService
  // to accept an optional TvAudioHandler and call its methods when
  // playback state changes. For now, the provider documents the pattern.
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
  final channelDataService = ref.watch(channelDataServiceProvider);
  try {
    final channels = await channelDataService.fetchChannels(
      forceRefresh: forceRefresh,
    );
    if (channels.isNotEmpty) {
      return channels;
    }
  } catch (e) {
    debugPrint(
      '[Provider] ChannelDataService refresh failed, falling back to M3U: $e',
    );
  }

  // Fallback to legacy M3U parser
  final parser = ref.watch(m3uParserProvider);
  return parser.fetchPlaylist(forceRefresh: forceRefresh);
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

  return searchIndex?.filterAndSort(
        category: category,
        flavor: flavor,
        query: searchQuery,
        preferenceKeywords: preferences,
      ) ??
      const [];
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

/// Streaming state provider
final streamingStateProvider = StreamProvider<StreamingState>((ref) {
  final service = ref.watch(iptvStreamingServiceProvider);
  return service.stateStream;
});

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
