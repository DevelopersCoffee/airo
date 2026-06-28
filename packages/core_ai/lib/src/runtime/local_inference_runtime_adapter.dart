import 'package:meta/meta.dart';

import '../llm/llm_client.dart';
import '../models/offline_model_info.dart';

enum LocalRuntimeKind { geminiNano, liteRtLm, gguf }

enum RuntimeBackend { cpu, gpu, npu }

@immutable
class RuntimeCapabilities {
  const RuntimeCapabilities({
    required this.supportedBackends,
    this.supportsStreaming = false,
    this.supportsImages = false,
    this.supportsAudio = false,
    this.supportsToolCalling = false,
    this.supportsSystemPrompt = true,
    this.supportsSpeculativeDecoding = false,
  });

  final Set<RuntimeBackend> supportedBackends;
  final bool supportsStreaming;
  final bool supportsImages;
  final bool supportsAudio;
  final bool supportsToolCalling;
  final bool supportsSystemPrompt;
  final bool supportsSpeculativeDecoding;
}

@immutable
class RuntimeGenerationRequest {
  const RuntimeGenerationRequest({
    required this.prompt,
    this.systemPrompt,
    this.requiresVision = false,
    this.requiresAudio = false,
    this.requiresToolCalling = false,
    this.localOnly = false,
  });

  final String prompt;
  final String? systemPrompt;
  final bool requiresVision;
  final bool requiresAudio;
  final bool requiresToolCalling;
  final bool localOnly;
}

abstract class LocalInferenceRuntimeAdapter implements LLMClient {
  LocalRuntimeKind get runtimeKind;

  Future<bool> supportsModel(OfflineModelInfo model);

  RuntimeCapabilities capabilitiesForModel(OfflineModelInfo model);

  Future<void> prepareModel({OfflineModelInfo? model});

  Future<String?> generateText(
    RuntimeGenerationRequest request, {
    OfflineModelInfo? model,
  });
}

class LocalInferenceRuntimeRegistry {
  LocalInferenceRuntimeRegistry({
    Iterable<LocalInferenceRuntimeAdapter>? adapters,
  }) : _adapters = [...?adapters];

  final List<LocalInferenceRuntimeAdapter> _adapters;

  List<LocalInferenceRuntimeAdapter> get adapters =>
      List.unmodifiable(_adapters);

  void register(LocalInferenceRuntimeAdapter adapter) {
    _adapters.removeWhere(
      (existing) => existing.runtimeKind == adapter.runtimeKind,
    );
    _adapters.add(adapter);
  }
}

extension LocalInferenceRuntimeRegistryAsync on LocalInferenceRuntimeRegistry {
  Future<List<LocalInferenceRuntimeAdapter>> supportedAdaptersForModel(
    OfflineModelInfo model,
  ) async {
    final supported = <LocalInferenceRuntimeAdapter>[];
    for (final adapter in adapters) {
      if (await adapter.supportsModel(model)) {
        supported.add(adapter);
      }
    }
    return supported;
  }
}
