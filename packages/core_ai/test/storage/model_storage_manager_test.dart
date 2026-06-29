import 'dart:io';
import 'package:core_ai/core_ai.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ModelStorageManager storageManager;
  late List<MethodCall> log;
  late Directory tempDir;

  const MethodChannel channel = MethodChannel('com.airo.model_download');

  setUp(() async {
    log = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          log.add(methodCall);
          if (methodCall.method == 'getFreeDiskSpace') {
            return 2 * 1024 * 1024 * 1024; // 2 GB
          }
          return null;
        });

    storageManager = ModelStorageManager(channel: channel);
    tempDir = await Directory.systemTemp.createTemp('airo_storage_test');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'getApplicationDocumentsDirectory') {
              return tempDir.path;
            }
            return null;
          },
        );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
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
}
