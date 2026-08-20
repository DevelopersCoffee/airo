import 'package:core_ai/core_ai.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ModelCatalog web runtime support', () {
    test('Gemma-4-E2B catalog size matches the published artifact', () {
      final model = ModelCatalog.bundledModels.firstWhere(
        (m) => m.id == 'gemma-4-e2b-it-litertlm',
      );

      expect(model.fileSizeBytes, 2588147712);
    });

    test('Gemma-4-E2B is flagged web-capable with a .task asset URL', () {
      final model = ModelCatalog.bundledModels.firstWhere(
        (m) => m.id == 'gemma-4-e2b-it-litertlm',
      );

      expect(model.supportsWebRuntime, isTrue);
      expect(model.webAssetUrl, isNotNull);
      expect(model.webAssetUrl, endsWith('.task'));
    });

    test('Gemma-4-E4B is flagged web-capable with a .task asset URL', () {
      final model = ModelCatalog.bundledModels.firstWhere(
        (m) => m.id == 'gemma-4-e4b-it-litertlm',
      );

      expect(model.supportsWebRuntime, isTrue);
      expect(model.webAssetUrl, isNotNull);
      expect(model.webAssetUrl, endsWith('.task'));
    });

    test('Qwen2.5-1.5B is flagged web-capable with a .task asset URL', () {
      final model = ModelCatalog.bundledModels.firstWhere(
        (m) => m.id == 'qwen2.5-1.5b-it-litert',
      );

      expect(model.supportsWebRuntime, isTrue);
      expect(model.webAssetUrl, isNotNull);
      expect(model.webAssetUrl, endsWith('.task'));
    });

    test('non-Gemma models default to web-unsupported', () {
      final model = ModelCatalog.bundledModels.firstWhere(
        (m) => m.id == 'mistral-7b-q4',
      );

      expect(model.supportsWebRuntime, isFalse);
      expect(model.webAssetUrl, isNull);
    });

    test('byWebRuntimeSupport returns only web-capable models', () {
      final webModels = ModelCatalog.webRuntimeSupported;

      expect(webModels, isNotEmpty);
      expect(webModels.every((m) => m.supportsWebRuntime), isTrue);
    });
  });

  group('License compliance (#1630, #1718)', () {
    test('the default catalog contains no Llama-licensed model', () {
      expect(
        ModelCatalog.bundledModels.where(
          (m) =>
              m.family == ModelFamily.llama ||
              (m.license ?? '').toLowerCase().contains('llama'),
        ),
        isEmpty,
        reason:
            'Llama 3.2 Community License terms do not fit an unconditional '
            'default registry -- see #1718.',
      );
    });

    test('every bundled model declares a structured license string', () {
      for (final model in ModelCatalog.bundledModels) {
        expect(
          model.license,
          isNotNull,
          reason: '${model.id} is missing structured license metadata.',
        );
        expect(model.license, isNotEmpty);
      }
    });
  });

  group('EmbeddingGemma catalog entry', () {
    test('declares only the embeddings capability', () {
      final model = ModelCatalog.bundledModels.firstWhere(
        (m) => m.id == 'embeddinggemma-300m-embed',
      );

      expect(model.capabilities, [ModelCapability.embeddings]);
      expect(model.fileSizeBytes, 187695104);
      expect(model.downloadUrl, endsWith('.tflite'));
    });

    test('TaskModelRouter resolves AiTask.embeddings to the embed entry, '
        'never the tokenizer', () {
      const router = TaskModelRouter();

      final resolved = router.resolve(
        AiTask.embeddings,
        ModelCatalog.bundledModels,
      );

      expect(resolved?.id, 'embeddinggemma-300m-embed');
    });

    test('the tokenizer entry is not routable via any AiTask', () {
      final tokenizer = ModelCatalog.bundledModels.firstWhere(
        (m) => m.id == 'embeddinggemma-300m-tokenizer',
      );

      expect(tokenizer.capabilities, isEmpty);
      for (final task in AiTask.values.where((t) => t.isCatalogResolvable)) {
        const router = TaskModelRouter();
        final resolved = router.resolve(task, [tokenizer]);
        expect(
          resolved,
          isNull,
          reason: 'the tokenizer must never answer for $task',
        );
      }
    });

    test('companionsFor queues the tokenizer with the embed model', () {
      final embed = ModelCatalog.bundledModels.firstWhere(
        (m) => m.id == 'embeddinggemma-300m-embed',
      );

      final companions = ModelCatalog.companionsFor(embed);

      expect(companions.map((m) => m.id), ['embeddinggemma-300m-tokenizer']);
      expect(ModelCatalog.companionsFor(companions.single), isEmpty);
    });
  });

  group('Honest capability tags', () {
    test(
      'chat packages that summarize meetings declare meetingSummarization',
      () {
        final chatModels = ModelCatalog.bundledModels.where(
          (model) => model.capabilities.contains(ModelCapability.chat),
        );
        expect(
          chatModels.any(
            (model) => model.capabilities.contains(
              ModelCapability.meetingSummarization,
            ),
          ),
          isTrue,
        );
      },
    );

    test(
      'no catalog row invents vision without image modality or capability',
      () {
        for (final model in ModelCatalog.bundledModels) {
          if (model.capabilities.contains(ModelCapability.imageUnderstanding)) {
            expect(
              model.supportsVision ||
                  model.modalities.contains(ModelModality.image),
              isTrue,
              reason: '${model.id} tagged vision without image support',
            );
          }
        }
      },
    );

    test('tokenizer companions stay capability-empty', () {
      final tokenizer = ModelCatalog.bundledModels.where(
        (model) => model.id.contains('tokenizer'),
      );
      for (final model in tokenizer) {
        expect(model.capabilities, isEmpty);
      }
    });
  });
}
