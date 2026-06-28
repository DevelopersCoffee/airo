import 'package:airo_app/features/agent_chat/application/assistant_model_preferences.dart';
import 'package:airo_app/features/agent_chat/data/services/assistant_runtime_service.dart';
import 'package:airo_app/features/agent_chat/domain/models/assistant_runtime_ids.dart';
import 'package:airo_app/features/agent_chat/presentation/screens/model_library_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'shows diagnostics instead of launching unsupported local runtime',
    (tester) async {
      SharedPreferences.setMockInitialValues({});

      final candidate = const AssistantModelCandidate(
        id: geminiNanoAssistantModelId,
        name: 'Gemini Nano',
        runtime: 'AICore on-device',
        description: 'Local runtime',
        bestFor: [AssistantTask.chat],
        tags: ['Local'],
        privacyLabel: 'Prompt stays on device',
        sizeLabel: 'System managed',
        available: true,
        actionLabel: 'Start chat',
        local: true,
      );

      final state = AssistantModelLibraryState(
        task: AssistantTask.chat,
        deviceLabel: 'Pixel 8',
        platformLabel: 'ANDROID',
        candidates: [candidate],
        recommended: candidate,
        defaultPackages: const {},
      );

      var selected = false;
      final runtimeService = AssistantRuntimeService(
        isGeminiNanoSupported: () async => false,
        loadDeviceInfo: () async => {
          'manufacturer': 'Google',
          'model': 'Pixel 8',
          'platform': 'android',
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            assistantModelLibraryProvider.overrideWith((ref) async => state),
            selectedAssistantModelIdProvider.overrideWith(
              (ref) => _SelectedAssistantModelNotifier(),
            ),
          ],
          child: MaterialApp(
            home: ModelLibraryScreen(
              runtimeService: runtimeService,
              onModelSelected: (_) => selected = true,
              onOpenModelManager: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('Start chat'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(
        find.text('Gemini Nano is not supported on this device.'),
        findsOneWidget,
      );
      expect(find.text('Copy diagnostics'), findsOneWidget);
      expect(selected, isFalse);
    },
  );
}

class _SelectedAssistantModelNotifier extends SelectedAssistantModelNotifier {
  _SelectedAssistantModelNotifier() {
    state = null;
  }
}
