export 'package:core_ai/core_ai.dart'
    show
        LiteRtLmBackend,
        LiteRtLmClient,
        LiteRtLmConfig,
        LiteRtLmModelKind,
        LiteRtLmRuntimeAdapter,
        MethodChannelLiteRtLmClient;

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
  }) : _adapter =
           adapter ??
           LiteRtLmRuntimeAdapter(
             client: client,
             runtimeConfig: config,
             downloadService: downloadService,
           );

  final LiteRtLmConfig config;
  final LiteRtLmRuntimeAdapter _adapter;

  Future<bool> isAvailable() => _adapter.isAvailable();

  Future<String?> generateText(String prompt, {String? systemPrompt}) {
    return _adapter.generateText(
      RuntimeGenerationRequest(prompt: prompt, systemPrompt: systemPrompt),
    );
  }

  Future<bool> warmupInstalledModel() => _adapter.warmupInstalledModel();

  Future<bool> warmupModel(OfflineModelInfo model) =>
      _adapter.warmupModel(model);

  Future<String?> generateTextForModel(
    OfflineModelInfo model,
    String prompt, {
    String? systemPrompt,
  }) {
    return _adapter.generateText(
      RuntimeGenerationRequest(prompt: prompt, systemPrompt: systemPrompt),
      model: model,
    );
  }

  Future<OfflineModelInfo> hydrateDownloadedModel(OfflineModelInfo model) {
    return _adapter.hydrateDownloadedModel(model);
  }

  Future<String?> downloadedModelPath(String modelId) {
    return _adapter.downloadedModelPath(modelId);
  }
}
