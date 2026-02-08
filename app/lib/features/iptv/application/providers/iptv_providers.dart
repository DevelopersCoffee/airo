import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/iptv_channel.dart';
import '../../domain/models/streaming_state.dart';
import '../../domain/services/m3u_parser_service.dart';
import '../../domain/services/iptv_streaming_service.dart';
import '../../domain/services/video_player_streaming_service.dart';

/// Shared preferences provider
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'Override in main with SharedPreferences.getInstance()',
  );
});

/// Current navigation tab index provider (0=Coins, 1=Mind, 2=Media, 3=Arena, 4=Quest)
/// Used to detect when user navigates away from Media tab for mini player display
final currentNavigationTabProvider = StateProvider<int>((ref) => 2);

/// Dio HTTP client provider
final dioProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );
});

/// M3U Parser service provider
final m3uParserProvider = Provider<M3UParserService>((ref) {
  return M3UParserService(
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

/// All channels provider - fetches and caches playlist
final iptvChannelsProvider = FutureProvider<List<IPTVChannel>>((ref) async {
  final parser = ref.watch(m3uParserProvider);
  return parser.fetchPlaylist();
});

/// Refresh channels provider
final refreshChannelsProvider = FutureProvider.family<List<IPTVChannel>, bool>((
  ref,
  forceRefresh,
) async {
  final parser = ref.watch(m3uParserProvider);
  return parser.fetchPlaylist(forceRefresh: forceRefresh);
});

/// Current category filter
final selectedCategoryProvider = StateProvider<ChannelCategory>((ref) {
  return ChannelCategory.all;
});

/// Search query provider
final channelSearchQueryProvider = StateProvider<String>((ref) => '');

/// User preference keywords for channel sorting
final preferenceKeywordsProvider = StateProvider<List<String>>((ref) {
  return [
    'hindi',
    'india',
    'bollywood',
    'star',
    'zee',
    'sony',
    'colors',
    'sab',
    'aaj tak',
    'dd ',
    'news 18',
    'ndtv',
  ];
});

/// Filtered and sorted channels
final filteredChannelsProvider = Provider<List<IPTVChannel>>((ref) {
  final channelsAsync = ref.watch(iptvChannelsProvider);
  final category = ref.watch(selectedCategoryProvider);
  final searchQuery = ref.watch(channelSearchQueryProvider).toLowerCase();
  final preferences = ref.watch(preferenceKeywordsProvider);

  return channelsAsync.when(
    data: (channels) {
      // Filter by category
      var filtered = category == ChannelCategory.all
          ? channels
          : channels.where((c) => c.category == category).toList();

      // Filter by search query
      if (searchQuery.isNotEmpty) {
        filtered = filtered
            .where(
              (c) =>
                  c.name.toLowerCase().contains(searchQuery) ||
                  c.group.toLowerCase().contains(searchQuery),
            )
            .toList();
      }

      // Sort by preference score
      filtered.sort((a, b) {
        final scoreA = _getPreferenceScore(a, preferences);
        final scoreB = _getPreferenceScore(b, preferences);
        if (scoreA != scoreB) return scoreB.compareTo(scoreA);
        return a.name.compareTo(b.name);
      });

      return filtered;
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

int _getPreferenceScore(IPTVChannel channel, List<String> preferences) {
  final str = '${channel.name} ${channel.group}'.toLowerCase();
  for (var i = 0; i < preferences.length; i++) {
    if (str.contains(preferences[i])) {
      return preferences.length - i; // Higher score for earlier preferences
    }
  }
  return 0;
}

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
    error: (_, __) => null,
  );
});

/// Playback state provider
final playbackStateProvider = Provider<PlaybackState>((ref) {
  final state = ref.watch(streamingStateProvider);
  return state.when(
    data: (s) => s.playbackState,
    loading: () => PlaybackState.idle,
    error: (_, __) => PlaybackState.error,
  );
});

/// Buffer status provider
final bufferStatusProvider = Provider<BufferStatus>((ref) {
  final state = ref.watch(streamingStateProvider);
  return state.when(
    data: (s) => s.bufferStatus,
    loading: () => const BufferStatus(),
    error: (_, __) => const BufferStatus(),
  );
});

/// Current quality provider
final currentQualityProvider = Provider<VideoQuality>((ref) {
  final state = ref.watch(streamingStateProvider);
  return state.when(
    data: (s) => s.currentQuality,
    loading: () => VideoQuality.auto,
    error: (_, __) => VideoQuality.auto,
  );
});

/// Network quality provider
final networkQualityProvider = Provider<NetworkQuality>((ref) {
  final state = ref.watch(streamingStateProvider);
  return state.when(
    data: (s) => s.metrics?.networkQuality ?? NetworkQuality.good,
    loading: () => NetworkQuality.good,
    error: (_, __) => NetworkQuality.offline,
  );
});
