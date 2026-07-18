export 'package:core_ai/core_ai.dart'
    show
        LiteRtLmBackend,
        LiteRtLmClient,
        LiteRtLmConfig,
        LiteRtLmModelKind,
        LiteRtLmRuntimeAdapter,
        MediaPipeWebRuntimeAdapter,
        MethodChannelLiteRtLmClient;

import 'package:flutter/foundation.dart';
import 'package:core_ai/core_ai.dart';

/// Transitional app-facing shim around the framework-owned LiteRT-LM adapter.
///
/// Feature code should continue to inject/use this service until all call sites
/// move directly to the `core_ai` runtime contracts.
class LiteRtLmService {
  LiteRtLmService({
    LiteRtLmClient? client,
    this.config = const LiteRtLmConfig(),
    ModelDownloadService? downloadService,
    LiteRtLmRuntimeAdapter? adapter,
    MediaPipeWebRuntimeAdapter? webAdapter,
  }) : _isWeb = webAdapter != null || kIsWeb,
       _webAdapter = webAdapter ?? (kIsWeb ? MediaPipeWebRuntimeAdapter() : null),
       _nativeAdapter = (webAdapter != null || kIsWeb)
           ? null
           : (adapter ??
               LiteRtLmRuntimeAdapter(
                 client: client,
                 runtimeConfig: config,
                 downloadService: downloadService,
               ));

  final LiteRtLmConfig config;
  final bool _isWeb;
  final MediaPipeWebRuntimeAdapter? _webAdapter;
  final LiteRtLmRuntimeAdapter? _nativeAdapter;

  /// Whether this service is currently backed by the browser MediaPipe
  /// runtime instead of the native platform-channel runtime.
  bool get isUsingWebRuntime => _isWeb;

  Future<bool> isAvailable() =>
      _isWeb ? _webAdapter!.isAvailable() : _nativeAdapter!.isAvailable();

  Future<String?> generateText(String prompt, {String? systemPrompt}) {
    if (_isWeb) {
      throw UnsupportedError(
        'Browser runtime requires a model; call generateTextForModel instead.',
      );
    }
    return _nativeAdapter!.generateText(
      RuntimeGenerationRequest(prompt: prompt, systemPrompt: systemPrompt),
    );
  }

  Future<bool> warmupInstalledModel() => _isWeb
      ? Future.value(false)
      : _nativeAdapter!.warmupInstalledModel();

  Future<bool> warmupModel(OfflineModelInfo model) async {
    if (_isWeb) {
      if (!model.supportsWebRuntime) return false;
      await _webAdapter!.prepareModel(model: model);
      return true;
    }
    return _nativeAdapter!.warmupModel(model);
  }

  Future<String?> generateTextForModel(
    OfflineModelInfo model,
    String prompt, {
    String? systemPrompt,
  }) {
    final request = RuntimeGenerationRequest(
      prompt: prompt,
      systemPrompt: systemPrompt,
    );
    if (_isWeb) {
      return _webAdapter!.generateText(request, model: model);
    }
    return _nativeAdapter!.generateText(request, model: model);
  }

  Future<OfflineModelInfo> hydrateDownloadedModel(OfflineModelInfo model) {
    if (_isWeb) return Future.value(model);
    return _nativeAdapter!.hydrateDownloadedModel(model);
  }

  Future<String?> downloadedModelPath(String modelId) {
    if (_isWeb) return Future.value(null);
    return _nativeAdapter!.downloadedModelPath(modelId);
  }
}
