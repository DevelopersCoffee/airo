import 'package:feature_mind/src/agent_chat/domain/models/assistant_runtime_ids.dart';
import 'package:feature_mind/src/agent_chat/domain/models/grounded_citation.dart';
import 'package:feature_mind/src/agent_chat/presentation/screens/chat_screen.dart';
import 'package:feature_mind/src/agent_chat/application/assistant_model_preferences.dart';
import 'package:feature_mind/src/agent_chat/presentation/screens/model_library_screen.dart';
import 'package:feature_mind/src/host/assistant_host_adapter.dart';
import 'package:feature_mind/src/runtime/models/capability_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/fake_assistant_host_adapter.dart';
import '../../../support/gemini_nano_channel.dart';

void main() {
  testWidgets(
    'a grounded assistant message renders its safety banner and a tappable '
    'citation that resolves the real op',
    (tester) async {
      await _pumpChatScreen(
        tester,
        initialMessages: [
          AgentChatMessage(
            text: 'You logged Ibuprofen 400 mg for this recovery.',
            isUser: false,
            groundingState: GroundingState.grounded,
            safetyClass: CapabilitySafetyClass.health,
            citations: const [
              GroundedCitation(
                opSequence: 12481,
                sourceLabel: 'query_lifetrack_status',
                contextLabel: 'kneesurgery2026',
              ),
            ],
          ),
        ],
      );

      expect(find.textContaining('wellness only'), findsOneWidget);
      expect(find.text('GROUNDED IN'), findsOneWidget);
      expect(find.textContaining('op 12481'), findsOneWidget);

      await tester.tap(find.textContaining('op 12481'));
      await tester.pumpAndSettle();

      expect(find.text('Ibuprofen 400 mg logged'), findsOneWidget);
    },
  );

  testWidgets(
    'an ungrounded assistant message is labelled, not rendered as grounded, '
    'and carries no safety banner without a safety class',
    (tester) async {
      await _pumpChatScreen(
        tester,
        initialMessages: [
          AgentChatMessage(
            text: 'Here is a general answer with no logged operation.',
            isUser: false,
            groundingState: GroundingState.ungrounded,
          ),
        ],
      );

      expect(find.textContaining('UNGROUNDED'), findsOneWidget);
      expect(find.text('GROUNDED IN'), findsNothing);
      expect(find.textContaining('wellness only'), findsNothing);
    },
  );

  testWidgets('a plain message with no grounding claim renders neither block', (
    tester,
  ) async {
    await _pumpChatScreen(
      tester,
      initialMessages: [
        AgentChatMessage(text: 'Opening Money.', isUser: false),
      ],
    );

    expect(find.textContaining('UNGROUNDED'), findsNothing);
    expect(find.text('GROUNDED IN'), findsNothing);
  });
}

Future<void> _pumpChatScreen(
  WidgetTester tester, {
  required List<AgentChatMessage> initialMessages,
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
