import 'package:core_ai/src/embeddings/embedding_client.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('test.embedding');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  group('MethodChannelEmbeddingClient', () {
    test('initialize forwards the model and tokenizer paths', () async {
      MethodCall? captured;
      messenger.setMockMethodCallHandler(channel, (call) async {
        captured = call;
        return null;
      });

      final client = MethodChannelEmbeddingClient(channel: channel);
      await client.initialize(
        modelPath: '/models/embed.tflite',
        tokenizerPath: '/models/sentencepiece.model',
        useGpu: true,
      );

      expect(captured?.method, 'initialize');
      expect(captured?.arguments, {
        'modelPath': '/models/embed.tflite',
        'tokenizerPath': '/models/sentencepiece.model',
        'useGpu': true,
      });
    });

    test('embed converts the native vector to a List<double>', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'embed');
        expect(call.arguments, {
          'text': 'hello',
          'taskType': 'semanticSimilarity',
        });
        return [0.1, 0.2, 0.3];
      });

      final client = MethodChannelEmbeddingClient(channel: channel);
      final vector = await client.embed(text: 'hello');

      expect(vector, [0.1, 0.2, 0.3]);
    });

    test('embed forwards retrievalQuery / retrievalDocument task types', () async {
      MethodCall? captured;
      messenger.setMockMethodCallHandler(channel, (call) async {
        captured = call;
        return [0.0];
      });

      final client = MethodChannelEmbeddingClient(channel: channel);
      await client.embed(
        text: 'query',
        taskType: EmbeddingTaskType.retrievalQuery,
      );
      expect(captured?.arguments, {
        'text': 'query',
        'taskType': 'retrievalQuery',
      });

      await client.embed(
        text: 'doc',
        taskType: EmbeddingTaskType.retrievalDocument,
      );
      expect(captured?.arguments, {
        'text': 'doc',
        'taskType': 'retrievalDocument',
      });
    });

    test('embed throws when the native side returns nothing', () async {
      messenger.setMockMethodCallHandler(channel, (call) async => null);

      final client = MethodChannelEmbeddingClient(channel: channel);

      expect(() => client.embed(text: 'hello'), throwsStateError);
    });

    test(
      'isReady is false, not an error, when no plugin is registered',
      () async {
        // No handler set at all -- this is exactly what a build without the
        // embedding plugin (the stub flavor) looks like from Dart's side.
        final client = MethodChannelEmbeddingClient(channel: channel);

        expect(await client.isReady(), isFalse);
      },
    );

    test(
      'isReady is false when the native side reports a platform error',
      () async {
        messenger.setMockMethodCallHandler(channel, (call) async {
          throw PlatformException(code: 'NOT_INITIALIZED');
        });

        final client = MethodChannelEmbeddingClient(channel: channel);

        expect(await client.isReady(), isFalse);
      },
    );

    test('a wedged native call is bounded by the timeout', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        return true;
      });

      final client = MethodChannelEmbeddingClient(
        channel: channel,
        operationTimeout: const Duration(milliseconds: 10),
      );

      expect(await client.isReady(), isFalse);
    });
  });
}
