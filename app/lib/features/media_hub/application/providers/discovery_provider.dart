import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import "package:feature_iptv/feature_iptv.dart";
import "package:platform_channels/platform_channels.dart";
import '../../../music/application/providers/music_tracks_provider.dart';
import '../../domain/models/discovery_state.dart';
import '../../domain/models/media_category.dart';
import '../../domain/models/media_mode.dart';
import '../../domain/models/unified_media_content.dart';

final mediaHubDiscoveryPageSizeProvider = Provider<int>((ref) => 12);

final mediaHubDiscoverySourceProvider =
    FutureProvider.family<List<UnifiedMediaContent>, MediaMode>((
      ref,
      mode,
    ) async {
      switch (mode) {
        case MediaMode.music:
          final tracks = await ref.watch(musicTracksProvider.future);
          return tracks.map(UnifiedMediaContent.fromTrack).toList();
        case MediaMode.tv:
          final channels = await ref.watch(iptvChannelsProvider.future);
          return channels.map(UnifiedMediaContent.fromChannel).toList();
      }
    });

final mediaHubDiscoveryProvider =
    AsyncNotifierProvider.family<DiscoveryNotifier, DiscoveryState, MediaMode>(
      DiscoveryNotifier.new,
    );

class DiscoveryNotifier extends FamilyAsyncNotifier<DiscoveryState, MediaMode> {
  late MediaMode _mode;

  @override
  FutureOr<DiscoveryState> build(MediaMode arg) async {
    _mode = arg;
    final items = await ref.watch(mediaHubDiscoverySourceProvider(arg).future);
    final pageSize = ref.watch(mediaHubDiscoveryPageSizeProvider);
    return DiscoveryState.initial(mode: arg, items: items, pageSize: pageSize);
  }

  void setSearchQuery(String query) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(
      _rebuild(current, searchQuery: query.trim(), currentPage: 1),
    );
  }

  void setCategory(MediaCategory category) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(
      _rebuild(current, selectedCategory: category, currentPage: 1),
    );
  }

  void loadNextPage() {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore) return;
    state = AsyncData(_rebuild(current, currentPage: current.currentPage + 1));
  }

  Future<void> refresh() async {
    final previous = state.valueOrNull;
    state = const AsyncLoading();
    final items = await ref.refresh(
      mediaHubDiscoverySourceProvider(_mode).future,
    );
    final pageSize = ref.read(mediaHubDiscoveryPageSizeProvider);
    final base = DiscoveryState.initial(
      mode: _mode,
      items: items,
      pageSize: pageSize,
    );
    state = AsyncData(
      previous == null
          ? base
          : _rebuild(
              base,
              searchQuery: previous.searchQuery,
              selectedCategory: previous.selectedCategory,
              currentPage: previous.currentPage == 0 ? 1 : previous.currentPage,
            ),
    );
  }

  DiscoveryState _rebuild(
    DiscoveryState current, {
    List<UnifiedMediaContent>? items,
    String? searchQuery,
    MediaCategory? selectedCategory,
    int? currentPage,
  }) {
    final nextItems = List<UnifiedMediaContent>.unmodifiable(
      items ?? current.items,
    );
    final nextQuery = searchQuery ?? current.searchQuery;
    final nextCategory = selectedCategory ?? current.selectedCategory;
    final filtered = nextItems
        .where((item) {
          final matchesCategory =
              nextCategory == MediaCategory.all ||
              item.category == nextCategory;
          if (!matchesCategory) {
            return false;
          }
          if (nextQuery.isEmpty) {
            return true;
          }
          final normalizedQuery = nextQuery.toLowerCase();
          return item.title.toLowerCase().contains(normalizedQuery) ||
              item.subtitle.toLowerCase().contains(normalizedQuery) ||
              item.tags.any(
                (tag) => tag.toLowerCase().contains(normalizedQuery),
              );
        })
        .toList(growable: false);

    final requestedPage = currentPage ?? current.currentPage;
    final effectivePage = filtered.isEmpty
        ? 0
        : requestedPage.clamp(1, _maxPage(filtered.length, current.pageSize));
    final visibleCount = effectivePage == 0
        ? 0
        : (effectivePage * current.pageSize).clamp(0, filtered.length);
    final visibleItems = List<UnifiedMediaContent>.unmodifiable(
      filtered.take(visibleCount),
    );

    return current.copyWith(
      items: nextItems,
      visibleItems: visibleItems,
      searchQuery: nextQuery,
      selectedCategory: nextCategory,
      currentPage: effectivePage,
      filteredCount: filtered.length,
      hasMore: visibleCount < filtered.length,
    );
  }

  int _maxPage(int totalItems, int pageSize) {
    return ((totalItems + pageSize - 1) / pageSize).floor();
  }
}
