import 'package:equatable/equatable.dart';

import 'media_category.dart';
import 'media_mode.dart';
import 'unified_media_content.dart';

class DiscoveryState extends Equatable {
  const DiscoveryState({
    required this.mode,
    required this.items,
    required this.visibleItems,
    required this.searchQuery,
    required this.selectedCategory,
    required this.currentPage,
    required this.pageSize,
    required this.filteredCount,
    required this.hasMore,
  });

  factory DiscoveryState.initial({
    required MediaMode mode,
    required List<UnifiedMediaContent> items,
    int pageSize = 12,
  }) {
    return DiscoveryState(
      mode: mode,
      items: List.unmodifiable(items),
      visibleItems: List.unmodifiable(items.take(pageSize)),
      searchQuery: '',
      selectedCategory: MediaCategory.all,
      currentPage: items.isEmpty ? 0 : 1,
      pageSize: pageSize,
      filteredCount: items.length,
      hasMore: items.length > pageSize,
    );
  }

  final MediaMode mode;
  final List<UnifiedMediaContent> items;
  final List<UnifiedMediaContent> visibleItems;
  final String searchQuery;
  final MediaCategory selectedCategory;
  final int currentPage;
  final int pageSize;
  final int filteredCount;
  final bool hasMore;

  DiscoveryState copyWith({
    MediaMode? mode,
    List<UnifiedMediaContent>? items,
    List<UnifiedMediaContent>? visibleItems,
    String? searchQuery,
    MediaCategory? selectedCategory,
    int? currentPage,
    int? pageSize,
    int? filteredCount,
    bool? hasMore,
  }) {
    return DiscoveryState(
      mode: mode ?? this.mode,
      items: items ?? this.items,
      visibleItems: visibleItems ?? this.visibleItems,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      currentPage: currentPage ?? this.currentPage,
      pageSize: pageSize ?? this.pageSize,
      filteredCount: filteredCount ?? this.filteredCount,
      hasMore: hasMore ?? this.hasMore,
    );
  }

  @override
  List<Object?> get props => [
    mode,
    items,
    visibleItems,
    searchQuery,
    selectedCategory,
    currentPage,
    pageSize,
    filteredCount,
    hasMore,
  ];
}
