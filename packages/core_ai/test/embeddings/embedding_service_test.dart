import 'package:core_ai/core_ai.dart';
import 'package:flutter_test/flutter_test.dart';

OfflineModelInfo _model(
  String id, {
  List<ModelCapability> capabilities = const [ModelCapability.embeddings],
  List<String> tags = const [],
}) => OfflineModelInfo(
  id: id,
  name: id,
  family: ModelFamily.gemma,
  fileSizeBytes: 1000,
  capabilities: capabilities,
  tags: tags,
);

void main() {
  final embedModel = _model('embed-model');
  final tokenizerModel = _model(
    'tokenizer-model',
    capabilities: const [],
    tags: const ['tokenizer', 'embed-model'],
  );

  group('EmbeddingService.embed', () {
    test(
      'reports noModelInstalled when nothing with the embeddings capability is downloaded',
      () async {
        final service = EmbeddingService(
          client: _FakeEmbeddingClient(),
          downloadService: _FakeModelDownloadService(downloaded: const {}),
          catalog: [embedModel, tokenizerModel],
        );

        final result = await service.embed('hello');

        expect(result.isReady, isFalse);
        expect(result.unavailable, EmbeddingUnavailable.noModelInstalled);
      },
    );

    test(
      'initializes the client with the resolved model and its paired tokenizer paths',
      () async {
        final client = _FakeEmbeddingClient();
        final service = EmbeddingService(
          client: client,
          downloadService: _FakeModelDownloadService(
            downloaded: {
              'embed-model': '/models/embed-model.tflite',
              'tokenizer-model': '/models/sentencepiece.model',
            },
          ),
          catalog: [embedModel, tokenizerModel],
        );

        await service.embed('hello');

        expect(client.initializeCalls, 1);
        expect(client.lastModelPath, '/models/embed-model.tflite');
        expect(client.lastTokenizerPath, '/models/sentencepiece.model');
      },
    );

    test('returns the ready vector on success', () async {
      final service = EmbeddingService(
        client: _FakeEmbeddingClient(vector: [0.1, 0.2, 0.3]),
        downloadService: _FakeModelDownloadService(
          downloaded: {
            'embed-model': '/models/embed-model.tflite',
            'tokenizer-model': '/models/sentencepiece.model',
          },
        ),
        catalog: [embedModel, tokenizerModel],
      );

      final result = await service.embed('hello');

      expect(result.isReady, isTrue);
      expect(result.vector, [0.1, 0.2, 0.3]);
      expect(
        result.modelId,
        'embed-model',
        reason:
            'callers that persist a vector need to know which model '
            'produced it',
      );
    });

    test('modelId is null when unavailable', () async {
      final service = EmbeddingService(
        client: _FakeEmbeddingClient(),
        downloadService: _FakeModelDownloadService(downloaded: const {}),
        catalog: [embedModel, tokenizerModel],
      );

      final result = await service.embed('hello');

      expect(result.modelId, isNull);
    });

    test('only initializes the client once across repeated calls', () async {
      final client = _FakeEmbeddingClient();
      final service = EmbeddingService(
        client: client,
        downloadService: _FakeModelDownloadService(
          downloaded: {
            'embed-model': '/models/embed-model.tflite',
            'tokenizer-model': '/models/sentencepiece.model',
          },
        ),
        catalog: [embedModel, tokenizerModel],
      );

      await service.embed('hello');
      await service.embed('world');

      expect(client.initializeCalls, 1);
      expect(client.embedCalls, 2);
    });

    test('forwards EmbeddingTaskType to the client', () async {
      final client = _FakeEmbeddingClient();
      final service = EmbeddingService(
        client: client,
        downloadService: _FakeModelDownloadService(
          downloaded: {
            'embed-model': '/models/embed-model.tflite',
            'tokenizer-model': '/models/sentencepiece.model',
          },
        ),
        catalog: [embedModel, tokenizerModel],
      );

      await service.embed(
        'hello',
        taskType: EmbeddingTaskType.retrievalQuery,
      );

      expect(client.lastTaskType, EmbeddingTaskType.retrievalQuery);
    });

    test(
      'reports modelFailed, not an exception, when the client throws',
      () async {
        final service = EmbeddingService(
          client: _FakeEmbeddingClient(embedError: StateError('native crash')),
          downloadService: _FakeModelDownloadService(
            downloaded: {
              'embed-model': '/models/embed-model.tflite',
              'tokenizer-model': '/models/sentencepiece.model',
            },
          ),
          catalog: [embedModel, tokenizerModel],
        );

        final result = await service.embed('hello');

        expect(result.isReady, isFalse);
        expect(result.unavailable, EmbeddingUnavailable.modelFailed);
        expect(result.detail, contains('native crash'));
      },
    );
  });
}

class _FakeEmbeddingClient implements EmbeddingClient {
  _FakeEmbeddingClient({this.vector = const [0.0], this.embedError});

  final List<double> vector;
  final Object? embedError;
  var initializeCalls = 0;
  var embedCalls = 0;
  String? lastModelPath;
  String? lastTokenizerPath;

  @override
  Future<void> initialize({
    required String modelPath,
    required String tokenizerPath,
    bool useGpu = false,
  }) async {
    initializeCalls++;
    lastModelPath = modelPath;
    lastTokenizerPath = tokenizerPath;
  }

  @override
  Future<bool> isReady() async => initializeCalls > 0;

  @override
  Future<List<double>> embed({
    required String text,
    EmbeddingTaskType taskType = EmbeddingTaskType.semanticSimilarity,
  }) async {
    embedCalls++;
    lastTaskType = taskType;
    if (embedError != null) throw embedError!;
    return vector;
  }

  EmbeddingTaskType? lastTaskType;
}

class _FakeModelDownloadService extends ModelDownloadService {
  _FakeModelDownloadService({required this.downloaded});

  final Map<String, String> downloaded;

  @override
  Future<bool> isModelDownloaded(
    String modelId, {
    OfflineModelInfo? model,
  }) async {
    return downloaded.containsKey(modelId);
  }

  @override
  Future<String> getModelPath(String modelId, {OfflineModelInfo? model}) async {
    return downloaded[modelId] ?? '/missing/$modelId';
  }

  @override
  Stream<ModelDownloadProgress> downloadModel(OfflineModelInfo model) {
    // EmbeddingService must never trigger a download itself -- see the
    // "does not download a model itself" acceptance criterion. A call here
    // fails the test loudly instead of the assertion silently proving
    // nothing because the fake never records anything.
    throw StateError(
      'EmbeddingService must never call downloadModel (${model.id})',
    );
  }
}
