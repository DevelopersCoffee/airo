import 'package:meta/meta.dart';

enum AddonEvaluationKind {
  valid,
  invalid,
  retry,
  clarificationRequired,
  modelUnavailable,
}

@immutable
class AddonEvaluation {
  const AddonEvaluation({
    required this.kind,
    this.reason = '',
    this.safeCopy = '',
  });

  final AddonEvaluationKind kind;
  final String reason;
  final String safeCopy;

  bool get isValid => kind == AddonEvaluationKind.valid;
  bool get wantsRetry => kind == AddonEvaluationKind.retry;
}
