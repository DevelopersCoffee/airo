import 'package:airo_app/core/services/local_runtime_preloader_service.dart';
import 'package:airo_app/features/agent_chat/application/assistant_model_preferences.dart';
import 'package:airo_app/features/agent_chat/domain/models/assistant_runtime_ids.dart';
import 'package:airo_app/features/agent_chat/presentation/screens/chat_screen.dart';
import 'package:airo_app/features/agent_chat/presentation/screens/model_library_screen.dart';
import 'package:core_ai/core_ai.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('chat initialization triggers the global local preloader', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'selected_assistant_model_id': geminiNanoAssistantModelId,
    });
    const channel = MethodChannel('com.airo.gemini_nano');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'isAvailable') {
            return false;
          }
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final preloader = _RecordingPreloader();
    const recommended = AssistantModelCandidate(
      id: geminiNanoAssistantModelId,
      name: 'Gemini Nano',
      runtime: 'AICore on-device',
      description: 'Local runtime',
      bestFor: [AssistantTask.chat],
      tags: ['Local'],
      privacyLabel: 'Prompt stays on device',
      sizeLabel: 'System managed',
      available: true,
      actionLabel: 'Start',
      local: true,
    );

    final localPreloader = LocalRuntimePreloaderService(
      preloader: preloader,
      loadAssistantModelLibrary: () async => const AssistantModelLibraryState(
        task: AssistantTask.chat,
        deviceLabel: 'Pixel 9',
        platformLabel: 'ANDROID',
        candidates: [recommended],
        recommended: recommended,
        defaultPackages: {},
      ),
      selectedModelId: () => geminiNanoAssistantModelId,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          selectedAssistantModelIdProvider.overrideWith(
            (ref) => _SelectedAssistantModelNotifier(),
          ),
        ],
        child: MaterialApp(
          home: ChatScreen(
            localRuntimePreloader: localPreloader,
            enableAiInitialization: true,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 10));

    expect(preloader.invoked, isTrue);
  });
}

class _SelectedAssistantModelNotifier extends SelectedAssistantModelNotifier {
  _SelectedAssistantModelNotifier() {
    state = geminiNanoAssistantModelId;
  }
}

class _RecordingPreloader extends ModelPreloader {
  _RecordingPreloader()
    : super(
        residencyManager: ModelResidencyManager(loadBudgetBytes: () async => 1),
      );

  bool invoked = false;

  @override
  Future<ModelPreloadReport> preloadSelectedModels({
    required List<ModelWarmupAdapter> adapters,
  }) async {
    invoked = true;
    return ModelPreloadReport(
      entries: const [],
      startedAt: DateTime(2026, 6, 28),
      finishedAt: DateTime(2026, 6, 28),
      aborted: false,
    );
  }
}
