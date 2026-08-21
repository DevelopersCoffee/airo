import 'package:meta/meta.dart';

import 'prompt_reliability.dart';

/// Versioned prompt artifact. Prompts are not anonymous strings.
@immutable
class RegisteredPrompt {
  const RegisteredPrompt({
    required this.id,
    required this.version,
    required this.taskType,
    this.outputSchema = '',
    this.hasEvalSuite = false,
    this.hasSecurityPolicy = true,
    this.documented = true,
  });

  final String id;
  final String version;
  final String taskType;
  final String outputSchema;
  final bool hasEvalSuite;
  final bool hasSecurityPolicy;
  final bool documented;

  bool get isRegistered => id.isNotEmpty && version.isNotEmpty;

  String get qualifiedId => '$id.v$version';
}

/// Central catalog. Chat, skills, and evals look up these ids instead of
/// scattering hard-coded prompt literals without a version.
abstract final class AiroPromptRegistry {
  static const chatAssistant = RegisteredPrompt(
    id: 'chat.assistant',
    version: '1',
    taskType: 'chat',
    hasEvalSuite: true,
  );

  static const skillSelect = RegisteredPrompt(
    id: 'skill.select',
    version: '1',
    taskType: 'skill',
    outputSchema: '{"skill_id":""}',
    hasEvalSuite: true,
  );

  static const skillNextAction = RegisteredPrompt(
    id: 'skill.next_action',
    version: '1',
    taskType: 'skill',
    outputSchema: '{"type":"tool_call|final"}',
    hasEvalSuite: true,
  );

  static const notebookSuperSummary = RegisteredPrompt(
    id: 'notebook.super_summary',
    version: '1',
    taskType: 'summary',
    outputSchema: '# Summary\n# Key points',
    hasEvalSuite: true,
  );

  static const meetingMinutes = RegisteredPrompt(
    id: 'meeting.minutes',
    version: '1',
    taskType: 'minutes',
    outputSchema: 'Markdown',
    hasEvalSuite: true,
  );

  static const all = <RegisteredPrompt>[
    chatAssistant,
    skillSelect,
    skillNextAction,
    notebookSuperSummary,
    meetingMinutes,
  ];

  static RegisteredPrompt? byId(String id) {
    for (final prompt in all) {
      if (prompt.id == id || prompt.qualifiedId == id) return prompt;
    }
    return null;
  }
}

/// One chat inference attempt after the Prompt Quality Gate.
@immutable
class ChatTurnPlan {
  const ChatTurnPlan({
    required this.gate,
    required this.compactContext,
    required this.maxHistoryMessages,
    required this.definition,
  });

  final PromptGateReport gate;
  final bool compactContext;
  final int maxHistoryMessages;
  final RegisteredPrompt definition;

  bool get blocksInference =>
      gate.decision == PromptGateDecision.askUser ||
      gate.decision == PromptGateDecision.abort;

  bool get rebuildContext => gate.decision == PromptGateDecision.rebuildContext;
}

/// Plans prevent → (optional) context rebuild → allow inference.
abstract final class ChatTurnReliability {
  static const defaultHistoryMessages = 6;
  static const rebuiltHistoryMessages = 2;

  static ChatTurnPlan plan({
    required String userText,
    bool historyEmpty = true,
    int estimatedTokens = 0,
    int modelContextLimit = 0,
    int outputBudget = 256,
    RegisteredPrompt definition = AiroPromptRegistry.chatAssistant,
    PrefixCacheCapability prefixCache = PrefixCacheCapability.unsupported,
    int cacheablePrefixTokens = 0,
  }) {
    final gate = PromptQualityGate.inspectUserTurn(
      userText: userText,
      historyEmpty: historyEmpty,
      estimatedTokens: estimatedTokens,
      modelContextLimit: modelContextLimit,
      outputBudget: outputBudget,
      prefixCache: prefixCache,
      cacheablePrefixTokens: cacheablePrefixTokens,
    );
    final rebuild = gate.decision == PromptGateDecision.rebuildContext;
    return ChatTurnPlan(
      gate: gate,
      compactContext: rebuild,
      maxHistoryMessages: rebuild
          ? rebuiltHistoryMessages
          : defaultHistoryMessages,
      definition: definition,
    );
  }
}
