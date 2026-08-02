import 'dart:async';

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

  testWidgets('queued downloads show their queue position', (tester) async {
    SharedPreferences.setMockInitialValues({});

    final registry =
        _FakeModelRegistry(
          compatibilityByModelId: {
            'gemma-queued': ModelCompatibilityResult.compatible(
              MemorySeverity.safe,
            ),
          },
        )..registerModel(
          const OfflineModelInfo(
            id: 'gemma-queued',
            name: 'Gemma Queued',
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
                'gemma-queued': const ModelDownloadProgress(
                  modelId: 'gemma-queued',
                  totalBytes: 100,
                  downloadedBytes: 0,
                  status: ModelDownloadStatus.pending,
                  queuePosition: 1,
                ),
              },
          ),
        ],
        child: const MaterialApp(home: AIModelsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Queued #2'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        RegExp(r'Download progress: Queued #2 0 percent\.'),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'model card actions route through download manager and registry',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final downloadService = _FakeModelDownloadService();
      final registry =
          _FakeModelRegistry(
            compatibilityByModelId: {
              'gemma-action': ModelCompatibilityResult.compatible(
                MemorySeverity.safe,
              ),
            },
          )..registerModel(
            const OfflineModelInfo(
              id: 'gemma-action',
              name: 'Gemma Action',
              family: ModelFamily.gemma,
              fileSizeBytes: 1024,
              downloadUrl: 'https://example.com/gemma.gguf',
              provider: AIProvider.gemma,
            ),
          );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            modelRegistryProvider.overrideWithValue(registry),
            modelDownloadServiceProvider.overrideWithValue(downloadService),
          ],
          child: const MaterialApp(home: AIModelsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Download'));
      await tester.pumpAndSettle();
      expect(downloadService.downloadedModelIds, contains('gemma-action'));
      expect(find.text('Starting download: Gemma Action'), findsOneWidget);

      await tester.tap(find.byType(Card).first);
      await tester.pumpAndSettle();
      expect(find.text('Specifications'), findsOneWidget);
    },
  );

  testWidgets('active download controls call pause resume retry and cancel', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final downloadService = _FakeModelDownloadService();
    final registry =
        _FakeModelRegistry(
          compatibilityByModelId: {
            'gemma-progress': ModelCompatibilityResult.compatible(
              MemorySeverity.safe,
            ),
          },
        )..registerModel(
          const OfflineModelInfo(
            id: 'gemma-progress',
            name: 'Gemma Progress',
            family: ModelFamily.gemma,
            fileSizeBytes: 2048,
            provider: AIProvider.gemma,
          ),
        );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          modelRegistryProvider.overrideWithValue(registry),
          modelDownloadServiceProvider.overrideWithValue(downloadService),
          activeDownloadsProvider.overrideWith(
            (ref) => ActiveDownloadsNotifier(ref)
              ..state = {
                'gemma-progress': const ModelDownloadProgress(
                  modelId: 'gemma-progress',
                  totalBytes: 100,
                  downloadedBytes: 50,
                  status: ModelDownloadStatus.downloading,
                  resumeSupported: true,
                ),
              },
          ),
        ],
        child: const MaterialApp(home: AIModelsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byTooltip('Pause download'));
    await tester.pump();
    await tester.tap(find.byTooltip('Cancel download'));
    await tester.pump();

    expect(downloadService.pausedModelIds, contains('gemma-progress'));
    expect(downloadService.cancelledModelIds, contains('gemma-progress'));
  });

  testWidgets('failed downloads expose retry through the download manager', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final downloadService = _FakeModelDownloadService();
    final registry =
        _FakeModelRegistry(
          compatibilityByModelId: {
            'gemma-progress': ModelCompatibilityResult.compatible(
              MemorySeverity.safe,
            ),
          },
        )..registerModel(
          const OfflineModelInfo(
            id: 'gemma-progress',
            name: 'Gemma Progress',
            family: ModelFamily.gemma,
            fileSizeBytes: 2048,
            provider: AIProvider.gemma,
          ),
        );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          modelRegistryProvider.overrideWithValue(registry),
          modelDownloadServiceProvider.overrideWithValue(downloadService),
          activeDownloadsProvider.overrideWith(
            (ref) => ActiveDownloadsNotifier(ref)
              ..state = {
                'gemma-progress': const ModelDownloadProgress(
                  modelId: 'gemma-progress',
                  totalBytes: 100,
                  downloadedBytes: 50,
                  status: ModelDownloadStatus.failed,
                  resumeSupported: false,
                ),
              },
          ),
        ],
        child: const MaterialApp(home: AIModelsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byTooltip('Retry download'));
    await tester.pump();
    expect(downloadService.retriedModelIds, contains('gemma-progress'));
  });

  testWidgets('stalled downloads expose retry instead of pause', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final downloadService = _FakeModelDownloadService();
    final registry =
        _FakeModelRegistry(
          compatibilityByModelId: {
            'gemma-stalled': ModelCompatibilityResult.compatible(
              MemorySeverity.safe,
            ),
          },
        )..registerModel(
          const OfflineModelInfo(
            id: 'gemma-stalled',
            name: 'Gemma Stalled',
            family: ModelFamily.gemma,
            fileSizeBytes: 2048,
            provider: AIProvider.gemma,
          ),
        );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          modelRegistryProvider.overrideWithValue(registry),
          modelDownloadServiceProvider.overrideWithValue(downloadService),
          activeDownloadsProvider.overrideWith(
            (ref) => ActiveDownloadsNotifier(ref)
              ..state = {
                'gemma-stalled': ModelDownloadProgress(
                  modelId: 'gemma-stalled',
                  totalBytes: 100,
                  downloadedBytes: 50,
                  status: ModelDownloadStatus.downloading,
                  speedBytesPerSecond: 0,
                  lastProgressAt: DateTime.now().subtract(
                    const Duration(minutes: 5),
                  ),
                ),
              },
          ),
        ],
        child: const MaterialApp(home: AIModelsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Stalled'), findsOneWidget);
    expect(find.textContaining('No throughput'), findsOneWidget);
    expect(find.byTooltip('Pause download'), findsNothing);
    await tester.tap(find.byTooltip('Retry download'));
    await tester.pump();
    expect(downloadService.retriedModelIds, contains('gemma-stalled'));
  });

  testWidgets('downloaded models can be activated and deleted', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final downloadService = _FakeModelDownloadService(deleteResult: true);
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
          modelDownloadServiceProvider.overrideWithValue(downloadService),
        ],
        child: const MaterialApp(home: AIModelsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Downloaded'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Set Active'));
    await tester.pumpAndSettle();
    expect(find.text('Gemma Downloaded is now active'), findsOneWidget);

    await tester.tap(find.byTooltip('Delete model Gemma Downloaded'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(downloadService.deletedModelIds, contains('gemma-downloaded'));
    expect(registry.getModel('gemma-downloaded')?.isDownloaded, isFalse);
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
  _FakeModelDownloadService({this.deleteResult = false});

  final bool deleteResult;
  final downloadedModelIds = <String>[];
  final pausedModelIds = <String>[];
  final resumedModelIds = <String>[];
  final retriedModelIds = <String>[];
  final cancelledModelIds = <String>[];
  final deletedModelIds = <String>[];
  final _progressController =
      StreamController<ModelDownloadProgress>.broadcast();

  void resetActionLog() {
    pausedModelIds.clear();
    resumedModelIds.clear();
    retriedModelIds.clear();
    cancelledModelIds.clear();
  }

  @override
  Stream<ModelDownloadProgress> get globalProgressStream =>
      _progressController.stream;

  @override
  Stream<ModelDownloadProgress> downloadModel(OfflineModelInfo model) {
    downloadedModelIds.add(model.id);
    return const Stream<ModelDownloadProgress>.empty();
  }

  @override
  Future<void> pauseDownload(String modelId) async {
    pausedModelIds.add(modelId);
  }

  @override
  Future<void> resumeDownload(String modelId) async {
    resumedModelIds.add(modelId);
  }

  @override
  Future<void> retryDownload(String modelId, {OfflineModelInfo? model}) async {
    retriedModelIds.add(modelId);
  }

  @override
  Future<void> cancelDownload(String modelId) async {
    cancelledModelIds.add(modelId);
  }

  @override
  Future<List<ModelDownloadProgress>> restoreQueue({
    Iterable<OfflineModelInfo> catalogModels = const <OfflineModelInfo>[],
  }) async {
    return const <ModelDownloadProgress>[];
  }

  @override
  Future<bool> deleteModel(String modelId) async {
    deletedModelIds.add(modelId);
    return deleteResult;
  }

  @override
  Future<void> dispose() async {
    await _progressController.close();
    await super.dispose();
  }
}
