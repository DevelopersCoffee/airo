import 'package:core_ai/core_ai.dart';
import 'package:feature_mind/src/agent_chat/application/assistant_model_preferences.dart';
import 'package:feature_mind/src/agent_chat/domain/models/agent_skill.dart';
import 'package:feature_mind/src/agent_chat/domain/models/assistant_runtime_ids.dart';
import 'package:feature_mind/src/agent_chat/domain/models/research_event.dart';
import 'package:feature_mind/src/agent_chat/domain/models/research_request.dart';
import 'package:feature_mind/src/agent_chat/domain/services/deep_research_engine.dart';
import 'package:feature_mind/src/agent_chat/presentation/screens/chat_screen.dart';
import 'package:feature_mind/src/agent_chat/presentation/screens/model_library_screen.dart';
import 'package:feature_mind/src/host/assistant_host_adapter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/fake_assistant_host_adapter.dart';
import '../../../support/gemini_nano_channel.dart';

void main() {
  testWidgets('Deep Research button starts a typed research job, not chat', (
    tester,
  ) async {
    await _pumpChatScreen(tester);

    expect(
      find.byKey(const Key('agent_chat_deep_research_button')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('agent_chat_deep_research_button')));
    await tester.pump();

    final input = find.byKey(const Key('agent_chat_input'));
    expect(
      tester.widget<TextField>(input).decoration?.hintText,
      'Ask a research question...',
    );

    await tester.enterText(input, 'Best offline LLM for Pixel 9 in 2026');
    await tester.ensureVisible(find.byKey(const Key('agent_chat_send_button')));
    await tester.tap(find.byKey(const Key('agent_chat_send_button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('agent_chat_deep_research_progress')),
      findsOneWidget,
    );
    expect(find.text('RESEARCH COMPLETE'), findsOneWidget);
    expect(
      find.textContaining('Live search providers are not connected'),
      findsWidgets,
    );
    expect(find.textContaining('I think'), findsNothing);
  });

  testWidgets('new chat dismisses the research progress banner', (
    tester,
  ) async {
    await _pumpChatScreen(tester);

    await tester.tap(find.byKey(const Key('agent_chat_deep_research_button')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('agent_chat_input')),
      'Best offline LLM for Pixel 9 in 2026',
    );
    await tester.ensureVisible(find.byKey(const Key('agent_chat_send_button')));
    await tester.tap(find.byKey(const Key('agent_chat_send_button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('agent_chat_deep_research_progress')),
      findsOneWidget,
    );

    await tester.ensureVisible(find.byKey(const Key('mind.chats.new')));
    await tester.tap(find.byKey(const Key('mind.chats.new')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('agent_chat_deep_research_progress')),
      findsNothing,
    );
    expect(find.text('RESEARCH COMPLETE'), findsNothing);
  });
}

class _ImmediateResearchEngine implements DeepResearchEngine {
  const _ImmediateResearchEngine();

  @override
  Stream<ResearchEvent> run(ResearchRequest request) async* {
    yield const ResearchEvent(
      kind: ResearchEventKind.planningStarted,
      label: 'Understanding question',
    );
    yield const ResearchEvent(
      kind: ResearchEventKind.planCreated,
      label: 'Creating research plan',
    );
    yield const ResearchEvent(
      kind: ResearchEventKind.searchStarted,
      label: 'Searching sources',
    );
    yield const ResearchEvent(
      kind: ResearchEventKind.gapDetected,
      label: 'Finding missing evidence',
    );
    yield ResearchEvent(
      kind: ResearchEventKind.researchCompleted,
      label: 'Research completed',
      detail:
          'Live search providers are not connected yet.\nQuestion: ${request.question}',
    );
  }
}

Future<void> _pumpChatScreen(WidgetTester tester) async {
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
          initialMessages: [AgentChatMessage(text: 'Ready', isUser: false)],
          deepResearchEngine: const _ImmediateResearchEngine(),
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
