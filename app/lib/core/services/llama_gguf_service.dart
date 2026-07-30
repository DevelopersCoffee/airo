import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:llama_flutter_android/llama_flutter_android.dart';
import 'package:core_ai/core_ai.dart';

/// Thin Android platform adapter for the backend-neutral GGUF path.
///
/// Product policy remains in `core_ai`/the assistant runtime. This adapter
/// only translates model lifecycle and generation calls to llama.cpp's typed
/// Flutter bridge. Non-Android targets report unavailable and keep their
/// existing runtime fallbacks.
class LlamaGgufService {
  LlamaGgufService({LlamaController? controller}) : _controller = controller;

  LlamaController? _controller;
  bool _loaded = false;

  LlamaController get _nativeController => _controller ??= LlamaController();

  bool get isPlatformSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<bool> isAvailable() async {
    if (!isPlatformSupported) return false;
    try {
      await _nativeController.detectGpu();
      return true;
    } on Object {
      return false;
    }
  }

  Future<bool> loadModel(
    OfflineModelInfo model, {
    int? contextSize,
    int threads = 4,
  }) async {
    final path = model.filePath?.trim();
    if (!isPlatformSupported || path == null || path.isEmpty) return false;
    try {
      final gpu = await _nativeController.detectGpu();
      final requestedContext = contextSize ?? model.contextLength;
      final safeContext = requestedContext.clamp(512, 8192).toInt();
      await _nativeController.loadModel(
        modelPath: path,
        threads: threads,
        contextSize: safeContext,
        gpuLayers: gpu.recommendedGpuLayers,
      );
      _loaded = true;
      return true;
    } on Object {
      _loaded = false;
      return false;
    }
  }

  Stream<String> generate({
    required String prompt,
    int maxTokens = 512,
    double temperature = 0.7,
    double topP = 0.9,
    int topK = 40,
  }) {
    if (!_loaded) {
      return Stream<String>.error(StateError('gguf_model_not_loaded'));
    }
    return _guardedGeneration(
      prompt: prompt,
      maxTokens: maxTokens,
      temperature: temperature,
      topP: topP,
      topK: topK,
    );
  }

  /// The Android plugin normally closes its token stream with `onDone`.
  /// Keep a bounded safety net around that platform boundary so a lost
  /// terminal callback cannot leave a chat request awaiting forever.
  Stream<String> _guardedGeneration({
    required String prompt,
    required int maxTokens,
    required double temperature,
    required double topP,
    required int topK,
  }) async* {
    try {
      await for (final token
          in _nativeController
              .generate(
                prompt: prompt,
                maxTokens: maxTokens,
                temperature: temperature,
                topP: topP,
                topK: topK,
              )
              .timeout(const Duration(minutes: 2))) {
        yield token;
      }
    } on TimeoutException {
      await stop();
      throw TimeoutException('GGUF generation timed out.');
    }
  }

  Future<void> stop() async {
    if (_controller?.isGenerating ?? false) await _nativeController.stop();
  }

  Future<void> unload() async {
    _loaded = false;
    if (!isPlatformSupported) return;
    await _controller?.dispose();
    _controller = null;
  }
}
