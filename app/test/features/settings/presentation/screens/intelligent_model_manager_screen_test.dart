import 'dart:async';

import 'package:airo_app/features/settings/application/ai_model_management.dart';
import 'package:airo_app/features/settings/presentation/intelligent_model_manager_provider.dart';
import 'package:airo_app/features/settings/presentation/screens/intelligent_model_manager_screen.dart';
import 'package:core_ai/core_ai.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockDownloadService extends Mock implements ModelDownloadService {}

class _MockManager extends Mock implements IntelligentModelManager {}

void main() {
  setUpAll(() {
    registerFallbackValue(<OfflineModelInfo>[]);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
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
        key: UniqueKey(),
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

  testWidgets('renders loading state while snapshot is pending', (
    tester,
  ) async {
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
            (ref) => Completer<ModelManagerSnapshot>().future,
          ),
          activeDownloadsProvider.overrideWith(
            (ref) => ActiveDownloadsNotifier(ref)..state = const {},
          ),
        ],
        child: const MaterialApp(home: IntelligentModelManagerScreen()),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('renders error state for snapshot failures', (tester) async {
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
            (ref) async => throw StateError('catalog unavailable'),
          ),
          activeDownloadsProvider.overrideWith(
            (ref) => ActiveDownloadsNotifier(ref)..state = const {},
          ),
        ],
        child: const MaterialApp(home: IntelligentModelManagerScreen()),
      ),
    );
    await tester.pump();

    expect(find.textContaining('catalog unavailable'), findsOneWidget);
  });

  testWidgets('shows active download progress and pauses the queue item', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? copiedText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final data = Map<String, dynamic>.from(call.arguments as Map);
          copiedText = data['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    const modelInfo = OfflineModelInfo(
      id: 'downloading',
      name: 'Downloading Model',
      family: ModelFamily.gemma,
      fileSizeBytes: 4096,
      description: 'Currently downloading.',
    );
    final registry = ModelRegistry()..registerModel(modelInfo);
    const progress = ModelDownloadProgress(
      modelId: 'downloading',
      totalBytes: 4096,
      downloadedBytes: 2048,
      status: ModelDownloadStatus.downloading,
      speedBytesPerSecond: 512,
      queuePosition: 1,
      resumeSupported: true,
    );
    const queuedProgress = ModelDownloadProgress(
      modelId: 'queued-before',
      totalBytes: 1024,
      downloadedBytes: 0,
      status: ModelDownloadStatus.pending,
      queuePosition: 0,
    );
    const snapshot = ModelManagerSnapshot(
      models: [
        ModelEntry(
          id: 'downloading',
          name: 'Downloading Model',
          version: 'Unversioned',
          description: 'Currently downloading.',
          sizeBytes: 4096,
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
    when(() => downloads.pauseDownload('downloading')).thenAnswer((_) async {});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          modelRegistryProvider.overrideWithValue(registry),
          modelDownloadServiceProvider.overrideWithValue(downloads),
          intelligentModelManagerSnapshotProvider.overrideWith(
            (ref) async => snapshot,
          ),
          activeDownloadsProvider.overrideWith(
            (ref) => ActiveDownloadsNotifier(ref)
              ..state = {
                'downloading': progress,
                'queued-before': queuedProgress,
              },
          ),
        ],
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: const IntelligentModelManagerScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Download queue'), findsOneWidget);
    expect(find.textContaining('#1 queued-before'), findsOneWidget);
    expect(find.textContaining('#2 downloading'), findsOneWidget);
    expect(find.text('Copy diagnostics'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('Copy model manager diagnostics')),
      findsOneWidget,
    );
    await tester.tap(find.text('Copy diagnostics'));
    await tester.pump();

    expect(find.text('Model manager diagnostics copied.'), findsOneWidget);
    expect(copiedText, contains('# Airo Model Manager Diagnostics'));
    expect(copiedText, contains('| Download queue | `2` |'));
    expect(copiedText, contains('- `queued-before`'));
    expect(copiedText, contains('- `downloading`'));
    expect(copiedText, contains('  - Downloaded: `2.0 KB / 4.0 KB`'));
    expect(copiedText, isNot(contains('/Users/')));
    expect(copiedText, isNot(contains('/storage/')));
    ScaffoldMessenger.of(
      tester.element(find.text('Intelligent Model Manager')),
    ).hideCurrentSnackBar();
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsWidgets);
    await tester.ensureVisible(find.byTooltip('Pause'));
    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();

    verify(() => downloads.pauseDownload('downloading')).called(1);
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
    expect(find.text('Download Manager'), findsWidgets);
    expect(find.text('Integrity: verified'), findsOneWidget);
    expect(find.text('Local storage: 1.0 KB'), findsOneWidget);
    expect(find.text('Downloaded: 512 B of 2.0 KB'), findsOneWidget);
    expect(find.text('Resume supported'), findsOneWidget);
    expect(find.text('Failure: Download was interrupted.'), findsOneWidget);
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

  testWidgets('health center recovery actions execute manager callbacks', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const modelInfo = OfflineModelInfo(
      id: 'memory-bound',
      name: 'Memory Bound Model',
      family: ModelFamily.gemma,
      fileSizeBytes: 1024,
      parameterCount: 999,
      contextLength: 4096,
      filePath: '/models/memory-bound.gguf',
      minMemoryBytes: 6 * 1024 * 1024 * 1024,
      description: 'Installed but needs a smaller runtime context.',
    );
    final registry = ModelRegistry(
      loadMemoryInfo: () async =>
          MemoryInfo.fromMegabytes(totalMB: 8192, availableMB: 512),
    )..registerModel(modelInfo);
    const snapshot = ModelManagerSnapshot(
      models: [
        ModelEntry(
          id: 'memory-bound',
          name: 'Memory Bound Model',
          version: 'Unversioned',
          description: 'Installed but needs a smaller runtime context.',
          sizeBytes: 1024,
          isDownloaded: true,
          updateState: ModelUpdateState.unknown,
        ),
      ],
      downloadQueue: [],
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
      () => manager.isModelInstalled('memory-bound'),
    ).thenAnswer((_) async => true);

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

    expect(find.text('999'), findsOneWidget);

    await tester.ensureVisible(find.text('Why?'));
    await tester.tap(find.text('Why?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry with reduced context'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Context reduced to 1024 tokens'),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 4));

    await tester.ensureVisible(find.text('Why?'));
    await tester.tap(find.text('Why?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose another installed model'));
    await tester.pumpAndSettle();
  });

  testWidgets('health center resumes and retries incomplete downloads', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const modelInfo = OfflineModelInfo(
      id: 'stale-path',
      name: 'Stale Path Model',
      family: ModelFamily.gemma,
      fileSizeBytes: 2048,
      filePath: '/models/stale.gguf',
      description: 'Registry says installed, but the file is missing.',
    );
    final registry = ModelRegistry(
      loadMemoryInfo: () async =>
          MemoryInfo.fromMegabytes(totalMB: 8192, availableMB: 4096),
    )..registerModel(modelInfo);
    const snapshot = ModelManagerSnapshot(
      models: [
        ModelEntry(
          id: 'stale-path',
          name: 'Stale Path Model',
          version: 'Unversioned',
          description: 'Registry says installed, but the file is missing.',
          sizeBytes: 2048,
          isDownloaded: true,
          updateState: ModelUpdateState.unknown,
        ),
      ],
      downloadQueue: [],
      storageUsedBytes: 2048,
    );
    final downloads = _MockDownloadService();
    final manager = _MockManager();
    var warmupCall = 0;
    when(
      () => downloads.globalProgressStream,
    ).thenAnswer((_) => const Stream<ModelDownloadProgress>.empty());
    when(
      () => downloads.restoreQueue(catalogModels: any(named: 'catalogModels')),
    ).thenAnswer((_) async => []);
    when(
      () => manager.isModelInstalled('stale-path'),
    ).thenAnswer((_) async => false);
    when(() => manager.resumeDownload('stale-path')).thenAnswer((_) async {});
    when(() => manager.warmModel('stale-path')).thenAnswer((_) async {
      warmupCall += 1;
      return ModelWarmupResult(
        modelId: 'stale-path',
        status: warmupCall == 1
            ? ModelWarmupStatus.warmed
            : ModelWarmupStatus.failed,
        detail: warmupCall == 1 ? null : 'runtime failure',
      );
    });

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

    await tester.ensureVisible(find.text('Why?'));
    await tester.tap(find.text('Why?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Resume download'));
    await tester.pumpAndSettle();
    expect(find.text('Model download resumed.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));

    await tester.ensureVisible(find.text('Why?'));
    await tester.tap(find.text('Why?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry runtime'));
    await tester.pumpAndSettle();
    expect(find.text('Model warm-up succeeded.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));

    await tester.ensureVisible(find.text('Why?'));
    await tester.tap(find.text('Why?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry runtime'));
    await tester.pumpAndSettle();
    expect(find.text('Warm-up failed: runtime failure.'), findsOneWidget);

    verify(() => manager.resumeDownload('stale-path')).called(1);
    verify(() => manager.warmModel('stale-path')).called(2);
  });

  testWidgets('warm and benchmark report unavailable and failed statuses', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const modelInfo = OfflineModelInfo(
      id: 'runtime-offline',
      name: 'Runtime Offline Model',
      family: ModelFamily.gemma,
      fileSizeBytes: 1234,
      filePath: '/models/runtime-offline.gguf',
      description: 'Installed but runtime is unavailable.',
    );
    final registry = ModelRegistry(
      loadMemoryInfo: () async =>
          MemoryInfo.fromMegabytes(totalMB: 8192, availableMB: 4096),
    )..registerModel(modelInfo);
    const snapshot = ModelManagerSnapshot(
      models: [
        ModelEntry(
          id: 'runtime-offline',
          name: 'Runtime Offline Model',
          version: 'Unversioned',
          description: 'Installed but runtime is unavailable.',
          sizeBytes: 1234,
          isDownloaded: true,
          updateState: ModelUpdateState.unknown,
        ),
      ],
      downloadQueue: [],
      storageUsedBytes: 1234,
    );
    final downloads = _MockDownloadService();
    final manager = _MockManager();
    var warmupCall = 0;
    when(
      () => downloads.globalProgressStream,
    ).thenAnswer((_) => const Stream<ModelDownloadProgress>.empty());
    when(
      () => downloads.restoreQueue(catalogModels: any(named: 'catalogModels')),
    ).thenAnswer((_) async => []);
    when(() => manager.warmModel('runtime-offline')).thenAnswer((_) async {
      warmupCall += 1;
      if (warmupCall == 1) {
        return const ModelWarmupResult(
          modelId: 'runtime-offline',
          status: ModelWarmupStatus.unavailable,
          detail: 'adapter_missing',
        );
      }
      return const ModelWarmupResult(
        modelId: 'runtime-offline',
        status: ModelWarmupStatus.failed,
        detail: 'kernel crash',
      );
    });

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

    await tester.ensureVisible(find.text('Warm now'));
    await tester.tap(find.text('Warm now'));
    await tester.pump();
    expect(
      find.text('Model could not be warmed: adapter_missing.'),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets(
    'scribe-tagged models show status only and leave other rows untouched',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const scribeInfo = OfflineModelInfo(
        id: 'mind-scribe-whisper-tiny-en',
        name: 'Whisper Tiny (English)',
        family: ModelFamily.other,
        fileSizeBytes: 77691713,
        // Installed according to the registry, which is the only source that
        // looks in the scribe's own directory.
        filePath: '/support/airo_mind/ggml-tiny.en.bin',
        description: 'Powers the Airo Mind Scribe.',
        tags: [mindScribeModelTag],
      );
      const chatInfo = OfflineModelInfo(
        id: 'installed',
        name: 'Installed Model',
        family: ModelFamily.gemma,
        fileSizeBytes: 1024,
        filePath: '/models/installed.gguf',
        description: 'Ready locally.',
      );
      final registry = ModelRegistry(
        loadMemoryInfo: () async =>
            MemoryInfo.fromMegabytes(totalMB: 8192, availableMB: 4096),
      )..registerModels([scribeInfo, chatInfo]);
      const snapshot = ModelManagerSnapshot(
        models: [
          // The manager reports the scribe entry as not downloaded: it asks
          // its own storage manager, which never looks where the scribe
          // installs. The card must read install state from the registry.
          ModelEntry(
            id: 'mind-scribe-whisper-tiny-en',
            name: 'Whisper Tiny (English)',
            version: 'Unversioned',
            description: 'Powers the Airo Mind Scribe.',
            sizeBytes: 77691713,
            updateState: ModelUpdateState.notInstalled,
          ),
          ModelEntry(
            id: 'installed',
            name: 'Installed Model',
            version: 'Unversioned',
            description: 'Ready locally.',
            sizeBytes: 1024,
            isDownloaded: true,
            updateState: ModelUpdateState.unknown,
          ),
        ],
        downloadQueue: [],
        storageUsedBytes: 1024,
      );
      final downloads = _MockDownloadService();
      final manager = _MockManager();
      when(
        () => downloads.globalProgressStream,
      ).thenAnswer((_) => const Stream<ModelDownloadProgress>.empty());
      when(
        () =>
            downloads.restoreQueue(catalogModels: any(named: 'catalogModels')),
      ).thenAnswer((_) async => []);

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

      // The scribe row reports real install state and hands the user back to
      // the Scribe rather than offering chat-runtime verbs.
      expect(find.text('Managed by Scribe'), findsOneWidget);
      expect(find.text('Status: installed'), findsOneWidget);
      expect(find.text('Required storage: 74.1 MB'), findsOneWidget);
      expect(
        find.textContaining('Manage it from the Scribe screen.'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp('Scribe model status for Whisper Tiny')),
        findsOneWidget,
      );
      expect(
        find.text('Download Model (74.1 MB)'),
        findsNothing,
        reason: 'the scribe acquires its own weights',
      );

      // The untagged row keeps every control it had.
      expect(find.text('Warm now'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Benchmark'), findsOneWidget);
      expect(find.text('Activate'), findsOneWidget);
      expect(find.byTooltip('Delete Model'), findsOneWidget);
      expect(find.text('Download Manager'), findsOneWidget);
    },
  );

  testWidgets('benchmark reports failed runtime status', (tester) async {
    tester.view.physicalSize = const Size(1200, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const modelInfo = OfflineModelInfo(
      id: 'benchmark-fails',
      name: 'Benchmark Fails Model',
      family: ModelFamily.gemma,
      fileSizeBytes: 1234,
      filePath: '/models/benchmark-fails.gguf',
      description: 'Installed but benchmark fails.',
    );
    final registry = ModelRegistry(
      loadMemoryInfo: () async =>
          MemoryInfo.fromMegabytes(totalMB: 8192, availableMB: 4096),
    )..registerModel(modelInfo);
    const snapshot = ModelManagerSnapshot(
      models: [
        ModelEntry(
          id: 'benchmark-fails',
          name: 'Benchmark Fails Model',
          version: 'Unversioned',
          description: 'Installed but benchmark fails.',
          sizeBytes: 1234,
          isDownloaded: true,
          updateState: ModelUpdateState.unknown,
        ),
      ],
      downloadQueue: [],
      storageUsedBytes: 1234,
    );
    final downloads = _MockDownloadService();
    final manager = _MockManager();
    when(
      () => downloads.globalProgressStream,
    ).thenAnswer((_) => const Stream<ModelDownloadProgress>.empty());
    when(
      () => downloads.restoreQueue(catalogModels: any(named: 'catalogModels')),
    ).thenAnswer((_) async => []);
    when(() => manager.warmModel('benchmark-fails')).thenAnswer(
      (_) async => const ModelWarmupResult(
        modelId: 'benchmark-fails',
        status: ModelWarmupStatus.failed,
        detail: 'kernel crash',
      ),
    );

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

    await tester.ensureVisible(
      find.widgetWithText(OutlinedButton, 'Benchmark'),
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Benchmark'));
    await tester.pump();
    expect(find.textContaining('Benchmark failed after'), findsOneWidget);
  });
}
