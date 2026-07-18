import 'package:core_ai/core_ai.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeMediaPipeWebClient implements MediaPipeWebClient {
  _FakeMediaPipeWebClient({
    this.webGpuSupported = true,
    this.cached = false,
    this.response = 'Hello from the browser model.',
  });

  final bool webGpuSupported;
  bool cached;
  final String response;
  bool loadModelCalled = false;
  MediaPipeWebBackend? lastBackend;

  @override
  Future<bool> isWebGpuSupported() async => webGpuSupported;

  @override
  Future<bool> isModelCached(String modelUrl) async => cached;

  @override
  Future<void> loadModel({
    required String modelUrl,
    required MediaPipeWebBackend backend,
    required int maxTokens,
  }) async {
    loadModelCalled = true;
    lastBackend = backend;
    cached = true;
  }

  @override
  Future<String> generate({
    required String prompt,
    String? systemPrompt,
    required int maxTokens,
  }) async => response;

  @override
  Future<void> dispose() async {}
}

const _webCapableModel = OfflineModelInfo(
  id: 'gemma-4-e2b-it-litertlm',
  name: 'Gemma-4-E2B-it',
  family: ModelFamily.gemma,
  fileSizeBytes: 2583085056,
  provider: AIProvider.gemma,
  supportsWebRuntime: true,
  webAssetUrl: 'https://storage.googleapis.com/mediapipe-models/llm_inference/gemma-4-e2b-it/float16/latest/gemma-4-e2b-it.task',
);

const _webIncapableModel = OfflineModelInfo(
  id: 'mistral-7b-q4',
  name: 'Mistral 7B',
  family: ModelFamily.mistral,
  fileSizeBytes: 4100000000,
  provider: AIProvider.gguf,
);

void main() {
  group('MediaPipeWebRuntimeAdapter', () {
    test('runtimeKind is mediaPipeWeb', () {
      final adapter = MediaPipeWebRuntimeAdapter(
        client: _FakeMediaPipeWebClient(),
      );
      expect(adapter.runtimeKind, LocalRuntimeKind.mediaPipeWeb);
    });

    test('supportsModel is true only for catalog entries flagged web-capable', () async {
      final adapter = MediaPipeWebRuntimeAdapter(
        client: _FakeMediaPipeWebClient(),
      );

      expect(await adapter.supportsModel(_webCapableModel), isTrue);
      expect(await adapter.supportsModel(_webIncapableModel), isFalse);
    });

    test('capabilitiesForModel advertises webgpu backend when supported', () async {
      final adapter = MediaPipeWebRuntimeAdapter(
        client: _FakeMediaPipeWebClient(webGpuSupported: true),
      );

      // Prime the WebGPU check via prepareModel, then inspect capabilities.
      await adapter.prepareModel(model: _webCapableModel);
      final capabilities = adapter.capabilitiesForModel(_webCapableModel);

      expect(capabilities.supportedBackends, contains(RuntimeBackend.gpu));
      expect(capabilities.supportedBackends, contains(RuntimeBackend.cpu));
    });

    test('capabilitiesForModel omits gpu backend when WebGPU unsupported', () async {
      final adapter = MediaPipeWebRuntimeAdapter(
        client: _FakeMediaPipeWebClient(webGpuSupported: false),
      );

      await adapter.prepareModel(model: _webCapableModel);
      final capabilities = adapter.capabilitiesForModel(_webCapableModel);

      expect(capabilities.supportedBackends, isNot(contains(RuntimeBackend.gpu)));
      expect(capabilities.supportedBackends, contains(RuntimeBackend.cpu));
    });

    test('generateText loads the model then returns the client response', () async {
      final client = _FakeMediaPipeWebClient();
      final adapter = MediaPipeWebRuntimeAdapter(client: client);

      final text = await adapter.generateText(
        const RuntimeGenerationRequest(prompt: 'hi'),
        model: _webCapableModel,
      );

      expect(client.loadModelCalled, isTrue);
      expect(text, 'Hello from the browser model.');
    });

    test('generateText throws for a model with no web asset URL', () async {
      final adapter = MediaPipeWebRuntimeAdapter(
        client: _FakeMediaPipeWebClient(),
      );

      expect(
        () => adapter.generateText(
          const RuntimeGenerationRequest(prompt: 'hi'),
          model: _webIncapableModel,
        ),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('isAvailable is true for a client that can report readiness', () async {
      final adapter = MediaPipeWebRuntimeAdapter(
        client: _FakeMediaPipeWebClient(),
      );

      expect(await adapter.isAvailable(), isTrue);
    });
  });
}
