import 'package:airo_app/features/agent_chat/application/assistant_model_preferences.dart';
import 'package:airo_app/features/agent_chat/domain/models/agent_skill.dart';
import 'package:airo_app/features/agent_chat/domain/models/assistant_runtime_ids.dart';
import 'package:airo_app/features/agent_chat/domain/models/chat_response_metadata.dart';
import 'package:airo_app/features/agent_chat/presentation/screens/chat_screen.dart';
import 'package:airo_app/features/agent_chat/presentation/screens/model_library_screen.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../support/gemini_nano_channel.dart';

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

  test('formatChatTranscript exports visible non-empty turns', () {
    final transcript = formatChatTranscript([
      ChatMessage(text: 'Welcome', isUser: false),
      ChatMessage(text: '  ', isUser: false),
      ChatMessage(text: 'How many r?', isUser: true),
      ChatMessage(text: 'Three.', isUser: false),
    ]);

    expect(
      transcript,
      'Airo chat transcript\n\n'
      'Airo:\n'
      'Welcome\n\n'
      'User:\n'
      'How many r?\n\n'
      'Airo:\n'
      'Three.',
    );
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
    expect(find.textContaining('Gemini Nano'), findsWidgets);

    await tester.tap(find.byKey(const Key('agent_chat_metadata_button')));
    await tester.pumpAndSettle();

    expect(find.text('Response details'), findsOneWidget);
    expect(find.text('Model'), findsOneWidget);
    expect(find.text('Gemini Nano'), findsWidgets);
    expect(find.text('Runtime'), findsOneWidget);
    expect(find.text('AICore on-device'), findsWidgets);
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

  testWidgets('chat screen prefills the composer draft when provided', (
    tester,
  ) async {
    await _pumpChatScreen(
      tester,
      initialMessages: [ChatMessage(text: 'Hello from Airo', isUser: false)],
      initialDraft: 'Follow up on my reminder',
    );

    final input = tester.widget<TextField>(
      find.byKey(const Key('agent_chat_input')),
    );
    expect(input.controller?.text, 'Follow up on my reminder');
  });

  testWidgets('prompt suggestion fills the composer without sending', (
    tester,
  ) async {
    await _pumpChatScreen(
      tester,
      initialMessages: [ChatMessage(text: 'Welcome', isUser: false)],
    );

    expect(find.text('Try a prompt'), findsOneWidget);
    await tester.tap(find.text('AI Chat'));
    await tester.pumpAndSettle();

    final input = tester.widget<TextField>(
      find.byKey(const Key('agent_chat_input')),
    );
    expect(input.controller?.text, 'Help me think through a task');
  });

  testWidgets('message actions copy assistant and user messages', (
    tester,
  ) async {
    String? clipboardText;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      switch (call.method) {
        case 'Clipboard.setData':
          clipboardText =
              (call.arguments as Map<Object?, Object?>)['text'] as String?;
          return null;
        case 'Clipboard.getData':
          return <String, Object?>{'text': clipboardText};
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await _pumpChatScreen(
      tester,
      initialMessages: [
        ChatMessage(text: 'Assistant answer', isUser: false),
        ChatMessage(text: 'User prompt', isUser: true),
      ],
    );

    tester
        .widget<IconButton>(
          find.byKey(const ValueKey('agent_chat_message_actions_0')),
        )
        .onPressed
        ?.call();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Message copied'), findsOneWidget);
    expect(
      (await Clipboard.getData('text/plain'))?.text,
      equals('Assistant answer'),
    );

    tester
        .widget<IconButton>(
          find.byKey(const ValueKey('agent_chat_message_actions_1')),
        )
        .onPressed
        ?.call();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      (await Clipboard.getData('text/plain'))?.text,
      equals('User prompt'),
    );
  });

  testWidgets('copy transcript exports the visible chat session', (
    tester,
  ) async {
    String? clipboardText;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      switch (call.method) {
        case 'Clipboard.setData':
          clipboardText =
              (call.arguments as Map<Object?, Object?>)['text'] as String?;
          return null;
        case 'Clipboard.getData':
          return <String, Object?>{'text': clipboardText};
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await _pumpChatScreen(
      tester,
      initialMessages: [
        ChatMessage(text: 'Assistant answer', isUser: false),
        ChatMessage(text: 'User prompt', isUser: true),
      ],
    );

    await tester.tap(
      find.byKey(const Key('agent_chat_copy_transcript_button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Transcript copied'), findsOneWidget);
    expect(
      (await Clipboard.getData('text/plain'))?.text,
      equals(
        'Airo chat transcript\n\n'
        'Airo:\n'
        'Assistant answer\n\n'
        'User:\n'
        'User prompt',
      ),
    );
  });

  testWidgets('clear chat confirms before removing visible messages', (
    tester,
  ) async {
    await _pumpChatScreen(
      tester,
      initialMessages: [
        ChatMessage(text: 'Assistant answer', isUser: false),
        ChatMessage(text: 'User prompt', isUser: true),
      ],
    );

    await tester.tap(
      find.byKey(const Key('agent_chat_clear_conversation_button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Clear conversation?'), findsOneWidget);
    expect(find.text('Assistant answer'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Assistant answer'), findsOneWidget);
    expect(find.text('User prompt'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('agent_chat_clear_conversation_button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Clear chat'));
    await tester.pumpAndSettle();

    expect(find.text('Assistant answer'), findsNothing);
    expect(find.text('User prompt'), findsNothing);
    expect(find.text('Conversation cleared'), findsOneWidget);
    final clearButton = tester.widget<IconButton>(
      find.byKey(const Key('agent_chat_clear_conversation_button')),
    );
    expect(clearButton.onPressed, isNull);
  });

  testWidgets('empty streaming placeholder hides copy action', (tester) async {
    await _pumpChatScreen(
      tester,
      initialMessages: [ChatMessage(text: '', isUser: false)],
    );

    expect(
      find.byKey(const ValueKey('agent_chat_message_actions_0')),
      findsNothing,
    );
  });

  testWidgets('renders fenced code with language label and copy action', (
    tester,
  ) async {
    String? clipboardText;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      switch (call.method) {
        case 'Clipboard.setData':
          clipboardText =
              (call.arguments as Map<Object?, Object?>)['text'] as String?;
          return null;
        case 'Clipboard.getData':
          return <String, Object?>{'text': clipboardText};
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await _pumpChatScreen(
      tester,
      initialMessages: [
        ChatMessage(
          text: 'Use this:\n```dart\nfinal answer = true;\n```',
          isUser: false,
        ),
      ],
    );

    expect(find.text('dart'), findsOneWidget);
    final code = tester.widget<SelectableText>(
      find.byKey(const Key('agent_chat_code_block')),
    );
    expect(code.textSpan?.toPlainText(), contains('final answer = true;'));
    expect(find.byTooltip('Copy code'), findsOneWidget);

    await tester.tap(find.byTooltip('Copy code'));
    await tester.pumpAndSettle();

    expect(
      (await Clipboard.getData('text/plain'))?.text,
      equals('final answer = true;\n'),
    );
  });
}

Future<void> _pumpChatScreen(
  WidgetTester tester, {
  required List<ChatMessage> initialMessages,
  String? initialDraft,
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
          initialDraft: initialDraft,
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
  local: true,
);

const _chatLibraryState = AssistantModelLibraryState(
  task: AssistantTask.chat,
  deviceLabel: 'Google Pixel 9',
  platformLabel: 'ANDROID',
  candidates: [_chatCandidate],
  recommended: _chatCandidate,
  defaultPackages: {},
);
