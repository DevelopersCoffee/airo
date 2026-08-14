import 'dart:io';
import 'package:core_ai/core_ai.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:platform_downloads/platform_downloads.dart';

class FakeBackgroundDownloads implements BackgroundDownloads {
  int? availableBytes = 2 * 1024 * 1024 * 1024;

  @override
  Stream<DownloadProgress> get events => const Stream.empty();

  @override
  Future<void> cancel(String artifactId) async {}

  @override
  Future<void> enqueue(DownloadArtifactRequest request) async {}

  @override
  Future<int?> getAvailableBytes() async => availableBytes;

  @override
  Future<DownloadQueueSnapshot> getQueue() async {
    return const DownloadQueueSnapshot(entries: []);
  }

  @override
  Future<void> pause(String artifactId) async {}

  @override
  Future<void> resume(String artifactId) async {}

  @override
  Future<void> retry(String artifactId) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ModelStorageManager storageManager;
  late FakeBackgroundDownloads downloads;
  late Directory tempDir;

  setUp(() async {
    downloads = FakeBackgroundDownloads();
    storageManager = ModelStorageManager(downloads: downloads);
    tempDir = await Directory.systemTemp.createTemp('airo_storage_test');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'getApplicationDocumentsDirectory') {
              return tempDir.path;
            }
            if (methodCall.method == 'getApplicationSupportDirectory') {
              return path.join(tempDir.path, 'support');
            }
            return null;
          },
        );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  // Application support is private and, on iOS, neither user-visible in Files
  // nor backed up to iCloud. A caller that asks for it must not silently get
  // documents instead.
  test(
    'applicationSupport keeps artifacts out of the documents root',
    () async {
      final manager = ModelStorageManager(
        downloads: downloads,
        location: ModelStorageLocation.applicationSupport,
      );

      final dir = await manager.getModelsDirectory();

      expect(dir.path, path.join(tempDir.path, 'support', 'models'));
      expect(dir.path, isNot(startsWith(path.join(tempDir.path, 'models'))));
      expect(await dir.exists(), isTrue);
    },
  );

  test('applicationDocuments remains the default root', () async {
    final dir = await storageManager.getModelsDirectory();
    expect(dir.path, path.join(tempDir.path, 'models'));
  });

  test('calculateSHA256 computes correct hash', () async {
    final testFile = File(path.join(tempDir.path, 'test.txt'));
    await testFile.writeAsString('hello world');

    const expectedHash =
        'b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9';

    final hash = await storageManager.calculateSHA256(testFile);
    expect(hash, expectedHash);
  });

  test('verifyModelIntegrity matches valid file', () async {
    final modelsDir = Directory(path.join(tempDir.path, 'models'));
    await modelsDir.create(recursive: true);

    final file = File(path.join(modelsDir.path, 'gemma.gguf'));
    await file.writeAsString('hello world');

    final model = OfflineModelInfo(
      id: 'gemma',
      name: 'Gemma 2B',
      family: ModelFamily.gemma,
      fileSizeBytes: 11,
      sha256:
          'b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9',
    );

    final isValid = await storageManager.verifyModelIntegrity(model);
    expect(isValid, isTrue);
  });

  test(
    'getModelPath preserves LiteRT artifact extension from download URL',
    () async {
      final modelPath = await storageManager.getModelPath(
        'gemma-4-e2b-it-litertlm',
        model: const OfflineModelInfo(
          id: 'gemma-4-e2b-it-litertlm',
          name: 'Gemma 4 E2B',
          family: ModelFamily.gemma,
          fileSizeBytes: 1024,
          downloadUrl: 'https://example.com/gemma-4-E2B-it.litertlm',
        ),
      );

      expect(modelPath, endsWith('gemma-4-e2b-it-litertlm.litertlm'));
    },
  );

  test(
    'findExistingModelPath resolves legacy gguf path for LiteRT models',
    () async {
      final modelsDir = Directory(path.join(tempDir.path, 'models'));
      await modelsDir.create(recursive: true);

      final legacyFile = File(
        path.join(modelsDir.path, 'gemma-4-e2b-it-litertlm.gguf'),
      );
      await legacyFile.writeAsString('legacy content');

      final resolvedPath = await storageManager.findExistingModelPath(
        'gemma-4-e2b-it-litertlm',
        model: const OfflineModelInfo(
          id: 'gemma-4-e2b-it-litertlm',
          name: 'Gemma 4 E2B',
          family: ModelFamily.gemma,
          fileSizeBytes: 14,
          downloadUrl: 'https://example.com/gemma-4-E2B-it.litertlm',
        ),
      );

      expect(resolvedPath, legacyFile.path);
    },
  );

  test('verifyModelIntegrity fails invalid file', () async {
    final modelsDir = Directory(path.join(tempDir.path, 'models'));
    await modelsDir.create(recursive: true);

    final file = File(path.join(modelsDir.path, 'gemma.gguf'));
    await file.writeAsString('wrong content');

    final model = OfflineModelInfo(
      id: 'gemma',
      name: 'Gemma 2B',
      family: ModelFamily.gemma,
      fileSizeBytes: 11,
      sha256:
          'b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9',
    );

    final isValid = await storageManager.verifyModelIntegrity(model);
    expect(isValid, isFalse);
  });

  test('hasEnoughDiskSpace evaluates space correctly', () async {
    expect(await storageManager.hasEnoughDiskSpace(1024 * 1024 * 1024), isTrue);
    expect(
      await storageManager.hasEnoughDiskSpace(1800 * 1024 * 1024),
      isFalse,
    );
  });

  test('install receipts persist exact catalog update evidence', () async {
    const model = OfflineModelInfo(
      id: 'receipt-model',
      name: 'Receipt Model',
      family: ModelFamily.gemma,
      fileSizeBytes: 1024,
      downloadUrl: 'https://example.com/model-v2.gguf',
      version: '2.0.0',
      sha256:
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
    );

    final written = await storageManager.writeInstallReceipt(
      model,
      installedAt: DateTime.utc(2026, 7, 27),
    );
    final restored = await storageManager.readInstallReceipt(model.id);

    expect(restored?.modelId, model.id);
    expect(restored?.version, '2.0.0');
    expect(restored?.catalogFingerprint, written.catalogFingerprint);
    expect(
      restored?.catalogFingerprint,
      storageManager.catalogFingerprint(model),
    );

    await storageManager.deleteInstallReceipt(model.id);
    expect(await storageManager.readInstallReceipt(model.id), isNull);
  });

  test(
    'cleanupOrphanedFiles deletes unregistered files across extensions',
    () async {
      final modelsDir = Directory(path.join(tempDir.path, 'models'));
      await modelsDir.create(recursive: true);

      final registeredFile = File(path.join(modelsDir.path, 'registered.gguf'));
      await registeredFile.writeAsString('registered content');

      final orphanedFile = File(path.join(modelsDir.path, 'orphaned.litertlm'));
      await orphanedFile.writeAsString('orphaned content');

      final orphanedTmpFile = File(
        path.join(modelsDir.path, 'another.task.tmp'),
      );
      await orphanedTmpFile.writeAsString('temp content');

      final catalog = [
        OfflineModelInfo(
          id: 'registered',
          name: 'Registered',
          family: ModelFamily.gemma,
          fileSizeBytes: 10,
        ),
      ];

      final deleted = await storageManager.cleanupOrphanedFiles(catalog);

      expect(deleted, contains(orphanedFile.path));
      expect(deleted, contains(orphanedTmpFile.path));
      expect(deleted, isNot(contains(registeredFile.path)));

      expect(await registeredFile.exists(), isTrue);
      expect(await orphanedFile.exists(), isFalse);
      expect(await orphanedTmpFile.exists(), isFalse);
    },
  );

  group('enforceStorageQuota (disk-level eviction, #1630)', () {
    Future<File> writeArtifact(
      Directory modelsDir,
      String id,
      int sizeBytes,
      DateTime modified,
    ) async {
      final file = File(path.join(modelsDir.path, '$id.gguf'));
      await file.writeAsBytes(List<int>.filled(sizeBytes, 0));
      await file.setLastModified(modified);
      return file;
    }

    test('does nothing while usage is within budget', () async {
      final modelsDir = Directory(path.join(tempDir.path, 'models'));
      await modelsDir.create(recursive: true);
      await writeArtifact(modelsDir, 'a', 100, DateTime(2026));

      final evicted = await storageManager.enforceStorageQuota(
        maxTotalBytes: 1000,
      );

      expect(evicted, isEmpty);
    });

    test(
      'deletes the oldest-installed artifacts first until under budget',
      () async {
        final modelsDir = Directory(path.join(tempDir.path, 'models'));
        await modelsDir.create(recursive: true);
        await writeArtifact(modelsDir, 'oldest', 100, DateTime(2026, 1, 1));
        await writeArtifact(modelsDir, 'middle', 100, DateTime(2026, 1, 2));
        final newestFile = await writeArtifact(
          modelsDir,
          'newest',
          100,
          DateTime(2026, 1, 3),
        );

        final evicted = await storageManager.enforceStorageQuota(
          maxTotalBytes: 150,
        );

        expect(evicted, ['oldest', 'middle']);
        expect(await newestFile.exists(), isTrue);
        expect(
          await File(path.join(modelsDir.path, 'oldest.gguf')).exists(),
          isFalse,
        );
        expect(
          await File(path.join(modelsDir.path, 'middle.gguf')).exists(),
          isFalse,
        );
      },
    );

    test('never evicts a protected model even if it is oldest', () async {
      final modelsDir = Directory(path.join(tempDir.path, 'models'));
      await modelsDir.create(recursive: true);
      final protectedFile = await writeArtifact(
        modelsDir,
        'in-use',
        100,
        DateTime(2026, 1, 1),
      );
      await writeArtifact(modelsDir, 'newer', 100, DateTime(2026, 1, 2));

      final evicted = await storageManager.enforceStorageQuota(
        maxTotalBytes: 50,
        protectedModelIds: {'in-use'},
      );

      expect(evicted, ['newer']);
      expect(await protectedFile.exists(), isTrue);
    });

    test('deletes the install receipt alongside an evicted artifact', () async {
      final modelsDir = Directory(path.join(tempDir.path, 'models'));
      await modelsDir.create(recursive: true);
      await writeArtifact(modelsDir, 'evict-me', 100, DateTime(2026, 1, 1));
      await storageManager.writeInstallReceipt(
        const OfflineModelInfo(
          id: 'evict-me',
          name: 'Evict Me',
          family: ModelFamily.gemma,
          fileSizeBytes: 100,
        ),
      );

      await storageManager.enforceStorageQuota(maxTotalBytes: 0);

      expect(await storageManager.readInstallReceipt('evict-me'), isNull);
    });

    test('ignores in-flight .tmp/.part staging files', () async {
      final modelsDir = Directory(path.join(tempDir.path, 'models'));
      await modelsDir.create(recursive: true);
      final staging = File(path.join(modelsDir.path, 'downloading.gguf.tmp'));
      await staging.writeAsBytes(List<int>.filled(500, 0));

      final total = await storageManager.installedArtifactsTotalBytes();
      final evicted = await storageManager.enforceStorageQuota(
        maxTotalBytes: 0,
      );

      expect(total, 0);
      expect(evicted, isEmpty);
      expect(await staging.exists(), isTrue);
    });
  });
}
