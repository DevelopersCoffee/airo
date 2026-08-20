/// Desktop no-op stand-in for `llama_flutter_android`.
///
/// The real plugin is Android JNI + Vulkan. macOS Mind loads GGUF through
/// `DesktopGgufBackend` / `airo_mind_llama`. This stub keeps the Dart import
/// compiling without shipping the Android plugin.
library;

import 'package:flutter/services.dart';

class GpuInfo {
  GpuInfo({
    this.vulkanSupported = false,
    this.gpuName = 'None',
    this.vulkanApiVersion = -1,
    this.deviceLocalMemoryBytes = -1,
    this.freeRamBytes = -1,
    this.recommendedGpuLayers = 0,
  });

  final bool vulkanSupported;
  final String gpuName;
  final int vulkanApiVersion;
  final int deviceLocalMemoryBytes;
  final int freeRamBytes;
  final int recommendedGpuLayers;
}

class LlamaController {
  LlamaController({BinaryMessenger? binaryMessenger});

  bool get isGenerating => false;

  Future<GpuInfo> detectGpu() async => GpuInfo();

  Future<void> loadModel({
    required String modelPath,
    int threads = 4,
    int contextSize = 2048,
    int? gpuLayers,
  }) async {}

  Stream<String> generate({
    required String prompt,
    int maxTokens = 512,
    double temperature = 0.7,
    double topP = 0.9,
    int topK = 40,
    double minP = 0.05,
    double typicalP = 1.0,
    double repeatPenalty = 1.1,
    double frequencyPenalty = 0.0,
    double presencePenalty = 0.0,
    int repeatLastN = 64,
    int mirostat = 0,
    double mirostatTau = 5.0,
    double mirostatEta = 0.1,
    int? seed,
    bool penalizeNewline = true,
  }) {
    return const Stream<String>.empty();
  }

  Future<void> stop() async {}

  Future<void> dispose() async {}
}
