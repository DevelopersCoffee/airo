import 'package:airo_app/core/services/litert_lm_service.dart';
import 'package:core_ai/core_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LiteRtLmService web runtime selection', () {
    test('reports web runtime usage matches kIsWeb', () {
      final service = LiteRtLmService();
      expect(service.isUsingWebRuntime, kIsWeb);
    });

    test('can be constructed with an injected web adapter', () {
      final webAdapter = MediaPipeWebRuntimeAdapter(
        client: _NoopMediaPipeWebClient(),
      );
      final service = LiteRtLmService(webAdapter: webAdapter);

      expect(service.isUsingWebRuntime, isTrue);
    });
  });

  group('LiteRtLmService', () {
    test(
      'reports unavailable when no active model or model URL exists',
      () async {
        final client = _FakeLiteRtLmClient(hasActiveModel: false);
        final service = LiteRtLmService(client: client);

        final available = await service.isAvailable();

        expect(available, isFalse);
        expect(client.installCalls, isEmpty);
      },
    );

    test('installs configured model before generating text', () async {
      final client = _FakeLiteRtLmClient(hasActiveModel: false);
      final service = LiteRtLmService(
        client: client,
        config: const LiteRtLmConfig(
          modelUrl: 'https://example.com/gemma3-1b.task',
          modelKind: LiteRtLmModelKind.gemmaIt,
          backend: LiteRtLmBackend.gpu,
          maxTokens: 512,
        ),
      );

      final response = await service.generateText(
        'Extract receipt items',
        systemPrompt: 'Return JSON only.',
      );

      expect(response, 'ok');
      expect(client.installCalls, ['https://example.com/gemma3-1b.task']);
      expect(client.generatedPrompts.single, 'Extract receipt items');
      expect(client.generatedSystemPrompts.single, 'Return JSON only.');
      expect(client.backends.single, LiteRtLmBackend.gpu);
      expect(client.maxTokens.single, 512);
      expect(client.initializeModelPaths, [null]);
    });

    test(
      'method channel client initializes from cached downloaded path',
      () async {
        TestWidgetsFlutterBinding.ensureInitialized();
        const channel = MethodChannel('test.litert_lm');
        final calls = <MethodCall>[];

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              calls.add(call);
              return switch (call.method) {
                'isAvailable' =>
                  call.arguments['modelPath'] ==
                      '/app/files/litert_lm_models/gemma.task',
                'installModel' => '/app/files/litert_lm_models/gemma.task',
                'initialize' => true,
                'generateContent' => 'done',
                _ => null,
              };
            });
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, null);
        });

        final client = MethodChannelLiteRtLmClient(
          config: const LiteRtLmConfig(
            modelUrl: 'https://example.com/gemma.task',
          ),
          channel: channel,
        );
        final service = LiteRtLmService(
          client: client,
          config: const LiteRtLmConfig(
            modelUrl: 'https://example.com/gemma.task',
          ),
        );

        final response = await service.generateText('hello');

        expect(response, 'done');
        expect(
          calls.where((call) => call.method == 'initialize').single.arguments,
          containsPair('modelPath', '/app/files/litert_lm_models/gemma.task'),
        );
      },
    );

    test('uses downloaded model path for specific offline package', () async {
      final client = _FakeLiteRtLmClient(hasActiveModel: true);
      final downloadService = _FakeModelDownloadService(
        downloadedPaths: {'gemma-4': '/models/gemma-4-e2b-it.litertlm'},
      );
      final service = LiteRtLmService(
        client: client,
        downloadService: downloadService,
      );

      final response = await service.generateTextForModel(
        const OfflineModelInfo(
          id: 'gemma-4',
          name: 'Gemma 4',
          family: ModelFamily.gemma,
          fileSizeBytes: 1024,
          backendPreference: ModelBackendPreference.npu,
        ),
        'Plan my day',
      );

      expect(response, 'ok');
      expect(
        client.activeModelExistsPaths,
        contains('/models/gemma-4-e2b-it.litertlm'),
      );
      expect(
        client.initializeModelPaths,
        contains('/models/gemma-4-e2b-it.litertlm'),
      );
      expect(client.backends.single, LiteRtLmBackend.npu);
    });
  });
}

class _FakeLiteRtLmClient implements LiteRtLmClient {
  _FakeLiteRtLmClient({required this.hasActiveModel});

  bool hasActiveModel;
  final installCalls = <String>[];
  final activeModelExistsPaths = <String?>[];
  final generatedPrompts = <String>[];
  final generatedSystemPrompts = <String?>[];
  final initializeModelPaths = <String?>[];
  final backends = <LiteRtLmBackend>[];
  final maxTokens = <int>[];

  @override
  Future<bool> activeModelExists({String? modelPath}) async {
    activeModelExistsPaths.add(modelPath);
    return hasActiveModel;
  }

  @override
  Future<String> generate({
    required String prompt,
    required LiteRtLmBackend backend,
    required int maxTokens,
    String? systemPrompt,
  }) async {
    generatedPrompts.add(prompt);
    generatedSystemPrompts.add(systemPrompt);
    backends.add(backend);
    this.maxTokens.add(maxTokens);
    return 'ok';
  }

  @override
  Future<void> initialize({
    String? huggingFaceToken,
    String? modelPath,
    LiteRtLmBackend? backend,
    int? maxTokens,
  }) async {
    initializeModelPaths.add(modelPath);
  }

  @override
  Future<void> installModel({
    required String url,
    required LiteRtLmModelKind modelKind,
    String? huggingFaceToken,
  }) async {
    installCalls.add(url);
    hasActiveModel = true;
  }
}

class _NoopMediaPipeWebClient implements MediaPipeWebClient {
  @override
  Future<bool> isWebGpuSupported() async => false;
  @override
  Future<bool> isModelCached(String modelUrl) async => false;
  @override
  Future<void> loadModel({
    required String modelUrl,
    required MediaPipeWebBackend backend,
    required int maxTokens,
  }) async {}
  @override
  Future<String> generate({
    required String prompt,
    String? systemPrompt,
    required int maxTokens,
  }) async => '';
  @override
  Future<void> dispose() async {}
}

class _FakeModelDownloadService extends ModelDownloadService {
  _FakeModelDownloadService({required this.downloadedPaths});

  final Map<String, String> downloadedPaths;

  @override
  Future<String> getModelPath(String modelId, {OfflineModelInfo? model}) async {
    return downloadedPaths[modelId] ?? '/missing/$modelId';
  }

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
}
