import 'package:meta/meta.dart';

import '../provider/ai_provider.dart';

/// GPU acceleration backend for GGUF models.
enum GpuBackend {
  /// No GPU acceleration (CPU only)
  none,

  /// Apple Metal (iOS/macOS)
  metal,

  /// OpenCL (Android/Linux)
  openCL,

  /// Vulkan (Android/Windows/Linux)
  vulkan,

  /// Auto-detect best available backend
  auto,
}

/// Configuration for GGUF format models (llama.cpp compatible).
///
/// This configuration is used by [GGUFModelClient] to load and run
/// GGUF models for on-device inference.
@immutable
class GGUFModelConfig {
  const GGUFModelConfig({
    required this.modelPath,
    required this.modelName,
    this.provider = AIProvider.gguf,
    this.contextSize = 2048,
    this.batchSize = 512,
    this.gpuLayers = 0,
    this.gpuBackend = GpuBackend.auto,
    this.threads = 4,
    this.temperature = 0.7,
    this.topK = 40,
    this.topP = 0.95,
    this.repeatPenalty = 1.1,
    this.maxTokens = 1024,
    this.mmprojPath,
    this.seed,
    this.useMmap = true,
    this.useMlock = false,
    this.vocabOnly = false,
  });

  /// Path to the GGUF model file on device storage.
  final String modelPath;

  /// Human-readable model name for display.
  final String modelName;

  /// AI provider type for this model.
  final AIProvider provider;

  /// Context window size in tokens.
  /// Larger values use more memory but allow longer conversations.
  final int contextSize;

  /// Batch size for prompt processing.
  final int batchSize;

  /// Number of layers to offload to GPU (0 = CPU only).
  /// Set to -1 to offload all layers.
  final int gpuLayers;

  /// GPU backend to use for acceleration.
  final GpuBackend gpuBackend;

  /// Number of CPU threads to use.
  final int threads;

  /// Temperature for response randomness (0.0 - 2.0).
  final double temperature;

  /// Top-K sampling parameter.
  final int topK;

  /// Top-P (nucleus) sampling parameter.
  final double topP;

  /// Repeat penalty to reduce repetition.
  final double repeatPenalty;

  /// Maximum tokens to generate.
  final int maxTokens;

  /// Path to multimodal projector file (for vision models).
  final String? mmprojPath;

  /// Random seed for reproducibility (null = random).
  final int? seed;

  /// Use memory-mapped file for model loading.
  final bool useMmap;

  /// Lock model in memory (prevents swapping).
  final bool useMlock;

  /// Load vocabulary only (for tokenization without inference).
  final bool vocabOnly;

  /// Whether this is a vision-capable model.
  bool get isVisionModel => mmprojPath != null;

  /// Estimated memory usage in bytes (rough approximation).
  /// Actual usage depends on model architecture and quantization.
  int get estimatedMemoryBytes {
    // Base estimate: context * 4 bytes per token * 2 (KV cache)
    final kvCacheBytes = contextSize * 4 * 2;
    // Add batch processing overhead
    final batchBytes = batchSize * 4 * 2;
    return kvCacheBytes + batchBytes;
  }

  /// Creates a copy with modified fields.
  GGUFModelConfig copyWith({
    String? modelPath,
    String? modelName,
    AIProvider? provider,
    int? contextSize,
    int? batchSize,
    int? gpuLayers,
    GpuBackend? gpuBackend,
    int? threads,
    double? temperature,
    int? topK,
    double? topP,
    double? repeatPenalty,
    int? maxTokens,
    String? mmprojPath,
    int? seed,
    bool? useMmap,
    bool? useMlock,
    bool? vocabOnly,
  }) =>
      GGUFModelConfig(
        modelPath: modelPath ?? this.modelPath,
        modelName: modelName ?? this.modelName,
        provider: provider ?? this.provider,
        contextSize: contextSize ?? this.contextSize,
        batchSize: batchSize ?? this.batchSize,
        gpuLayers: gpuLayers ?? this.gpuLayers,
        gpuBackend: gpuBackend ?? this.gpuBackend,
        threads: threads ?? this.threads,
        temperature: temperature ?? this.temperature,
        topK: topK ?? this.topK,
        topP: topP ?? this.topP,
        repeatPenalty: repeatPenalty ?? this.repeatPenalty,
        maxTokens: maxTokens ?? this.maxTokens,
        mmprojPath: mmprojPath ?? this.mmprojPath,
        seed: seed ?? this.seed,
        useMmap: useMmap ?? this.useMmap,
        useMlock: useMlock ?? this.useMlock,
        vocabOnly: vocabOnly ?? this.vocabOnly,
      );
}

