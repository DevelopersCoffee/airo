import 'package:core_ai/core_ai.dart';
import 'package:feature_mind/src/agent_chat/data/services/assistant_chat_context_builder.dart';
import 'package:feature_mind/src/agent_chat/domain/models/assistant_runtime_ids.dart';
import 'package:feature_mind/src/agent_chat/domain/services/intent_parser.dart';
import 'package:feature_mind/src/reasoning/chat_reasoning_request.dart';
import 'package:feature_mind/src/reasoning/reasoning_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reason() is never selected from a raw Nano/cloud id', () {
    expect(
      shouldUseOnDeviceReasoning(
        engineReady: true,
        selectedModelId: geminiNanoAssistantModelId,
      ),
      isFalse,
    );
    expect(
      shouldUseOnDeviceReasoning(
        engineReady: true,
        selectedModelId: 'offline-qwen-0.5b',
        isLiteRt: true,
      ),
      isFalse,
    );
    expect(
      shouldUseOnDeviceReasoning(
        engineReady: false,
        selectedModelId: 'offline-qwen-0.5b',
      ),
      isFalse,
    );
    expect(
      shouldUseOnDeviceReasoning(
        engineReady: true,
        selectedModelId: 'offline-qwen-0.5b',
      ),
      isTrue,
    );
  });

  test('classified kinds do not substring-match the query', () {
    const planning = Intent(
      type: IntentType.createDietPlan,
      originalText: 'Write a plan for the week',
    );
    expect(reasoningIntentKind(planning.type), 'planning');
    expect(reasoningIntentComplexity(planning), 0.85);

    const lookup = Intent(
      type: IntentType.openBudget,
      originalText: 'plan my budget',
    );
    expect(reasoningIntentKind(lookup.type), 'navigation');
    expect(reasoningIntentComplexity(lookup), 0.2);

    const chat = Intent(
      type: IntentType.unknown,
      originalText: 'Why is the sky blue?',
    );
    expect(reasoningIntentKind(chat.type), 'conversation');
    expect(reasoningIntentComplexity(chat), lessThan(0.5));
  });

  test('device tier clamps the max level the engine may request', () {
    expect(
      maxReasoningLevelForTier(LlmDeviceTier.none),
      MindReasoningLevel.none,
    );
    expect(
      maxReasoningLevelForTier(LlmDeviceTier.small),
      MindReasoningLevel.light,
    );
    expect(
      maxReasoningLevelForTier(LlmDeviceTier.medium),
      MindReasoningLevel.standard,
    );
    expect(
      maxReasoningLevelForTier(LlmDeviceTier.large),
      MindReasoningLevel.deep,
    );
  });

  test('history packing drops the current turn and operational status', () {
    final items = reasoningHistoryItems(
      currentUserPrompt: 'What next?',
      history: const [
        AssistantChatContextMessage(
          text: 'You selected Gemma. Warming it on device.',
          isUser: false,
        ),
        AssistantChatContextMessage(text: 'Hi', isUser: true),
        AssistantChatContextMessage(text: 'Hello from Airo', isUser: false),
        AssistantChatContextMessage(text: 'What next?', isUser: true),
      ],
    );
    expect(items, [
      const MindReasoningContextItem(source: 'user', text: 'Hi'),
      const MindReasoningContextItem(
        source: 'assistant',
        text: 'Hello from Airo',
      ),
    ]);
  });

  test('thermal pressure is forwarded as a device flag, not an OS check', () {
    final request = buildMindReasoningRequest(
      userQuery: 'Summarise the notes',
      intent: const Intent(
        type: IntentType.unknown,
        originalText: 'Summarise the notes',
      ),
      history: const [],
      tier: LlmDeviceTier.small,
      signals: const LlmDeviceSignals(
        totalRamMb: 3072,
        availableStorageMb: 4096,
        thermalPressure: LlmThermalPressure.serious,
      ),
    );
    expect(request.maxReasoningLevel, MindReasoningLevel.light);
    expect(request.availableMemoryMb, 3072);
    expect(request.thermalConstrained, isTrue);
    expect(request.gpuAvailable, isFalse);
  });
}
