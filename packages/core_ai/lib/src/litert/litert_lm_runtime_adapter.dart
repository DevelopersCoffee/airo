import 'package:core_domain/core_domain.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../download/model_download_service.dart';
import '../llm/active_model_service.dart';
import '../llm/llm_config.dart';
import '../llm/llm_response.dart';
import '../models/offline_model_info.dart';
import '../runtime/local_inference_runtime_adapter.dart';
import '../utils/token_counter.dart';

enum LiteRtLmModelKind {
  gemmaIt,
  gemma4,
  functionGemma,
  qwen,
  qwen3,
  phi,
  deepSeek,
  general,
}

enum LiteRtLmBackend { cpu, gpu, npu }

class LiteRtLmConfig {
  final String modelPath;
  final String modelUrl;
  final String huggingFaceToken;
  final LiteRtLmModelKind modelKind;
  final LiteRtLmBackend backend;
  final int maxTokens;

  const LiteRtLmConfig({
    this.modelPath = const String.fromEnvironment('LITERT_LM_MODEL_PATH'),
    this.modelUrl = const String.fromEnvironment('LITERT_LM_MODEL_URL'),
    this.huggingFaceToken = const String.fromEnvironment('HUGGINGFACE_TOKEN'),
    this.modelKind = LiteRtLmModelKind.gemmaIt,
    this.backend = LiteRtLmBackend.gpu,
    this.maxTokens = 2048,
  });

  bool get hasModelPath => modelPath.trim().isNotEmpty;
  bool get hasModelUrl => modelUrl.trim().isNotEmpty;
  String? get optionalHuggingFaceToken =>
      huggingFaceToken.trim().isEmpty ? null : huggingFaceToken.trim();
}

abstract class LiteRtLmClient {
  Future<void> initialize({
    String? huggingFaceToken,
    String? modelPath,
    LiteRtLmBackend? backend,
    int? maxTokens,
  });

  Future<bool> activeModelExists({String? modelPath});

  Future<void> installModel({
    required String url,
    required LiteRtLmModelKind modelKind,
    String? huggingFaceToken,
  });

  Future<String> generate({
    required String prompt,
    required LiteRtLmBackend backend,
    required int maxTokens,
    String? systemPrompt,
  });
}

class LiteRtLmRuntimeAdapter implements LocalInferenceRuntimeAdapter {
  LiteRtLmRuntimeAdapter({
    LiteRtLmClient? client,
    this.runtimeConfig = const LiteRtLmConfig(),
    ModelDownloadService? downloadService,
    ActiveModelService? activeModelService,
    Set<RuntimeBackend>? supportedBackends,
  }) : _client = client ?? MethodChannelLiteRtLmClient(config: runtimeConfig),
       _downloadService = downloadService ?? ModelDownloadService(),
       _activeModelService = activeModelService ?? ActiveModelService.instance,
       _supportedBackends =
           supportedBackends ??
           const {RuntimeBackend.cpu, RuntimeBackend.gpu, RuntimeBackend.npu};

  final LiteRtLmClient _client;
  final LiteRtLmConfig runtimeConfig;
  final ModelDownloadService _downloadService;
  final ActiveModelService _activeModelService;
  final Set<RuntimeBackend> _supportedBackends;
  String? _initializedModelPath;

  @override
  LocalRuntimeKind get runtimeKind => LocalRuntimeKind.liteRtLm;

  @override
  LLMConfig get config => LLMConfig(
    provider: 'litert-lm',
    modelName: 'LiteRT-LM',
    maxOutputTokens: runtimeConfig.maxTokens,
  );

  @override
  int get maxContextLength => 32768;

  @override
  RuntimeCapabilities capabilitiesForModel(OfflineModelInfo model) {
    return RuntimeCapabilities(
      supportedBackends: _supportedBackends,
      supportsStreaming: false,
      supportsImages: model.supportsVision,
      supportsAudio: model.supportsAudio,
      supportsToolCalling: model.supportsFunctionCalling,
      supportsSystemPrompt: true,
      supportsSpeculativeDecoding: false,
    );
  }

  @override
  Future<void> prepareModel({OfflineModelInfo? model}) async {
    if (kIsWeb) {
      throw UnsupportedError('LiteRT-LM is not available on web.');
    }

    final resolvedModel = model == null
        ? null
        : await hydrateDownloadedModel(model);
    final modelPath = resolvedModel?.filePath?.trim();
    final backend = resolvedModel == null
        ? runtimeConfig.backend
        : _backendFor(resolvedModel.backendPreference);
    final initialized = await _ensureInitializedForRequest(
      modelPath:
          modelPath ??
          (runtimeConfig.hasModelPath ? runtimeConfig.modelPath.trim() : null),
      backend: backend,
      maxTokens: runtimeConfig.maxTokens,
      installUrl: resolvedModel == null && runtimeConfig.hasModelUrl
          ? runtimeConfig.modelUrl.trim()
          : resolvedModel?.downloadUrl,
      modelKind: runtimeConfig.modelKind,
    );
    if (!initialized) {
      throw StateError('LiteRT-LM runtime could not initialize.');
    }

    final activeModelId = resolvedModel?.id ?? 'litert-default';
    final activePath =
        modelPath ?? _initializedModelPath ?? runtimeConfig.modelPath.trim();
    await _activeModelService.activateRuntime(
      runtimeKind: ActiveRuntimeKind.liteRtLm,
      runtimeId: 'litert-lm',
      modelId: activeModelId,
      modelPath: activePath,
      displayName: resolvedModel?.name ?? 'LiteRT-LM',
      estimatedMemoryBytes:
          resolvedModel?.recommendedMemoryBytes ??
          resolvedModel?.minMemoryBytes ??
          (resolvedModel?.fileSizeBytes ?? 1024 * 1024 * 1024),
    );
  }

  @override
  Future<Result<LLMResponse>> generate(String prompt) async {
    final text = await generateText(RuntimeGenerationRequest(prompt: prompt));
    if (text == null) {
      return Failure(
        ServerFailure(
          message: 'LiteRT-LM runtime is unavailable for the requested prompt.',
        ),
      );
    }
    return Success(
      LLMResponse(
        text: text,
        provider: 'litert-lm',
        promptTokens: estimateTokens(prompt),
        completionTokens: estimateTokens(text),
      ),
    );
  }

  @override
  Stream<String> generateStream(String prompt) async* {
    final text = await generateText(RuntimeGenerationRequest(prompt: prompt));
    if (text == null) {
      return;
    }
    yield text;
  }

  @override
  Future<String?> generateText(
    RuntimeGenerationRequest request, {
    OfflineModelInfo? model,
  }) async {
    if (request.prompt.trim().isEmpty) return null;
    if (model != null) {
      _validateCapabilityRequest(model, request);
      await prepareModel(model: model);
      final hydratedModel = await hydrateDownloadedModel(model);
      final modelPath = hydratedModel.filePath?.trim();
      if (modelPath == null || modelPath.isEmpty) {
        return null;
      }

      return _client.generate(
        prompt: request.prompt,
        systemPrompt: request.systemPrompt,
        backend: _backendFor(hydratedModel.backendPreference),
        maxTokens: runtimeConfig.maxTokens,
      );
    }

    final initialized = await _ensureInitializedForRequest(
      modelPath: runtimeConfig.hasModelPath
          ? runtimeConfig.modelPath.trim()
          : null,
      backend: runtimeConfig.backend,
      maxTokens: runtimeConfig.maxTokens,
      installUrl: runtimeConfig.hasModelUrl
          ? runtimeConfig.modelUrl.trim()
          : null,
      modelKind: runtimeConfig.modelKind,
    );
    if (!initialized) {
      return null;
    }

    await _activeModelService.activateRuntime(
      runtimeKind: ActiveRuntimeKind.liteRtLm,
      runtimeId: 'litert-lm',
      modelId: 'litert-default',
      modelPath: _initializedModelPath ?? runtimeConfig.modelPath.trim(),
      displayName: 'LiteRT-LM',
      estimatedMemoryBytes: 1024 * 1024 * 1024,
    );

    return _client.generate(
      prompt: request.prompt,
      systemPrompt: request.systemPrompt,
      backend: runtimeConfig.backend,
      maxTokens: runtimeConfig.maxTokens,
    );
  }

  @override
  Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    if (await _client.activeModelExists()) return true;
    return runtimeConfig.hasModelUrl;
  }

  @override
  int estimateTokens(String text) => TokenCounter.estimate(text);

  @override
  Future<void> dispose() async {}

  @override
  Future<bool> supportsModel(OfflineModelInfo model) async {
    final filePath = model.filePath?.toLowerCase();
    final downloadUrl = model.downloadUrl?.toLowerCase();
    final tags = model.tags.map((tag) => tag.toLowerCase());

    final looksLikeLiteRt =
        (filePath?.endsWith('.litertlm') ?? false) ||
        (filePath?.endsWith('.task') ?? false) ||
        (downloadUrl?.endsWith('.litertlm') ?? false) ||
        (downloadUrl?.endsWith('.task') ?? false) ||
        tags.contains('litert-lm');

    return looksLikeLiteRt;
  }

  Future<bool> warmupInstalledModel() async {
    if (kIsWeb) return false;

    try {
      final defaultModelPath = runtimeConfig.hasModelPath
          ? runtimeConfig.modelPath.trim()
          : null;
      if (!await _client.activeModelExists(modelPath: defaultModelPath)) {
        return false;
      }

      if (_initializedModelPath == null ||
          _initializedModelPath != defaultModelPath) {
        await _client.initialize(
          huggingFaceToken: runtimeConfig.optionalHuggingFaceToken,
          modelPath: defaultModelPath,
          backend: runtimeConfig.backend,
          maxTokens: runtimeConfig.maxTokens,
        );
        _initializedModelPath = defaultModelPath;
      }
      await _client.generate(
        prompt: ' ',
        backend: runtimeConfig.backend,
        maxTokens: 1,
      );
      await _activeModelService.activateRuntime(
        runtimeKind: ActiveRuntimeKind.liteRtLm,
        runtimeId: 'litert-lm',
        modelId: 'litert-default',
        modelPath: _initializedModelPath ?? defaultModelPath ?? '',
        displayName: 'LiteRT-LM',
        estimatedMemoryBytes: 1024 * 1024 * 1024,
      );
      return true;
    } catch (e) {
      debugPrint('LiteRT-LM warmup skipped: $e');
      return false;
    }
  }

  Future<bool> warmupModel(OfflineModelInfo model) async {
    if (kIsWeb) return false;

    try {
      final hydratedModel = await hydrateDownloadedModel(model);
      final modelPath = hydratedModel.filePath?.trim();
      if (modelPath == null || modelPath.isEmpty) {
        return false;
      }

      final backend = _backendFor(hydratedModel.backendPreference);
      if (!await _ensureInitializedForRequest(
        modelPath: modelPath,
        backend: backend,
        maxTokens: runtimeConfig.maxTokens,
      )) {
        return false;
      }

      await _client.generate(prompt: ' ', backend: backend, maxTokens: 1);
      await _activeModelService.activateRuntime(
        runtimeKind: ActiveRuntimeKind.liteRtLm,
        runtimeId: 'litert-lm',
        modelId: hydratedModel.id,
        modelPath: modelPath,
        displayName: hydratedModel.name,
        estimatedMemoryBytes:
            hydratedModel.recommendedMemoryBytes ??
            hydratedModel.minMemoryBytes ??
            hydratedModel.fileSizeBytes,
      );
      return true;
    } catch (e) {
      debugPrint('LiteRT-LM model warmup skipped: $e');
      return false;
    }
  }

  Future<OfflineModelInfo> hydrateDownloadedModel(
    OfflineModelInfo model,
  ) async {
    if (kIsWeb) return model;
    if (model.filePath?.trim().isNotEmpty == true) {
      return model;
    }

    final modelPath = await downloadedModelPath(model.id);
    if (modelPath == null) {
      return model;
    }
    return model.copyWith(filePath: modelPath);
  }

  Future<String?> downloadedModelPath(String modelId) async {
    if (kIsWeb) return null;
    final isDownloaded = await _downloadService.isModelDownloaded(modelId);
    if (!isDownloaded) return null;
    return _downloadService.getModelPath(modelId);
  }

  Future<bool> _ensureInitializedForRequest({
    String? modelPath,
    LiteRtLmBackend? backend,
    int? maxTokens,
    String? installUrl,
    LiteRtLmModelKind? modelKind,
  }) async {
    final trimmedModelPath = modelPath?.trim();
    if (_initializedModelPath != null &&
        trimmedModelPath != null &&
        _initializedModelPath == trimmedModelPath) {
      return true;
    }

    var resolvedModelPath = trimmedModelPath;
    if (!await _client.activeModelExists(modelPath: resolvedModelPath)) {
      final resolvedInstallUrl = installUrl?.trim();
      if (resolvedInstallUrl == null || resolvedInstallUrl.isEmpty) {
        return false;
      }
      await _client.installModel(
        url: resolvedInstallUrl,
        modelKind: modelKind ?? runtimeConfig.modelKind,
        huggingFaceToken: runtimeConfig.optionalHuggingFaceToken,
      );
      resolvedModelPath = null;
    }

    await _client.initialize(
      huggingFaceToken: runtimeConfig.optionalHuggingFaceToken,
      modelPath: resolvedModelPath,
      backend: backend ?? runtimeConfig.backend,
      maxTokens: maxTokens ?? runtimeConfig.maxTokens,
    );

    _initializedModelPath =
        resolvedModelPath ??
        installUrl?.trim() ??
        (runtimeConfig.hasModelPath ? runtimeConfig.modelPath.trim() : null);
    return true;
  }

  LiteRtLmBackend _backendFor(ModelBackendPreference preference) {
    return switch (preference) {
      ModelBackendPreference.cpu => LiteRtLmBackend.cpu,
      ModelBackendPreference.gpu => LiteRtLmBackend.gpu,
      ModelBackendPreference.npu ||
      ModelBackendPreference.aiCore => LiteRtLmBackend.npu,
      ModelBackendPreference.auto => runtimeConfig.backend,
    };
  }

  void _validateCapabilityRequest(
    OfflineModelInfo model,
    RuntimeGenerationRequest request,
  ) {
    final capabilities = capabilitiesForModel(model);
    final backend = _runtimeBackendFor(model.backendPreference);
    if (!capabilities.supportedBackends.contains(backend)) {
      throw UnsupportedError(
        'LiteRT-LM backend ${backend.name} is not supported on this device.',
      );
    }
    if (request.requiresVision && !capabilities.supportsImages) {
      throw UnsupportedError(
        'LiteRT-LM model ${model.id} does not support vision input.',
      );
    }
    if (request.requiresAudio && !capabilities.supportsAudio) {
      throw UnsupportedError(
        'LiteRT-LM model ${model.id} does not support audio input.',
      );
    }
    if (request.requiresToolCalling && !capabilities.supportsToolCalling) {
      throw UnsupportedError(
        'LiteRT-LM model ${model.id} does not support tool calling.',
      );
    }
  }

  RuntimeBackend _runtimeBackendFor(ModelBackendPreference preference) {
    return switch (preference) {
      ModelBackendPreference.cpu => RuntimeBackend.cpu,
      ModelBackendPreference.gpu => RuntimeBackend.gpu,
      ModelBackendPreference.npu ||
      ModelBackendPreference.aiCore => RuntimeBackend.npu,
      ModelBackendPreference.auto => switch (runtimeConfig.backend) {
        LiteRtLmBackend.cpu => RuntimeBackend.cpu,
        LiteRtLmBackend.gpu => RuntimeBackend.gpu,
        LiteRtLmBackend.npu => RuntimeBackend.npu,
      },
    };
  }
}

class MethodChannelLiteRtLmClient implements LiteRtLmClient {
  MethodChannelLiteRtLmClient({
    required this._config,
    this._channel = const MethodChannel('com.airo.litert_lm'),
  });

  final LiteRtLmConfig _config;
  final MethodChannel _channel;
  String? _installedModelPath;

  String? get _activeModelPath {
    final installedPath = _installedModelPath?.trim();
    if (installedPath != null && installedPath.isNotEmpty) {
      return installedPath;
    }
    return _config.hasModelPath ? _config.modelPath : null;
  }

  @override
  Future<bool> activeModelExists({String? modelPath}) async {
    final resolvedModelPath = (modelPath?.trim().isNotEmpty ?? false)
        ? modelPath!.trim()
        : _activeModelPath;
    if (resolvedModelPath == null) return false;
    try {
      final available = await _channel.invokeMethod<bool>('isAvailable', {
        'modelPath': resolvedModelPath,
      });
      return available ?? false;
    } on PlatformException catch (e) {
      debugPrint('LiteRT-LM availability check failed: ${e.message}');
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<String> generate({
    required String prompt,
    required LiteRtLmBackend backend,
    required int maxTokens,
    String? systemPrompt,
  }) async {
    final response = await _channel.invokeMethod<String>('generateContent', {
      'prompt': prompt,
      'systemPrompt': systemPrompt,
      'backend': backend.name,
      'maxTokens': maxTokens,
    });
    return response ?? '';
  }

  @override
  Future<void> initialize({
    String? huggingFaceToken,
    String? modelPath,
    LiteRtLmBackend? backend,
    int? maxTokens,
  }) async {
    final resolvedModelPath = (modelPath?.trim().isNotEmpty ?? false)
        ? modelPath!.trim()
        : _activeModelPath;
    if (resolvedModelPath == null) {
      throw StateError('LiteRT-LM model path is not configured');
    }

    await _channel.invokeMethod<bool>('initialize', {
      'modelPath': resolvedModelPath,
      'backend': (backend ?? _config.backend).name,
      'maxTokens': maxTokens ?? _config.maxTokens,
    });
  }

  @override
  Future<void> installModel({
    required String url,
    required LiteRtLmModelKind modelKind,
    String? huggingFaceToken,
  }) async {
    _installedModelPath = await _channel.invokeMethod<String>('installModel', {
      'url': url,
      'modelKind': modelKind.name,
      'huggingFaceToken': huggingFaceToken,
    });
  }
}
