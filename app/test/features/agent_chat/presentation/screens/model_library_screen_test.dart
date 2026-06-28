import 'package:airo_app/features/agent_chat/application/assistant_model_preferences.dart';
import 'package:airo_app/features/agent_chat/data/services/assistant_runtime_service.dart';
import 'package:airo_app/features/agent_chat/domain/models/assistant_runtime_ids.dart';
import 'package:airo_app/features/agent_chat/presentation/screens/model_library_screen.dart';
import 'package:core_ai/core_ai.dart';
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

  testWidgets('project cards do not overflow on narrow mobile widths', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(360, 900);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    SharedPreferences.setMockInitialValues({});

    final package = OfflineModelInfo(
      id: 'mobile-actions-270m-litertlm',
      name: 'MobileActions-270M',
      family: ModelFamily.gemma,
      fileSizeBytes: 276 * 1024 * 1024,
      backendPreference: ModelBackendPreference.npu,
      provider: AIProvider.gemma,
      capabilities: const [ModelCapability.mobileActions],
      learnMoreUrl: 'https://example.com/models/mobile-actions',
    );

    final candidate = AssistantModelCandidate(
      id: 'litert-gemma',
      name: 'Gemma mobile package',
      runtime: 'LiteRT-LM local model',
      description:
          'Default local package for planning, documents, and medium reasoning.',
      bestFor: const [AssistantTask.chat],
      tags: const ['Local', 'Downloadable', 'Gemma'],
      privacyLabel: 'Prompt stays on device',
      sizeLabel: '2 GB to 4 GB typical',
      available: false,
      actionLabel: 'Download package',
      unavailableReason:
          'Set LITERT_LM_MODEL_PATH or LITERT_LM_MODEL_URL, or install a compatible local model.',
      local: true,
      opensModelManager: true,
      package: package,
    );

    final state = AssistantModelLibraryState(
      task: AssistantTask.chat,
      deviceLabel: 'Pixel 9',
      platformLabel: 'ANDROID',
      candidates: [candidate],
      recommended: candidate,
      defaultPackages: {AssistantTask.chat: package},
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
            onModelSelected: (_) {},
            onOpenModelManager: () {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('General Chat'), findsOneWidget);
    expect(find.text('Download package'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

class _SelectedAssistantModelNotifier extends SelectedAssistantModelNotifier {
  _SelectedAssistantModelNotifier() {
    state = null;
  }
}
