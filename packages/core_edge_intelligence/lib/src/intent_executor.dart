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
  const IntentExecutionCompleted({required this.resultCount});

  final int resultCount;
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
