import 'package:feature_mind/src/agent_chat/application/assistant_model_preferences.dart';
import 'package:feature_mind/src/agent_chat/domain/models/assistant_runtime_ids.dart';
import 'package:feature_mind/src/agent_chat/presentation/screens/chat_screen.dart';
import 'package:feature_mind/src/agent_chat/presentation/screens/model_library_screen.dart';
import 'package:feature_mind/src/host/assistant_host_adapter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_assistant_host_adapter.dart';
import '../support/gemini_nano_channel.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'selected_assistant_model_id': _cloudChatModelId,
    });
  });

  test('the host adapter provider fails loudly when no shell overrides it', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      () => container.read(assistantHostAdapterProvider),
      throwsA(
        predicate<Object>(
          (error) =>
              error.toString().contains('UnimplementedError') &&
              error.toString().contains(
                'AssistantHostAdapter must be overridden',
              ),
          'surfaces the missing-override UnimplementedError',
        ),
      ),
    );
  });

  testWidgets('ChatScreen builds against a faked host adapter', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 1000);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    final adapter = FakeAssistantHostAdapter();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assistantHostAdapterProvider.overrideWithValue(adapter),
          selectedAssistantModelIdProvider.overrideWith(
            (ref) => _SelectedAssistantModelNotifier(),
          ),
        ],
        child: const MaterialApp(home: ChatScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('agent_chat_input')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a finance-shaped message is routed through the host adapter', (
    tester,
  ) async {
    stubGeminiNanoChannel();
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 1000);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    var undone = false;
    final adapter = FakeAssistantHostAdapter(
      onIngest: (message) async => AssistantFinanceIngestion(
        responseText: 'Added to Coins: Swiggy - ₹450.00 - food.',
        undoLabel: 'Added Swiggy to Coins.',
        onUndo: () async {
          undone = true;
          return 'Removed Swiggy from Coins.';
        },
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assistantHostAdapterProvider.overrideWithValue(adapter),
          assistantModelLibraryProvider.overrideWith(
            (ref) async => _financeChatLibraryState,
          ),
          selectedAssistantModelIdProvider.overrideWith(
            (ref) => _FinanceChatModelNotifier(),
          ),
        ],
        child: const MaterialApp(
          home: ChatScreen(enableAiInitialization: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('agent_chat_input')),
      'INR 450.00 spent on your HDFC Bank Credit Card at Swiggy on 20-06-26.',
    );
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(adapter.ingestedMessages, hasLength(1));
    expect(
      find.textContaining('Added to Coins: Swiggy'),
      findsOneWidget,
      reason: 'the host response is appended to the transcript',
    );

    expect(find.text('Undo'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(undone, isTrue);
    expect(find.textContaining('Removed Swiggy from Coins.'), findsOneWidget);
  });
}

class _SelectedAssistantModelNotifier extends SelectedAssistantModelNotifier {
  _SelectedAssistantModelNotifier() {
    state = geminiNanoAssistantModelId;
  }
}

class _FinanceChatModelNotifier extends SelectedAssistantModelNotifier {
  _FinanceChatModelNotifier() {
    state = _cloudChatModelId;
  }
}

const _cloudChatModelId = 'cloud-chat-test';

const _financeChatCandidate = AssistantModelCandidate(
  id: _cloudChatModelId,
  name: 'Cloud chat',
  runtime: 'Network',
  description: 'Remote model for tests',
  bestFor: [AssistantTask.chat],
  tags: ['Cloud'],
  privacyLabel: 'Processed remotely',
  sizeLabel: 'No download',
  available: true,
  actionLabel: 'Use',
  local: false,
);

const _financeChatLibraryState = AssistantModelLibraryState(
  task: AssistantTask.chat,
  deviceLabel: 'Test host',
  platformLabel: 'TEST',
  candidates: [_financeChatCandidate],
  recommended: _financeChatCandidate,
  defaultPackages: {},
);
