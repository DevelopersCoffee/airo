/// Base async state class for consistent state management.
///
/// Represents the four common states of async operations:
/// - Initial: Not yet started
/// - Loading: In progress
/// - Data: Successfully completed with data
/// - Error: Failed with error
sealed class AsyncState<T> {
  const AsyncState();

  /// Create initial state.
  factory AsyncState.initial() = AsyncInitial<T>;

  /// Create loading state.
  factory AsyncState.loading({T? previousData}) {
    return AsyncLoading<T>(previousData: previousData);
  }

  /// Create data state.
  factory AsyncState.data(T data) = AsyncData<T>;

  /// Create error state.
  factory AsyncState.error(Object error, {StackTrace? stackTrace, T? previousData}) {
    return AsyncError<T>(error, stackTrace: stackTrace, previousData: previousData);
  }

  /// Check if in initial state.
  bool get isInitial => this is AsyncInitial<T>;

  /// Check if loading.
  bool get isLoading => this is AsyncLoading<T>;

  /// Check if has data.
  bool get hasData => this is AsyncData<T>;

  /// Check if has error.
  bool get hasError => this is AsyncError<T>;

  /// Get data if available.
  T? get dataOrNull => switch (this) {
        AsyncData<T>(data: final d) => d,
        AsyncLoading<T>(previousData: final d) => d,
        AsyncError<T>(previousData: final d) => d,
        _ => null,
      };

  /// Get error if available.
  Object? get errorOrNull => switch (this) {
        AsyncError<T>(error: final e) => e,
        _ => null,
      };

  /// Map the data to a new type.
  AsyncState<R> map<R>(R Function(T data) mapper) {
    return switch (this) {
      AsyncInitial<T>() => AsyncState<R>.initial(),
      AsyncLoading<T>(previousData: final d) => AsyncState<R>.loading(
          previousData: d != null ? mapper(d) : null,
        ),
      AsyncData<T>(data: final d) => AsyncState<R>.data(mapper(d)),
      AsyncError<T>(error: final e, stackTrace: final s, previousData: final d) =>
        AsyncState<R>.error(e, stackTrace: s, previousData: d != null ? mapper(d) : null),
    };
  }

  /// Execute a function based on the current state.
  R when<R>({
    required R Function() initial,
    required R Function(T? previousData) loading,
    required R Function(T data) data,
    required R Function(Object error, StackTrace? stackTrace, T? previousData) error,
  }) {
    return switch (this) {
      AsyncInitial<T>() => initial(),
      AsyncLoading<T>(previousData: final d) => loading(d),
      AsyncData<T>(data: final d) => data(d),
      AsyncError<T>(error: final e, stackTrace: final s, previousData: final d) =>
        error(e, s, d),
    };
  }

  /// Execute a function based on the current state with optional handlers.
  R maybeWhen<R>({
    R Function()? initial,
    R Function(T? previousData)? loading,
    R Function(T data)? data,
    R Function(Object error, StackTrace? stackTrace, T? previousData)? error,
    required R Function() orElse,
  }) {
    return switch (this) {
      AsyncInitial<T>() => initial?.call() ?? orElse(),
      AsyncLoading<T>(previousData: final d) => loading?.call(d) ?? orElse(),
      AsyncData<T>(data: final d) => data?.call(d) ?? orElse(),
      AsyncError<T>(error: final e, stackTrace: final s, previousData: final d) =>
        error?.call(e, s, d) ?? orElse(),
    };
  }
}

/// Initial state - operation not yet started.
class AsyncInitial<T> extends AsyncState<T> {
  const AsyncInitial();
}

/// Loading state - operation in progress.
class AsyncLoading<T> extends AsyncState<T> {
  final T? previousData;

  const AsyncLoading({this.previousData});
}

/// Data state - operation completed successfully.
class AsyncData<T> extends AsyncState<T> {
  final T data;

  const AsyncData(this.data);
}

/// Error state - operation failed.
class AsyncError<T> extends AsyncState<T> {
  final Object error;
  final StackTrace? stackTrace;
  final T? previousData;

  const AsyncError(this.error, {this.stackTrace, this.previousData});
}

