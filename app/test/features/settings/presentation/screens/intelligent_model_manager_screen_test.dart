import 'package:airo_app/features/settings/application/ai_model_management.dart';
import 'package:airo_app/features/settings/presentation/intelligent_model_manager_provider.dart';
import 'package:airo_app/features/settings/presentation/screens/intelligent_model_manager_screen.dart';
import 'package:core_ai/core_ai.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDownloadService extends Mock implements ModelDownloadService {}

class _MockManager extends Mock implements IntelligentModelManager {}

void main() {
  setUpAll(() {
    registerFallbackValue(<OfflineModelInfo>[]);
  });

  testWidgets('renders complete manager state and wires lifecycle controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const installedInfo = OfflineModelInfo(
      id: 'installed',
      name: 'Installed Model',
      family: ModelFamily.gemma,
      fileSizeBytes: 1024,
      version: '2.0.0',
      filePath: '/private/models/installed.gguf',
    );
    const queuedInfo = OfflineModelInfo(
      id: 'queued',
      name: 'Queued Model',
      family: ModelFamily.gemma,
      fileSizeBytes: 2048,
    );
    final registry = ModelRegistry()
      ..registerModels([installedInfo, queuedInfo]);
    const failedProgress = ModelDownloadProgress(
      modelId: 'queued',
      totalBytes: 2048,
      downloadedBytes: 512,
      status: ModelDownloadStatus.failed,
      failureCode: 'transport',
      error: 'Download was interrupted.',
      resumeSupported: true,
      queuePosition: 0,
    );
    const snapshot = ModelManagerSnapshot(
      models: [
        ModelEntry(
          id: 'installed',
          name: 'Installed Model',
          version: '2.0.0',
          installedVersion: '1.0.0',
          description: 'Ready locally.',
          sizeBytes: 1024,
          isDownloaded: true,
          isActive: true,
          isRecommended: true,
          preloadFrequentlyUsed: true,
          isResident: true,
          updateState: ModelUpdateState.updateAvailable,
        ),
        ModelEntry(
          id: 'queued',
          name: 'Queued Model',
          version: 'Unversioned',
          description: 'Waiting to retry.',
          sizeBytes: 2048,
          updateState: ModelUpdateState.notInstalled,
        ),
      ],
      downloadQueue: [failedProgress],
      storageUsedBytes: 1024,
    );
    final downloads = _MockDownloadService();
    final manager = _MockManager();
    when(
      () => downloads.globalProgressStream,
    ).thenAnswer((_) => const Stream<ModelDownloadProgress>.empty());
    when(
      () => downloads.restoreQueue(catalogModels: any(named: 'catalogModels')),
    ).thenAnswer((_) async => []);
    when(() => downloads.retryDownload('queued')).thenAnswer((_) async {});
    when(() => downloads.resumeDownload('queued')).thenAnswer((_) async {});
    when(() => downloads.cancelDownload('queued')).thenAnswer((_) async {});
    when(
      () => downloads.downloadModel(installedInfo),
    ).thenAnswer((_) => const Stream<ModelDownloadProgress>.empty());
    when(() => manager.warmModel('installed')).thenAnswer(
      (_) async => const ModelWarmupResult(
        modelId: 'installed',
        status: ModelWarmupStatus.alreadyResident,
      ),
    );
    when(
      () => manager.setPreloadFrequentlyUsed('installed', false),
    ).thenAnswer((_) async {});
    when(() => manager.deleteModel('installed')).thenAnswer((_) async {});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          modelRegistryProvider.overrideWithValue(registry),
          modelDownloadServiceProvider.overrideWithValue(downloads),
          intelligentModelManagerProvider.overrideWithValue(manager),
          intelligentModelManagerSnapshotProvider.overrideWith(
            (ref) async => snapshot,
          ),
          activeDownloadsProvider.overrideWith(
            (ref) =>
                ActiveDownloadsNotifier(ref)
                  ..state = {'queued': failedProgress},
          ),
        ],
        child: const MaterialApp(home: IntelligentModelManagerScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Installed: 1'), findsOneWidget);
    expect(find.text('Download queue'), findsOneWidget);
    expect(find.text('Recommended'), findsOneWidget);
    expect(find.text('Update available'), findsOneWidget);
    expect(find.text('Warm'), findsOneWidget);
    expect(find.text('Preload when frequently used'), findsOneWidget);
    expect(find.textContaining('/private/'), findsNothing);

    await tester.ensureVisible(find.byTooltip('Retry'));
    await tester.tap(find.byTooltip('Retry'));
    await tester.tap(find.byTooltip('Resume'));
    await tester.tap(find.byTooltip('Cancel'));
    await tester.ensureVisible(find.text('Update'));
    await tester.tap(find.text('Update'));
    await tester.ensureVisible(find.text('Warm now'));
    await tester.tap(find.text('Warm now'));
    await tester.pump();
    await tester.ensureVisible(find.text('Preload when frequently used'));
    await tester.tap(find.text('Preload when frequently used'));
    await tester.pump();
    await tester.ensureVisible(find.byTooltip('Delete Model'));
    await tester.tap(find.byTooltip('Delete Model'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();

    verify(() => downloads.retryDownload('queued')).called(1);
    verify(() => downloads.resumeDownload('queued')).called(1);
    verify(() => downloads.cancelDownload('queued')).called(1);
    verify(() => downloads.downloadModel(installedInfo)).called(1);
    verify(() => manager.warmModel('installed')).called(1);
    verify(
      () => manager.setPreloadFrequentlyUsed('installed', false),
    ).called(1);
    verify(() => manager.deleteModel('installed')).called(1);
    expect(find.text('Model is already warm.'), findsOneWidget);
  });
}
