import 'package:meta/meta.dart';

import 'failure.dart';

/// A Result type that represents either a success value or a failure.
///
/// This is a functional approach to error handling that avoids exceptions
/// for expected error cases.
@immutable
sealed class Result<T> {
  const Result();

  /// Returns true if this is a success result
  bool get isSuccess => this is Success<T>;

  /// Returns true if this is a failure result
  bool get isFailure => this is Failure<T>;

  /// Gets the success value or throws if this is a failure
  T get value {
    return switch (this) {
      Success<T>(:final value) => value,
      Failure<T>(:final failure) =>
        throw StateError('Cannot get value from failure: $failure'),
    };
  }

  /// Gets the failure or throws if this is a success
  Failure get failure {
    return switch (this) {
      Success<T>() => throw StateError('Cannot get failure from success'),
      Failure<T>(:final failure) => failure,
    };
  }

  /// Gets the success value or null if this is a failure
  T? get valueOrNull => switch (this) {
        Success<T>(:final value) => value,
        Failure<T>() => null,
      };

  /// Maps the success value using the provided function
  Result<R> map<R>(R Function(T value) mapper) => switch (this) {
        Success<T>(:final value) => Success(mapper(value)),
        Failure<T>(:final failure) => Failure(failure),
      };

  /// Flat maps the success value using the provided function
  Result<R> flatMap<R>(Result<R> Function(T value) mapper) => switch (this) {
        Success<T>(:final value) => mapper(value),
        Failure<T>(:final failure) => Failure(failure),
      };

  /// Executes the appropriate callback based on success or failure
  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(Failure failure) onFailure,
  }) =>
      switch (this) {
        Success<T>(:final value) => onSuccess(value),
        Failure<T>(:final failure) => onFailure(failure),
      };

  /// Executes side effect on success
  Result<T> onSuccess(void Function(T value) action) {
    if (this case Success<T>(:final value)) {
      action(value);
    }
    return this;
  }

  /// Executes side effect on failure
  Result<T> onFailure(void Function(Failure failure) action) {
    if (this case Failure<T>(:final failure)) {
      action(failure);
    }
    return this;
  }
}

/// Represents a successful result containing a value
@immutable
final class Success<T> extends Result<T> {
  const Success(this.value);

  @override
  final T value;

  @override
  String toString() => 'Success($value)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Success<T> && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

/// Represents a failed result containing a Failure
@immutable
final class Failure<T> extends Result<T> {
  const Failure(this.failure);

  @override
  final Failure failure;

  @override
  String toString() => 'Failure($failure)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Failure<T> && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;
}

