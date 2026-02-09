import 'package:equatable/equatable.dart';
import 'media_category.dart';
import 'media_mode.dart';
import 'unified_media_content.dart';

/// Discovery/browse state for content exploration
class DiscoveryState extends Equatable {
  /// Current media mode (Music/TV)
  final MediaMode currentMode;

  /// Selected category for filtering (null = all)
  final MediaCategory? selectedCategory;

  /// All content items
  final List<UnifiedMediaContent> contentItems;

  /// Loading state
  final bool isLoading;

  /// Error message if any
  final String? errorMessage;

  /// Current search query
  final String? searchQuery;

  /// Whether more content is available (pagination)
  final bool hasMore;

  /// Pagination cursor/offset
  final String? nextCursor;

  const DiscoveryState({
    this.currentMode = MediaMode.music,
    this.selectedCategory,
    this.contentItems = const [],
    this.isLoading = false,
    this.errorMessage,
    this.searchQuery,
    this.hasMore = true,
    this.nextCursor,
  });

  /// Get available categories for current mode
  List<MediaCategory> get availableCategories =>
      MediaCategories.forMode(currentMode);

  /// Filtered content based on selected category
  List<UnifiedMediaContent> get filteredContent {
    if (selectedCategory == null) return contentItems;
    return contentItems
        .where((c) => c.category?.id == selectedCategory!.id)
        .toList();
  }

  /// Content filtered by current mode
  List<UnifiedMediaContent> get modeFilteredContent {
    return contentItems.where((c) => c.type == currentMode).toList();
  }

  /// Check if currently searching
  bool get isSearching =>
      searchQuery != null && searchQuery!.isNotEmpty;

  /// Check if has error
  bool get hasError => errorMessage != null;

  /// Check if content is empty
  bool get isEmpty => contentItems.isEmpty && !isLoading;

  DiscoveryState copyWith({
    MediaMode? currentMode,
    MediaCategory? selectedCategory,
    List<UnifiedMediaContent>? contentItems,
    bool? isLoading,
    String? errorMessage,
    String? searchQuery,
    bool? hasMore,
    String? nextCursor,
    bool clearCategory = false,
    bool clearError = false,
    bool clearSearch = false,
  }) {
    return DiscoveryState(
      currentMode: currentMode ?? this.currentMode,
      selectedCategory:
          clearCategory ? null : (selectedCategory ?? this.selectedCategory),
      contentItems: contentItems ?? this.contentItems,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      searchQuery: clearSearch ? null : (searchQuery ?? this.searchQuery),
      hasMore: hasMore ?? this.hasMore,
      nextCursor: nextCursor ?? this.nextCursor,
    );
  }

  @override
  List<Object?> get props => [
        currentMode,
        selectedCategory,
        contentItems,
        isLoading,
        errorMessage,
        searchQuery,
        hasMore,
        nextCursor,
      ];
}

