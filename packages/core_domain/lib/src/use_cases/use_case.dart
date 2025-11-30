import '../value_objects/result.dart';

/// Base interface for use cases.
///
/// Use cases encapsulate a single business operation and return
/// a [Result] to handle success and failure cases.
abstract class UseCase<Input, Output> {
  /// Executes the use case with the given input.
  Future<Result<Output>> call(Input input);
}

/// Use case that requires no input.
abstract class NoInputUseCase<Output> {
  /// Executes the use case.
  Future<Result<Output>> call();
}

/// Use case that returns no output (void operations).
abstract class NoOutputUseCase<Input> {
  /// Executes the use case with the given input.
  Future<Result<void>> call(Input input);
}

/// Use case that requires no input and returns no output.
abstract class VoidUseCase {
  /// Executes the use case.
  Future<Result<void>> call();
}

/// Synchronous use case variant.
abstract class SyncUseCase<Input, Output> {
  /// Executes the use case synchronously.
  Result<Output> call(Input input);
}

/// Streaming use case that returns a stream of results.
abstract class StreamUseCase<Input, Output> {
  /// Returns a stream of outputs.
  Stream<Output> call(Input input);
}

