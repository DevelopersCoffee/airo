import 'dart:async';
import 'dart:io';

import 'package:core_ai/core_ai.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:platform_downloads/platform_downloads.dart';

class MockModelStorageManager extends Mock implements ModelStorageManager {}

class FakeAiroPlatformBridge extends AiroPlatformBridge {
  final eventController = StreamController<AiroDownload>.broadcast();
  final requests = <AiroDownloadRequest>[];
  final actions = <String>[];
  var downloads = <AiroDownload>[];

  @override
  Stream<AiroDownload> get events => eventController.stream;

  @override
  Future<void> enqueue(AiroDownloadRequest request) async {
    requests.add(request);
  }

  @override
  Future<void> pause(String id) async {
    actions.add('pause:$id');
  }

  @override
  Future<void> resume(String id) async {
    actions.add('resume:$id');
  }

  @override
  Future<void> retry(String id) async {
    actions.add('retry:$id');
  }

  @override
  Future<void> cancel(String id) async {
    actions.add('cancel:$id');
  }

  @override
  Future<List<AiroDownload>> getAll() async => List.unmodifiable(downloads);

  @override
  Future<int?> getAvailableBytes() async => 10 * 1024 * 1024 * 1024;

  Future<void> dispose() => eventController.close();
}

AiroDownload _transfer({
  required String id,
  required AiroDownloadStatus status,
  int downloadedBytes = 0,
  int totalBytes = 0,
  double speedBytesPerSecond = 0,
  int retryCount = 0,
  AiroFailureReason? failureReason,
  String? failureMessage,
}) {
  return AiroDownload(
    request: AiroDownloadRequest(
      id: id,
      url: Uri.parse('https://example.com/$id'),
      destination: '/sandbox/$id',
    ),
    status: status,
    downloadedBytes: downloadedBytes,
    totalBytes: totalBytes,
    speedBytesPerSecond: speedBytesPerSecond,
    retryCount: retryCount,
    failureReason: failureReason,
    failureMessage: failureMessage,
  );
}

void main() {
  late ModelDownloadService downloadService;
  late MockModelStorageManager storage;
  late FakeAiroPlatformBridge bridge;

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
    bridge = FakeAiroPlatformBridge();
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
    when(
      () => storage.enforceStorageQuota(
        maxTotalBytes: any(named: 'maxTotalBytes'),
        protectedModelIds: any(named: 'protectedModelIds'),
      ),
    ).thenAnswer((_) async => <String>[]);
    downloadService = ModelDownloadService(
      engine: AiroDownloadEngine(bridge: bridge),
      storageManager: storage,
    );
  });

  tearDown(() async {
    await downloadService.dispose();
    await bridge.dispose();
  });

  test(
    'downloadModel delegates a verified request to AiroDownloadEngine',
    () async {
      final firstProgress = downloadService.downloadModel(model).first;

      await Future<void>.delayed(Duration.zero);

      expect(bridge.requests, hasLength(1));
      final request = bridge.requests.single;
      expect(request.id, model.id);
      expect(request.url, Uri.parse(model.downloadUrl!));
      expect(request.destination, '/sandbox/model-a.gguf');
      expect(request.expectedBytes, model.fileSizeBytes);
      expect(request.checksum?.algorithm, AiroChecksumAlgorithm.sha256);
      expect(request.checksum?.value, model.sha256);
      expect((await firstProgress).status, ModelDownloadStatus.pending);
    },
  );

  test('engine progress maps to model progress without path leakage', () async {
    final progressValues = <ModelDownloadProgress>[];
    final subscription = downloadService
        .downloadModel(model)
        .listen(progressValues.add);
    await Future<void>.delayed(Duration.zero);

    bridge.eventController.add(
      _transfer(
        id: 'model-a',
        status: AiroDownloadStatus.downloading,
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
  });

  test(
    'download progress records last byte movement for stall recovery',
    () async {
      final progressValues = <ModelDownloadProgress>[];
      final subscription = downloadService
          .downloadModel(model)
          .listen(progressValues.add);
      await Future<void>.delayed(Duration.zero);

      bridge.eventController.add(
        _transfer(
          id: 'model-a',
          status: AiroDownloadStatus.downloading,
          downloadedBytes: 400,
          totalBytes: 1000,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      final firstMovement = progressValues.last.lastProgressAt;

      bridge.eventController.add(
        _transfer(
          id: 'model-a',
          status: AiroDownloadStatus.downloading,
          downloadedBytes: 400,
          totalBytes: 1000,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(progressValues.last.startTime, isNotNull);
      expect(progressValues.last.lastProgressAt, firstMovement);
      await subscription.cancel();
    },
  );

  test('completed engine transfer records an install receipt', () async {
    var verificationCalls = 0;
    when(
      () => storage.verifyModelIntegrity(model),
    ).thenAnswer((_) async => ++verificationCalls >= 2);
    final progressValues = <ModelDownloadProgress>[];
    final subscription = downloadService
        .downloadModel(model)
        .listen(progressValues.add);
    await Future<void>.delayed(Duration.zero);

    bridge.eventController.add(
      _transfer(
        id: 'model-a',
        status: AiroDownloadStatus.completed,
        downloadedBytes: 1000,
        totalBytes: 1000,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    verify(() => storage.writeInstallReceipt(model)).called(1);
    expect(progressValues.last.status, ModelDownloadStatus.completed);
    await subscription.cancel();
  });

  test('completed engine transfer is rejected when integrity fails', () async {
    final progressValues = <ModelDownloadProgress>[];
    final subscription = downloadService
        .downloadModel(model)
        .listen(progressValues.add);
    await Future<void>.delayed(Duration.zero);

    bridge.eventController.add(
      _transfer(
        id: 'model-a',
        status: AiroDownloadStatus.completed,
        downloadedBytes: 1000,
        totalBytes: 1000,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(progressValues, hasLength(3));
    expect(progressValues[1].status, ModelDownloadStatus.verifying);
    expect(progressValues.last.status, ModelDownloadStatus.failed);
    expect(progressValues.last.failureCode, 'integrity_mismatch');
    verifyNever(() => storage.writeInstallReceipt(model));
    await subscription.cancel();
  });

  test(
    'pause resume retry and cancel delegate to the transfer engine',
    () async {
      downloadService.downloadModel(model);
      await Future<void>.delayed(Duration.zero);

      await downloadService.pauseDownload(model.id);
      await downloadService.resumeDownload(model.id);
      await downloadService.retryDownload(model.id);
      await downloadService.cancelDownload(model.id);

      expect(bridge.actions, [
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
      expect(bridge.requests, isEmpty);
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

  test(
    'explicit model paths are only resolved when the file still exists',
    () async {
      final directory = await Directory.systemTemp.createTemp('airo-explicit-');
      addTearDown(() => directory.delete(recursive: true));
      final artifactPath = '${directory.path}/model-a.gguf';
      await File(artifactPath).writeAsBytes(const <int>[1]);
      when(
        () => storage.findExistingModelPath(any(), model: any(named: 'model')),
      ).thenAnswer((_) async => null);

      final hydrated = model.copyWith(filePath: artifactPath);
      expect(
        await downloadService.resolveExistingModelPath(
          model.id,
          model: hydrated,
        ),
        artifactPath,
      );
      expect(
        await downloadService.resolveExistingModelPath(
          model.id,
          model: model.copyWith(filePath: '${directory.path}/missing.gguf'),
        ),
        isNull,
      );
    },
  );

  test('insufficient space fails before enqueue', () async {
    when(
      () => storage.hasEnoughDiskSpace(model.fileSizeBytes),
    ).thenAnswer((_) async => false);

    final progress = await downloadService.downloadModel(model).first;

    expect(progress.status, ModelDownloadStatus.failed);
    expect(progress.error, contains('Insufficient disk space'));
    expect(bridge.requests, isEmpty);
  });

  test('downloadModel enforces the storage quota, protecting the incoming '
      'model, before enqueuing', () async {
    downloadService.downloadModel(model);
    await Future<void>.delayed(Duration.zero);

    final captured = verify(
      () => storage.enforceStorageQuota(
        maxTotalBytes: any(named: 'maxTotalBytes'),
        protectedModelIds: captureAny(named: 'protectedModelIds'),
      ),
    ).captured;

    expect(captured.single, {model.id});
    expect(bridge.requests, hasLength(1));
  });

  test('a quota-exceeding model still fails cleanly if eviction cannot make '
      'room', () async {
    when(
      () => storage.hasEnoughDiskSpace(model.fileSizeBytes),
    ).thenAnswer((_) async => false);

    final progress = await downloadService.downloadModel(model).first;

    expect(progress.status, ModelDownloadStatus.failed);
    verifyNever(
      () => storage.enforceStorageQuota(
        maxTotalBytes: any(named: 'maxTotalBytes'),
        protectedModelIds: any(named: 'protectedModelIds'),
      ),
    );
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
      bridge.requests.single.destination,
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

      expect(bridge.actions, contains('cancel:model-a'));
      expect(bridge.requests, hasLength(2));
      expect(bridge.requests.last.expectedBytes, model.fileSizeBytes);
    },
  );

  test('repair clears stale files before starting a fresh request', () async {
    when(
      () => storage.getCandidateModelPaths(model.id),
    ).thenAnswer((_) async => const ['/sandbox/model-a.gguf']);

    await downloadService.repairModel(model);
    await Future<void>.delayed(Duration.zero);

    expect(bridge.actions, contains('cancel:model-a'));
    expect(bridge.requests, hasLength(1));
    verify(() => storage.deleteInstallReceipt(model.id)).called(1);
  });

  test(
    'restoreQueue maps persisted engine state after process restart',
    () async {
      bridge.downloads = [
        _transfer(
          id: 'model-a',
          status: AiroDownloadStatus.paused,
          downloadedBytes: 400,
          totalBytes: 1000,
          retryCount: 2,
        ),
      ];

      final restored = await downloadService.restoreQueue();

      expect(restored.single.modelId, 'model-a');
      expect(restored.single.status, ModelDownloadStatus.paused);
      expect(restored.single.downloadedBytes, 400);
      expect(restored.single.retryCount, 2);
      expect(restored.single.resumeSupported, isTrue);
    },
  );

  test(
    'restoreQueue keeps failed entries resumable without blocking re-enqueue',
    () async {
      bridge.downloads = [
        _transfer(
          id: model.id,
          status: AiroDownloadStatus.failed,
          downloadedBytes: 400,
          totalBytes: 1000,
        ),
      ];

      final restored = await downloadService.restoreQueue(
        catalogModels: [model],
      );

      expect(restored.single.status, ModelDownloadStatus.failed);
      expect(restored.single.resumeSupported, isTrue);

      downloadService.downloadModel(model);
      await Future<void>.delayed(Duration.zero);

      expect(bridge.requests, hasLength(1));
    },
  );

  test('recoverDownload resumes when the engine retained a partial', () async {
    bridge.downloads = [
      _transfer(
        id: model.id,
        status: AiroDownloadStatus.failed,
        downloadedBytes: 400,
        totalBytes: 1000,
      ),
    ];

    await downloadService.recoverDownload(model.id, model: model);

    expect(bridge.actions, ['resume:model-a']);
    expect(bridge.requests, isEmpty);
  });

  test('recoverDownload retries when resume is not available', () async {
    await downloadService.recoverDownload(model.id, model: model);
    await Future<void>.delayed(Duration.zero);

    expect(bridge.actions, contains('cancel:model-a'));
    expect(bridge.requests, hasLength(1));
  });
}
