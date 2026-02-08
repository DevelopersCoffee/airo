import 'package:core_ai/core_ai.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OfflineModelInfo', () {
    test('should create with required fields', () {
      const model = OfflineModelInfo(
        id: 'test-model',
        name: 'Test Model',
        family: ModelFamily.gemma,
        fileSizeBytes: 1500000000,
      );

      expect(model.id, 'test-model');
      expect(model.name, 'Test Model');
      expect(model.family, ModelFamily.gemma);
      expect(model.isDownloaded, false);
    });

    test('should calculate file size display', () {
      const smallModel = OfflineModelInfo(
        id: 'small',
        name: 'Small',
        family: ModelFamily.gemma,
        fileSizeBytes: 500000000, // 500 MB
      );
      expect(smallModel.fileSizeDisplay, contains('MB'));

      const largeModel = OfflineModelInfo(
        id: 'large',
        name: 'Large',
        family: ModelFamily.llama,
        fileSizeBytes: 4000000000, // 4 GB
      );
      expect(largeModel.fileSizeDisplay, contains('GB'));
    });

    test('should detect downloaded status', () {
      const notDownloaded = OfflineModelInfo(
        id: 'test',
        name: 'Test',
        family: ModelFamily.phi,
        fileSizeBytes: 1000000000,
      );
      expect(notDownloaded.isDownloaded, false);

      const downloaded = OfflineModelInfo(
        id: 'test',
        name: 'Test',
        family: ModelFamily.phi,
        fileSizeBytes: 1000000000,
        filePath: '/path/to/model.gguf',
      );
      expect(downloaded.isDownloaded, true);
    });

    test('should serialize to/from JSON', () {
      const original = OfflineModelInfo(
        id: 'test-model',
        name: 'Test Model',
        family: ModelFamily.gemma,
        fileSizeBytes: 1500000000,
        quantization: ModelQuantization.q4,
        credibility: ModelCredibility.official,
        tags: ['chat', 'mobile'],
      );

      final json = original.toJson();
      final restored = OfflineModelInfo.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.family, original.family);
      expect(restored.quantization, original.quantization);
      expect(restored.credibility, original.credibility);
      expect(restored.tags, original.tags);
    });

    test('should format parameter count display', () {
      const model2B = OfflineModelInfo(
        id: 'test',
        name: 'Test',
        family: ModelFamily.gemma,
        fileSizeBytes: 1000000000,
        parameterCount: 2000000000,
      );
      expect(model2B.parameterCountDisplay, '2.0B');

      const model7B = OfflineModelInfo(
        id: 'test',
        name: 'Test',
        family: ModelFamily.llama,
        fileSizeBytes: 4000000000,
        parameterCount: 7000000000,
      );
      expect(model7B.parameterCountDisplay, '7.0B');
    });
  });

  group('ModelCredibility', () {
    test('should have correct trust levels', () {
      expect(ModelCredibility.official.isTrusted, true);
      expect(ModelCredibility.verified.isTrusted, true);
      expect(ModelCredibility.community.isTrusted, false);
      expect(ModelCredibility.unverified.isTrusted, false);
    });

    test('should warn for unverified models', () {
      expect(ModelCredibility.official.shouldWarn, false);
      expect(ModelCredibility.unverified.shouldWarn, true);
    });

    test('should have increasing trust scores', () {
      expect(
        ModelCredibility.official.trustScore,
        greaterThan(ModelCredibility.verified.trustScore),
      );
      expect(
        ModelCredibility.verified.trustScore,
        greaterThan(ModelCredibility.community.trustScore),
      );
    });
  });

  group('ModelQuantization', () {
    test('should have correct bit values', () {
      expect(ModelQuantization.q4.bits, 4);
      expect(ModelQuantization.q8.bits, 8);
      expect(ModelQuantization.fp16.bits, 16);
    });

    test('should have correct memory multipliers', () {
      expect(ModelQuantization.q4.memoryMultiplier, 0.25);
      expect(ModelQuantization.q8.memoryMultiplier, 0.5);
      expect(ModelQuantization.fp16.memoryMultiplier, 1.0);
    });
  });

  group('ModelRegistry', () {
    late ModelRegistry registry;

    setUp(() {
      registry = ModelRegistry();
    });

    tearDown(() {
      registry.dispose();
    });

    test('should register and retrieve models', () {
      const model = OfflineModelInfo(
        id: 'test-model',
        name: 'Test Model',
        family: ModelFamily.gemma,
        fileSizeBytes: 1500000000,
      );

      registry.registerModel(model);

      expect(registry.modelCount, 1);
      expect(registry.hasModel('test-model'), true);
      expect(registry.getModel('test-model'), model);
    });

    test('should unregister models', () {
      const model = OfflineModelInfo(
        id: 'test-model',
        name: 'Test Model',
        family: ModelFamily.gemma,
        fileSizeBytes: 1500000000,
      );

      registry.registerModel(model);
      expect(registry.modelCount, 1);

      final removed = registry.unregisterModel('test-model');
      expect(removed, true);
      expect(registry.modelCount, 0);
      expect(registry.hasModel('test-model'), false);
    });

    test('should query models by family', () {
      registry.registerModels([
        const OfflineModelInfo(
          id: 'gemma-1',
          name: 'Gemma 1',
          family: ModelFamily.gemma,
          fileSizeBytes: 1000000000,
        ),
        const OfflineModelInfo(
          id: 'llama-1',
          name: 'Llama 1',
          family: ModelFamily.llama,
          fileSizeBytes: 2000000000,
        ),
        const OfflineModelInfo(
          id: 'gemma-2',
          name: 'Gemma 2',
          family: ModelFamily.gemma,
          fileSizeBytes: 1500000000,
        ),
      ]);

      final gemmaModels = registry.queryModels(family: ModelFamily.gemma);
      expect(gemmaModels.length, 2);
      expect(gemmaModels.every((m) => m.family == ModelFamily.gemma), true);
    });

    test('should query models by download status', () {
      registry.registerModels([
        const OfflineModelInfo(
          id: 'downloaded',
          name: 'Downloaded Model',
          family: ModelFamily.phi,
          fileSizeBytes: 1000000000,
          filePath: '/path/to/model.gguf',
        ),
        const OfflineModelInfo(
          id: 'not-downloaded',
          name: 'Not Downloaded',
          family: ModelFamily.phi,
          fileSizeBytes: 1000000000,
        ),
      ]);

      final downloaded = registry.queryModels(downloaded: true);
      expect(downloaded.length, 1);
      expect(downloaded.first.id, 'downloaded');

      final available = registry.queryModels(downloaded: false);
      expect(available.length, 1);
      expect(available.first.id, 'not-downloaded');
    });

    test('should query models by search query', () {
      registry.registerModels([
        const OfflineModelInfo(
          id: 'gemma-instruct',
          name: 'Gemma Instruct',
          family: ModelFamily.gemma,
          fileSizeBytes: 1000000000,
          description: 'An instruction-tuned model',
        ),
        const OfflineModelInfo(
          id: 'llama-chat',
          name: 'Llama Chat',
          family: ModelFamily.llama,
          fileSizeBytes: 2000000000,
          tags: ['chat', 'assistant'],
        ),
      ]);

      final instructResults = registry.queryModels(searchQuery: 'instruct');
      expect(instructResults.length, 1);
      expect(instructResults.first.id, 'gemma-instruct');

      final chatResults = registry.queryModels(searchQuery: 'chat');
      expect(chatResults.length, 1);
      expect(chatResults.first.id, 'llama-chat');
    });

    test('should emit events on changes', () async {
      final events = <ModelRegistryEvent>[];
      registry.changes.listen(events.add);

      const model = OfflineModelInfo(
        id: 'test',
        name: 'Test',
        family: ModelFamily.gemma,
        fileSizeBytes: 1000000000,
      );

      registry.registerModel(model);
      await Future.delayed(Duration.zero);

      expect(events.length, 1);
      expect(events.first, isA<ModelAddedEvent>());
    });

    test('should mark model as downloaded', () {
      const model = OfflineModelInfo(
        id: 'test',
        name: 'Test',
        family: ModelFamily.gemma,
        fileSizeBytes: 1000000000,
      );

      registry.registerModel(model);
      expect(registry.getModel('test')?.isDownloaded, false);

      registry.markAsDownloaded('test', '/path/to/model.gguf');
      expect(registry.getModel('test')?.isDownloaded, true);
      expect(registry.getModel('test')?.filePath, '/path/to/model.gguf');
    });
  });

  group('ModelCatalog', () {
    test('should have bundled models', () {
      final models = ModelCatalog.bundledModels;
      expect(models, isNotEmpty);
    });

    test('should have mobile recommended models under 3GB', () {
      final models = ModelCatalog.mobileRecommended;
      for (final model in models) {
        expect(model.fileSizeBytes, lessThan(3000000000));
      }
    });

    test('should filter by family', () {
      final gemmaModels = ModelCatalog.byFamily(ModelFamily.gemma);
      for (final model in gemmaModels) {
        expect(model.family, ModelFamily.gemma);
      }
    });

    test('should have official models', () {
      final officialModels = ModelCatalog.officialModels;
      for (final model in officialModels) {
        expect(model.credibility, ModelCredibility.official);
      }
    });
  });
}
