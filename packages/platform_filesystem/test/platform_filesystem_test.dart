import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_filesystem/platform_filesystem.dart';
import 'package:platform_filesystem/src/directories/default_directory_provider.dart';
import 'package:platform_filesystem/src/files/default_file_manager.dart';
import 'package:platform_filesystem/src/integrity/crypto_integrity_verifier.dart';
import 'package:platform_events/platform_events.dart';
import 'package:path/path.dart' as p;

class MockEventPublisher implements EventPublisher {
  @override
  void publish(PlatformEvent event) {}
}

void main() {
  late Directory tempDir;
  late DefaultDirectoryProvider directoryProvider;
  late DefaultFileManager fileManager;
  late CryptoIntegrityVerifier integrityVerifier;
  late MockEventPublisher eventPublisher;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('platform_filesystem_test_');
    directoryProvider = DefaultDirectoryProvider()..initializeWith(tempDir);
    
    // Mock event publisher for test
    eventPublisher = MockEventPublisher();
    
    fileManager = DefaultFileManager(directoryProvider, eventPublisher);
    integrityVerifier = CryptoIntegrityVerifier();
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('DirectoryProvider', () {
    test('Creates predictable directory hierarchy', () async {
      final models = await directoryProvider.modelsDirectory();
      expect(p.basename(models.path), 'models');
      
      final workspace = await directoryProvider.workspaceDirectory('ws_123');
      expect(p.basename(workspace.path), 'ws_123');
      expect(p.basename(workspace.parent.path), 'workspaces');
    });
  });

  group('FileManager', () {
    test('Can create and delete typed files', () async {
      final modelFile = ModelFile('llama3.gguf', 'llm');
      
      await fileManager.createFile(modelFile);
      expect(await fileManager.exists(modelFile), isTrue);
      
      await fileManager.deleteFile(modelFile);
      expect(await fileManager.exists(modelFile), isFalse);
    });

    test('Atomic write creates file safely', () async {
      final doc = DocumentFile('notes.txt', 'ws_123');
      
      await fileManager.atomicWrite(doc, (tempFile) async {
        await tempFile.writeAsString('Hello AIRO');
      });
      
      expect(await fileManager.exists(doc), isTrue);
    });
  });

  group('IntegrityVerifier', () {
    test('Verifies valid SHA-256 hash', () async {
      final file = File(p.join(tempDir.path, 'test.txt'));
      await file.writeAsString('Hello World'); // SHA-256 of 'Hello World'
      
      // Known SHA-256 for 'Hello World'
      const expectedHash = 'a591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e';
      
      final result = await integrityVerifier.verifySha256(file, expectedHash);
      
      expect(result.isValid, isTrue);
      expect(result.actualHash, expectedHash);
    });

    test('Fails on invalid SHA-256 hash', () async {
      final file = File(p.join(tempDir.path, 'test.txt'));
      await file.writeAsString('Corrupt Data');
      
      const expectedHash = 'a591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e';
      
      final result = await integrityVerifier.verifySha256(file, expectedHash);
      
      expect(result.isValid, isFalse);
    });
  });
}
