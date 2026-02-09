import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../iptv/application/providers/iptv_providers.dart'
    hide selectedCategoryProvider;
import '../../../iptv/domain/models/iptv_channel.dart';
import '../../domain/models/discovery_state.dart';
import '../../domain/models/media_category.dart';
import '../../domain/models/media_mode.dart';
import '../../domain/models/unified_media_content.dart';
import 'media_hub_providers.dart';

/// Discovery state notifier for content browsing
class DiscoveryNotifier extends StateNotifier<DiscoveryState> {
  final Ref _ref;

  DiscoveryNotifier(this._ref) : super(const DiscoveryState()) {
    _initializeListeners();
  }

  void _initializeListeners() {
    // Listen to mode changes and update content
    _ref.listen<MediaMode>(selectedMediaModeProvider, (prev, next) {
      if (prev != next) {
        setMode(next);
      }
    });

    // Listen to IPTV channels and update TV content
    _ref.listen<AsyncValue<List<IPTVChannel>>>(iptvChannelsProvider, (
      prev,
      next,
    ) {
      next.whenData((channels) {
        if (state.currentMode == MediaMode.tv) {
          _updateTVContent(channels);
        }
      });
    });
  }

  /// Set current mode and reload content
  void setMode(MediaMode mode) {
    state = state.copyWith(
      currentMode: mode,
      clearCategory: true,
      isLoading: true,
    );
    _loadContent();
  }

  /// Set selected category for filtering
  void setCategory(MediaCategory? category) {
    state = state.copyWith(
      selectedCategory: category,
      clearCategory: category == null,
    );
  }

  /// Search content
  void search(String query) {
    if (query.length < 2) {
      state = state.copyWith(clearSearch: true);
      return;
    }
    state = state.copyWith(searchQuery: query, isLoading: true);
    _performSearch(query);
  }

  /// Clear search
  void clearSearch() {
    state = state.copyWith(clearSearch: true);
  }

  /// Refresh content
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    await _loadContent();
  }

  /// Load more content (pagination)
  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoading) return;
    state = state.copyWith(isLoading: true);
    // TODO: Implement pagination
  }

  Future<void> _loadContent() async {
    try {
      if (state.currentMode == MediaMode.tv) {
        final channels = await _ref.read(iptvChannelsProvider.future);
        _updateTVContent(channels);
      } else {
        // TODO: Load music content from music provider
        _updateMusicContent([]);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load content: $e',
      );
    }
  }

  void _updateTVContent(List<IPTVChannel> channels) {
    final content = channels.map(UnifiedMediaContent.fromChannel).toList();
    state = state.copyWith(
      contentItems: content,
      isLoading: false,
      clearError: true,
    );
  }

  void _updateMusicContent(List<UnifiedMediaContent> tracks) {
    state = state.copyWith(
      contentItems: tracks,
      isLoading: false,
      clearError: true,
    );
  }

  void _performSearch(String query) {
    final queryLower = query.toLowerCase();
    final filtered = state.contentItems.where((content) {
      return content.title.toLowerCase().contains(queryLower) ||
          (content.subtitle?.toLowerCase().contains(queryLower) ?? false) ||
          content.tags.any((tag) => tag.toLowerCase().contains(queryLower));
    }).toList();

    state = state.copyWith(contentItems: filtered, isLoading: false);
  }
}

/// Discovery provider
final discoveryProvider =
    StateNotifierProvider<DiscoveryNotifier, DiscoveryState>(
      (ref) => DiscoveryNotifier(ref),
    );

/// Derived: Filtered content based on mode and category
final filteredContentProvider = Provider<List<UnifiedMediaContent>>((ref) {
  final discovery = ref.watch(discoveryProvider);
  final mode = ref.watch(selectedMediaModeProvider);
  final category = ref.watch(selectedCategoryProvider);

  var content = discovery.contentItems.where((c) => c.type == mode).toList();

  if (category != null) {
    content = content.where((c) => c.category?.id == category.id).toList();
  }

  return content;
});

/// Derived: TV content only
final tvContentProvider = Provider<List<UnifiedMediaContent>>((ref) {
  return ref
      .watch(discoveryProvider)
      .contentItems
      .where((c) => c.isTV)
      .toList();
});

/// Derived: Music content only
final musicContentProvider = Provider<List<UnifiedMediaContent>>((ref) {
  return ref
      .watch(discoveryProvider)
      .contentItems
      .where((c) => c.isMusic)
      .toList();
});
