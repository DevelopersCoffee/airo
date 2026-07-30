import 'dart:async';
import 'dart:io';

import 'package:core_ai/core_ai.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:platform_downloads/platform_downloads.dart';

class MockModelStorageManager extends Mock implements ModelStorageManager {}

class FakeBackgroundDownloads implements BackgroundDownloads {
  final eventController = StreamController<DownloadProgress>.broadcast();
  final requests = <DownloadArtifactRequest>[];
  final actions = <String>[];
  var queue = const DownloadQueueSnapshot(entries: []);

  @override
  Stream<DownloadProgress> get events => eventController.stream;

  @override
  Future<void> enqueue(DownloadArtifactRequest request) async {
    requests.add(request);
  }

  @override
  Future<void> pause(String artifactId) async {
    actions.add('pause:$artifactId');
  }

  @override
  Future<void> resume(String artifactId) async {
    actions.add('resume:$artifactId');
  }

  @override
  Future<void> retry(String artifactId) async {
    actions.add('retry:$artifactId');
  }

  @override
  Future<void> cancel(String artifactId) async {
    actions.add('cancel:$artifactId');
  }

  @override
  Future<DownloadQueueSnapshot> getQueue() async => queue;

  @override
  Future<int?> getAvailableBytes() async => 10 * 1024 * 1024 * 1024;

  Future<void> dispose() => eventController.close();
}

void main() {
  late ModelDownloadService downloadService;
  late MockModelStorageManager storage;
  late FakeBackgroundDownloads downloads;

  final model = OfflineModelInfo(
    id: 'model-a',
    name: 'Model A',
    family: ModelFamily.gemma,
    fileSizeBytes: 1000,
    downloadUrl: 'https://example.com/a.gguf',
    sha256: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
  );

  setUpAll(() {
    registerFallbackValue(model);
  });

  setUp(() {
    storage = MockModelStorageManager();
    downloads = FakeBackgroundDownloads();
    when(
      () => storage.verifyModelIntegrity(model),
    ).thenAnswer((_) async => false);
    when(
      () => storage.hasEnoughDiskSpace(model.fileSizeBytes),
    ).thenAnswer((_) async => true);
    when(
      () => storage.getModelPath(model.id, model: model),
    ).thenAnswer((_) async => '/sandbox/model-a.gguf');
    when(() => storage.writeInstallReceipt(any())).thenAnswer(
      (_) async => ModelInstallReceipt(
        modelId: model.id,
        catalogFingerprint: 'fingerprint',
        installedAt: DateTime.utc(2026, 7, 27),
      ),
    );
    when(() => storage.deleteInstallReceipt(any())).thenAnswer((_) async {});
    downloadService = ModelDownloadService(
      downloads: downloads,
      storageManager: storage,
    );
  });

  tearDown(() async {
    await downloadService.dispose();
    await downloads.dispose();
  });

  test(
    'downloadModel delegates a verified request to platform_downloads',
    () async {
      final firstProgress = downloadService.downloadModel(model).first;

      await Future<void>.delayed(Duration.zero);

      expect(downloads.requests, hasLength(1));
      final request = downloads.requests.single;
      expect(request.artifactId, model.id);
      expect(request.source, Uri.parse(model.downloadUrl!));
      expect(request.destinationPath, '/sandbox/model-a.gguf');
      expect(request.expectedBytes, model.fileSizeBytes);
      expect(request.expectedSha256, model.sha256);
      expect((await firstProgress).status, ModelDownloadStatus.pending);
    },
  );

  test(
    'platform progress maps to model progress without path leakage',
    () async {
      final progressValues = <ModelDownloadProgress>[];
      final subscription = downloadService
          .downloadModel(model)
          .listen(progressValues.add);
      await Future<void>.delayed(Duration.zero);

      downloads.eventController.add(
        const DownloadProgress(
          artifactId: 'model-a',
          status: DownloadStatus.downloading,
          downloadedBytes: 500,
          totalBytes: 1000,
          speedBytesPerSecond: 100,
          retryCount: 1,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(progressValues.last.modelId, model.id);
      expect(progressValues.last.status, ModelDownloadStatus.downloading);
      expect(progressValues.last.downloadedBytes, 500);
      expect(progressValues.last.speedBytesPerSecond, 100);
      expect(progressValues.last.error, isNull);
      await subscription.cancel();
    },
  );

  test('completed platform transfer records an install receipt', () async {
    final progressValues = <ModelDownloadProgress>[];
    final subscription = downloadService
        .downloadModel(model)
        .listen(progressValues.add);
    await Future<void>.delayed(Duration.zero);

    downloads.eventController.add(
      const DownloadProgress(
        artifactId: 'model-a',
        status: DownloadStatus.completed,
        downloadedBytes: 1000,
        totalBytes: 1000,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    verify(() => storage.writeInstallReceipt(model)).called(1);
    expect(progressValues.last.status, ModelDownloadStatus.completed);
    await subscription.cancel();
  });

  test(
    'pause resume retry and cancel delegate to the shared controller',
    () async {
      downloadService.downloadModel(model);
      await Future<void>.delayed(Duration.zero);

      await downloadService.pauseDownload(model.id);
      await downloadService.resumeDownload(model.id);
      await downloadService.retryDownload(model.id);
      await downloadService.cancelDownload(model.id);

      expect(downloads.actions, [
        'pause:model-a',
        'resume:model-a',
        'retry:model-a',
        'cancel:model-a',
      ]);
    },
  );

  test(
    'valid existing artifact completes without enqueuing transfer',
    () async {
      when(
        () => storage.verifyModelIntegrity(model),
      ).thenAnswer((_) async => true);

      final progress = await downloadService.downloadModel(model).first;

      expect(progress.status, ModelDownloadStatus.completed);
      expect(downloads.requests, isEmpty);
    },
  );

  test('installed state requires verified catalog integrity', () async {
    final directory = await Directory.systemTemp.createTemp('airo-model-');
    addTearDown(() => directory.delete(recursive: true));
    final artifactPath = '${directory.path}/model-a.gguf';
    await File(artifactPath).writeAsBytes(const <int>[1]);
    when(
      () => storage.findExistingModelPath(model.id, model: model),
    ).thenAnswer((_) async => artifactPath);
    when(
      () => storage.verifyModelIntegrity(any()),
    ).thenAnswer((_) async => false);

    expect(
      await downloadService.isModelDownloaded(model.id, model: model),
      isFalse,
    );
    verify(() => storage.verifyModelIntegrity(any())).called(1);
  });

  test('insufficient space fails before enqueue', () async {
    when(
      () => storage.hasEnoughDiskSpace(model.fileSizeBytes),
    ).thenAnswer((_) async => false);

    final progress = await downloadService.downloadModel(model).first;

    expect(progress.status, ModelDownloadStatus.failed);
    expect(progress.error, contains('Insufficient disk space'));
    expect(downloads.requests, isEmpty);
  });

  test('downloadModel preserves LiteRT destination extension', () async {
    final litertModel = OfflineModelInfo(
      id: 'gemma-litert',
      name: 'Gemma LiteRT',
      family: ModelFamily.gemma,
      fileSizeBytes: 1000,
      downloadUrl: 'https://example.com/gemma.litertlm',
    );
    when(
      () => storage.verifyModelIntegrity(litertModel),
    ).thenAnswer((_) async => false);
    when(
      () => storage.hasEnoughDiskSpace(litertModel.fileSizeBytes),
    ).thenAnswer((_) async => true);
    when(
      () => storage.getModelPath(litertModel.id, model: litertModel),
    ).thenAnswer((_) async => '/sandbox/gemma-litert.litertlm');

    downloadService.downloadModel(litertModel);
    await Future<void>.delayed(Duration.zero);

    expect(
      downloads.requests.single.destinationPath,
      '/sandbox/gemma-litert.litertlm',
    );
  });

  test(
    'retry with the current catalog refreshes stale request metadata',
    () async {
      downloadService.downloadModel(model);
      await Future<void>.delayed(Duration.zero);

      await downloadService.retryDownload(model.id, model: model);
      await Future<void>.delayed(Duration.zero);

      expect(downloads.actions, contains('cancel:model-a'));
      expect(downloads.requests, hasLength(2));
      expect(downloads.requests.last.expectedBytes, model.fileSizeBytes);
    },
  );

  test('repair clears stale files before starting a fresh request', () async {
    when(
      () => storage.getCandidateModelPaths(model.id),
    ).thenAnswer((_) async => const ['/sandbox/model-a.gguf']);

    await downloadService.repairModel(model);
    await Future<void>.delayed(Duration.zero);

    expect(downloads.actions, contains('cancel:model-a'));
    expect(downloads.requests, hasLength(1));
    verify(() => storage.deleteInstallReceipt(model.id)).called(1);
  });

  test(
    'restoreQueue maps persisted platform state after engine restart',
    () async {
      downloads.queue = const DownloadQueueSnapshot(
        entries: [
          DownloadProgress(
            artifactId: 'model-a',
            status: DownloadStatus.paused,
            downloadedBytes: 400,
            totalBytes: 1000,
            queuePosition: 0,
            retryCount: 2,
            resumeSupported: true,
          ),
        ],
      );

      final restored = await downloadService.restoreQueue();

      expect(restored.single.modelId, 'model-a');
      expect(restored.single.status, ModelDownloadStatus.paused);
      expect(restored.single.downloadedBytes, 400);
      expect(restored.single.retryCount, 2);
      expect(restored.single.resumeSupported, isTrue);
    },
  );
}
