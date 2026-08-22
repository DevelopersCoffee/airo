import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:llama_flutter_android/llama_flutter_android.dart';
import 'package:core_ai/core_ai.dart';

import '../model_bench/model_bench_protocol.dart';
import 'desktop_gguf_backend.dart';
import 'gguf_load_outcome.dart';
import 'gguf_runtime_stats.dart';

export 'gguf_runtime_stats.dart';

/// Thin platform adapter for the backend-neutral GGUF path.
///
/// Product policy remains in `core_ai`/the assistant runtime. This adapter
/// prefers the shared `airo_mind_llama` FRB slot (macOS/Windows/Linux/Android)
/// so chat `reason()` can drive the same engine. Android JNI
/// (`llama_flutter_android`) is the fallback when that slot cannot load.
class LlamaGgufService {
  LlamaGgufService({
    LlamaController? nativeController,
    DesktopGgufBackend? desktopBackend,
    Future<bool> Function()? desktopAvailabilityOverride,
  }) : _controller = nativeController,
       _desktopBackend = desktopBackend ?? DesktopGgufBackend(),
       _desktopAvailabilityOverride = desktopAvailabilityOverride;

  LlamaController? _controller;
  final DesktopGgufBackend _desktopBackend;
  final Future<bool> Function()? _desktopAvailabilityOverride;
  bool _loaded = false;

  /// Engine stats from the most recent FFI GGUF completion, if any.
  GgufRuntimeStats? get lastStats =>
      _ffiEngineReady ? _desktopBackend.readLastStats() : null;

  LlamaController get _nativeController => _controller ??= LlamaController();

  bool get isPlatformSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  bool get isDesktopGgufSupported => DesktopGgufBackend.isSupported;

  bool get _ffiEngineReady =>
      isDesktopGgufSupported && _desktopBackend.isEngineReady;

  /// True when this adapter (or the shared FRB llama slot) has a model.
  bool get isLoaded {
    if (_ffiEngineReady) return true;
    return _loaded;
  }

  Future<bool> _ffiSlotUsable() async {
    if (!isDesktopGgufSupported) return false;
    if (_desktopAvailabilityOverride != null) {
      return _desktopAvailabilityOverride!();
    }
    return _desktopBackend.isAvailable();
  }

  Future<bool> isAvailable() async {
    if (await _ffiSlotUsable()) return true;
    if (isPlatformSupported) {
      try {
        await _nativeController.detectGpu();
        return true;
      } on Object {
        return false;
      }
    }
    return false;
  }

  Future<bool> loadModel(
    OfflineModelInfo model, {
    int? contextSize,
    int threads = 4,
    int memoryBudgetMb = 4096,
  }) async {
    final outcome = await loadModelOutcome(
      model,
      contextSize: contextSize,
      threads: threads,
      memoryBudgetMb: memoryBudgetMb,
    );
    return outcome.succeeded;
  }

  Future<GgufLoadOutcome> loadModelOutcome(
    OfflineModelInfo model, {
    int? contextSize,
    int threads = 4,
    int memoryBudgetMb = 4096,
  }) async {
    final path = model.filePath?.trim();
    if (path == null || path.isEmpty) {
      return const GgufLoadOutcome.fileMissing();
    }

    if (await _ffiSlotUsable()) {
      final outcome = await _desktopBackend.loadModel(
        model,
        memoryBudgetMb: memoryBudgetMb,
      );
      _loaded = outcome.succeeded;
      return outcome;
    }

    if (isPlatformSupported) {
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
        return const GgufLoadOutcome.success();
      } on Object catch (error) {
        _loaded = false;
        return GgufLoadOutcome.engineError(error.toString());
      }
    }

    if (isDesktopGgufSupported) {
      final outcome = await _desktopBackend.loadModel(
        model,
        memoryBudgetMb: memoryBudgetMb,
      );
      _loaded = outcome.succeeded;
      return outcome;
    }

    return const GgufLoadOutcome.engineError('gguf_backend_unavailable');
  }

  Stream<String> generate({
    required String prompt,
    int maxTokens = 512,
    double temperature = 0.7,
    double topP = 0.9,
    int topK = 40,
    String? grammar,
  }) {
    if (!isLoaded) {
      return Stream<String>.error(StateError('gguf_model_not_loaded'));
    }
    if (_ffiEngineReady) {
      return _desktopBackend.generate(
        prompt: prompt,
        maxTokens: maxTokens,
        grammar: grammar,
      );
    }
    if (isPlatformSupported) {
      return _guardedGeneration(
        prompt: prompt,
        maxTokens: maxTokens,
        temperature: temperature,
        topP: topP,
        topK: topK,
      );
    }
    return Stream<String>.error(StateError('gguf_backend_unavailable'));
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
    if (_ffiEngineReady) {
      await _desktopBackend.stop();
      return;
    }
    if (_controller?.isGenerating ?? false) await _nativeController.stop();
  }

  Future<void> unload() async {
    _loaded = false;
    if (isDesktopGgufSupported) {
      await _desktopBackend.unload();
    }
    if (!isPlatformSupported) return;
    await _controller?.dispose();
    _controller = null;
  }

  /// One generate()+stats cycle for Model Bench.
  ///
  /// Desktop reads llama.cpp [RuntimeStats]. Android times the token stream:
  /// TTFT is wall clock to the first chunk; tok/s is remaining chunks over
  /// the rest of the stream. Peak RSS and prompt-token counts are unknown
  /// on Android and stay zero rather than guessed.
  Future<GenerationBenchSample> collectBenchSample({
    String prompt = kModelBenchPrompt,
    int maxOutputTokens = kModelBenchMaxOutputTokens,
  }) async {
    if (!isLoaded) {
      throw StateError('gguf_model_not_loaded');
    }
    if (_ffiEngineReady) {
      await generate(prompt: prompt, maxTokens: maxOutputTokens).drain<void>();
      return _desktopBackend.lastBenchSample();
    }
    if (isPlatformSupported) {
      return _wallClockSample(prompt: prompt, maxOutputTokens: maxOutputTokens);
    }
    throw StateError('gguf_backend_unavailable');
  }

  Future<GenerationBenchSample> _wallClockSample({
    required String prompt,
    required int maxOutputTokens,
  }) async {
    final sw = Stopwatch()..start();
    var firstChunkMs = 0;
    var chunks = 0;
    await for (final _ in generate(
      prompt: prompt,
      maxTokens: maxOutputTokens,
    )) {
      chunks += 1;
      if (chunks == 1) firstChunkMs = sw.elapsedMilliseconds;
    }
    final totalMs = sw.elapsedMilliseconds;
    if (chunks == 0) {
      throw StateError('benchmark produced no generated chunks');
    }
    final decodeMs = (totalMs - firstChunkMs).clamp(1, 1 << 30);
    final decodeChunks = chunks > 1 ? chunks - 1 : chunks;
    return GenerationBenchSample(
      prefillMs: firstChunkMs,
      prefillTokens: 0,
      generationMs: decodeMs,
      generatedTokens: chunks,
      tokensPerSecond: decodeChunks * 1000.0 / decodeMs,
      peakRssBytes: 0,
    );
  }
}
