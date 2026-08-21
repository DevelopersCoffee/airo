import 'package:core_ai/core_ai.dart';
import 'package:feature_mind/src/agent_chat/application/assistant_model_preferences.dart';
import 'package:feature_mind/src/agent_chat/data/services/chat_history_store.dart';
import 'package:feature_mind/src/agent_chat/domain/models/assistant_runtime_ids.dart';
import 'package:feature_mind/src/agent_chat/presentation/screens/chat_screen.dart';
import 'package:feature_mind/src/agent_chat/presentation/screens/model_library_screen.dart';
import 'package:feature_mind/src/bridges/mind_generation_bridge.dart';
import 'package:feature_mind/src/host/assistant_host_adapter.dart';
import 'package:feature_mind/src/reasoning/chat_reasoning_request.dart';
import 'package:feature_mind/src/reasoning/reasoning_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/fake_assistant_host_adapter.dart';
import '../../../support/fake_bridges.dart';
import '../../../support/gemini_nano_channel.dart';

void main() {
  test('restored chat messages keep summary and level, never thought keys', () {
    final message = AgentChatMessage(
      text: 'Ice is less dense than water.',
      isUser: false,
      reasoningSummary: 'Used density, not a scratchpad.',
      reasoningLevel: MindReasoningLevel.light,
    );
    final json = message.toHistoryEntry().toJson();
    expect(jsonContainsBannedReasoningTraceKeys(json), isFalse);
    expect(json['reasoningLevel'], 'light');
    final restored = AgentChatMessage.fromHistoryEntry(
      ChatHistoryEntry.fromJson(json)!,
    );
    expect(restored.reasoningSummary, 'Used density, not a scratchpad.');
    expect(restored.reasoningLevel, MindReasoningLevel.light);
    expect(restored.text, 'Ice is less dense than water.');
  });
  testWidgets(
    'an assistant bubble shows thinking steps without putting the answer in them',
    (tester) async {
      await _pumpChatScreen(
        tester,
        initialMessages: [
          AgentChatMessage(
            text: 'Buy rice tomorrow.',
            isUser: false,
            reasoningSteps: const [
              ReasoningProgressStep(label: 'Reading your request'),
              ReasoningProgressStep(label: 'Writing an answer'),
            ],
            reasoningSummary: 'Turned the query into a grocery line.',
          ),
        ],
      );

      expect(find.text('Thinking · 2 steps'), findsOneWidget);
      expect(find.text('Buy rice tomorrow.'), findsOneWidget);

      await tester.tap(find.text('Thinking · 2 steps'));
      await tester.pumpAndSettle();
      expect(find.text('Reading your request'), findsOneWidget);
      expect(
        find.text('Turned the query into a grocery line.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'GGUF-ready chat streams reason() into the bubble, not a thought dump',
    (tester) async {
      final bridge = FakeMindGenerationBridge()
        ..reasoningEvents = const [
          MindReasoningStageChanged(MindReasoningStage.understanding),
          MindReasoningProgress('level=Light'),
          MindReasoningAnswerDelta('Ice is less dense than water.'),
          MindReasoningCompleted(
            answer: 'Ice is less dense than water.',
            reasoningSummary: 'Used density, not a scratchpad.',
            level: MindReasoningLevel.light,
          ),
        ];
      await bridge.ensureLoaded(modelsDir: '/tmp', memoryBudgetMb: 1024);

      await _pumpChatScreen(
        tester,
        initialMessages: [AgentChatMessage(text: 'Ready', isUser: false)],
        generationBridge: bridge,
        useOnDeviceReasoning: () => true,
        deviceSignalsProbe: const FakeLlmDeviceSignalsProbe(
          LlmDeviceSignals(totalRamMb: 8192, availableStorageMb: 8192),
        ),
      );

      await tester.enterText(
        find.byKey(const Key('agent_chat_input')),
        'Why does ice float?',
      );
      await tester.ensureVisible(
        find.byKey(const Key('agent_chat_send_button')),
      );
      await tester.tap(find.byKey(const Key('agent_chat_send_button')));
      await tester.pumpAndSettle();

      expect(find.text('Why does ice float?'), findsOneWidget);
      expect(find.text('Ice is less dense than water.'), findsOneWidget);
      expect(find.text('Thinking · 1 step'), findsOneWidget);
      expect(find.textContaining('level=Light'), findsNothing);
      expect(bridge.lastReasonRequest?.userQuery, 'Why does ice float?');
      expect(bridge.lastReasonRequest?.intentKind, 'conversation');
    },
  );

  testWidgets('a small-RAM probe clamps the request to light reasoning', (
    tester,
  ) async {
    final bridge = FakeMindGenerationBridge()
      ..reasoningEvents = const [
        MindReasoningCompleted(
          answer: 'Tuesday is free after 3.',
          reasoningSummary: 'Looked at the calendar.',
          level: MindReasoningLevel.none,
        ),
      ];
    await bridge.ensureLoaded(modelsDir: '/tmp', memoryBudgetMb: 1024);

    await _pumpChatScreen(
      tester,
      initialMessages: [AgentChatMessage(text: 'Ready', isUser: false)],
      generationBridge: bridge,
      useOnDeviceReasoning: () => true,
      deviceSignalsProbe: const FakeLlmDeviceSignalsProbe(
        LlmDeviceSignals(totalRamMb: 3072, availableStorageMb: 4096),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('agent_chat_input')),
      'Why is the sky blue on Earth?',
    );
    await tester.ensureVisible(find.byKey(const Key('agent_chat_send_button')));
    await tester.tap(find.byKey(const Key('agent_chat_send_button')));
    await tester.pumpAndSettle();

    expect(
      bridge.lastReasonRequest?.maxReasoningLevel,
      MindReasoningLevel.light,
    );
    expect(bridge.lastReasonRequest?.availableMemoryMb, 3072);
  });
}

Future<void> _pumpChatScreen(
  WidgetTester tester, {
  required List<AgentChatMessage> initialMessages,
  MindGenerationBridge? generationBridge,
  bool Function()? useOnDeviceReasoning,
  LlmDeviceSignalsProbe? deviceSignalsProbe,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(1200, 1000);
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });

  stubGeminiNanoChannel();

  SharedPreferences.setMockInitialValues({
    'selected_assistant_model_id': geminiNanoAssistantModelId,
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        assistantHostAdapterProvider.overrideWithValue(
          FakeAssistantHostAdapter(),
        ),
        assistantModelLibraryProvider.overrideWith(
          (ref) async => _chatLibraryState,
        ),
        selectedAssistantModelIdProvider.overrideWith(
          (ref) => _SelectedAssistantModelNotifier(),
        ),
      ],
      child: MaterialApp(
        home: ChatScreen(
          enableAiInitialization: false,
          initialMessages: initialMessages,
          generationBridge: generationBridge,
          useOnDeviceReasoning: useOnDeviceReasoning,
          deviceSignalsProbe: deviceSignalsProbe,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _SelectedAssistantModelNotifier extends SelectedAssistantModelNotifier {
  _SelectedAssistantModelNotifier() {
    state = geminiNanoAssistantModelId;
  }
}

const _chatCandidate = AssistantModelCandidate(
  id: geminiNanoAssistantModelId,
  name: 'Gemini Nano',
  runtime: 'AICore on-device',
  description: 'System runtime',
  bestFor: [AssistantTask.chat],
  tags: ['Local'],
  privacyLabel: 'Prompt stays on device',
  sizeLabel: 'System managed',
  available: true,
  actionLabel: 'Start',
  local: false,
);

const _chatLibraryState = AssistantModelLibraryState(
  task: AssistantTask.chat,
  deviceLabel: 'Google Pixel 9',
  platformLabel: 'ANDROID',
  candidates: [_chatCandidate],
  recommended: _chatCandidate,
  defaultPackages: {},
);
