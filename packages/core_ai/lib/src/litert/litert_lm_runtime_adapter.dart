import 'dart:async';

import 'package:core_domain/core_domain.dart';
import 'package:core_native/core_native.dart'
    show ExecutionPlan, InferenceRequest;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../download/model_download_service.dart';
import '../llm/active_model_service.dart';
import '../llm/llm_config.dart';
import '../llm/llm_response.dart';
import '../models/offline_model_info.dart';
import '../runtime/local_inference_runtime_adapter.dart';
import '../utils/token_counter.dart';
import 'litert_lm_execution_adapter.dart';

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
  final Duration operationTimeout;

  const LiteRtLmConfig({
    this.modelPath = const String.fromEnvironment('LITERT_LM_MODEL_PATH'),
    this.modelUrl = const String.fromEnvironment('LITERT_LM_MODEL_URL'),
    this.huggingFaceToken = const String.fromEnvironment('HUGGINGFACE_TOKEN'),
    this.modelKind = LiteRtLmModelKind.gemmaIt,
    this.backend = LiteRtLmBackend.gpu,
    this.maxTokens = 2048,
    this.operationTimeout = const Duration(minutes: 2),
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
    bool vision = false,
  });

  Future<bool> activeModelExists({String? modelPath});

  Future<String?> installModel({
    required String url,
    required LiteRtLmModelKind modelKind,
    String? huggingFaceToken,
  });

  Future<String> generate({
    required String prompt,
    required LiteRtLmBackend backend,
    required int maxTokens,
    String? systemPrompt,
    String? imagePath,
    bool reuseConversation = true,
  });

  /// Native builds return tool calls alongside text. Fakes that only implement
  /// [generate] keep the previous text-only behavior.
  Future<LiteRtLmReply> generateReply({
    required String prompt,
    required LiteRtLmBackend backend,
    required int maxTokens,
    String? systemPrompt,
    String? imagePath,
    bool reuseConversation = true,
    List<LiteRtLmToolSpec> tools = const [],
    List<LiteRtLmToolResponse> toolResponses = const [],
  }) async {
    final text = await generate(
      prompt: prompt,
      backend: backend,
      maxTokens: maxTokens,
      systemPrompt: systemPrompt,
      imagePath: imagePath,
      reuseConversation: reuseConversation,
    );
    return LiteRtLmReply(text: text);
  }

  Stream<String> generateStream({
    required String prompt,
    required LiteRtLmBackend backend,
    required int maxTokens,
    String? systemPrompt,
    String? imagePath,
    bool reuseConversation = true,
  });

  Future<LiteRtLmModelFacts?> describeModel({String? modelPath});
}

class LiteRtLmToolSpec {
  const LiteRtLmToolSpec({
    required this.name,
    required this.description,
    this.parameters = const {
      'type': 'object',
      'properties': <String, Object?>{},
    },
  });

  final String name;
  final String description;
  final Map<String, Object?> parameters;
}

class LiteRtLmToolCall {
  const LiteRtLmToolCall({required this.name, this.arguments = const {}});

  final String name;
  final Map<String, Object?> arguments;
}

class LiteRtLmToolResponse {
  const LiteRtLmToolResponse({required this.name, required this.response});

  final String name;
  final String response;
}

class LiteRtLmReply {
  const LiteRtLmReply({required this.text, this.toolCalls = const []});

  final String text;
  final List<LiteRtLmToolCall> toolCalls;

  static LiteRtLmReply fromChannel(Object? raw) {
    if (raw is String) return LiteRtLmReply(text: raw);
    if (raw is! Map) return const LiteRtLmReply(text: '');
    final calls = <LiteRtLmToolCall>[];
    final rawCalls = raw['toolCalls'];
    if (rawCalls is List) {
      for (final item in rawCalls) {
        if (item is! Map) continue;
        final name = item['name']?.toString().trim() ?? '';
        if (name.isEmpty) continue;
        final arguments = item['arguments'];
        calls.add(
          LiteRtLmToolCall(
            name: name,
            arguments: arguments is Map
                ? arguments.map((key, value) => MapEntry(key.toString(), value))
                : const {},
          ),
        );
      }
    }
    return LiteRtLmReply(text: raw['text']?.toString() ?? '', toolCalls: calls);
  }
}

class LiteRtLmModelFacts {
  const LiteRtLmModelFacts({
    required this.modelType,
    required this.maxContextTokens,
    required this.vision,
    required this.audio,
    required this.functionCalling,
    required this.thinking,
    required this.speculativeDecoding,
  });

  final String modelType;
  final int maxContextTokens;
  final bool vision;
  final bool audio;
  final bool functionCalling;
  final bool thinking;
  final bool speculativeDecoding;

  static LiteRtLmModelFacts? fromChannel(Object? raw) {
    if (raw is! Map) return null;
    int readInt(Object? value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return 0;
    }

    bool readBool(Object? value) => value == true;
    return LiteRtLmModelFacts(
      modelType: raw['modelType']?.toString() ?? 'UNKNOWN',
      maxContextTokens: readInt(raw['maxContextTokens']),
      vision: readBool(raw['vision']),
      audio: readBool(raw['audio']),
      functionCalling: readBool(raw['functionCalling']),
      thinking: readBool(raw['thinking']),
      speculativeDecoding: readBool(raw['speculativeDecoding']),
    );
  }
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
  bool _initializedVision = false;

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
      supportsStreaming: true,
      supportsImages: model.supportsVision,
      supportsAudio: model.supportsAudio,
      supportsToolCalling: model.supportsFunctionCalling,
      supportsSystemPrompt: true,
      supportsSpeculativeDecoding: _supportedBackends.contains(
        RuntimeBackend.gpu,
      ),
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
      vision: resolvedModel?.supportsVision ?? false,
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
  Stream<String> generateStream(String prompt) {
    return generateTextStream(RuntimeGenerationRequest(prompt: prompt));
  }

  Stream<String> generateTextStream(
    RuntimeGenerationRequest request, {
    OfflineModelInfo? model,
  }) async* {
    if (request.prompt.trim().isEmpty) return;
    if (model != null) {
      _validateCapabilityRequest(model, request);
      await prepareModel(model: model);
    } else {
      final imagePath = request.imagePath?.trim();
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
        vision: imagePath != null && imagePath.isNotEmpty,
      );
      if (!initialized) return;
    }
    final hydrated = model == null ? null : await hydrateDownloadedModel(model);
    yield* _client.generateStream(
      prompt: request.prompt,
      systemPrompt: request.systemPrompt,
      backend: hydrated == null
          ? runtimeConfig.backend
          : _backendFor(hydrated.backendPreference),
      maxTokens: runtimeConfig.maxTokens,
      imagePath: request.imagePath,
      reuseConversation: request.reuseConversation,
    );
  }

  @override
  Future<String?> generateText(
    RuntimeGenerationRequest request, {
    OfflineModelInfo? model,
  }) async {
    final reply = await generateReply(request, model: model);
    return reply?.text;
  }

  Future<LiteRtLmReply?> generateReply(
    RuntimeGenerationRequest request, {
    OfflineModelInfo? model,
    List<LiteRtLmToolSpec> tools = const [],
    List<LiteRtLmToolResponse> toolResponses = const [],
  }) async {
    if (request.prompt.trim().isEmpty && toolResponses.isEmpty) return null;
    final toolRequest = tools.isEmpty
        ? request
        : RuntimeGenerationRequest(
            prompt: request.prompt,
            systemPrompt: request.systemPrompt,
            imagePath: request.imagePath,
            reuseConversation: request.reuseConversation,
            requiresVision: request.requiresVision,
            requiresAudio: request.requiresAudio,
            requiresToolCalling: true,
            localOnly: request.localOnly,
          );
    if (model != null) {
      _validateCapabilityRequest(model, toolRequest);
      await prepareModel(model: model);
      final hydratedModel = await hydrateDownloadedModel(model);
      final modelPath = hydratedModel.filePath?.trim();
      if (modelPath == null || modelPath.isEmpty) {
        return null;
      }

      return _client.generateReply(
        prompt: request.prompt,
        systemPrompt: request.systemPrompt,
        backend: _backendFor(hydratedModel.backendPreference),
        maxTokens: runtimeConfig.maxTokens,
        imagePath: request.imagePath,
        reuseConversation: request.reuseConversation,
        tools: tools,
        toolResponses: toolResponses,
      );
    }

    final imagePath = request.imagePath?.trim();
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
      vision: imagePath != null && imagePath.isNotEmpty,
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

    return _client.generateReply(
      prompt: request.prompt,
      systemPrompt: request.systemPrompt,
      backend: runtimeConfig.backend,
      maxTokens: runtimeConfig.maxTokens,
      imagePath: request.imagePath,
      reuseConversation: request.reuseConversation,
      tools: tools,
      toolResponses: toolResponses,
    );
  }

  /// Executes an already-planned v1 request through LiteRT.
  ///
  /// Callers obtain [plan] from the Rust planner. This method deliberately
  /// performs no model or resource selection; it only delegates the immutable
  /// plan to the thin backend adapter.
  Future<String> generatePlanned({
    required ExecutionPlan plan,
    required InferenceRequest request,
    required String modelPath,
    String? systemPrompt,
  }) {
    return LiteRtLmExecutionAdapter(client: _client).generate(
      plan: plan,
      request: request,
      modelPath: modelPath,
      systemPrompt: systemPrompt,
    );
  }

  @override
  Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    // A download URL describes a possible install source, not a ready
    // runtime. Provider discovery must not advertise LiteRT as usable until
    // the native client confirms that an executable model is present.
    return _client.activeModelExists(
      modelPath: runtimeConfig.hasModelPath
          ? runtimeConfig.modelPath.trim()
          : null,
    );
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
        reuseConversation: false,
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
        vision: hydratedModel.supportsVision,
      )) {
        return false;
      }

      await _client.generate(
        prompt: ' ',
        backend: backend,
        maxTokens: 1,
        reuseConversation: false,
      );
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
    final modelPath = await downloadedModelPath(model.id, model: model);
    if (modelPath == null) {
      // A persisted receipt can outlive the artifact it described. Clear the
      // stale path so the catalog cannot present a non-existent LiteRT model
      // as runnable on the next launch.
      return model.copyWith(clearFilePath: true);
    }
    final hydrated = model.copyWith(filePath: modelPath);
    try {
      final facts = await _client.describeModel(modelPath: modelPath);
      if (facts == null) return hydrated;
      return hydrated.copyWith(
        contextLength: facts.maxContextTokens > 0
            ? facts.maxContextTokens
            : hydrated.contextLength,
        supportsVision: hydrated.supportsVision || facts.vision,
        supportsFunctionCalling:
            hydrated.supportsFunctionCalling || facts.functionCalling,
      );
    } catch (e) {
      debugPrint('LiteRT-LM model description skipped: $e');
      return hydrated;
    }
  }

  Future<String?> downloadedModelPath(
    String modelId, {
    OfflineModelInfo? model,
  }) async {
    if (kIsWeb) return null;
    final isDownloaded = await _downloadService.isModelDownloaded(
      modelId,
      model: model,
    );
    if (!isDownloaded) return null;
    final existingPath = await _downloadService.resolveExistingModelPath(
      modelId,
      model: model,
    );
    return existingPath ?? _downloadService.getModelPath(modelId, model: model);
  }

  Future<bool> _ensureInitializedForRequest({
    String? modelPath,
    LiteRtLmBackend? backend,
    int? maxTokens,
    String? installUrl,
    LiteRtLmModelKind? modelKind,
    bool vision = false,
  }) async {
    final trimmedModelPath = modelPath?.trim();
    if (_initializedModelPath != null &&
        trimmedModelPath != null &&
        _initializedModelPath == trimmedModelPath &&
        _initializedVision == vision) {
      return true;
    }

    var resolvedModelPath = trimmedModelPath;
    if (!await _client.activeModelExists(modelPath: resolvedModelPath)) {
      final resolvedInstallUrl = installUrl?.trim();
      if (resolvedInstallUrl == null || resolvedInstallUrl.isEmpty) {
        return false;
      }
      final installedModelPath = await _client.installModel(
        url: resolvedInstallUrl,
        modelKind: modelKind ?? runtimeConfig.modelKind,
        huggingFaceToken: runtimeConfig.optionalHuggingFaceToken,
      );
      final trimmedInstalledModelPath = installedModelPath?.trim();
      resolvedModelPath =
          trimmedInstalledModelPath != null &&
              trimmedInstalledModelPath.isNotEmpty
          ? trimmedInstalledModelPath
          : null;
    }

    try {
      await _client.initialize(
        huggingFaceToken: runtimeConfig.optionalHuggingFaceToken,
        modelPath: resolvedModelPath,
        backend: backend ?? runtimeConfig.backend,
        maxTokens: maxTokens ?? runtimeConfig.maxTokens,
        vision: vision,
      );
    } catch (_) {
      _initializedModelPath = null;
      _initializedVision = false;
      rethrow;
    }

    _initializedModelPath =
        resolvedModelPath ??
        (runtimeConfig.hasModelPath ? runtimeConfig.modelPath.trim() : null);
    _initializedVision = vision;
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

class MethodChannelLiteRtLmClient extends LiteRtLmClient {
  MethodChannelLiteRtLmClient({
    required this._config,
    this._channel = const MethodChannel('com.airo.litert_lm'),
    EventChannel? eventChannel,
  }) : _eventChannel =
           eventChannel ?? const EventChannel('com.airo.litert_lm/stream');

  final LiteRtLmConfig _config;
  final MethodChannel _channel;
  final EventChannel _eventChannel;
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
      final available = await _channel
          .invokeMethod<bool>('isAvailable', {'modelPath': resolvedModelPath})
          .timeout(_config.operationTimeout);
      return available ?? false;
    } on PlatformException catch (e) {
      debugPrint('LiteRT-LM availability check failed: ${e.message}');
      return false;
    } on MissingPluginException {
      return false;
    } on TimeoutException {
      debugPrint('LiteRT-LM availability check timed out.');
      return false;
    }
  }

  @override
  Future<String> generate({
    required String prompt,
    required LiteRtLmBackend backend,
    required int maxTokens,
    String? systemPrompt,
    String? imagePath,
    bool reuseConversation = true,
  }) async {
    final reply = await generateReply(
      prompt: prompt,
      backend: backend,
      maxTokens: maxTokens,
      systemPrompt: systemPrompt,
      imagePath: imagePath,
      reuseConversation: reuseConversation,
    );
    return reply.text;
  }

  @override
  Future<LiteRtLmReply> generateReply({
    required String prompt,
    required LiteRtLmBackend backend,
    required int maxTokens,
    String? systemPrompt,
    String? imagePath,
    bool reuseConversation = true,
    List<LiteRtLmToolSpec> tools = const [],
    List<LiteRtLmToolResponse> toolResponses = const [],
  }) async {
    final response = await _channel
        .invokeMethod<Object?>('generateContent', {
          'prompt': prompt,
          'systemPrompt': systemPrompt,
          'backend': backend.name,
          'maxTokens': maxTokens,
          'imagePath': imagePath,
          'reuseConversation': reuseConversation,
          'tools': [
            for (final tool in tools)
              {
                'name': tool.name,
                'description': tool.description,
                'parameters': tool.parameters,
              },
          ],
          'toolResponses': [
            for (final response in toolResponses)
              {'name': response.name, 'response': response.response},
          ],
        })
        .timeout(_config.operationTimeout);
    return LiteRtLmReply.fromChannel(response);
  }

  @override
  Stream<String> generateStream({
    required String prompt,
    required LiteRtLmBackend backend,
    required int maxTokens,
    String? systemPrompt,
    String? imagePath,
    bool reuseConversation = true,
  }) async* {
    final controller = StreamController<String>();
    final subscription = _eventChannel.receiveBroadcastStream().listen(
      (event) {
        if (event is String && event.isNotEmpty) {
          controller.add(event);
        }
      },
      onError: controller.addError,
      onDone: () {
        if (!controller.isClosed) controller.close();
      },
    );
    try {
      unawaited(
        _channel
            .invokeMethod<bool>('generateContentStream', {
              'prompt': prompt,
              'systemPrompt': systemPrompt,
              'backend': backend.name,
              'maxTokens': maxTokens,
              'imagePath': imagePath,
              'reuseConversation': reuseConversation,
            })
            .timeout(_config.operationTimeout)
            .catchError((Object error, StackTrace stackTrace) {
              if (!controller.isClosed) {
                controller.addError(error, stackTrace);
                controller.close();
              }
              return false;
            }),
      );
      yield* controller.stream;
    } finally {
      await subscription.cancel();
      if (!controller.isClosed) {
        await controller.close();
      }
    }
  }

  @override
  Future<LiteRtLmModelFacts?> describeModel({String? modelPath}) async {
    final resolvedModelPath = (modelPath?.trim().isNotEmpty ?? false)
        ? modelPath!.trim()
        : _activeModelPath;
    if (resolvedModelPath == null) return null;
    try {
      final raw = await _channel
          .invokeMethod<Object?>('describeModel', {
            'modelPath': resolvedModelPath,
          })
          .timeout(_config.operationTimeout);
      return LiteRtLmModelFacts.fromChannel(raw);
    } on PlatformException catch (e) {
      debugPrint('LiteRT-LM model description failed: ${e.message}');
      return null;
    } on MissingPluginException {
      return null;
    } on TimeoutException {
      debugPrint('LiteRT-LM model description timed out.');
      return null;
    }
  }

  @override
  Future<void> initialize({
    String? huggingFaceToken,
    String? modelPath,
    LiteRtLmBackend? backend,
    int? maxTokens,
    bool vision = false,
  }) async {
    final resolvedModelPath = (modelPath?.trim().isNotEmpty ?? false)
        ? modelPath!.trim()
        : _activeModelPath;
    if (resolvedModelPath == null) {
      throw StateError('LiteRT-LM model path is not configured');
    }

    await _channel
        .invokeMethod<bool>('initialize', {
          'modelPath': resolvedModelPath,
          'backend': (backend ?? _config.backend).name,
          'maxTokens': maxTokens ?? _config.maxTokens,
          'vision': vision,
        })
        .timeout(_config.operationTimeout);
  }

  @override
  Future<String?> installModel({
    required String url,
    required LiteRtLmModelKind modelKind,
    String? huggingFaceToken,
  }) async {
    _installedModelPath = await _channel
        .invokeMethod<String>('installModel', {
          'url': url,
          'modelKind': modelKind.name,
          'huggingFaceToken': huggingFaceToken,
        })
        .timeout(_config.operationTimeout);
    return _installedModelPath;
  }
}
