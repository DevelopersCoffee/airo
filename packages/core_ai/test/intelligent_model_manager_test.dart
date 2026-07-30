import 'package:core_ai/core_ai.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockModelStorageManager extends Mock implements ModelStorageManager {}

class MockModelRegistry extends Mock implements ModelRegistry {}

class MockModelDownloadService extends Mock implements ModelDownloadService {}

class MockModelPreloadPreferences extends Mock
    implements ModelPreloadPreferences {}

class MockModelWarmupGateway extends Mock implements ModelWarmupGateway {}

class MockModelActivationGateway extends Mock
    implements ModelActivationGateway {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      const OfflineModelInfo(
        id: 'fallback',
        name: 'Fallback',
        family: ModelFamily.gemma,
        fileSizeBytes: 0,
      ),
    );
  });

  group('IntelligentModelManager Tests', () {
    late IntelligentModelManager manager;
    late MockModelStorageManager mockStorage;
    late MockModelRegistry mockRegistry;
    late MockModelDownloadService mockDownload;
    late MockModelPreloadPreferences mockPreload;
    late MockModelWarmupGateway mockWarmup;
    late MockModelActivationGateway mockActivation;

    final testModel = const OfflineModelInfo(
      id: 'gemma-2b-it-q4',
      name: 'Gemma 2B Instruct',
      family: ModelFamily.gemma,
      fileSizeBytes: 1500000000,
      downloadUrl: 'https://example.com/gemma.gguf',
      version: '2.0.0',
    );

    setUp(() {
      mockStorage = MockModelStorageManager();
      mockRegistry = MockModelRegistry();
      mockDownload = MockModelDownloadService();
      mockPreload = MockModelPreloadPreferences();
      mockWarmup = MockModelWarmupGateway();
      mockActivation = MockModelActivationGateway();
      manager = IntelligentModelManager(
        mockStorage,
        mockRegistry,
        mockDownload,
        preloadPreferences: mockPreload,
        warmupGateway: mockWarmup,
        activationGateway: mockActivation,
      );
      when(
        () => mockStorage.catalogFingerprint(any()),
      ).thenReturn('catalog-v2');
      when(
        () => mockStorage.readInstallReceipt(any()),
      ).thenAnswer((_) async => null);
      when(() => mockWarmup.residentModelIds).thenReturn(<String>{});
    });

    test(
      'listModels maps OfflineModelInfo to ModelEntry correctly when downloaded',
      () async {
        when(() => mockRegistry.allModels).thenReturn([testModel]);
        when(
          () =>
              mockStorage.findExistingModelPath(testModel.id, model: testModel),
        ).thenAnswer((_) async => '/path/to/gemma.gguf');

        final results = await manager.listModels();

        expect(results.length, 1);
        final entry = results.first;
        expect(entry.id, testModel.id);
        expect(entry.name, testModel.name);
        expect(entry.isDownloaded, isTrue);
        expect(entry.localPath, isNull);
        expect(entry.sizeBytes, testModel.fileSizeBytes);
        expect(entry.updateState, ModelUpdateState.unknown);
      },
    );

    test(
      'listModels reports update only from durable receipt evidence',
      () async {
        when(() => mockRegistry.allModels).thenReturn([testModel]);
        when(
          () =>
              mockStorage.findExistingModelPath(testModel.id, model: testModel),
        ).thenAnswer((_) async => '/path/to/gemma.gguf');
        when(() => mockStorage.readInstallReceipt(testModel.id)).thenAnswer(
          (_) async => ModelInstallReceipt(
            modelId: testModel.id,
            catalogFingerprint: 'catalog-v1',
            installedAt: DateTime.utc(2026, 7, 1),
            version: '1.0.0',
          ),
        );

        final entry = (await manager.listModels(
          activeModelId: testModel.id,
          recommendedModelIds: {testModel.id},
          preloadModelIds: {testModel.id},
        )).single;

        expect(entry.updateState, ModelUpdateState.updateAvailable);
        expect(entry.installedVersion, '1.0.0');
        expect(entry.version, '2.0.0');
        expect(entry.isActive, isTrue);
        expect(entry.isRecommended, isTrue);
        expect(entry.preloadFrequentlyUsed, isTrue);
      },
    );

    test(
      'listModels maps OfflineModelInfo to ModelEntry correctly when NOT downloaded',
      () async {
        when(() => mockRegistry.allModels).thenReturn([testModel]);
        when(
          () =>
              mockStorage.findExistingModelPath(testModel.id, model: testModel),
        ).thenAnswer((_) async => null);

        final results = await manager.listModels();

        expect(results.length, 1);
        final entry = results.first;
        expect(entry.id, testModel.id);
        expect(entry.isDownloaded, isFalse);
        expect(entry.localPath, isNull);
      },
    );

    test('downloadModel starts download via ModelDownloadService', () async {
      when(() => mockRegistry.getModel(testModel.id)).thenReturn(testModel);
      when(
        () => mockDownload.downloadModel(any()),
      ).thenAnswer((_) => const Stream.empty());

      await manager.downloadModel(testModel.id);

      verify(() => mockRegistry.getModel(testModel.id)).called(1);
      verify(() => mockDownload.downloadModel(testModel)).called(1);
    });

    test('downloadModel throws ArgumentError for unknown model ID', () async {
      when(() => mockRegistry.getModel('unknown')).thenReturn(null);

      expect(() => manager.downloadModel('unknown'), throwsArgumentError);
    });

    test(
      'queue controls delegate through the shared download contract',
      () async {
        when(() => mockRegistry.getModel(testModel.id)).thenReturn(testModel);
        when(
          () => mockDownload.pauseDownload(testModel.id),
        ).thenAnswer((_) async {});
        when(
          () => mockDownload.resumeDownload(testModel.id),
        ).thenAnswer((_) async {});
        when(
          () => mockDownload.retryDownload(testModel.id, model: testModel),
        ).thenAnswer((_) async {});
        when(
          () => mockDownload.cancelDownload(testModel.id),
        ).thenAnswer((_) async {});

        await manager.pauseDownload(testModel.id);
        await manager.resumeDownload(testModel.id);
        await manager.retryDownload(testModel.id);
        await manager.cancelDownload(testModel.id);

        verify(() => mockDownload.pauseDownload(testModel.id)).called(1);
        verify(() => mockDownload.resumeDownload(testModel.id)).called(1);
        verify(
          () => mockDownload.retryDownload(testModel.id, model: testModel),
        ).called(1);
        verify(() => mockDownload.cancelDownload(testModel.id)).called(1);
      },
    );

    test(
      'repairModel delegates a clean repair to the download service',
      () async {
        when(() => mockRegistry.getModel(testModel.id)).thenReturn(testModel);
        when(
          () => mockDownload.repairModel(testModel),
        ).thenAnswer((_) async {});

        await manager.repairModel(testModel.id);

        verify(() => mockDownload.repairModel(testModel)).called(1);
      },
    );

    test(
      'deleteModel calls delete on download service and marks as removed in registry',
      () async {
        when(
          () => mockDownload.deleteModel(testModel.id),
        ).thenAnswer((_) async => true);
        when(() => mockRegistry.getModel(testModel.id)).thenReturn(testModel);
        when(() => mockRegistry.markAsRemoved(testModel.id)).thenAnswer((_) {});
        when(
          () => mockPreload.setEnabled(testModel.id, false),
        ).thenAnswer((_) async {});
        when(() => mockActivation.clear(testModel)).thenAnswer((_) async {});

        await manager.deleteModel(testModel.id);

        verify(() => mockDownload.deleteModel(testModel.id)).called(1);
        verify(() => mockRegistry.markAsRemoved(testModel.id)).called(1);
        verify(() => mockPreload.setEnabled(testModel.id, false)).called(1);
        verify(() => mockActivation.clear(testModel)).called(1);
      },
    );

    test(
      'activateModel rejects missing files and delegates installed models',
      () async {
        when(() => mockRegistry.getModel(testModel.id)).thenReturn(testModel);
        when(
          () =>
              mockStorage.findExistingModelPath(testModel.id, model: testModel),
        ).thenAnswer((_) async => '/path/to/gemma.gguf');
        when(() => mockActivation.activate(any())).thenAnswer((_) async {});

        await manager.activateModel(testModel.id);

        final activated =
            verify(() => mockActivation.activate(captureAny())).captured.single
                as OfflineModelInfo;
        expect(activated.filePath, '/path/to/gemma.gguf');
      },
    );

    test('warmModel delegates only when the artifact is installed', () async {
      when(() => mockRegistry.getModel(testModel.id)).thenReturn(testModel);
      when(
        () => mockStorage.findExistingModelPath(testModel.id, model: testModel),
      ).thenAnswer((_) async => '/path/to/gemma.gguf');
      when(() => mockWarmup.warm(any())).thenAnswer(
        (_) async => const ModelWarmupResult(
          modelId: 'gemma-2b-it-q4',
          status: ModelWarmupStatus.warmed,
        ),
      );

      final result = await manager.warmModel(testModel.id);

      expect(result.status, ModelWarmupStatus.warmed);
      final warmed =
          verify(() => mockWarmup.warm(captureAny())).captured.single
              as OfflineModelInfo;
      expect(warmed.filePath, '/path/to/gemma.gguf');
    });

    test(
      'snapshot exposes queue, storage, and device recommendations',
      () async {
        when(() => mockRegistry.allModels).thenReturn([testModel]);
        when(
          () => mockRegistry.getCompatibleModels(),
        ).thenAnswer((_) async => [testModel]);
        when(() => mockPreload.loadModelIds()).thenAnswer((_) async => {});
        when(
          () => mockDownload.restoreQueue(
            catalogModels: any(named: 'catalogModels'),
          ),
        ).thenAnswer(
          (_) async => [
            const ModelDownloadProgress(
              modelId: 'gemma-2b-it-q4',
              totalBytes: 1500000000,
              downloadedBytes: 500,
              status: ModelDownloadStatus.paused,
            ),
          ],
        );
        when(() => mockDownload.getStorageUsed()).thenAnswer((_) async => 42);
        when(
          () =>
              mockStorage.findExistingModelPath(testModel.id, model: testModel),
        ).thenAnswer((_) async => null);

        final snapshot = await manager.snapshot();

        expect(snapshot.storageUsedBytes, 42);
        expect(
          snapshot.downloadQueue.single.status,
          ModelDownloadStatus.paused,
        );
        expect(snapshot.recommendedModels.single.id, testModel.id);
      },
    );
  });
}
