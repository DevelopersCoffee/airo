import 'package:airo_app/features/agent_chat/application/assistant_model_preferences.dart';
import 'package:airo_app/features/agent_chat/domain/models/agent_skill.dart';
import 'package:airo_app/features/agent_chat/domain/models/assistant_runtime_ids.dart';
import 'package:airo_app/features/agent_chat/domain/models/chat_response_metadata.dart';
import 'package:airo_app/features/agent_chat/presentation/screens/chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('buildRuntimeChatResponseMetadata records tokens and timings', () {
    final metadata = buildRuntimeChatResponseMetadata(
      title: 'Gemini Nano',
      runtime: 'AICore on-device',
      executionMode: 'Local',
      prompt: 'hello',
      response: 'Hello from Airo',
      totalDurationMs: 2400,
      timeToFirstTokenMs: 350,
      recordedAt: DateTime(2026, 6, 28, 10, 0),
      modelId: geminiNanoAssistantModelId,
    );

    expect(metadata.modelId, geminiNanoAssistantModelId);
    expect(metadata.totalDurationMs, 2400);
    expect(metadata.timeToFirstTokenMs, 350);
    expect(metadata.promptTokens, isNotNull);
    expect(metadata.completionTokens, isNotNull);
    expect(metadata.totalTokens, isNotNull);
    expect(metadata.finishReason, 'stop');
  });

  test('buildSkillChatResponseMetadata counts executed tools', () {
    final metadata = buildSkillChatResponseMetadata(
      traces: const [
        AgentActionTrace(title: 'Load skill', detail: 'schedule-notification'),
        AgentActionTrace(
          title: 'Execute action',
          detail: 'schedule_notification',
          durationMs: 120,
        ),
      ],
      totalDurationMs: 900,
      recordedAt: DateTime(2026, 6, 28, 10, 0),
    );

    expect(metadata.toolCount, 1);
    expect(metadata.totalDurationMs, 900);
    expect(metadata.executionMode, 'Local');
  });

  testWidgets('runtime responses expose timing metadata details', (
    tester,
  ) async {
    await _pumpChatScreen(
      tester,
      initialMessages: [
        ChatMessage(
          text: 'Hello from Airo',
          isUser: false,
          metadata: buildRuntimeChatResponseMetadata(
            title: 'Gemini Nano',
            runtime: 'AICore on-device',
            executionMode: 'Local',
            prompt: 'hello',
            response: 'Hello from Airo',
            totalDurationMs: 2400,
            timeToFirstTokenMs: 350,
            recordedAt: DateTime(2026, 6, 28, 10, 0),
            modelId: geminiNanoAssistantModelId,
            systemPromptPreview:
                'You are Airo, the assistant inside the Airo app.',
            promptPreview: 'hello',
            responsePreview: 'Hello from Airo',
          ),
        ),
      ],
    );

    expect(find.text('Hello from Airo'), findsOneWidget);
    expect(find.byKey(const Key('agent_chat_metadata_button')), findsOneWidget);
    expect(find.textContaining('Gemini Nano'), findsOneWidget);

    await tester.tap(find.byKey(const Key('agent_chat_metadata_button')));
    await tester.pumpAndSettle();

    expect(find.text('Response details'), findsOneWidget);
    expect(find.text('Model'), findsOneWidget);
    expect(find.text('Gemini Nano'), findsWidgets);
    expect(find.text('Runtime'), findsOneWidget);
    expect(find.text('AICore on-device'), findsOneWidget);
    expect(find.text('Execution'), findsOneWidget);
    expect(find.text('Local'), findsOneWidget);
    expect(find.text('Time to first token'), findsOneWidget);
    expect(find.text('Prompt tokens'), findsOneWidget);
    expect(find.text('Completion tokens'), findsOneWidget);
    expect(find.text('System context'), findsOneWidget);
    expect(
      find.text('You are Airo, the assistant inside the Airo app.'),
      findsOneWidget,
    );
    expect(find.text('Prompt preview'), findsOneWidget);
    expect(find.text('Response preview'), findsOneWidget);
  });

  testWidgets('agent skill responses show tool count and action timings', (
    tester,
  ) async {
    await _pumpChatScreen(
      tester,
      initialMessages: [
        ChatMessage(
          text: 'Scheduled it.',
          isUser: false,
          traces: const [
            AgentActionTrace(
              title: 'Execute action',
              detail: 'schedule_notification',
              durationMs: 120,
            ),
          ],
          metadata: buildSkillChatResponseMetadata(
            traces: const [
              AgentActionTrace(
                title: 'Execute action',
                detail: 'schedule_notification',
                durationMs: 120,
              ),
            ],
            totalDurationMs: 900,
            recordedAt: DateTime(2026, 6, 28, 10, 0),
          ),
        ),
      ],
    );

    expect(find.text('Scheduled it.'), findsOneWidget);
    expect(find.text('120ms'), findsOneWidget);
    expect(find.textContaining('1 tool'), findsOneWidget);

    await tester.tap(find.byKey(const Key('agent_chat_metadata_button')));
    await tester.pumpAndSettle();

    expect(find.text('Tool calls'), findsOneWidget);
    expect(find.text('1'), findsWidgets);
    expect(find.text('Action timings'), findsOneWidget);
    expect(find.text('schedule_notification'), findsWidgets);
  });

  testWidgets(
    'assistant messages without metadata hide the metadata affordance',
    (tester) async {
      await _pumpChatScreen(
        tester,
        initialMessages: [
          ChatMessage(text: geminiNanoUnavailableMessage, isUser: false),
        ],
      );

      expect(find.text(geminiNanoUnavailableMessage), findsOneWidget);
      expect(find.byKey(const Key('agent_chat_metadata_button')), findsNothing);
    },
  );
}

Future<void> _pumpChatScreen(
  WidgetTester tester, {
  required List<ChatMessage> initialMessages,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(1200, 1000);
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });

  SharedPreferences.setMockInitialValues({
    'selected_assistant_model_id': geminiNanoAssistantModelId,
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        selectedAssistantModelIdProvider.overrideWith(
          (ref) => _SelectedAssistantModelNotifier(),
        ),
      ],
      child: MaterialApp(
        home: ChatScreen(
          enableAiInitialization: false,
          initialMessages: initialMessages,
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
