/// State for paginated data loading.
class PaginatedState<T> {
  final List<T> items;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final int page;
  final int? totalItems;
  final Object? error;

  PaginatedState({
    List<T>? items,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.page = 0,
    this.totalItems,
    this.error,
  }) : items = items ?? <T>[];

  /// Create initial state.
  factory PaginatedState.initial() => PaginatedState<T>();

  /// Create loading state (first page).
  factory PaginatedState.loading() => PaginatedState<T>(isLoading: true);

  /// Check if empty (no items and not loading).
  bool get isEmpty => items.isEmpty && !isLoading && !isLoadingMore;

  /// Check if has error.
  bool get hasError => error != null;

  /// Get item count.
  int get itemCount => items.length;

  /// Copy with new values.
  PaginatedState<T> copyWith({
    List<T>? items,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? page,
    int? totalItems,
    Object? error,
    bool clearError = false,
  }) {
    return PaginatedState<T>(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      page: page ?? this.page,
      totalItems: totalItems ?? this.totalItems,
      error: clearError ? null : (error ?? this.error),
    );
  }

  /// Start loading first page.
  PaginatedState<T> startLoading() {
    return copyWith(isLoading: true, clearError: true);
  }

  /// Start loading more items.
  PaginatedState<T> startLoadingMore() {
    return copyWith(isLoadingMore: true, clearError: true);
  }

  /// Set loaded data for first page.
  PaginatedState<T> setData(
    List<T> newItems, {
    bool hasMore = true,
    int? totalItems,
  }) {
    return copyWith(
      items: newItems,
      isLoading: false,
      isLoadingMore: false,
      hasMore: hasMore,
      page: 1,
      totalItems: totalItems,
      clearError: true,
    );
  }

  /// Append more items.
  PaginatedState<T> appendData(List<T> moreItems, {bool hasMore = true}) {
    return copyWith(
      items: [...items, ...moreItems],
      isLoading: false,
      isLoadingMore: false,
      hasMore: hasMore,
      page: page + 1,
    );
  }

  /// Set error state.
  PaginatedState<T> setError(Object error) {
    return copyWith(isLoading: false, isLoadingMore: false, error: error);
  }

  /// Add item to the beginning.
  PaginatedState<T> prependItem(T item) {
    return copyWith(
      items: [item, ...items],
      totalItems: totalItems != null ? totalItems! + 1 : null,
    );
  }

  /// Add item to the end.
  PaginatedState<T> appendItem(T item) {
    return copyWith(
      items: [...items, item],
      totalItems: totalItems != null ? totalItems! + 1 : null,
    );
  }

  /// Remove item by predicate.
  PaginatedState<T> removeWhere(bool Function(T item) test) {
    final newItems = items.where((item) => !test(item)).toList();
    return copyWith(
      items: newItems,
      totalItems: totalItems != null
          ? totalItems! - (items.length - newItems.length)
          : null,
    );
  }

  /// Update item by predicate.
  PaginatedState<T> updateWhere(
    bool Function(T item) test,
    T Function(T item) update,
  ) {
    return copyWith(
      items: items.map((item) => test(item) ? update(item) : item).toList(),
    );
  }

  /// Refresh (clear and reload).
  PaginatedState<T> refresh() {
    return PaginatedState<T>.loading();
  }
}
