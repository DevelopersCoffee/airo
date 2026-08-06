import 'dart:async';

import 'package:feature_assistant/src/agent_chat/application/assistant_model_preferences.dart';
import 'package:feature_assistant/src/agent_chat/data/services/assistant_runtime_service.dart';
import 'package:feature_assistant/src/agent_chat/domain/models/assistant_runtime_ids.dart';
import 'package:feature_assistant/src/agent_chat/presentation/screens/model_library_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regression cover for the setup dialog that gates the local chat runtime.
///
/// Found on the rig Pixel 9: "Start chat" reached "Runtime ready 100%" and then
/// stayed there forever. Cancel did nothing and Android back dropped the user
/// back on the project list without ever opening chat. The library provider
/// refreshes while the runtime prepares, which unmounts
/// `_ModelLibraryContent`; the old code read `context.mounted` after the await
/// to decide whether to close the dialog and whether to select the model, so
/// both were skipped.
void main() {
  const candidate = AssistantModelCandidate(
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
    deviceLabel: 'Pixel 9',
    platformLabel: 'ANDROID',
    candidates: const [candidate],
    recommended: candidate,
    defaultPackages: const {},
  );

  testWidgets(
    'a library refresh while the runtime prepares still closes the setup '
    'dialog and launches the selected runtime',
    (tester) async {
      SharedPreferences.setMockInitialValues({});

      final warmupGate = Completer<bool>();
      final runtimeService = AssistantRuntimeService(
        isGeminiNanoSupported: () async => true,
        initializeGeminiNano: () async => true,
        // Holds preparation open so the library can refresh mid-flight.
        warmupGeminiNano: () => warmupGate.future,
        loadDeviceInfo: () async => {
          'manufacturer': 'Google',
          'model': 'Pixel 9',
          'platform': 'android',
        },
      );

      var selectedCandidates = 0;

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
              onModelSelected: (_) => selectedCandidates++,
              onOpenModelManager: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(ModelLibraryScreen)),
      );

      await tester.tap(find.text('Start chat'));
      await tester.pump();
      expect(
        find.text('General Chat setup'),
        findsOneWidget,
        reason: 'preparation dialog should be showing while warmup is pending',
      );

      // The library reloads while the runtime is still warming up — this is
      // what unmounts the content subtree on device.
      container.invalidate(assistantModelLibraryProvider);
      await tester.pump();

      warmupGate.complete(true);
      await tester.pumpAndSettle();

      expect(
        find.text('General Chat setup'),
        findsNothing,
        reason:
            'the dialog must close once preparation finishes, otherwise the '
            'user is stuck on an undismissable 100% progress dialog',
      );
      expect(
        container.read(selectedAssistantModelIdProvider),
        geminiNanoAssistantModelId,
        reason: 'a ready runtime must be selected so chat can open',
      );
      expect(selectedCandidates, 1);
    },
  );

  testWidgets('cancel closes the setup dialog while preparation is pending', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    final warmupGate = Completer<bool>();
    final runtimeService = AssistantRuntimeService(
      isGeminiNanoSupported: () async => true,
      initializeGeminiNano: () async => true,
      warmupGeminiNano: () => warmupGate.future,
      loadDeviceInfo: () async => {
        'manufacturer': 'Google',
        'model': 'Pixel 9',
        'platform': 'android',
      },
    );

    var selectedCandidates = 0;

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
            onModelSelected: (_) => selectedCandidates++,
            onOpenModelManager: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start chat'));
    await tester.pump();
    expect(find.text('General Chat setup'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(
      find.text('General Chat setup'),
      findsNothing,
      reason: 'cancel must dismiss the dialog immediately, not only flag it',
    );

    warmupGate.complete(true);
    await tester.pumpAndSettle();

    expect(
      selectedCandidates,
      0,
      reason: 'a cancelled preparation must not launch the runtime',
    );
  });
}

class _SelectedAssistantModelNotifier extends SelectedAssistantModelNotifier {
  _SelectedAssistantModelNotifier() {
    state = null;
  }
}
