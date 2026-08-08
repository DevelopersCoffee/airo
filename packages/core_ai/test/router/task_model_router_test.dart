import 'package:core_ai/src/models/offline_model_info.dart';
import 'package:core_ai/src/router/ai_task.dart';
import 'package:core_ai/src/router/task_model_router.dart';
import 'package:flutter_test/flutter_test.dart';

OfflineModelInfo _model(
  String id, {
  List<ModelCapability> capabilities = const [ModelCapability.chat],
}) => OfflineModelInfo(
  id: id,
  name: id,
  family: ModelFamily.gemma,
  fileSizeBytes: 1000,
  capabilities: capabilities,
);

void main() {
  group('AiTask', () {
    test('every text/vision task carries the capability it routes on', () {
      expect(AiTask.chat.requiredCapability, ModelCapability.chat);
      expect(
        AiTask.meetingSummarization.requiredCapability,
        ModelCapability.meetingSummarization,
      );
      expect(
        AiTask.translation.requiredCapability,
        ModelCapability.translation,
      );
      expect(AiTask.embeddings.requiredCapability, ModelCapability.embeddings);
      expect(AiTask.ocr.requiredCapability, ModelCapability.ocr);
      expect(AiTask.chat.isCatalogResolvable, isTrue);
    });

    test('speech tasks have no catalog capability and are not resolvable', () {
      expect(AiTask.speechToText.requiredCapability, isNull);
      expect(AiTask.textToSpeech.requiredCapability, isNull);
      expect(AiTask.speechToText.isCatalogResolvable, isFalse);
      expect(AiTask.textToSpeech.isCatalogResolvable, isFalse);
    });
  });

  group('TaskModelRouter.resolve', () {
    test(
      'picks the first available model declaring the required capability',
      () {
        const router = TaskModelRouter();
        final chatModel = _model('chat-model');
        final embeddingModel = _model(
          'embed-model',
          capabilities: [ModelCapability.embeddings],
        );

        expect(
          router.resolve(AiTask.chat, [chatModel, embeddingModel]),
          chatModel,
        );
        expect(
          router.resolve(AiTask.embeddings, [chatModel, embeddingModel]),
          embeddingModel,
        );
      },
    );

    test('does not re-rank -- returns the first capable match in order', () {
      const router = TaskModelRouter();
      final first = _model('first');
      final second = _model('second');

      expect(router.resolve(AiTask.chat, [first, second]), first);
      expect(router.resolve(AiTask.chat, [second, first]), second);
    });

    test('returns null when no available model declares the capability', () {
      const router = TaskModelRouter();
      final embeddingOnly = _model(
        'embed-only',
        capabilities: [ModelCapability.embeddings],
      );

      expect(router.resolve(AiTask.chat, [embeddingOnly]), isNull);
      expect(router.resolve(AiTask.chat, []), isNull);
    });

    test('an override wins over capability search when it is installed', () {
      final preferred = _model('preferred-chat-model');
      final other = _model('other-chat-model');
      final router = TaskModelRouter(
        taskOverrides: {AiTask.chat: preferred.id},
      );

      expect(router.resolve(AiTask.chat, [other, preferred]), preferred);
    });

    test(
      'an override for a model that is not installed degrades to capability search',
      () {
        final installed = _model('installed-chat-model');
        const router = TaskModelRouter(
          taskOverrides: {AiTask.chat: 'not-installed-model'},
        );

        expect(router.resolve(AiTask.chat, [installed]), installed);
      },
    );

    test('throws for speech tasks instead of silently returning null', () {
      const router = TaskModelRouter();

      expect(
        () => router.resolve(AiTask.speechToText, []),
        throwsA(isA<UnroutableTaskException>()),
      );
      expect(
        () => router.resolve(AiTask.textToSpeech, [_model('anything')]),
        throwsA(isA<UnroutableTaskException>()),
      );
    });
  });
}
