import 'model_contract.dart';
import 'offline_model_info.dart';

/// Synchronous readiness evaluation — no load/warmup I/O.
///
/// ```text
/// notDownloaded → installed → runtimeAvailable → ready
///                      ↘ runtimeUnavailable (platform/backend)
/// ```
class ModelReadinessService {
  const ModelReadinessService._();

  static ModelReadinessState evaluate(
    OfflineModelInfo model, {
    required bool nativeGgufAvailable,
    required bool liteRtNativeAvailable,
    required bool webMediaPipeAvailable,
  }) {
    if (!model.isDownloaded) {
      return ModelReadinessState.notDownloaded;
    }

    final runtime = model.effectiveRuntime;
    final platform = model.effectivePlatformSupport;
    final platformLabel = platform.unsupportedPlatformLabel();

    if (platformLabel != null) {
      return ModelReadinessState(
        phase: ModelReadinessPhase.runtimeUnavailable,
        headline: 'Not supported on $platformLabel',
        detail: _platformDetail(runtime, platformLabel),
        isRunnable: false,
        canPrepare: false,
      );
    }

    final backendReady = switch (runtime) {
      InferenceRuntime.llamaCpp => nativeGgufAvailable,
      InferenceRuntime.litertLm => liteRtNativeAvailable,
      InferenceRuntime.mediaPipeWeb => webMediaPipeAvailable,
      InferenceRuntime.onnx => false,
      InferenceRuntime.whisper => false,
      InferenceRuntime.geminiNano => false,
      InferenceRuntime.geminiCloud => true,
    };

    if (!backendReady) {
      return ModelReadinessState(
        phase: ModelReadinessPhase.runtimeUnavailable,
        headline: 'Runtime unavailable',
        detail: _backendDetail(runtime),
        isRunnable: false,
        canPrepare: false,
      );
    }

    return ModelReadinessState(
      phase: ModelReadinessPhase.runtimeAvailable,
      headline: 'Ready on this device',
      detail: 'Installed and runnable with the ${runtime.displayName} backend.',
      isRunnable: true,
      canPrepare: true,
    );
  }

  static String _platformDetail(InferenceRuntime runtime, String platform) {
    return switch (runtime) {
      InferenceRuntime.litertLm =>
        'LiteRT-LM packages run on Android today. On $platform, download a GGUF model for local chat.',
      InferenceRuntime.mediaPipeWeb =>
        'This MediaPipe bundle targets the browser runtime.',
      _ => 'This package is not published for $platform yet.',
    };
  }

  static String _backendDetail(InferenceRuntime runtime) {
    return switch (runtime) {
      InferenceRuntime.llamaCpp =>
        'The native llama.cpp backend is not available. Download a GGUF model or configure a compatible remote server.',
      InferenceRuntime.litertLm =>
        'LiteRT-LM is not configured on this device. Install on Android or choose a GGUF package.',
      InferenceRuntime.mediaPipeWeb =>
        'The browser MediaPipe runtime is not available in this session.',
      InferenceRuntime.onnx => 'ONNX Runtime is not wired for this model yet.',
      InferenceRuntime.whisper =>
        'Whisper runtime is managed by the Scribe pipeline.',
      InferenceRuntime.geminiNano =>
        'Gemini Nano requires a supported Pixel device with AICore.',
      InferenceRuntime.geminiCloud => 'Cloud runtime is not configured.',
    };
  }
}

class ModelContractInference {
  ModelContractInference._();

  static String artifactKey(OfflineModelInfo model) {
    return '${model.id} ${model.filePath ?? ''} ${model.downloadUrl ?? ''}'
        .toLowerCase();
  }

  static InferenceRuntime inferRuntime(OfflineModelInfo model) {
    if (model.runtime != null) return model.runtime!;
    final key = artifactKey(model);
    if (key.contains('.litertlm') || key.contains('litertlm')) {
      return InferenceRuntime.litertLm;
    }
    if (key.contains('.task')) {
      return InferenceRuntime.mediaPipeWeb;
    }
    if (key.contains('.onnx')) {
      return InferenceRuntime.onnx;
    }
    return InferenceRuntime.llamaCpp;
  }

  static PlatformSupport inferPlatformSupport(
    OfflineModelInfo model,
    InferenceRuntime runtime,
  ) {
    if (model.platformSupport != null) return model.platformSupport!;
    return switch (runtime) {
      InferenceRuntime.litertLm => const PlatformSupport.androidOnly(),
      InferenceRuntime.mediaPipeWeb => const PlatformSupport.webOnly(),
      InferenceRuntime.llamaCpp ||
      InferenceRuntime.onnx ||
      InferenceRuntime.whisper => const PlatformSupport.allNative(),
      InferenceRuntime.geminiNano => const PlatformSupport(android: true),
      InferenceRuntime.geminiCloud => const PlatformSupport.allNative(),
    };
  }

  static ModelTask inferTask(OfflineModelInfo model) {
    if (model.task != null) return model.task!;
    if (model.capabilities.contains(ModelCapability.embeddings)) {
      return ModelTask.embedding;
    }
    final runtime = model.runtime ?? inferRuntime(model);
    if (runtime == InferenceRuntime.whisper) {
      return ModelTask.speechToText;
    }
    if (model.modalities.contains(ModelModality.audio) &&
        model.capabilities.contains(ModelCapability.audioUnderstanding) &&
        !model.capabilities.contains(ModelCapability.chat)) {
      return ModelTask.speechToText;
    }
    if (model.capabilities.contains(ModelCapability.imageUnderstanding) &&
        !model.capabilities.contains(ModelCapability.chat)) {
      return ModelTask.vision;
    }
    return ModelTask.textGeneration;
  }
}

extension OfflineModelContract on OfflineModelInfo {
  ModelTask get effectiveTask => ModelContractInference.inferTask(this);

  InferenceRuntime get effectiveRuntime =>
      ModelContractInference.inferRuntime(this);

  PlatformSupport get effectivePlatformSupport =>
      ModelContractInference.inferPlatformSupport(this, effectiveRuntime);

  bool get isRunnableOnCurrentPlatform =>
      effectivePlatformSupport.supportsCurrentPlatform();
}
