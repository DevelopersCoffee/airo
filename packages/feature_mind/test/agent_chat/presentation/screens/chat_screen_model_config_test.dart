import 'package:feature_mind/src/agent_chat/application/assistant_model_preferences.dart';
import 'package:feature_mind/src/agent_chat/domain/models/assistant_runtime_ids.dart';
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
  testWidgets('chat screen settings opens the Configurations dialog', (
    tester,
  ) async {
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
        child: const MaterialApp(
          home: ChatScreen(enableAiInitialization: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('agent_chat_model_config_button')));
    await tester.pumpAndSettle();

    expect(find.text('Configurations'), findsOneWidget);
    expect(find.text('Model Configs'), findsOneWidget);
    expect(find.text('Max Tokens'), findsOneWidget);
    expect(find.text('GPU'), findsOneWidget);
  });
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
