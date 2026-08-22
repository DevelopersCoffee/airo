import 'package:meta/meta.dart';

import 'reasoning_reliability.dart';

/// Retry / reread / replan budgets. The model cannot mark recovery successful.
@immutable
class RecoveryPolicy {
  const RecoveryPolicy({
    this.maxRetries = 2,
    this.maxRereads = 2,
    this.maxReplans = 2,
    this.maxToolCalls = 8,
  });

  final int maxRetries;
  final int maxRereads;
  final int maxReplans;
  final int maxToolCalls;

  /// Skill JSON parse: one retry, then schema-invalid. Matches the live client.
  static const skillJson = RecoveryPolicy(maxRetries: 1);
}

@immutable
class AttemptCounts {
  const AttemptCounts({
    this.retries = 0,
    this.rereads = 0,
    this.replans = 0,
    this.toolCalls = 0,
  });

  final int retries;
  final int rereads;
  final int replans;
  final int toolCalls;

  AttemptCounts copyWith({
    int? retries,
    int? rereads,
    int? replans,
    int? toolCalls,
  }) {
    return AttemptCounts(
      retries: retries ?? this.retries,
      rereads: rereads ?? this.rereads,
      replans: replans ?? this.replans,
      toolCalls: toolCalls ?? this.toolCalls,
    );
  }
}

enum RecoveryDecision { execute, abort }

/// Dart mirror of `airo_mind_reliability::RecoveryEngine` for Flutter seams
/// that have not yet crossed FFI.
class RecoveryEngine {
  RecoveryEngine([this.policy = const RecoveryPolicy()]);

  final RecoveryPolicy policy;
  AttemptCounts _attempts = const AttemptCounts();

  AttemptCounts get attempts => _attempts;

  RecoveryDecision select(RecoveryAction action) {
    if (action == RecoveryAction.abort || _exhausted(action)) {
      return RecoveryDecision.abort;
    }
    return RecoveryDecision.execute;
  }

  /// Record that the runtime performed [action]. Does not mean it succeeded.
  void noteAttempt(RecoveryAction action) {
    switch (action) {
      case RecoveryAction.retry:
        _attempts = _attempts.copyWith(retries: _attempts.retries + 1);
      case RecoveryAction.reRetrieve || RecoveryAction.rerank:
        _attempts = _attempts.copyWith(rereads: _attempts.rereads + 1);
      case RecoveryAction.replan || RecoveryAction.reinterpretIntent:
        _attempts = _attempts.copyWith(replans: _attempts.replans + 1);
      case RecoveryAction.validateWithTool:
        _attempts = _attempts.copyWith(toolCalls: _attempts.toolCalls + 1);
      case RecoveryAction.rebuildContext ||
          RecoveryAction.askUser ||
          RecoveryAction.abort:
        break;
    }
  }

  bool _exhausted(RecoveryAction action) {
    return switch (action) {
      RecoveryAction.retry => _attempts.retries >= policy.maxRetries,
      RecoveryAction.reRetrieve ||
      RecoveryAction.rerank => _attempts.rereads >= policy.maxRereads,
      RecoveryAction.replan || RecoveryAction.reinterpretIntent =>
        _attempts.replans >= policy.maxReplans,
      RecoveryAction.validateWithTool =>
        _attempts.toolCalls >= policy.maxToolCalls,
      RecoveryAction.rebuildContext || RecoveryAction.askUser => false,
      RecoveryAction.abort => true,
    };
  }
}
