import 'package:meta/meta.dart';

import 'instruction_set.dart';
import 'reasoning_reliability.dart';

/// Prompt-defect taxonomy. Separate domain from [FailureMode] / [RuntimeFailure].
enum PromptDefect {
  spec001AmbiguousInstruction('PD-SPEC-001'),
  spec002UnderspecifiedConstraints('PD-SPEC-002'),
  spec003ConflictingInstructions('PD-SPEC-003'),
  spec004IntentMisalignment('PD-SPEC-004'),
  input001MisleadingContent('PD-INPUT-001'),
  input002PromptInjection('PD-INPUT-002'),
  input003PolicyViolatingInput('PD-INPUT-003'),
  input004CrossModalMisalignment('PD-INPUT-004'),
  struct001RoleSeparation('PD-STRUCT-001'),
  struct002PoorOrganization('PD-STRUCT-002'),
  struct003FormattingError('PD-STRUCT-003'),
  struct004UndefinedOutputFormat('PD-STRUCT-004'),
  struct005OverloadedPrompt('PD-STRUCT-005'),
  context001Overflow('PD-CONTEXT-001'),
  context002MissingContext('PD-CONTEXT-002'),
  context003NoisyContext('PD-CONTEXT-003'),
  context004Misreferencing('PD-CONTEXT-004'),
  context005ForgottenInstructions('PD-CONTEXT-005'),
  perf001ExcessiveLength('PD-PERF-001'),
  perf002InefficientFewShot('PD-PERF-002'),
  perf003NoPrefixCache('PD-PERF-003'),
  perf004UnboundedOutput('PD-PERF-004'),
  eng001HardCodedPrompt('PD-ENG-001'),
  eng002InsufficientTesting('PD-ENG-002'),
  eng003PoorDocumentation('PD-ENG-003'),
  eng004SecurityReviewGap('PD-ENG-004'),
  eng005IntegrationMismatch('PD-ENG-005');

  const PromptDefect(this.id);
  final String id;

  static PromptDefect? fromId(String id) {
    for (final defect in values) {
      if (defect.id == id) return defect;
    }
    return null;
  }
}

enum PromptGateDecision { allow, askUser, rebuildContext, abort }

/// Whether the active model adapter can reuse a static prompt prefix.
/// Adapter capability only — never required, never a new Mind primitive.
enum PrefixCacheCapability { unsupported, supported }

@immutable
class PromptGateReport {
  const PromptGateReport({
    required this.decision,
    required this.defects,
    required this.userMessage,
    this.recovery,
    this.warnings = const [],
  });

  final PromptGateDecision decision;
  final List<PromptDefect> defects;
  final String userMessage;
  final RecoveryAction? recovery;

  /// Compiled-prompt issues (system vs user, product-prompt polarity).
  /// Never included in [defects], never changes [decision].
  final List<PromptDefect> warnings;

  bool get blocksInference =>
      decision == PromptGateDecision.askUser ||
      decision == PromptGateDecision.abort;

  bool get needsContextRebuild => decision == PromptGateDecision.rebuildContext;
}

/// Pre-inference prompt quality gate. Mirrors `airo_mind_reliability::PromptQualityGate`
/// for Dart paths that have not yet crossed FFI.
abstract final class PromptQualityGate {
  static final _injection = RegExp(
    r'ignore (all )?(previous|prior|above) instructions|reveal the (system|hidden) prompt|disregard the system',
    caseSensitive: false,
  );

  static const _ambiguous = {
    'make it better',
    'make this better',
    'make that better',
    'make my code better',
    'improve it',
    'improve this',
    'improve that',
    'improve my code',
    'improve the code',
    'fix it',
    'fix this',
    'fix that',
    'optimize it',
    'optimize this',
    'optimize that',
    'do it',
    'do that',
    'book that one',
    'generate test cases',
    'generate tests',
    'write tests',
    'write a summary',
    'summarize this',
  };

  static const _dangling = {
    'that one',
    'do it',
    'do that',
    'the other one',
    'book that one',
  };

  static const prefixCacheWarnTokens = 256;

  static PromptGateReport inspectUserTurn({
    required String userText,
    bool historyEmpty = true,
    int estimatedTokens = 0,
    int modelContextLimit = 0,
    int outputBudget = 256,
    bool requiresStructuredOutput = false,
    String outputContract = '',
    PrefixCacheCapability prefixCache = PrefixCacheCapability.unsupported,
    int cacheablePrefixTokens = 0,
  }) {
    final normalized = _normalize(userText);
    final defects = <PromptDefect>[];

    if (_injection.hasMatch(userText)) {
      defects.add(PromptDefect.input002PromptInjection);
    }
    if (_ambiguous.contains(normalized)) {
      defects.add(PromptDefect.spec001AmbiguousInstruction);
      defects.add(PromptDefect.spec002UnderspecifiedConstraints);
    }
    if (historyEmpty &&
        (_dangling.contains(normalized) || normalized.contains('that one'))) {
      defects.add(PromptDefect.context004Misreferencing);
    }
    if (requiresStructuredOutput && outputContract.trim().isEmpty) {
      defects.add(PromptDefect.struct004UndefinedOutputFormat);
    }
    if (modelContextLimit > 0 &&
        estimatedTokens + outputBudget > modelContextLimit) {
      defects.add(PromptDefect.perf001ExcessiveLength);
      defects.add(PromptDefect.context001Overflow);
    }
    if (prefixCache == PrefixCacheCapability.unsupported &&
        cacheablePrefixTokens > prefixCacheWarnTokens) {
      defects.add(PromptDefect.perf003NoPrefixCache);
    }
    if (_hasUnsatisfiablePolarity(userText)) {
      defects.add(PromptDefect.spec003ConflictingInstructions);
    }

    final decision = _decide(defects);
    final recovery = switch (decision) {
      PromptGateDecision.allow => null,
      PromptGateDecision.askUser => RecoveryAction.askUser,
      PromptGateDecision.rebuildContext => RecoveryAction.rebuildContext,
      PromptGateDecision.abort => RecoveryAction.abort,
    };
    return PromptGateReport(
      decision: decision,
      defects: defects,
      recovery: recovery,
      userMessage: _userCopy(defects),
    );
  }

  /// User-turn gate plus compiled system/task/output analysis.
  ///
  /// Cross-layer conflicts and compiled-system unsatisfiable polarity are
  /// [PromptGateReport.warnings] only — they must not block an allow-path.
  static PromptGateReport inspectLivePrompt({
    required String userText,
    String systemPrompt = '',
    String taskInstructions = '',
    String outputContract = '',
    bool historyEmpty = true,
    int estimatedTokens = 0,
    int modelContextLimit = 0,
    int outputBudget = 256,
    bool requiresStructuredOutput = false,
    PrefixCacheCapability prefixCache = PrefixCacheCapability.unsupported,
    int cacheablePrefixTokens = 0,
  }) {
    final userReport = inspectUserTurn(
      userText: userText,
      historyEmpty: historyEmpty,
      estimatedTokens: estimatedTokens,
      modelContextLimit: modelContextLimit,
      outputBudget: outputBudget,
      requiresStructuredOutput: requiresStructuredOutput,
      outputContract: outputContract,
      prefixCache: prefixCache,
      cacheablePrefixTokens: cacheablePrefixTokens,
    );
    final warnings = InstructionSet.fromLayers(
      system: systemPrompt,
      task: taskInstructions,
      user: userText,
      output: outputContract,
    ).compiledWarnings(hasAcceptanceCriteria: outputContract.trim().isNotEmpty);
    if (warnings.isEmpty) return userReport;
    final seen = <PromptDefect>{};
    final unique = <PromptDefect>[];
    for (final issue in warnings) {
      if (seen.add(issue.defect)) unique.add(issue.defect);
    }
    return PromptGateReport(
      decision: userReport.decision,
      defects: userReport.defects,
      recovery: userReport.recovery,
      userMessage: userReport.userMessage,
      warnings: unique,
    );
  }

  static String _userCopy(List<PromptDefect> defects) {
    if (defects.contains(PromptDefect.input002PromptInjection)) {
      return "I can't follow instructions that try to override how I work.";
    }
    if (defects.contains(PromptDefect.context001Overflow) ||
        defects.contains(PromptDefect.perf001ExcessiveLength)) {
      return 'I need to narrow the context before I continue.';
    }
    if (defects.contains(PromptDefect.spec001AmbiguousInstruction) ||
        defects.contains(PromptDefect.spec002UnderspecifiedConstraints) ||
        defects.contains(PromptDefect.spec003ConflictingInstructions) ||
        defects.contains(PromptDefect.context002MissingContext) ||
        defects.contains(PromptDefect.context004Misreferencing) ||
        defects.contains(PromptDefect.struct004UndefinedOutputFormat)) {
      return 'I need a bit more detail before I continue.';
    }
    return '';
  }

  static PromptGateDecision _decide(List<PromptDefect> defects) {
    if (defects.contains(PromptDefect.input002PromptInjection) ||
        defects.contains(PromptDefect.input003PolicyViolatingInput) ||
        defects.contains(PromptDefect.eng005IntegrationMismatch)) {
      return PromptGateDecision.abort;
    }
    if (defects.contains(PromptDefect.spec001AmbiguousInstruction) ||
        defects.contains(PromptDefect.spec002UnderspecifiedConstraints) ||
        defects.contains(PromptDefect.spec003ConflictingInstructions) ||
        defects.contains(PromptDefect.context002MissingContext) ||
        defects.contains(PromptDefect.context004Misreferencing) ||
        defects.contains(PromptDefect.struct004UndefinedOutputFormat)) {
      return PromptGateDecision.askUser;
    }
    if (defects.contains(PromptDefect.context001Overflow) ||
        defects.contains(PromptDefect.perf001ExcessiveLength)) {
      return PromptGateDecision.rebuildContext;
    }
    return PromptGateDecision.allow;
  }

  static String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .join(' ');
  }

  static bool _hasUnsatisfiablePolarity(String userText) {
    final text = userText.toLowerCase();
    return _axisConflict(
          text,
          const ['be brief', 'concise', 'one sentence', 'short answer'],
          const [
            'extensive detail',
            'be detailed',
            'comprehensive',
            'as much detail',
          ],
        ) ||
        _axisConflict(
          text,
          const ['json only', 'respond in json', 'output json', 'return json'],
          const [
            'markdown only',
            'respond in markdown',
            'output markdown',
            'explain this normally',
            'explain normally',
            'in prose',
          ],
        );
  }

  static bool _axisConflict(
    String text,
    List<String> left,
    List<String> right,
  ) {
    return left.any(text.contains) && right.any(text.contains);
  }
}
