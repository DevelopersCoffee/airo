import 'package:core_domain/src/value_objects/failure.dart' as failures;

/// Type alias for the base Failure class from failure.dart
typedef BaseFailure = failures.Failure;

/// Sealed result type for functional error handling
///
/// Supports both Ok/Err pattern and Success/Failure pattern for compatibility.
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

  /// Fold into a single value (Ok/Err pattern - positional args)
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

  /// Check if result is success (Ok/Err pattern)
  bool get isOk => this is Ok<T>;

  /// Check if result is error (Ok/Err pattern)
  bool get isErr => this is Err<T>;

  // === Compatibility with Success/Failure pattern ===

  /// Check if result is success (Success/Failure pattern - alias for isOk)
  bool get isSuccess => isOk;

  /// Check if result is failure (Success/Failure pattern - alias for isErr)
  bool get isFailure => isErr;

  /// Gets the success value or throws if this is a failure
  T get value {
    return switch (this) {
      Ok(value: final v) => v,
      Err(error: final e) => throw StateError(
        'Cannot get value from error: $e',
      ),
    };
  }

  /// Gets the failure or throws if this is a success
  BaseFailure get failure {
    return switch (this) {
      Ok() => throw StateError('Cannot get failure from success'),
      Err(error: final e) =>
        e is BaseFailure
            ? e
            : failures.UnexpectedFailure(message: e.toString(), cause: e),
    };
  }

  /// Gets the success value or null if this is a failure (alias for getOrNull)
  T? get valueOrNull => getOrNull();
}

/// Success result (also aliased as Success)
class Ok<T> extends Result<T> {
  @override
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

/// Error result (also aliased as Failure)
class Err<T> extends Result<T> {
  final Object error;
  final StackTrace stack;

  const Err(this.error, this.stack);

  /// Create an Err from a BaseFailure (for Success/Failure pattern compatibility)
  const Err.fromFailure(BaseFailure failure)
    : error = failure,
      stack = StackTrace.empty;

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

/// Type alias for Success/Failure pattern compatibility
/// Usage: `return Success(value)` is equivalent to `return Ok(value)`
typedef Success<T> = Ok<T>;

/// Type alias for Failure pattern - wraps a BaseFailure in an Err
/// Usage: `return Failure(someFailure)` creates an Err with that failure
class Failure<T> extends Err<T> {
  /// The failure wrapped in this result
  @override
  BaseFailure get failure => error as BaseFailure;

  /// Create a Failure result from a BaseFailure
  const Failure(BaseFailure failure) : super(failure, StackTrace.empty);
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
