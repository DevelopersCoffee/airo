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
