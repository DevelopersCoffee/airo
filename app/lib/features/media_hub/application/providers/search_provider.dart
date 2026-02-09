import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../iptv/application/providers/iptv_providers.dart';
import '../../../music/application/providers/music_tracks_provider.dart';
import '../../domain/models/media_mode.dart';
import '../../domain/models/unified_media_content.dart';
import 'media_hub_providers.dart';

/// Search state for unified media search
class MediaSearchState {
  /// Current search query
  final String query;

  /// Whether search is in progress
  final bool isSearching;

  /// Music search results
  final List<UnifiedMediaContent> musicResults;

  /// TV search results
  final List<UnifiedMediaContent> tvResults;

  /// Recent search queries (persisted)
  final List<String> recentSearches;

  /// Error message if any
  final String? errorMessage;

  const MediaSearchState({
    this.query = '',
    this.isSearching = false,
    this.musicResults = const [],
    this.tvResults = const [],
    this.recentSearches = const [],
    this.errorMessage,
  });

  /// All results combined
  List<UnifiedMediaContent> get allResults => [...musicResults, ...tvResults];

  /// Whether there are any results
  bool get hasResults => musicResults.isNotEmpty || tvResults.isNotEmpty;

  /// Whether search is active (query length >= 2)
  bool get isSearchActive => query.length >= 2;

  MediaSearchState copyWith({
    String? query,
    bool? isSearching,
    List<UnifiedMediaContent>? musicResults,
    List<UnifiedMediaContent>? tvResults,
    List<String>? recentSearches,
    String? errorMessage,
    bool clearError = false,
  }) {
    return MediaSearchState(
      query: query ?? this.query,
      isSearching: isSearching ?? this.isSearching,
      musicResults: musicResults ?? this.musicResults,
      tvResults: tvResults ?? this.tvResults,
      recentSearches: recentSearches ?? this.recentSearches,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Notifier for unified media search
class MediaSearchNotifier extends StateNotifier<MediaSearchState> {
  final Ref _ref;
  Timer? _debounceTimer;
  static const String _recentSearchesKey = 'media_hub_recent_searches';
  static const int _maxRecentSearches = 10;
  static const Duration _debounceDuration = Duration(milliseconds: 300);

  MediaSearchNotifier(this._ref) : super(const MediaSearchState()) {
    _loadRecentSearches();
  }

  /// Search with debounce (300ms)
  void search(String query) {
    _debounceTimer?.cancel();

    state = state.copyWith(query: query, clearError: true);

    if (query.length < 2) {
      state = state.copyWith(
        musicResults: [],
        tvResults: [],
        isSearching: false,
      );
      return;
    }

    state = state.copyWith(isSearching: true);

    _debounceTimer = Timer(_debounceDuration, () async {
      await _performSearch(query);
    });
  }

  /// Clear search and results
  void clear() {
    _debounceTimer?.cancel();
    state = state.copyWith(
      query: '',
      musicResults: [],
      tvResults: [],
      isSearching: false,
    );
  }

  /// Add query to recent searches
  Future<void> addToRecentSearches(String query) async {
    if (query.length < 2) return;

    // Use Set literal to remove duplicates
    final updated = {
      query,
      ...state.recentSearches,
    }.take(_maxRecentSearches).toList();

    state = state.copyWith(recentSearches: updated);
    await _saveRecentSearches();
  }

  /// Remove a query from recent searches
  Future<void> removeFromRecentSearches(String query) async {
    final updated = state.recentSearches.where((s) => s != query).toList();
    state = state.copyWith(recentSearches: updated);
    await _saveRecentSearches();
  }

  /// Clear all recent searches
  Future<void> clearRecentSearches() async {
    state = state.copyWith(recentSearches: []);
    await _saveRecentSearches();
  }

  Future<void> _performSearch(String query) async {
    try {
      final queryLower = query.toLowerCase();

      // Search music content
      final musicTracks = await _ref.read(musicTracksProvider.future);
      final musicResults = musicTracks
          .where(
            (track) =>
                track.title.toLowerCase().contains(queryLower) ||
                track.artist.toLowerCase().contains(queryLower),
          )
          .map(UnifiedMediaContent.fromTrack)
          .toList();

      // Search TV content
      final channels = await _ref.read(iptvChannelsProvider.future);
      final tvResults = channels
          .where(
            (channel) =>
                channel.name.toLowerCase().contains(queryLower) ||
                channel.group.toLowerCase().contains(queryLower),
          )
          .map(UnifiedMediaContent.fromChannel)
          .toList();

      state = state.copyWith(
        musicResults: musicResults,
        tvResults: tvResults,
        isSearching: false,
      );
    } catch (e) {
      state = state.copyWith(
        isSearching: false,
        errorMessage: 'Search failed: $e',
      );
    }
  }

  Future<void> _loadRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_recentSearchesKey);
      if (jsonString != null) {
        final list = jsonDecode(jsonString) as List<dynamic>;
        state = state.copyWith(
          recentSearches: list.map((e) => e.toString()).toList(),
        );
      }
    } catch (e) {
      // Failed to load, keep empty list
    }
  }

  Future<void> _saveRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _recentSearchesKey,
        jsonEncode(state.recentSearches),
      );
    } catch (e) {
      // Failed to save
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

/// Provider for unified media search
final mediaSearchProvider =
    StateNotifierProvider<MediaSearchNotifier, MediaSearchState>(
      (ref) => MediaSearchNotifier(ref),
    );

/// Derived: Results filtered by current mode
final modeFilteredSearchResultsProvider = Provider<List<UnifiedMediaContent>>((
  ref,
) {
  final searchState = ref.watch(mediaSearchProvider);
  final currentMode = ref.watch(selectedMediaModeProvider);

  return currentMode == MediaMode.music
      ? searchState.musicResults
      : searchState.tvResults;
});

/// Derived: Suggested categories based on mode
final suggestedCategoriesProvider = Provider<List<String>>((ref) {
  final mode = ref.watch(selectedMediaModeProvider);
  if (mode == MediaMode.music) {
    return ['Trending', 'New Releases', 'Top Charts', 'Bollywood', 'Regional'];
  } else {
    return ['Live TV', 'Movies', 'News', 'Sports', 'Kids'];
  }
});
