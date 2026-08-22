import 'package:core_ai/core_ai.dart';

import '../agent_chat/data/services/assistant_chat_context_builder.dart';
import '../agent_chat/domain/models/assistant_runtime_ids.dart';
import '../agent_chat/domain/services/intent_parser.dart';
import 'reasoning_models.dart';

/// True when chat should call [MindGenerationBridge.reason] instead of
/// unconstrained GGUF completion.
///
/// LiteRT, Nano, and cloud stay on their existing runtimes. Android GGUF
/// uses `reason()` when the FRB llama slot is loaded; JNI-only loads stay
/// on unconstrained completion.
bool shouldUseOnDeviceReasoning({
  required bool engineReady,
  required String selectedModelId,
  bool isLiteRt = false,
}) {
  if (!engineReady || isLiteRt) return false;
  return isOfflineAssistantModelId(selectedModelId);
}

/// Legacy [IntentParser] → `ClassifiedIntent.kind` compatibility wire.
///
/// Dart must not grow new routing rules here. The registry in
/// `airo_mind_intent` owns capabilities; this map may only emit kinds the
/// Rust legacy adapter already understands. Diet is `diet`, not `planning`.
String reasoningIntentKind(IntentType type) {
  return switch (type) {
    IntentType.playMusic ||
    IntentType.pauseMusic ||
    IntentType.nextTrack => 'play_media',
    IntentType.openWifiSettings || IntentType.setFlashlight => 'toggle_setting',
    IntentType.openMoney ||
    IntentType.openBudget ||
    IntentType.openExpenses ||
    IntentType.splitBill ||
    IntentType.playGames ||
    IntentType.playChess ||
    IntentType.playGame ||
    IntentType.openMap ||
    IntentType.openOffers ||
    IntentType.openReader ||
    IntentType.openChat ||
    IntentType.openMeetingScribe ||
    IntentType.modelManagement ||
    IntentType.mobileActions => 'navigation',
    IntentType.createDietPlan => 'diet',
    IntentType.createRoutine => 'planning',
    IntentType.searchMeetings ||
    IntentType.getMeetingMom ||
    IntentType.audioScribe ||
    IntentType.myActionItems => 'summarization',
    IntentType.askImage ||
    IntentType.composeEmail ||
    IntentType.createContact ||
    IntentType.boredom ||
    IntentType.unknown => 'conversation',
  };
}

double reasoningIntentComplexity(Intent intent) {
  return switch (intent.type) {
    IntentType.createDietPlan || IntentType.createRoutine => 0.85,
    IntentType.searchMeetings ||
    IntentType.getMeetingMom ||
    IntentType.audioScribe => 0.55,
    IntentType.unknown ||
    IntentType.askImage ||
    IntentType.composeEmail ||
    IntentType.createContact ||
    IntentType.boredom => _complexityFromLength(intent.originalText),
    _ => 0.2,
  };
}

double _complexityFromLength(String text) {
  final trimmed = text.trim();
  var score = 0.25;
  if (trimmed.length > 160) score += 0.2;
  if (trimmed.length > 400) score += 0.2;
  if ('?'.allMatches(trimmed).length >= 2) score += 0.15;
  return score.clamp(0.0, 1.0);
}

MindReasoningLevel maxReasoningLevelForTier(LlmDeviceTier tier) {
  return switch (tier) {
    LlmDeviceTier.none => MindReasoningLevel.none,
    LlmDeviceTier.small => MindReasoningLevel.light,
    LlmDeviceTier.medium => MindReasoningLevel.standard,
    LlmDeviceTier.large => MindReasoningLevel.deep,
  };
}

String? reasoningLevelStableId(MindReasoningLevel? level) {
  if (level == null) return null;
  return switch (level) {
    MindReasoningLevel.none => 'none',
    MindReasoningLevel.light => 'light',
    MindReasoningLevel.standard => 'standard',
    MindReasoningLevel.deep => 'deep',
  };
}

MindReasoningLevel? reasoningLevelFromStableId(String? id) {
  return switch (id) {
    'none' => MindReasoningLevel.none,
    'light' => MindReasoningLevel.light,
    'standard' => MindReasoningLevel.standard,
    'deep' => MindReasoningLevel.deep,
    _ => null,
  };
}

/// Keys that must never appear in persisted chat history.
const bannedReasoningTraceKeys = {
  'thoughts',
  'thought',
  'scratchpad',
  'raw_thoughts',
  'partialThinkingResult',
};

bool jsonContainsBannedReasoningTraceKeys(Object? value) {
  if (value is Map) {
    for (final key in value.keys) {
      if (key is String && bannedReasoningTraceKeys.contains(key)) {
        return true;
      }
      if (jsonContainsBannedReasoningTraceKeys(value[key])) return true;
    }
    return false;
  }
  if (value is List) {
    return value.any(jsonContainsBannedReasoningTraceKeys);
  }
  return false;
}

List<MindReasoningContextItem> reasoningHistoryItems({
  required List<AssistantChatContextMessage> history,
  required String currentUserPrompt,
  int maxTurns = 12,
  int maxChars = 1200,
}) {
  final normalizedCurrent = currentUserPrompt.trim().toLowerCase();
  final filtered = history
      .where((message) => message.text.trim().isNotEmpty)
      .where((message) => !isAssistantOperationalStatus(message.text))
      .where((message) {
        if (!message.isUser) return true;
        return message.text.trim().toLowerCase() != normalizedCurrent;
      })
      .toList();
  final sliced = filtered.length <= maxTurns
      ? filtered
      : filtered.sublist(filtered.length - maxTurns);
  return [
    for (final message in sliced)
      MindReasoningContextItem(
        source: message.isUser ? 'user' : 'assistant',
        text: ContextCompiler.wrapAsData(
          _preview(message.text.trim(), maxChars),
        ),
      ),
  ];
}

String _preview(String value, int maxChars) {
  if (value.length <= maxChars) return value;
  return '${value.substring(0, maxChars)}...';
}

MindReasoningRequest buildMindReasoningRequest({
  required String userQuery,
  required Intent intent,
  required List<AssistantChatContextMessage> history,
  LlmDeviceTier tier = LlmDeviceTier.large,
  LlmDeviceSignals? signals,
  List<MindReasoningContextItem> documents = const [],
  List<String> toolNames = const [],
}) {
  final thermal = signals?.thermalPressure;
  return MindReasoningRequest(
    userQuery: userQuery,
    intentKind: reasoningIntentKind(intent.type),
    intentComplexity: reasoningIntentComplexity(intent),
    maxReasoningLevel: maxReasoningLevelForTier(tier),
    availableMemoryMb: signals?.totalRamMb ?? 8192,
    gpuAvailable: tier == LlmDeviceTier.large || tier == LlmDeviceTier.medium,
    npuAvailable: false,
    thermalConstrained:
        thermal == LlmThermalPressure.serious ||
        thermal == LlmThermalPressure.critical,
    batteryConstrained: false,
    history: reasoningHistoryItems(
      history: history,
      currentUserPrompt: userQuery,
    ),
    documents: [
      for (final document in documents)
        MindReasoningContextItem(
          source: document.source,
          text: ContextCompiler.wrapAsData(document.text),
        ),
    ],
    toolNames: toolNames,
  );
}
