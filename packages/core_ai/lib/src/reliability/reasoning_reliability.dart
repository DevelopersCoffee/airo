import 'package:meta/meta.dart';

/// WFGY-compatible diagnostic IDs. Classification only — never prompt text.
enum FailureMode {
  pm01HallucinationChunkDrift('PM-01'),
  pm02InterpretationCollapse('PM-02'),
  pm03LongChainDrift('PM-03'),
  pm04ConfidentNonsense('PM-04'),
  pm05SemanticEmbeddingMismatch('PM-05'),
  pm06LogicCollapse('PM-06'),
  pm07MemoryFailure('PM-07'),
  pm08BlackBox('PM-08'),
  pm09ContextCollapse('PM-09'),
  pm10CreativeFreeze('PM-10'),
  pm11SymbolicCollapse('PM-11'),
  pm12PhilosophicalRecursion('PM-12'),
  pm13MultiAgentChaos('PM-13'),
  pm14BootstrapOrdering('PM-14'),
  pm15DeploymentDeadlock('PM-15'),
  pm16PreDeployCollapse('PM-16');

  const FailureMode(this.id);
  final String id;

  static FailureMode? fromId(String id) {
    for (final mode in values) {
      if (mode.id == id) return mode;
    }
    return null;
  }
}

enum RuntimeFailure {
  r01ContextCompiler('AIRO-R01'),
  r02MemoryConflict('AIRO-R02'),
  r03ToolAuthorization('AIRO-R03'),
  r04SchemaViolation('AIRO-R04'),
  r05StateMachineViolation('AIRO-R05'),
  r06VerificationFailure('AIRO-R06'),
  r07ModelAdapter('AIRO-R07'),
  r08Timeout('AIRO-R08'),
  r09DeviceResourcePressure('AIRO-R09');

  const RuntimeFailure(this.id);
  final String id;

  static RuntimeFailure? fromId(String id) {
    for (final failure in values) {
      if (failure.id == id) return failure;
    }
    return null;
  }
}

enum RecoveryAction {
  retry,
  reRetrieve,
  rerank,
  rebuildContext,
  reinterpretIntent,
  replan,
  validateWithTool,
  askUser,
  abort,
}

/// User-facing copy. Never includes PM codes, prompts, or chain-of-thought.
@immutable
class ReliabilityUserMessage {
  const ReliabilityUserMessage({required this.user, this.developer});

  final String user;
  final String? developer;

  static ReliabilityUserMessage fromFailure({
    required FailureMode mode,
    RuntimeFailure? runtimeError,
    RecoveryAction? recovery,
    bool developerMode = false,
  }) {
    final user = switch (mode) {
      FailureMode.pm01HallucinationChunkDrift ||
      FailureMode.pm05SemanticEmbeddingMismatch =>
        'I found conflicting information. I\'m checking the original source.',
      FailureMode.pm02InterpretationCollapse =>
        'I need a bit more detail before I continue.',
      FailureMode.pm07MemoryFailure =>
        'I found conflicting saved information. I\'m checking which is current.',
      FailureMode.pm04ConfidentNonsense
          when runtimeError == RuntimeFailure.r03ToolAuthorization =>
        'I can only report tools I actually ran.',
      FailureMode.pm04ConfidentNonsense =>
        'I couldn\'t verify that yet, so I\'m not going to guess.',
      FailureMode.pm08BlackBox ||
      FailureMode.pm06LogicCollapse ||
      FailureMode.pm11SymbolicCollapse =>
        'I couldn\'t verify that result, so I\'m not going to guess.',
      _ => 'I couldn\'t complete that safely. Please try again or rephrase.',
    };
    if (!developerMode) {
      return ReliabilityUserMessage(user: user);
    }
    return ReliabilityUserMessage(
      user: user,
      developer:
          'Failure: ${mode.id}'
          '${runtimeError == null ? '' : ' ${runtimeError.id}'}'
          '${recovery == null ? '' : ' Recovery: ${recovery.name}'}',
    );
  }
}

/// Tool-claim guard used by the Dart skill loop until the Rust classifier
/// is on the chat FFI path. Matches AIRO-R03 / PM-04.
abstract final class ToolAuthorityGuard {
  static final _claim = RegExp(
    r"\bi (?:checked|looked(?:\s+up)?|queried|searched|opened) (?:your |the )?(?:calendar|schedule)\b",
    caseSensitive: false,
  );

  static bool claimsToolExecution(String message) => _claim.hasMatch(message);

  static bool toolWasExecuted({
    required Iterable<String> executedTools,
    required String toolHint,
  }) {
    final needle = toolHint.toLowerCase();
    return executedTools.any((tool) => tool.toLowerCase().contains(needle));
  }

  /// Null when the claim is allowed. Otherwise a user-safe refusal.
  static String? denyUngroundedClaim({
    required String message,
    required Iterable<String> executedTools,
    String toolHint = 'calendar',
  }) {
    if (!claimsToolExecution(message)) return null;
    if (toolWasExecuted(executedTools: executedTools, toolHint: toolHint)) {
      return null;
    }
    return ReliabilityUserMessage.fromFailure(
      mode: FailureMode.pm04ConfidentNonsense,
      runtimeError: RuntimeFailure.r03ToolAuthorization,
      recovery: RecoveryAction.abort,
    ).user;
  }
}

/// Lexical vs embedding scores for one meeting hit. Cosine similarity is not
/// proof of relevance — [failureMode] is PM-05 when they diverge.
@immutable
class RetrievalAlignment {
  const RetrievalAlignment({
    required this.meetingId,
    required this.keywordMatched,
    this.semanticScore,
  });

  final String meetingId;
  final bool keywordMatched;
  final double? semanticScore;

  /// 1.0 when keyword search hit this meeting; 0.0 for semantic-only.
  double get retrievalScore => keywordMatched ? 1.0 : 0.0;

  bool get isMismatch =>
      keywordMatched && semanticScore != null && semanticScore! < 0.5;

  FailureMode? get failureMode =>
      isMismatch ? FailureMode.pm05SemanticEmbeddingMismatch : null;
}

/// Skill/JSON output contract. Parse failures are AIRO-R04, not Flutter crashes.
abstract final class OutputSchemaGuard {
  static String userMessage() => ReliabilityUserMessage.fromFailure(
    mode: FailureMode.pm11SymbolicCollapse,
    runtimeError: RuntimeFailure.r04SchemaViolation,
    recovery: RecoveryAction.retry,
  ).user;
}

/// Post-model completion check. Empty or ungrounded output is not success.
enum OutputVerification { passed, failed, incomplete }

abstract final class ChatOutputVerifier {
  static OutputVerification verify({
    required String output,
    Iterable<String> executedTools = const [],
  }) {
    if (output.trim().isEmpty) return OutputVerification.incomplete;
    if (ToolAuthorityGuard.denyUngroundedClaim(
          message: output,
          executedTools: executedTools,
        ) !=
        null) {
      return OutputVerification.failed;
    }
    return OutputVerification.passed;
  }

  static String? userMessageFor(OutputVerification verification) {
    return switch (verification) {
      OutputVerification.passed => null,
      OutputVerification.incomplete ||
      OutputVerification.failed => ReliabilityUserMessage.fromFailure(
        mode: FailureMode.pm08BlackBox,
        runtimeError: RuntimeFailure.r06VerificationFailure,
        recovery: RecoveryAction.abort,
      ).user,
    };
  }
}
