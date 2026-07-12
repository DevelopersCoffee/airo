import 'package:airo_app/features/settings/application/ai_model_management.dart';
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

  testWidgets('downloaded tab refreshes after registry hydration updates', (
    tester,
  ) async {
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

    expect(find.text('Gemma Downloaded'), findsNothing);
    expect(find.textContaining('No downloaded models yet'), findsOneWidget);

    registry.markAsDownloaded('gemma-downloaded', '/models/gemma.gguf');
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Gemma Downloaded'), findsOneWidget);
  });

  testWidgets('shows stage, speed, eta, and percentage for active downloads', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    final registry =
        _FakeModelRegistry(
          compatibilityByModelId: {
            'gemma-download': ModelCompatibilityResult.compatible(
              MemorySeverity.safe,
            ),
          },
        )..registerModel(
          const OfflineModelInfo(
            id: 'gemma-download',
            name: 'Gemma Download',
            family: ModelFamily.gemma,
            fileSizeBytes: 2048,
            provider: AIProvider.gemma,
          ),
        );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          modelRegistryProvider.overrideWithValue(registry),
          activeDownloadsProvider.overrideWith(
            (ref) => ActiveDownloadsNotifier(ref)
              ..state = {
                'gemma-download': const ModelDownloadProgress(
                  modelId: 'gemma-download',
                  totalBytes: 300,
                  downloadedBytes: 200,
                  status: ModelDownloadStatus.verifying,
                  speedBytesPerSecond: 2.5 * 1024 * 1024,
                ),
              },
          ),
        ],
        child: const MaterialApp(home: AIModelsScreen()),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Verifying'), findsOneWidget);
    expect(find.text('67%'), findsOneWidget);
    expect(find.textContaining('2.5 MB/s'), findsOneWidget);
    expect(find.textContaining('remaining'), findsOneWidget);
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
