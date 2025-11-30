/// Sealed result type for functional error handling
sealed class Result<T> {
  const Result();

  /// Map the success value to another type
  Result<U> map<U>(U Function(T) fn) => switch (this) {
    Ok(value: final v) => Ok(fn(v)),
    Err(error: final e, stack: final s) => Err(e, s),
  };

  /// Flat map (bind) for chaining operations
  Result<U> flatMap<U>(Result<U> Function(T) fn) => switch (this) {
    Ok(value: final v) => fn(v),
    Err(error: final e, stack: final s) => Err(e, s),
  };

  /// Get the value or null
  T? getOrNull() => switch (this) {
    Ok(value: final v) => v,
    Err() => null,
  };

  /// Get the error or null
  Object? getErrorOrNull() => switch (this) {
    Ok() => null,
    Err(error: final e) => e,
  };

  /// Fold into a single value
  U fold<U>(U Function(Object, StackTrace) onError, U Function(T) onSuccess) =>
      switch (this) {
        Ok(value: final v) => onSuccess(v),
        Err(error: final e, stack: final s) => onError(e, s),
      };

  /// Execute side effect on success
  Result<T> tap(void Function(T) fn) {
    if (this is Ok<T>) {
      fn((this as Ok<T>).value);
    }
    return this;
  }

  /// Execute side effect on error
  Result<T> tapError(void Function(Object, StackTrace) fn) {
    if (this is Err<T>) {
      final err = this as Err<T>;
      fn(err.error, err.stack);
    }
    return this;
  }

  /// Check if result is success
  bool get isOk => this is Ok<T>;

  /// Check if result is error
  bool get isErr => this is Err<T>;
}

/// Success result
class Ok<T> extends Result<T> {
  final T value;

  const Ok(this.value);

  @override
  String toString() => 'Ok($value)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Ok<T> &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;
}

/// Error result
class Err<T> extends Result<T> {
  final Object error;
  final StackTrace stack;

  const Err(this.error, this.stack);

  @override
  String toString() => 'Err($error)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Err<T> &&
          runtimeType == other.runtimeType &&
          error == other.error;

  @override
  int get hashCode => error.hashCode;
}

/// Extension for easier Result creation
extension ResultExt<T> on T {
  Result<T> toOk() => Ok(this);
}

/// Extension for Future to Result conversion
extension FutureResultExt<T> on Future<T> {
  Future<Result<T>> toResult() async {
    try {
      return Ok(await this);
    } catch (e, s) {
      return Err(e, s);
    }
  }
}

