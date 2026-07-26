import 'intent_command.dart';

/// Implemented outside intelligence and player packages to preserve the
/// dependency boundary enforced by `scripts/check-edge-import-boundaries.py`.
abstract interface class IntentExecutor {
  Future<IntentExecutionResult> execute(IntentCommand command);
}

sealed class IntentExecutionResult {
  const IntentExecutionResult();
}

final class IntentExecutionCompleted extends IntentExecutionResult {
  IntentExecutionCompleted({required Iterable<String> resultIds})
    : resultIds = List.unmodifiable(resultIds);

  /// Stable media identifiers selected by the application-owned executor.
  ///
  /// Identifiers keep intelligence outside the playback dependency graph.
  final List<String> resultIds;

  int get resultCount => resultIds.length;
}

final class IntentExecutionRejected extends IntentExecutionResult {
  const IntentExecutionRejected({required this.code, required this.message});

  final String code;
  final String message;
}

final class IntentExecutionFailed extends IntentExecutionResult {
  const IntentExecutionFailed({required this.code});

  /// Stable, non-sensitive failure code. Raw exceptions and media URLs must
  /// not cross this boundary.
  final String code;
}
