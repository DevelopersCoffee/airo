import 'dart:async';
import 'dart:io';

import 'package:core_ai/core_ai.dart';
import 'package:feature_mind/src/models/download_model_provider.dart';
import 'package:feature_mind/src/models/model_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:platform_downloads/platform_downloads.dart';

class MockModelStorageManager extends Mock implements ModelStorageManager {}

/// Same shape as `core_ai`'s own test fake
/// (`packages/core_ai/test/download/model_download_service_test.dart`), kept
/// local rather than shared: a test double is not a dependency worth exporting
/// across a package boundary.
class FakeBackgroundDownloads implements BackgroundDownloads {
  final eventController = StreamController<DownloadProgress>.broadcast();
  final requests = <DownloadArtifactRequest>[];
  var queue = const DownloadQueueSnapshot(entries: []);

  @override
  Stream<DownloadProgress> get events => eventController.stream;

  @override
  Future<void> enqueue(DownloadArtifactRequest request) async {
    requests.add(request);
  }

  @override
  Future<void> pause(String artifactId) async {}

  @override
  Future<void> resume(String artifactId) async {}

  @override
  Future<void> retry(String artifactId) async {}

  @override
  Future<void> cancel(String artifactId) async {}

  @override
  Future<DownloadQueueSnapshot> getQueue() async => queue;

  @override
  Future<int?> getAvailableBytes() async => null;
}

RequiredModel _whisper() => const RequiredModel(
  fileName: 'ggml-tiny.en.bin',
  sizeBytes: 77704715,
  sha256: '921e4cf8686fdd993dcd081a5da5b6c365bfde1162e72b08d75ac75289920b1f',
);

void main() {
  setUpAll(() {
    registerFallbackValue(
      const OfflineModelInfo(
        id: 'fallback',
        name: 'fallback',
        family: ModelFamily.other,
        fileSizeBytes: 0,
      ),
    );
  });

  late FakeBackgroundDownloads downloads;
  late MockModelStorageManager storage;
  late ModelDownloadService service;
  late Directory modelsDir;

  setUp(() {
    downloads = FakeBackgroundDownloads();
    storage = MockModelStorageManager();
    service = ModelDownloadService(
      downloads: downloads,
      storageManager: storage,
    );
    modelsDir = Directory.systemTemp.createTempSync('mind_provider_test_');
  });

  tearDown(() {
    modelsDir.deleteSync(recursive: true);
  });

  test('requiredModels reflects the pinned Rust registry', () async {
    final provider = DownloadModelProvider(
      downloadService: service,
      requiredModelsLookup: () async => [_whisper()],
      downloadUrlFor: (_) => 'https://example.test/ggml-tiny.en.bin',
    );

    final required = await provider.requiredModels();

    expect(required, hasLength(1));
    expect(required.single.fileName, 'ggml-tiny.en.bin');
    expect(required.single.sha256, _whisper().sha256);
  });

  test(
    'isInstalled is false until the pinned file is the pinned size',
    () async {
      final provider = DownloadModelProvider(
        downloadService: service,
        requiredModelsLookup: () async => [_whisper()],
        downloadUrlFor: (_) => 'https://example.test/ggml-tiny.en.bin',
      );

      expect(await provider.isInstalled(modelsDir), isFalse);

      File('${modelsDir.path}/ggml-tiny.en.bin')
        ..createSync()
        ..writeAsBytesSync(List.filled(_whisper().sizeBytes.toInt(), 0));

      expect(await provider.isInstalled(modelsDir), isTrue);
    },
  );

  test(
    'acquire drives the download service and reports progress by file name',
    () async {
      final provider = DownloadModelProvider(
        downloadService: service,
        requiredModelsLookup: () async => [_whisper()],
        downloadUrlFor: (_) => 'https://example.test/ggml-tiny.en.bin',
      );
      // The service checks integrity twice: once before downloading (to skip
      // a model that is already correct on disk -- false here, this test
      // wants the download path exercised) and once after the transport
      // reports completion (true -- that is what "succeeded" means).
      var integrityChecks = 0;
      when(() => storage.verifyModelIntegrity(any())).thenAnswer((_) async {
        integrityChecks++;
        return integrityChecks > 1;
      });
      when(
        () => storage.hasEnoughDiskSpace(any()),
      ).thenAnswer((_) async => true);
      when(
        () => storage.getModelPath(any(), model: any(named: 'model')),
      ).thenAnswer((_) async => '${modelsDir.path}/ggml-tiny.en.bin');
      when(() => storage.writeInstallReceipt(any())).thenAnswer(
        (_) async => ModelInstallReceipt(
          modelId: _whisper().fileName,
          catalogFingerprint: 'test',
          installedAt: DateTime(2026),
        ),
      );

      final events = <ModelAcquisitionEvent>[];
      final acquisition = provider.acquire(modelsDir).forEach(events.add);

      // The service enqueues asynchronously (scheduleMicrotask); give it a
      // turn before asserting on what it queued.
      await Future<void>.delayed(Duration.zero);

      expect(downloads.requests, hasLength(1));
      final request = downloads.requests.single;
      expect(request.destinationPath, '${modelsDir.path}/ggml-tiny.en.bin');
      expect(request.expectedSha256, _whisper().sha256);

      // Drive the fake transport to completion -- the provider's `acquire`
      // stream never closes on its own (the service's per-model stream is
      // broadcast and persistent), so nothing here finishes without this.
      downloads.eventController.add(
        DownloadProgress(
          artifactId: request.artifactId,
          status: DownloadStatus.completed,
          downloadedBytes: _whisper().sizeBytes,
          totalBytes: _whisper().sizeBytes,
        ),
      );
      await acquisition;

      expect(
        events.whereType<ModelAcquisitionProgress>(),
        isNotEmpty,
        reason: 'the completed status should still report as progress once',
      );
      expect(
        events.last,
        isA<ModelAcquisitionDone>().having(
          (e) => e.failedFileNames,
          'failedFileNames',
          isEmpty,
        ),
      );
    },
  );

  test(
    'a model with no download URL fails closed rather than silently skipping',
    () async {
      final provider = DownloadModelProvider(
        downloadService: service,
        requiredModelsLookup: () async => [_whisper()],
        downloadUrlFor: (_) => null,
      );

      final failed =
          await provider
                  .acquire(modelsDir)
                  .firstWhere((e) => e is ModelAcquisitionDone)
              as ModelAcquisitionDone;

      expect(failed.failedFileNames, contains('ggml-tiny.en.bin'));
    },
  );
}
