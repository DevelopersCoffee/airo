import 'package:airo_app/features/settings/application/ai_model_management.dart';
import 'package:airo_app/features/agent_chat/application/assistant_model_preferences.dart';
import 'package:airo_app/features/agent_chat/domain/models/assistant_model_selection.dart';
import 'package:airo_app/features/settings/presentation/screens/ai_models_screen.dart';
import 'package:core_ai/core_ai.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('compatible-only filter hides incompatible models', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    final registry =
        _FakeModelRegistry(
          compatibilityByModelId: {
            'gemma-safe': ModelCompatibilityResult.compatible(
              MemorySeverity.safe,
            ),
            'gemma-huge': ModelCompatibilityResult.incompatible(
              'Insufficient memory.',
            ),
          },
        )..registerModels([
          const OfflineModelInfo(
            id: 'gemma-safe',
            name: 'Gemma Safe',
            family: ModelFamily.gemma,
            fileSizeBytes: 1024,
            provider: AIProvider.gemma,
          ),
          const OfflineModelInfo(
            id: 'gemma-huge',
            name: 'Gemma Huge',
            family: ModelFamily.gemma,
            fileSizeBytes: 2048,
            provider: AIProvider.gemma,
          ),
        ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [modelRegistryProvider.overrideWithValue(registry)],
        child: const MaterialApp(home: AIModelsScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Gemma Safe'), findsOneWidget);
    expect(find.text('Gemma Huge'), findsOneWidget);
    expect(find.text('May exceed device memory'), findsOneWidget);

    await tester.tap(find.text('Compatible only'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Gemma Safe'), findsOneWidget);
    expect(find.text('Gemma Huge'), findsNothing);
  });

  testWidgets('downloaded tab shows the active badge for selected models', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'selected_offline_model_id': 'gemma-downloaded',
    });

    final registry =
        _FakeModelRegistry(
          compatibilityByModelId: {
            'gemma-downloaded': ModelCompatibilityResult.compatible(
              MemorySeverity.safe,
            ),
          },
        )..registerModel(
          const OfflineModelInfo(
            id: 'gemma-downloaded',
            name: 'Gemma Downloaded',
            family: ModelFamily.gemma,
            fileSizeBytes: 1024,
            filePath: '/models/gemma-downloaded.gguf',
            provider: AIProvider.gemma,
          ),
        );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [modelRegistryProvider.overrideWithValue(registry)],
        child: const MaterialApp(home: AIModelsScreen()),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Downloaded'));
    await tester.pumpAndSettle();

    expect(find.text('Gemma Downloaded'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
  });

  testWidgets('downloaded tab can activate a downloaded model', (tester) async {
    SharedPreferences.setMockInitialValues({});

    final registry =
        _FakeModelRegistry(
          compatibilityByModelId: {
            'gemma-downloaded': ModelCompatibilityResult.compatible(
              MemorySeverity.safe,
            ),
          },
        )..registerModel(
          const OfflineModelInfo(
            id: 'gemma-downloaded',
            name: 'Gemma Downloaded',
            family: ModelFamily.gemma,
            fileSizeBytes: 1024,
            filePath: '/models/gemma-downloaded.gguf',
            provider: AIProvider.gemma,
          ),
        );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [modelRegistryProvider.overrideWithValue(registry)],
        child: const MaterialApp(home: AIModelsScreen()),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Downloaded'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Set Active'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(AIModelsScreen)),
    );
    expect(container.read(selectedModelIdProvider), 'gemma-downloaded');
    expect(
      container.read(selectedAssistantModelIdProvider),
      assistantModelIdForOfflineModel('gemma-downloaded'),
    );
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Gemma Downloaded is now active'), findsOneWidget);
  });

  testWidgets('deleting an active model clears both offline selections', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'selected_offline_model_id': 'gemma-downloaded',
      selectedAssistantModelKey: assistantModelIdForOfflineModel(
        'gemma-downloaded',
      ),
    });

    final registry =
        _FakeModelRegistry(
          compatibilityByModelId: {
            'gemma-downloaded': ModelCompatibilityResult.compatible(
              MemorySeverity.safe,
            ),
          },
        )..registerModel(
          const OfflineModelInfo(
            id: 'gemma-downloaded',
            name: 'Gemma Downloaded',
            family: ModelFamily.gemma,
            fileSizeBytes: 1024,
            filePath: '/models/gemma-downloaded.gguf',
            provider: AIProvider.gemma,
          ),
        );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          modelRegistryProvider.overrideWithValue(registry),
          modelDownloadServiceProvider.overrideWithValue(
            _FakeModelDownloadService(deleteResult: true),
          ),
        ],
        child: const MaterialApp(home: AIModelsScreen()),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Downloaded'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Delete model'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(AIModelsScreen)),
    );
    expect(container.read(selectedModelIdProvider), isNull);
    expect(container.read(selectedAssistantModelIdProvider), isNull);
    expect(find.text('Gemma Downloaded deleted successfully'), findsOneWidget);
    expect(find.text('Gemma Downloaded'), findsNothing);
  });
}

class _FakeModelRegistry extends ModelRegistry {
  _FakeModelRegistry({required this.compatibilityByModelId});

  final Map<String, ModelCompatibilityResult> compatibilityByModelId;

  @override
  Future<ModelCompatibilityResult> checkCompatibility(
    OfflineModelInfo model,
  ) async {
    return compatibilityByModelId[model.id] ??
        ModelCompatibilityResult.compatible(MemorySeverity.safe);
  }
}

class _FakeModelDownloadService extends ModelDownloadService {
  _FakeModelDownloadService({required this.deleteResult});

  final bool deleteResult;

  @override
  Future<bool> deleteModel(String modelId) async => deleteResult;
}
