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
  late Directory stagingDir;

  setUp(() {
    downloads = FakeBackgroundDownloads();
    storage = MockModelStorageManager();
    when(
      () => storage.enforceStorageQuota(
        maxTotalBytes: any(named: 'maxTotalBytes'),
        protectedModelIds: any(named: 'protectedModelIds'),
      ),
    ).thenAnswer((_) async => <String>[]);
    service = ModelDownloadService(
      downloads: downloads,
      storageManager: storage,
    );
    modelsDir = Directory.systemTemp.createTempSync('mind_provider_test_');
    // `core_ai` downloads into its own models directory, not Mind's — the
    // provider moves the verified artifact across afterwards.
    stagingDir = Directory.systemTemp.createTempSync('mind_provider_staging_');
  });

  tearDown(() {
    modelsDir.deleteSync(recursive: true);
    stagingDir.deleteSync(recursive: true);
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
      // Both mocks compose the staging path the way `ModelStorageManager`
      // really does -- `$modelId$extension` -- rather than returning a fixed
      // string. That is what makes this test able to see a doubled extension:
      // the download lands wherever the id says, and the install step has to
      // ask for the same id to find it (#1553).
      String stagingPathFor(Invocation invocation) =>
          '${stagingDir.path}/${invocation.positionalArguments.first}.bin';
      when(
        () => storage.getModelPath(any(), model: any(named: 'model')),
      ).thenAnswer((invocation) async => stagingPathFor(invocation));
      when(
        () => storage.findExistingModelPath(any(), model: any(named: 'model')),
      ).thenAnswer((invocation) async {
        final candidate = File(stagingPathFor(invocation));
        return candidate.existsSync() ? candidate.path : null;
      });
      // The pinned name is `ggml-tiny.en.bin`, so the id is `ggml-tiny.en` and
      // the artifact keeps exactly one extension.
      final staged = File('${stagingDir.path}/ggml-tiny.en.bin');
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
      expect(request.destinationPath, staged.path);
      expect(request.expectedSha256, _whisper().sha256);

      // What the transport writes: the bytes land in `core_ai`'s staging
      // directory, which is not where the engines read from.
      staged.writeAsBytesSync(List.filled(_whisper().sizeBytes.toInt(), 0));

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
      // The point of the whole exercise: the model is installed where the
      // Rust engines are pointed, under its pinned name, and nothing is left
      // behind in staging.
      expect(File('${modelsDir.path}/ggml-tiny.en.bin').existsSync(), isTrue);
      expect(staged.existsSync(), isFalse);
      expect(await provider.isInstalled(modelsDir), isTrue);
    },
  );

  // Verified bytes that cannot be moved across must not report success:
  // `isInstalled` would still be false and the app would loop on the same
  // blocker with no explanation.
  test(
    'a download that never lands in the models directory is a failure',
    () async {
      final provider = DownloadModelProvider(
        downloadService: service,
        requiredModelsLookup: () async => [_whisper()],
        downloadUrlFor: (_) => 'https://example.test/ggml-tiny.en.bin',
      );
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
      ).thenAnswer((_) async => '${stagingDir.path}/ggml-tiny.en.bin.bin');
      // Nothing on disk to move.
      when(
        () => storage.findExistingModelPath(any(), model: any(named: 'model')),
      ).thenAnswer((_) async => null);
      when(() => storage.writeInstallReceipt(any())).thenAnswer(
        (_) async => ModelInstallReceipt(
          modelId: _whisper().fileName,
          catalogFingerprint: 'test',
          installedAt: DateTime(2026),
        ),
      );

      final events = <ModelAcquisitionEvent>[];
      final acquisition = provider.acquire(modelsDir).forEach(events.add);
      await Future<void>.delayed(Duration.zero);
      downloads.eventController.add(
        DownloadProgress(
          artifactId: downloads.requests.single.artifactId,
          status: DownloadStatus.completed,
          downloadedBytes: _whisper().sizeBytes,
          totalBytes: _whisper().sizeBytes,
        ),
      );
      await acquisition;

      expect(
        (events.last as ModelAcquisitionDone).failedFileNames,
        contains('ggml-tiny.en.bin'),
      );
    },
  );

  // A throw out of the install step used to abort the whole `async*` stream:
  // no `ModelAcquisitionDone`, the next model never attempted, and a raw
  // exception where the retry should be.
  test(
    'an install that throws is one file failing, not the acquisition',
    () async {
      const second = RequiredModel(
        fileName: 'qwen2.5-0.5b-instruct-q4_k_m.gguf',
        sizeBytes: 491400032,
        sha256:
            '74a4da8c9fdbcd15bd1f6d01d621410d31c6fc00986f5eb687824e7b93d7a9db',
      );
      final provider = DownloadModelProvider(
        downloadService: service,
        requiredModelsLookup: () async => [_whisper(), second],
        // The second model has no source, so it fails on a path that cannot
        // throw — if the first model's throw had aborted the stream, this one
        // would never be reached and could not appear in the result.
        downloadUrlFor: (model) => model.fileName == _whisper().fileName
            ? 'https://example.test/ggml-tiny.en.bin'
            : null,
      );
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
      ).thenAnswer((_) async => '${stagingDir.path}/ggml-tiny.en.bin.bin');
      when(
        () => storage.findExistingModelPath(any(), model: any(named: 'model')),
      ).thenThrow(const FileSystemException('storage is gone'));
      when(() => storage.writeInstallReceipt(any())).thenAnswer(
        (_) async => ModelInstallReceipt(
          modelId: _whisper().fileName,
          catalogFingerprint: 'test',
          installedAt: DateTime(2026),
        ),
      );

      final events = <ModelAcquisitionEvent>[];
      final acquisition = provider.acquire(modelsDir).forEach(events.add);
      await Future<void>.delayed(Duration.zero);
      downloads.eventController.add(
        DownloadProgress(
          artifactId: downloads.requests.single.artifactId,
          status: DownloadStatus.completed,
          downloadedBytes: _whisper().sizeBytes,
          totalBytes: _whisper().sizeBytes,
        ),
      );

      // The stream completes rather than erroring, and says so.
      await acquisition;
      expect(
        (events.last as ModelAcquisitionDone).failedFileNames,
        containsAll(<String>[_whisper().fileName, second.fileName]),
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

  test(
    'airplane mode: a completed install still reports installed without network',
    () async {
      final provider = DownloadModelProvider(
        downloadService: service,
        requiredModelsLookup: () async => [_whisper()],
        downloadUrlFor: (_) => 'https://example.test/ggml-tiny.en.bin',
      );
      File('${modelsDir.path}/ggml-tiny.en.bin')
        ..createSync()
        ..writeAsBytesSync(List.filled(_whisper().sizeBytes.toInt(), 0));

      expect(await provider.isInstalled(modelsDir), isTrue);

      final events = await provider.acquire(modelsDir).toList();

      expect(downloads.requests, isEmpty);
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
    'acquire resumes a paused platform queue entry from retained partial bytes',
    () async {
      final provider = DownloadModelProvider(
        downloadService: service,
        requiredModelsLookup: () async => [_whisper()],
        downloadUrlFor: (_) => 'https://example.test/ggml-tiny.en.bin',
        stallThreshold: const Duration(days: 1),
      );
      when(
        () => storage.verifyModelIntegrity(any()),
      ).thenAnswer((_) async => false);
      when(
        () => storage.hasEnoughDiskSpace(any()),
      ).thenAnswer((_) async => true);
      when(
        () => storage.getModelPath(any(), model: any(named: 'model')),
      ).thenAnswer((_) async => '${stagingDir.path}/ggml-tiny.en.bin');
      when(
        () => storage.findExistingModelPath(any(), model: any(named: 'model')),
      ).thenAnswer((_) async => null);

      downloads.queue = const DownloadQueueSnapshot(
        entries: [
          DownloadProgress(
            artifactId: 'ggml-tiny.en',
            status: DownloadStatus.paused,
            downloadedBytes: 40_000_000,
            totalBytes: 77704715,
            resumeSupported: true,
          ),
        ],
      );

      final events = <ModelAcquisitionEvent>[];
      final acquisition = provider.acquire(modelsDir).forEach(events.add);
      await Future<void>.delayed(Duration.zero);

      expect(downloads.actions, contains('resume:ggml-tiny.en'));
      expect(
        events.whereType<ModelAcquisitionProgress>().first.fetched,
        40_000_000,
      );

      downloads.eventController.add(
        const DownloadProgress(
          artifactId: 'ggml-tiny.en',
          status: DownloadStatus.failed,
          downloadedBytes: 40_000_000,
          totalBytes: 77704715,
          resumeSupported: true,
        ),
      );
      await acquisition;

      final done = events.last as ModelAcquisitionDone;
      expect(done.failedFileNames, contains('ggml-tiny.en.bin'));
      expect(done.resumeSupported, isTrue);
    },
  );

  test(
    'stall watchdog fails a silent transfer so the UI can offer resume',
    () async {
      final provider = DownloadModelProvider(
        downloadService: service,
        requiredModelsLookup: () async => [_whisper()],
        downloadUrlFor: (_) => 'https://example.test/ggml-tiny.en.bin',
        stallThreshold: const Duration(milliseconds: 40),
        stallPollInterval: const Duration(milliseconds: 10),
      );
      when(
        () => storage.verifyModelIntegrity(any()),
      ).thenAnswer((_) async => false);
      when(
        () => storage.hasEnoughDiskSpace(any()),
      ).thenAnswer((_) async => true);
      when(
        () => storage.getModelPath(any(), model: any(named: 'model')),
      ).thenAnswer((_) async => '${stagingDir.path}/ggml-tiny.en.bin');
      when(
        () => storage.findExistingModelPath(any(), model: any(named: 'model')),
      ).thenAnswer((_) async => null);

      final events = <ModelAcquisitionEvent>[];
      final acquisition = provider.acquire(modelsDir).forEach(events.add);
      await Future<void>.delayed(Duration.zero);
      expect(downloads.requests, hasLength(1));

      // Platform reports downloading with no further byte movement.
      downloads.eventController.add(
        const DownloadProgress(
          artifactId: 'ggml-tiny.en',
          status: DownloadStatus.downloading,
          downloadedBytes: 1_000_000,
          totalBytes: 77704715,
          speedBytesPerSecond: 0,
        ),
      );
      await acquisition.timeout(const Duration(seconds: 2));

      final done = events.last as ModelAcquisitionDone;
      expect(done.failedFileNames, contains('ggml-tiny.en.bin'));
      expect(done.resumeSupported, isTrue);
    },
  );

  test(
    'wrong-sized leftover is not treated as installed and is replaced atomically',
    () async {
      final provider = DownloadModelProvider(
        downloadService: service,
        requiredModelsLookup: () async => [_whisper()],
        downloadUrlFor: (_) => 'https://example.test/ggml-tiny.en.bin',
      );
      File('${modelsDir.path}/ggml-tiny.en.bin')
        ..createSync()
        ..writeAsBytesSync(const [1, 2, 3]);
      File('${modelsDir.path}/ggml-tiny.en.bin.partial')
        ..createSync()
        ..writeAsBytesSync(const [9]);

      expect(await provider.isInstalled(modelsDir), isFalse);

      var integrityChecks = 0;
      when(() => storage.verifyModelIntegrity(any())).thenAnswer((_) async {
        integrityChecks++;
        return integrityChecks > 1;
      });
      when(
        () => storage.hasEnoughDiskSpace(any()),
      ).thenAnswer((_) async => true);
      String stagingPathFor(Invocation invocation) =>
          '${stagingDir.path}/${invocation.positionalArguments.first}.bin';
      when(
        () => storage.getModelPath(any(), model: any(named: 'model')),
      ).thenAnswer((invocation) async => stagingPathFor(invocation));
      when(
        () => storage.findExistingModelPath(any(), model: any(named: 'model')),
      ).thenAnswer((invocation) async {
        final candidate = File(stagingPathFor(invocation));
        return candidate.existsSync() ? candidate.path : null;
      });
      when(() => storage.writeInstallReceipt(any())).thenAnswer(
        (_) async => ModelInstallReceipt(
          modelId: _whisper().fileName,
          catalogFingerprint: 'test',
          installedAt: DateTime(2026),
        ),
      );

      final staged = File('${stagingDir.path}/ggml-tiny.en.bin');
      final events = <ModelAcquisitionEvent>[];
      final acquisition = provider.acquire(modelsDir).forEach(events.add);
      await Future<void>.delayed(Duration.zero);
      staged.writeAsBytesSync(List.filled(_whisper().sizeBytes.toInt(), 0));
      downloads.eventController.add(
        DownloadProgress(
          artifactId: downloads.requests.single.artifactId,
          status: DownloadStatus.completed,
          downloadedBytes: _whisper().sizeBytes,
          totalBytes: _whisper().sizeBytes,
        ),
      );
      await acquisition;

      expect((events.last as ModelAcquisitionDone).failedFileNames, isEmpty);
      expect(await provider.isInstalled(modelsDir), isTrue);
      expect(
        File('${modelsDir.path}/ggml-tiny.en.bin.partial').existsSync(),
        isFalse,
      );
    },
  );
}
