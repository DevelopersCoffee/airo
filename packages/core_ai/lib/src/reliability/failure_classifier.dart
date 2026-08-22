import 'package:meta/meta.dart';

import 'reasoning_reliability.dart';

/// In-process diagnostic. Never includes prompt or completion text.
@immutable
class PersistableDiagnostic {
  const PersistableDiagnostic({
    required this.executionId,
    this.failureMode,
    this.runtimeError,
  });

  final String executionId;
  final FailureMode? failureMode;
  final RuntimeFailure? runtimeError;
}

/// Bounded in-process checkpoint log. Mirror of Rust `ExecutionLog`.
///
/// Not an operation-log writer (ADR-0023). Process death drops the ring.
class ExecutionLog {
  ExecutionLog({this.capacity = 32});

  final int capacity;
  final List<PersistableDiagnostic> _checkpoints = [];

  void record(PersistableDiagnostic? diagnostic) {
    if (diagnostic == null) return;
    _checkpoints.add(diagnostic);
    if (_checkpoints.length > capacity) {
      _checkpoints.removeRange(0, _checkpoints.length - capacity);
    }
  }

  List<PersistableDiagnostic> get checkpoints =>
      List<PersistableDiagnostic>.unmodifiable(_checkpoints);

  PersistableDiagnostic? get last =>
      _checkpoints.isEmpty ? null : _checkpoints.last;

  PersistableDiagnostic? get lastFailure {
    for (var i = _checkpoints.length - 1; i >= 0; i--) {
      if (_checkpoints[i].failureMode != null) return _checkpoints[i];
    }
    return null;
  }

  bool get isEmpty => _checkpoints.isEmpty;
}

/// Dart mirror of `record_chat_completion` for Cloud / LiteRT / Gemini.
/// No new FFI events.
abstract final class FailureClassifier {
  static PersistableDiagnostic? recordChatCompletion({
    required String executionId,
    required String text,
    required bool engineOk,
  }) {
    if (!engineOk) {
      return PersistableDiagnostic(
        executionId: executionId,
        failureMode: FailureMode.pm08BlackBox,
        runtimeError: RuntimeFailure.r07ModelAdapter,
      );
    }
    if (text.trim().isEmpty) {
      return PersistableDiagnostic(
        executionId: executionId,
        failureMode: FailureMode.pm06LogicCollapse,
        runtimeError: RuntimeFailure.r06VerificationFailure,
      );
    }
    return null;
  }
}
