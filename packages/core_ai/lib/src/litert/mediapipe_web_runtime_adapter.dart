import 'package:core_domain/core_domain.dart';

import '../llm/llm_config.dart';
import '../llm/llm_response.dart';
import '../models/offline_model_info.dart';
import '../runtime/local_inference_runtime_adapter.dart';
import '../utils/token_counter.dart';
import 'mediapipe_web_client_stub.dart'
    if (dart.library.js_interop) 'mediapipe_web_client_web.dart';

enum MediaPipeWebBackend { wasm, webgpu }

class MediaPipeWebConfig {
  const MediaPipeWebConfig({
    this.wasmBaseUrl =
        'https://cdn.jsdelivr.net/npm/@mediapipe/tasks-genai@latest/wasm',
    this.maxTokens = 1024,
  });

  final String wasmBaseUrl;
  final int maxTokens;
}

abstract class MediaPipeWebClient {
  Future<bool> isWebGpuSupported();

  Future<bool> isModelCached(String modelUrl);

  Future<void> loadModel({
    required String modelUrl,
    required MediaPipeWebBackend backend,
    required int maxTokens,
    void Function(String stage)? onProgress,
  });

  Future<String> generate({
    required String prompt,
    String? systemPrompt,
    required int maxTokens,
  });

  Future<void> dispose();
}

class MediaPipeWebRuntimeAdapter implements LocalInferenceRuntimeAdapter {
  MediaPipeWebRuntimeAdapter({
    MediaPipeWebClient? client,
    this.runtimeConfig = const MediaPipeWebConfig(),
  }) : _client = client ?? createMediaPipeWebClient();

  final MediaPipeWebClient _client;
  final MediaPipeWebConfig runtimeConfig;

  String? _loadedModelUrl;
  bool? _webGpuSupported;

  @override
  LocalRuntimeKind get runtimeKind => LocalRuntimeKind.mediaPipeWeb;

  @override
  LLMConfig get config => LLMConfig(
    provider: 'mediapipe-web',
    modelName: 'MediaPipe LLM Inference (Web)',
    maxOutputTokens: runtimeConfig.maxTokens,
  );

  @override
  int get maxContextLength => 4096;

  @override
  RuntimeCapabilities capabilitiesForModel(OfflineModelInfo model) {
    final backends = <RuntimeBackend>{RuntimeBackend.cpu};
    if (_webGpuSupported ?? false) {
      backends.add(RuntimeBackend.gpu);
    }
    return RuntimeCapabilities(
      supportedBackends: backends,
      supportsStreaming: false,
      supportsImages: false,
      supportsAudio: false,
      supportsToolCalling: false,
      supportsSystemPrompt: true,
      supportsSpeculativeDecoding: false,
    );
  }

  @override
  Future<void> prepareModel({
    OfflineModelInfo? model,
    void Function(String stage)? onProgress,
  }) async {
    _webGpuSupported ??= await _client.isWebGpuSupported();
    if (model == null) return;
    await _ensureModelLoaded(model, onProgress: onProgress);
  }

  @override
  Future<Result<LLMResponse>> generate(String prompt) async {
    throw UnsupportedError(
      'MediaPipeWebRuntimeAdapter requires a model; use generateText with an OfflineModelInfo.',
    );
  }

  @override
  Stream<String> generateStream(String prompt) async* {
    throw UnsupportedError('MediaPipeWebRuntimeAdapter does not support streaming.');
  }

  @override
  Future<String?> generateText(
    RuntimeGenerationRequest request, {
    OfflineModelInfo? model,
  }) async {
    if (request.prompt.trim().isEmpty) return null;
    if (model == null || !model.supportsWebRuntime || model.webAssetUrl == null) {
      throw UnsupportedError(
        'MediaPipeWebRuntimeAdapter requires a model with supportsWebRuntime=true and a webAssetUrl.',
      );
    }
    if (request.requiresVision || request.requiresAudio || request.requiresToolCalling) {
      throw UnsupportedError(
        'MediaPipeWebRuntimeAdapter only supports plain text generation.',
      );
    }

    await _ensureModelLoaded(model);
    return _client.generate(
      prompt: request.prompt,
      systemPrompt: request.systemPrompt,
      maxTokens: runtimeConfig.maxTokens,
    );
  }

  @override
  Future<bool> isAvailable() async => true;

  @override
  int estimateTokens(String text) => TokenCounter.estimate(text);

  @override
  Future<void> dispose() => _client.dispose();

  @override
  Future<bool> supportsModel(OfflineModelInfo model) async =>
      model.supportsWebRuntime && model.webAssetUrl != null;

  Future<void> _ensureModelLoaded(
    OfflineModelInfo model, {
    void Function(String stage)? onProgress,
  }) async {
    final assetUrl = model.webAssetUrl!;
    _webGpuSupported ??= await _client.isWebGpuSupported();
    if (_loadedModelUrl == assetUrl) return;

    final backend = (_webGpuSupported ?? false)
        ? MediaPipeWebBackend.webgpu
        : MediaPipeWebBackend.wasm;
    await _client.loadModel(
      modelUrl: assetUrl,
      backend: backend,
      maxTokens: runtimeConfig.maxTokens,
      onProgress: onProgress,
    );
    _loadedModelUrl = assetUrl;
  }
}
