import 'package:core_ai/core_ai.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockModelStorageManager extends Mock implements ModelStorageManager {}
class MockModelRegistry extends Mock implements ModelRegistry {}
class MockModelDownloadService extends Mock implements ModelDownloadService {}

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

    final testModel = const OfflineModelInfo(
      id: 'gemma-2b-it-q4',
      name: 'Gemma 2B Instruct',
      family: ModelFamily.gemma,
      fileSizeBytes: 1500000000,
      downloadUrl: 'https://example.com/gemma.gguf',
    );

    setUp(() {
      mockStorage = MockModelStorageManager();
      mockRegistry = MockModelRegistry();
      mockDownload = MockModelDownloadService();
      manager = IntelligentModelManager(mockStorage, mockRegistry, mockDownload);
    });

    test('listModels maps OfflineModelInfo to ModelEntry correctly when downloaded', () async {
      when(() => mockRegistry.allModels).thenReturn([testModel]);
      when(
        () => mockStorage.findExistingModelPath(testModel.id, model: testModel),
      ).thenAnswer((_) async => '/path/to/gemma.gguf');

      final results = await manager.listModels();

      expect(results.length, 1);
      final entry = results.first;
      expect(entry.id, testModel.id);
      expect(entry.name, testModel.name);
      expect(entry.isDownloaded, isTrue);
      expect(entry.localPath, '/path/to/gemma.gguf');
      expect(entry.sizeBytes, testModel.fileSizeBytes);
    });

    test('listModels maps OfflineModelInfo to ModelEntry correctly when NOT downloaded', () async {
      when(() => mockRegistry.allModels).thenReturn([testModel]);
      when(
        () => mockStorage.findExistingModelPath(testModel.id, model: testModel),
      ).thenAnswer((_) async => null);

      final results = await manager.listModels();

      expect(results.length, 1);
      final entry = results.first;
      expect(entry.id, testModel.id);
      expect(entry.isDownloaded, isFalse);
      expect(entry.localPath, isNull);
    });

    test('downloadModel starts download via ModelDownloadService', () async {
      when(() => mockRegistry.getModel(testModel.id)).thenReturn(testModel);
      when(() => mockDownload.downloadModel(any())).thenAnswer((_) => const Stream.empty());

      await manager.downloadModel(testModel.id);

      verify(() => mockRegistry.getModel(testModel.id)).called(1);
      verify(() => mockDownload.downloadModel(testModel)).called(1);
    });

    test('downloadModel throws ArgumentError for unknown model ID', () async {
      when(() => mockRegistry.getModel('unknown')).thenReturn(null);

      expect(
        () => manager.downloadModel('unknown'),
        throwsArgumentError,
      );
    });

    test('deleteModel calls delete on download service and marks as removed in registry', () async {
      when(() => mockDownload.deleteModel(testModel.id)).thenAnswer((_) async => true);
      when(() => mockRegistry.markAsRemoved(testModel.id)).thenAnswer((_) {});

      await manager.deleteModel(testModel.id);

      verify(() => mockDownload.deleteModel(testModel.id)).called(1);
      verify(() => mockRegistry.markAsRemoved(testModel.id)).called(1);
    });
  });
}
