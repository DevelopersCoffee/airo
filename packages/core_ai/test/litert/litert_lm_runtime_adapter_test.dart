import 'package:core_ai/core_ai.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LiteRtLmRuntimeAdapter', () {
    late ActiveModelService activeModelService;

    setUp(() {
      ActiveModelService.resetInstance();
      activeModelService = ActiveModelService.forTesting();
    });

    tearDown(() async {
      await activeModelService.dispose();
      ActiveModelService.resetInstance();
    });

    test('supports LiteRT model packages by extension and tag', () async {
      final adapter = LiteRtLmRuntimeAdapter(
        client: _FakeLiteRtLmClient(hasActiveModel: true),
        activeModelService: activeModelService,
      );

      final supported = await adapter.supportsModel(
        const OfflineModelInfo(
          id: 'gemma-4-e2b-it-litertlm',
          name: 'Gemma 4 E2B',
          family: ModelFamily.gemma,
          fileSizeBytes: 1024,
          downloadUrl: 'https://example.com/gemma-4-e2b-it.litertlm',
          provider: AIProvider.gemma,
          tags: ['litert-lm'],
        ),
      );

      expect(supported, isTrue);
    });

    test(
      'does not report ready when only an install URL is configured',
      () async {
        final adapter = LiteRtLmRuntimeAdapter(
          client: _FakeLiteRtLmClient(hasActiveModel: false),
          activeModelService: activeModelService,
          runtimeConfig: const LiteRtLmConfig(
            modelUrl: 'https://example.com/gemma.task',
          ),
        );

        expect(await adapter.isAvailable(), isFalse);
      },
    );

    test(
      'records the resolved local path after installing from a URL',
      () async {
        final client = _FakeLiteRtLmClient(hasActiveModel: false);
        final adapter = LiteRtLmRuntimeAdapter(
          client: client,
          activeModelService: activeModelService,
          runtimeConfig: const LiteRtLmConfig(
            modelUrl: 'https://example.com/gemma.task',
          ),
        );

        await adapter.prepareModel();

        expect(client.installCalls, ['https://example.com/gemma.task']);
        expect(client.initializeModelPaths, [
          '/app/files/litert_lm_models/gemma.task',
        ]);
        expect(
          activeModelService.activeRuntime?.modelPath,
          '/app/files/litert_lm_models/gemma.task',
        );
      },
    );

    test('bounds a wedged native availability operation', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      const channel = MethodChannel('test.litert_lm.timeout');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (_) async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        return false;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      final client = MethodChannelLiteRtLmClient(
        config: const LiteRtLmConfig(
          modelPath: '/models/gemma.task',
          operationTimeout: Duration(milliseconds: 10),
        ),
        channel: channel,
      );

      expect(await client.activeModelExists(), isFalse);
    });

    test('surfaces unsupported tool-calling requests explicitly', () async {
      final adapter = LiteRtLmRuntimeAdapter(
        client: _FakeLiteRtLmClient(hasActiveModel: true),
        activeModelService: activeModelService,
      );

      expect(
        () => adapter.generateText(
          const RuntimeGenerationRequest(
            prompt: 'call a tool',
            requiresToolCalling: true,
          ),
          model: const OfflineModelInfo(
            id: 'gemma-basic',
            name: 'Gemma Basic',
            family: ModelFamily.gemma,
            fileSizeBytes: 1024,
            filePath: '/models/gemma-basic.litertlm',
            provider: AIProvider.gemma,
          ),
        ),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('activates LiteRT as the current runtime after warmup', () async {
      final adapter = LiteRtLmRuntimeAdapter(
        client: _FakeLiteRtLmClient(hasActiveModel: true),
        activeModelService: activeModelService,
        runtimeConfig: const LiteRtLmConfig(modelPath: '/models/gemma.task'),
      );

      final warmed = await adapter.warmupInstalledModel();

      expect(warmed, isTrue);
      expect(
        activeModelService.activeRuntime?.runtimeKind,
        ActiveRuntimeKind.liteRtLm,
      );
      expect(activeModelService.activeRuntime?.runtimeId, 'litert-lm');
    });

    test(
      'hydrates a legacy gguf download path for LiteRT catalog models',
      () async {
        final adapter = LiteRtLmRuntimeAdapter(
          client: _FakeLiteRtLmClient(hasActiveModel: true),
          activeModelService: activeModelService,
          downloadService: _FakeModelDownloadService(
            downloadedPaths: {
              'gemma-4-e2b-it-litertlm': '/models/gemma-4-e2b-it-litertlm.gguf',
            },
          ),
        );

        final hydrated = await adapter.hydrateDownloadedModel(
          const OfflineModelInfo(
            id: 'gemma-4-e2b-it-litertlm',
            name: 'Gemma 4 E2B',
            family: ModelFamily.gemma,
            fileSizeBytes: 1024,
            downloadUrl: 'https://example.com/gemma-4-E2B-it.litertlm',
            provider: AIProvider.gemma,
            tags: ['litert-lm'],
          ),
        );

        expect(hydrated.filePath, '/models/gemma-4-e2b-it-litertlm.gguf');
      },
    );

    test(
      'clears a stale persisted path when the artifact is missing',
      () async {
        final adapter = LiteRtLmRuntimeAdapter(
          client: _FakeLiteRtLmClient(hasActiveModel: false),
          activeModelService: activeModelService,
          downloadService: _FakeModelDownloadService(downloadedPaths: const {}),
        );

        final hydrated = await adapter.hydrateDownloadedModel(
          const OfflineModelInfo(
            id: 'gemma-stale',
            name: 'Stale Gemma',
            family: ModelFamily.gemma,
            fileSizeBytes: 1024,
            filePath: '/models/removed.litertlm',
            downloadUrl: 'https://example.com/removed.litertlm',
            provider: AIProvider.gemma,
            tags: ['litert-lm'],
          ),
        );

        expect(hydrated.filePath, isNull);
        expect(hydrated.isDownloaded, isFalse);
      },
    );

    test('streams cumulative chunks from the LiteRT client', () async {
      final client = _FakeLiteRtLmClient(
        hasActiveModel: true,
        streamChunks: const ['Hel', 'Hello'],
      );
      final adapter = LiteRtLmRuntimeAdapter(
        client: client,
        activeModelService: activeModelService,
        runtimeConfig: const LiteRtLmConfig(
          modelPath: '/models/gemma.litertlm',
        ),
      );

      final chunks = await adapter
          .generateTextStream(const RuntimeGenerationRequest(prompt: 'hi'))
          .toList();

      expect(chunks, ['Hel', 'Hello']);
    });

    test('applies ModelInfo context and tool support during hydrate', () async {
      final adapter = LiteRtLmRuntimeAdapter(
        client: _FakeLiteRtLmClient(
          hasActiveModel: true,
          facts: const LiteRtLmModelFacts(
            modelType: 'LLM',
            maxContextTokens: 32768,
            vision: true,
            audio: false,
            functionCalling: true,
            thinking: false,
            speculativeDecoding: true,
          ),
        ),
        activeModelService: activeModelService,
        downloadService: _FakeModelDownloadService(
          downloadedPaths: {
            'gemma-4-e2b-it-litertlm': '/models/gemma-4-e2b-it.litertlm',
          },
        ),
      );

      final hydrated = await adapter.hydrateDownloadedModel(
        const OfflineModelInfo(
          id: 'gemma-4-e2b-it-litertlm',
          name: 'Gemma 4 E2B',
          family: ModelFamily.gemma,
          fileSizeBytes: 1024,
          downloadUrl: 'https://example.com/gemma-4-E2B-it.litertlm',
          provider: AIProvider.gemma,
          tags: ['litert-lm'],
        ),
      );

      expect(hydrated.filePath, '/models/gemma-4-e2b-it.litertlm');
      expect(hydrated.contextLength, 32768);
      expect(hydrated.supportsVision, isTrue);
      expect(hydrated.supportsFunctionCalling, isTrue);
    });
  });
}

class _FakeLiteRtLmClient extends LiteRtLmClient {
  _FakeLiteRtLmClient({
    required this.hasActiveModel,
    this.streamChunks = const ['ok'],
    this.facts,
  });

  bool hasActiveModel;
  final List<String> streamChunks;
  final LiteRtLmModelFacts? facts;
  final installCalls = <String>[];
  final initializeModelPaths = <String?>[];

  @override
  Future<bool> activeModelExists({String? modelPath}) async => hasActiveModel;

  @override
  Future<String> generate({
    required String prompt,
    required LiteRtLmBackend backend,
    required int maxTokens,
    String? systemPrompt,
    String? imagePath,
    bool reuseConversation = true,
  }) async => 'ok';

  @override
  Stream<String> generateStream({
    required String prompt,
    required LiteRtLmBackend backend,
    required int maxTokens,
    String? systemPrompt,
    String? imagePath,
    bool reuseConversation = true,
  }) async* {
    for (final chunk in streamChunks) {
      yield chunk;
    }
  }

  @override
  Future<LiteRtLmModelFacts?> describeModel({String? modelPath}) async => facts;

  @override
  Future<void> initialize({
    String? huggingFaceToken,
    String? modelPath,
    LiteRtLmBackend? backend,
    int? maxTokens,
    bool vision = false,
  }) async {
    initializeModelPaths.add(modelPath);
  }

  @override
  Future<String?> installModel({
    required String url,
    required LiteRtLmModelKind modelKind,
    String? huggingFaceToken,
  }) async {
    installCalls.add(url);
    hasActiveModel = true;
    return '/app/files/litert_lm_models/${Uri.parse(url).pathSegments.last}';
  }
}

class _FakeModelDownloadService extends ModelDownloadService {
  _FakeModelDownloadService({required this.downloadedPaths});

  final Map<String, String> downloadedPaths;

  @override
  Future<bool> isModelDownloaded(
    String modelId, {
    OfflineModelInfo? model,
  }) async {
    return downloadedPaths.containsKey(modelId);
  }

  @override
  Future<String?> resolveExistingModelPath(
    String modelId, {
    OfflineModelInfo? model,
  }) async {
    return downloadedPaths[modelId];
  }

  @override
  Future<String> getModelPath(String modelId, {OfflineModelInfo? model}) async {
    return downloadedPaths[modelId] ?? '/missing/$modelId';
  }
}
