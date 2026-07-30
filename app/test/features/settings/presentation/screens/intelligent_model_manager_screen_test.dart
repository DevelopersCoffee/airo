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

  testWidgets('renders empty snapshot state', (tester) async {
    final downloads = _MockDownloadService();
    when(
      () => downloads.globalProgressStream,
    ).thenAnswer((_) => const Stream<ModelDownloadProgress>.empty());
    when(
      () => downloads.restoreQueue(catalogModels: any(named: 'catalogModels')),
    ).thenAnswer((_) async => []);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          modelRegistryProvider.overrideWithValue(ModelRegistry()),
          modelDownloadServiceProvider.overrideWithValue(downloads),
          intelligentModelManagerSnapshotProvider.overrideWith(
            (ref) async => const ModelManagerSnapshot(
              models: [],
              downloadQueue: [],
              storageUsedBytes: 0,
            ),
          ),
          activeDownloadsProvider.overrideWith(
            (ref) => ActiveDownloadsNotifier(ref)..state = const {},
          ),
        ],
        child: const MaterialApp(home: IntelligentModelManagerScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('No models found in the catalog.'), findsOneWidget);
  });

  testWidgets('starts a download for a catalog model that is not installed', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const modelInfo = OfflineModelInfo(
      id: 'downloadable',
      name: 'Downloadable Model',
      family: ModelFamily.gemma,
      fileSizeBytes: 734003200,
      parameterCount: 270000000,
      contextLength: 2048,
      author: 'Airo',
      description: 'Small local action model.',
    );
    final registry = ModelRegistry()..registerModel(modelInfo);
    const snapshot = ModelManagerSnapshot(
      models: [
        ModelEntry(
          id: 'downloadable',
          name: 'Downloadable Model',
          version: 'Unversioned',
          description: 'Small local action model.',
          sizeBytes: 734003200,
          updateState: ModelUpdateState.notInstalled,
        ),
      ],
      downloadQueue: [],
      storageUsedBytes: 0,
    );
    final downloads = _MockDownloadService();
    when(
      () => downloads.globalProgressStream,
    ).thenAnswer((_) => const Stream<ModelDownloadProgress>.empty());
    when(
      () => downloads.restoreQueue(catalogModels: any(named: 'catalogModels')),
    ).thenAnswer((_) async => []);
    when(
      () => downloads.downloadModel(modelInfo),
    ).thenAnswer((_) => const Stream<ModelDownloadProgress>.empty());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          modelRegistryProvider.overrideWithValue(registry),
          modelDownloadServiceProvider.overrideWithValue(downloads),
          intelligentModelManagerSnapshotProvider.overrideWith(
            (ref) async => snapshot,
          ),
          activeDownloadsProvider.overrideWith(
            (ref) => ActiveDownloadsNotifier(ref)..state = const {},
          ),
        ],
        child: const MaterialApp(home: IntelligentModelManagerScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Size'), findsOneWidget);
    expect(find.text('0.7 GB'), findsOneWidget);
    expect(find.text('270.0M'), findsOneWidget);
    await tester.tap(find.text('Download Model (0.7 GB)'));
    await tester.pump();

    verify(() => downloads.downloadModel(modelInfo)).called(1);
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
    final registry = ModelRegistry(
      loadMemoryInfo: () async =>
          MemoryInfo.fromMegabytes(totalMB: 8192, availableMB: 4096),
    )..registerModels([installedInfo, queuedInfo]);
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
    when(
      () => downloads.retryDownload('queued', model: queuedInfo),
    ).thenAnswer((_) async {});
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
    await tester.ensureVisible(find.text('Why?'));
    await tester.tap(find.text('Why?'));
    await tester.pumpAndSettle();
    expect(find.text('Runtime Health Center'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Preload when frequently used'));
    await tester.tap(find.text('Preload when frequently used'));
    await tester.pump();
    await tester.ensureVisible(find.byTooltip('Delete Model'));
    await tester.tap(find.byTooltip('Delete Model'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();

    verify(
      () => downloads.retryDownload('queued', model: queuedInfo),
    ).called(1);
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

  testWidgets('activates and benchmarks an installed inactive model', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const modelInfo = OfflineModelInfo(
      id: 'inactive',
      name: 'Inactive Model',
      family: ModelFamily.gemma,
      fileSizeBytes: 123456789,
      parameterCount: 1500000000,
      contextLength: 4096,
      filePath: '/models/inactive.task',
      description: 'Installed and ready.',
    );
    final registry = ModelRegistry(
      loadMemoryInfo: () async =>
          MemoryInfo.fromMegabytes(totalMB: 8192, availableMB: 4096),
    )..registerModel(modelInfo);
    const snapshot = ModelManagerSnapshot(
      models: [
        ModelEntry(
          id: 'inactive',
          name: 'Inactive Model',
          version: 'Unversioned',
          description: 'Installed and ready.',
          sizeBytes: 123456789,
          isDownloaded: true,
          updateState: ModelUpdateState.unknown,
        ),
      ],
      downloadQueue: [],
      storageUsedBytes: 123456789,
    );
    final downloads = _MockDownloadService();
    final manager = _MockManager();
    when(
      () => downloads.globalProgressStream,
    ).thenAnswer((_) => const Stream<ModelDownloadProgress>.empty());
    when(
      () => downloads.restoreQueue(catalogModels: any(named: 'catalogModels')),
    ).thenAnswer((_) async => []);
    when(() => manager.activateModel('inactive')).thenAnswer((_) async {});
    when(() => manager.warmModel('inactive')).thenAnswer(
      (_) async => const ModelWarmupResult(
        modelId: 'inactive',
        status: ModelWarmupStatus.warmed,
      ),
    );
    when(
      () => manager.setPreloadFrequentlyUsed('inactive', true),
    ).thenAnswer((_) async {});

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
            (ref) => ActiveDownloadsNotifier(ref)..state = const {},
          ),
        ],
        child: const MaterialApp(home: IntelligentModelManagerScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Version unknown'), findsOneWidget);
    expect(find.text('1.5B'), findsOneWidget);
    expect(find.text('4096 tokens'), findsOneWidget);

    await tester.ensureVisible(find.text('Activate'));
    await tester.tap(find.text('Activate'));
    await tester.pump();
    await tester.ensureVisible(find.text('Benchmark'));
    await tester.tap(find.text('Benchmark'));
    await tester.pump();
    await tester.ensureVisible(find.text('Preload when frequently used'));
    await tester.tap(find.text('Preload when frequently used'));
    await tester.pump();

    verify(() => manager.activateModel('inactive')).called(1);
    verify(() => manager.warmModel('inactive')).called(1);
    verify(() => manager.setPreloadFrequentlyUsed('inactive', true)).called(1);
    expect(find.textContaining('Warm-up benchmark:'), findsOneWidget);
  });
}
