import 'package:core_ai/core_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Supported LiteRT-LM model families used for model installation metadata.
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

/// Runtime backend preference for LiteRT-LM inference.
enum LiteRtLmBackend { cpu, gpu, npu }

/// Configuration for Airo's LiteRT-LM integration.
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

/// Thin boundary around the concrete LiteRT-LM runtime implementation.
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

/// App-facing LiteRT-LM service.
class LiteRtLmService {
  LiteRtLmService({
    LiteRtLmClient? client,
    this.config = const LiteRtLmConfig(),
    ModelDownloadService? downloadService,
  }) : _client = client ?? MethodChannelLiteRtLmClient(config: config),
       _downloadService = downloadService ?? ModelDownloadService();

  final LiteRtLmClient _client;
  final LiteRtLmConfig config;
  final ModelDownloadService _downloadService;
  String? _initializedModelPath;

  Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    if (await _client.activeModelExists()) return true;
    return config.hasModelUrl;
  }

  Future<String?> generateText(String prompt, {String? systemPrompt}) async {
    if (prompt.trim().isEmpty) return null;
    if (!await _ensureDefaultInitialized()) return null;

    return _client.generate(
      prompt: prompt,
      systemPrompt: systemPrompt,
      backend: config.backend,
      maxTokens: config.maxTokens,
    );
  }

  Future<String?> generateTextForModel(
    OfflineModelInfo model,
    String prompt, {
    String? systemPrompt,
  }) async {
    if (kIsWeb || prompt.trim().isEmpty) return null;

    final hydratedModel = await hydrateDownloadedModel(model);
    final modelPath = hydratedModel.filePath?.trim();
    if (modelPath == null || modelPath.isEmpty) {
      return null;
    }

    final backend = _backendFor(hydratedModel.backendPreference);
    if (!await _ensureInitializedForRequest(
      modelPath: modelPath,
      backend: backend,
      maxTokens: config.maxTokens,
    )) {
      return null;
    }

    return _client.generate(
      prompt: prompt,
      systemPrompt: systemPrompt,
      backend: backend,
      maxTokens: config.maxTokens,
    );
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

  Future<bool> _ensureDefaultInitialized() async {
    return _ensureInitializedForRequest(
      modelPath: config.hasModelPath ? config.modelPath.trim() : null,
      backend: config.backend,
      maxTokens: config.maxTokens,
      installUrl: config.hasModelUrl ? config.modelUrl.trim() : null,
      modelKind: config.modelKind,
    );
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
        modelKind: modelKind ?? config.modelKind,
        huggingFaceToken: config.optionalHuggingFaceToken,
      );
      resolvedModelPath = null;
    }
    await _client.initialize(
      huggingFaceToken: config.optionalHuggingFaceToken,
      modelPath: resolvedModelPath,
      backend: backend ?? config.backend,
      maxTokens: maxTokens ?? config.maxTokens,
    );
    _initializedModelPath =
        resolvedModelPath ??
        installUrl?.trim() ??
        (config.hasModelPath ? config.modelPath.trim() : null);
    return true;
  }

  LiteRtLmBackend _backendFor(ModelBackendPreference preference) {
    return switch (preference) {
      ModelBackendPreference.cpu => LiteRtLmBackend.cpu,
      ModelBackendPreference.gpu => LiteRtLmBackend.gpu,
      ModelBackendPreference.npu ||
      ModelBackendPreference.aiCore => LiteRtLmBackend.npu,
      ModelBackendPreference.auto => config.backend,
    };
  }
}

/// MethodChannel client backed by native LiteRT-LM integrations.
class MethodChannelLiteRtLmClient implements LiteRtLmClient {
  MethodChannelLiteRtLmClient({
    required LiteRtLmConfig config,
    MethodChannel channel = const MethodChannel('com.airo.litert_lm'),
  }) : _config = config,
       _channel = channel;

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
