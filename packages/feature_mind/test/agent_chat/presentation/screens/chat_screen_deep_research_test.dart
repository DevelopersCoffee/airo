import 'package:feature_mind/src/agent_chat/application/assistant_model_preferences.dart';
import 'package:feature_mind/src/agent_chat/domain/models/assistant_runtime_ids.dart';
import 'package:feature_mind/src/agent_chat/domain/models/research_event.dart';
import 'package:feature_mind/src/agent_chat/domain/models/research_request.dart';
import 'package:feature_mind/src/agent_chat/domain/services/deep_research_engine.dart';
import 'package:feature_mind/src/agent_chat/domain/services/research/research_checkpoint.dart';
import 'package:feature_mind/src/agent_chat/domain/services/research/research_checkpoint_log.dart';
import 'package:feature_mind/src/agent_chat/domain/services/research/research_control.dart';
import 'package:feature_mind/src/agent_chat/domain/services/research/research_library.dart';
import 'package:feature_mind/src/agent_chat/domain/services/research/research_library_log.dart';
import 'package:feature_mind/src/runtime/models/log_models.dart';
import 'package:feature_mind/src/runtime/ports/operation_log_port.dart';
import 'package:feature_mind/src/agent_chat/presentation/screens/chat_screen.dart';
import 'package:feature_mind/src/agent_chat/presentation/screens/model_library_screen.dart';
import 'package:feature_mind/src/host/assistant_host_adapter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/fake_assistant_host_adapter.dart';
import '../../../support/gemini_nano_channel.dart';
import '../../../support/recording_operation_log.dart';

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

  testWidgets('Private selection is carried by the research request', (
    tester,
  ) async {
    final engine = _RecordingLibraryEngine();
    await _pumpChatScreen(tester, deepResearchEngine: engine);

    await tester.tap(find.byKey(const Key('agent_chat_deep_research_button')));
    await tester.pump();

    expect(
      find.byKey(const Key('agent_chat_research_privacy_balanced')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('agent_chat_research_privacy_private')),
    );
    await tester.pump();
    expect(
      find.text(
        'On-device orchestration with Wikipedia. '
        'Self-hosted SearXNG is used when configured.',
      ),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const Key('agent_chat_input')),
      'What is private research?',
    );
    await tester.ensureVisible(find.byKey(const Key('agent_chat_send_button')));
    await tester.tap(find.byKey(const Key('agent_chat_send_button')));
    await tester.pumpAndSettle();

    expect(engine.request?.privacy, PrivacyProfile.private);
    expect(engine.request?.policy, SearchPolicy.privacyFirst);
    expect(
      engine.request!.privacy.engineIds,
      isNot(contains('semantic_scholar')),
    );
    final semantics = tester
        .getSemantics(
          find.byKey(const Key('agent_chat_research_privacy_private')),
        )
        .getSemanticsData();
    expect(semantics.hint, contains('Self-hosted SearXNG'));
  });

  testWidgets('Cloud copy names every currently routed remote source', (
    tester,
  ) async {
    await _pumpChatScreen(tester);

    await tester.tap(find.byKey(const Key('agent_chat_deep_research_button')));
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('agent_chat_research_privacy_cloud')),
    );
    await tester.pump();

    expect(
      find.text(
        'Remote allowlisted sources: Wikipedia, arXiv, and Semantic Scholar.',
      ),
      findsOneWidget,
    );
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

  testWidgets('reuses prior library urls and persists the onLibrary entry', (
    tester,
  ) async {
    final log = RecordingOperationLog();
    await appendResearchLibraryOp(
      log: log,
      entry: ResearchLibraryEntry.fromQuestion(
        question: 'Best offline LLM for Pixel 9 in 2026',
        retrievedAt: '2026-08-22T00:00:00Z',
        sourceUrls: const ['https://en.wikipedia.org/wiki/Qwen'],
        findings: const ['Qwen is a family of large language models.'],
      ),
    );
    final engine = _RecordingLibraryEngine();
    await _pumpChatScreen(
      tester,
      operationLogPort: log,
      deepResearchEngine: engine,
    );

    await tester.tap(find.byKey(const Key('agent_chat_deep_research_button')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('agent_chat_input')),
      'Best offline LLM for Pixel 9 in 2026',
    );
    await tester.ensureVisible(find.byKey(const Key('agent_chat_send_button')));
    await tester.tap(find.byKey(const Key('agent_chat_send_button')));
    await tester.pumpAndSettle();

    expect(engine.knownSourceUrls, ['https://en.wikipedia.org/wiki/Qwen']);
    expect(log.appended.last.kind, MindOpKind.researchLibrary);
    expect(
      (await latestLibraryEntryFor(
        log,
        'Best offline LLM for Pixel 9 in 2026',
      ))?.sourceUrls,
      ['https://en.wikipedia.org/wiki/Large_language_model'],
    );
  });

  testWidgets('reattaches a paused research job from the operation log', (
    tester,
  ) async {
    final log = RecordingOperationLog();
    await appendResearchCheckpointOp(
      log: log,
      checkpoint: const ResearchCheckpoint(
        jobId: 'job-1',
        question: 'What is Qwen?',
        state: ResearchPhase.paused,
        pausedFrom: ResearchPhase.searching,
        searchesUsed: 1,
        iterationsUsed: 1,
        completedNodeIds: ['root'],
      ),
    );

    await _pumpChatScreen(tester, operationLogPort: log);

    expect(find.text('RESEARCH PAUSED'), findsOneWidget);
    expect(
      find.byKey(const Key('agent_chat_deep_research_resume')),
      findsOneWidget,
    );
  });

  testWidgets('resumes a Private checkpoint without widening its policy', (
    tester,
  ) async {
    final log = RecordingOperationLog();
    await appendResearchCheckpointOp(
      log: log,
      checkpoint: const ResearchCheckpoint(
        jobId: 'job-private',
        question: 'What is Qwen?',
        state: ResearchPhase.paused,
        pausedFrom: ResearchPhase.searching,
        searchesUsed: 1,
        iterationsUsed: 1,
        completedNodeIds: ['root'],
        policy: SearchPolicy.privacyFirst,
      ),
    );
    final engine = _RecordingLibraryEngine();

    await _pumpChatScreen(
      tester,
      operationLogPort: log,
      deepResearchEngine: engine,
    );
    await tester.tap(find.byKey(const Key('agent_chat_deep_research_resume')));
    await tester.pumpAndSettle();

    expect(engine.request?.privacy, PrivacyProfile.private);
    expect(engine.request?.policy, SearchPolicy.privacyFirst);
  });

  testWidgets('privacy controls leave a usable input at 320px', (tester) async {
    await _pumpChatScreen(tester, physicalSize: const Size(320, 1000));
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('agent_chat_deep_research_button')));
    await tester.pump();

    expect(find.text('Research privacy'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('agent_chat_input'))).width,
      greaterThanOrEqualTo(200),
    );
    expect(tester.takeException(), isNull);
  });
}

class _RecordingLibraryEngine implements DeepResearchEngine {
  List<String> knownSourceUrls = const [];
  ResearchRequest? request;

  @override
  Stream<ResearchEvent> run(
    ResearchRequest request, {
    ResearchControl? control,
    ResearchCheckpoint? resumeFrom,
    void Function(ResearchCheckpoint checkpoint)? onCheckpoint,
    List<String> knownSourceUrls = const [],
    void Function(ResearchLibraryEntry entry)? onLibrary,
  }) async* {
    this.request = request;
    this.knownSourceUrls = knownSourceUrls;
    onLibrary?.call(
      ResearchLibraryEntry.fromQuestion(
        question: request.question,
        retrievedAt: '2026-08-22T12:00:00Z',
        sourceUrls: const [
          'https://en.wikipedia.org/wiki/Large_language_model',
        ],
        findings: const ['Large language models are trained on text.'],
      ),
    );
    yield ResearchEvent(
      kind: ResearchEventKind.researchCompleted,
      label: 'Research completed',
      detail: 'Question: ${request.question}',
    );
  }
}

class _ImmediateResearchEngine implements DeepResearchEngine {
  const _ImmediateResearchEngine();

  @override
  Stream<ResearchEvent> run(
    ResearchRequest request, {
    ResearchControl? control,
    ResearchCheckpoint? resumeFrom,
    void Function(ResearchCheckpoint checkpoint)? onCheckpoint,
    List<String> knownSourceUrls = const [],
    void Function(ResearchLibraryEntry entry)? onLibrary,
  }) async* {
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

Future<void> _pumpChatScreen(
  WidgetTester tester, {
  OperationLogPort? operationLogPort,
  DeepResearchEngine? deepResearchEngine,
  Size physicalSize = const Size(1200, 1000),
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = physicalSize;
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
          deepResearchEngine:
              deepResearchEngine ?? const _ImmediateResearchEngine(),
          operationLogPort: operationLogPort,
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
