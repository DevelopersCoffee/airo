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
  Future<void> initialize({String? huggingFaceToken});

  Future<bool> activeModelExists();

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
  }) : _client = client ?? MethodChannelLiteRtLmClient(config: config);

  final LiteRtLmClient _client;
  final LiteRtLmConfig config;
  bool _initialized = false;

  Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    if (await _client.activeModelExists()) return true;
    return config.hasModelUrl;
  }

  Future<String?> generateText(String prompt, {String? systemPrompt}) async {
    if (prompt.trim().isEmpty) return null;
    if (!await _ensureInitialized()) return null;

    return _client.generate(
      prompt: prompt,
      systemPrompt: systemPrompt,
      backend: config.backend,
      maxTokens: config.maxTokens,
    );
  }

  /// Pre-warm an already-installed LiteRT-LM model with a private dummy prompt.
  ///
  /// This method intentionally does not install or download a model. It only
  /// warms the local runtime when an active model file already exists.
  Future<bool> warmupInstalledModel() async {
    if (kIsWeb) return false;

    try {
      if (!await _client.activeModelExists()) return false;
      if (!_initialized) {
        await _client.initialize(
          huggingFaceToken: config.optionalHuggingFaceToken,
        );
        _initialized = true;
      }
      await _client.generate(
        prompt: ' ',
        backend: config.backend,
        maxTokens: 1,
      );
      return true;
    } catch (e) {
      debugPrint('LiteRT-LM warmup skipped: $e');
      return false;
    }
  }

  Future<bool> _ensureInitialized() async {
    if (_initialized) return true;

    if (!await _client.activeModelExists()) {
      if (!config.hasModelUrl) return false;
      await _client.installModel(
        url: config.modelUrl.trim(),
        modelKind: config.modelKind,
        huggingFaceToken: config.optionalHuggingFaceToken,
      );
    }

    await _client.initialize(huggingFaceToken: config.optionalHuggingFaceToken);
    _initialized = true;
    return true;
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
  Future<bool> activeModelExists() async {
    final modelPath = _activeModelPath;
    if (modelPath == null) return false;
    try {
      final available = await _channel.invokeMethod<bool>('isAvailable', {
        'modelPath': modelPath,
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
  Future<void> initialize({String? huggingFaceToken}) async {
    final modelPath = _activeModelPath;
    if (modelPath == null) {
      throw StateError('LiteRT-LM model path is not configured');
    }

    await _channel.invokeMethod<bool>('initialize', {
      'modelPath': modelPath,
      'backend': _config.backend.name,
      'maxTokens': _config.maxTokens,
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
