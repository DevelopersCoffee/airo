import 'dart:async';
import 'dart:io';

import 'package:core_ai/core_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../library_loader.dart';
import '../llama/api/minutes.dart' as llama;
import '../model_bench/model_bench_protocol.dart';
import 'gguf_artifact_guard.dart';
import 'gguf_load_outcome.dart';

/// macOS / Windows / Linux GGUF path via the Rust `airo_mind_llama` bridge.
///
/// Android keeps using [LlamaGgufService]'s `llama_flutter_android` adapter.
class DesktopGgufBackend {
  const DesktopGgufBackend();

  static bool get isSupported {
    if (kIsWeb) return false;
    return switch (defaultTargetPlatform) {
      TargetPlatform.macOS ||
      TargetPlatform.windows ||
      TargetPlatform.linux => true,
      _ => false,
    };
  }

  Future<bool> isAvailable() async {
    final outcome = await probe();
    return outcome.succeeded;
  }

  Future<GgufLoadOutcome> probe() async {
    if (!isSupported) return const GgufLoadOutcome.engineError('unsupported');
    try {
      await initializeLlamaBridge();
      return const GgufLoadOutcome.success();
    } on Object catch (error) {
      return GgufLoadOutcome.engineError(error.toString());
    }
  }

  Future<GgufLoadOutcome> loadModel(
    OfflineModelInfo model, {
    int memoryBudgetMb = 4096,
  }) async {
    if (!isSupported) {
      return const GgufLoadOutcome.engineError('unsupported');
    }
    final path = model.filePath?.trim();
    if (path == null || path.isEmpty) {
      return const GgufLoadOutcome.fileMissing();
    }
    final file = File(path);
    if (!file.existsSync()) {
      return const GgufLoadOutcome.fileMissing();
    }
    final mismatch = GgufArtifactGuard.sizeMismatch(model);
    if (mismatch != null) {
      return GgufLoadOutcome.incompleteDownload(
        expectedBytes: mismatch.expected,
        foundBytes: mismatch.found,
      );
    }

    final modelsDir = p.dirname(path);
    if (!Directory(modelsDir).existsSync()) {
      return const GgufLoadOutcome.fileMissing();
    }

    try {
      await initializeLlamaBridge();
      if (!llama.isReady()) {
        if (isLlamaLoaded) {
          llama.unloadGeneration();
        }
        await _initializeEngine(
          modelsDir: modelsDir,
          memoryBudgetMb: memoryBudgetMb,
        );
      }
      if (llama.isReady()) {
        return const GgufLoadOutcome.success();
      }

      // One recovery attempt: clear a half-initialised generation slot.
      llama.unloadGeneration();
      await _initializeEngine(
        modelsDir: modelsDir,
        memoryBudgetMb: memoryBudgetMb,
      );
      return llama.isReady()
          ? const GgufLoadOutcome.success()
          : const GgufLoadOutcome.engineError('engine_not_ready');
    } on Object catch (error) {
      return GgufLoadOutcome.engineError(error.toString());
    }
  }

  Future<void> _initializeEngine({
    required String modelsDir,
    required int memoryBudgetMb,
  }) async {
    await llama.initialize(
      config: llama.GenerationConfig(
        modelsDir: modelsDir,
        memoryBudgetMb: memoryBudgetMb,
        preferIndicGeneration: false,
        allowCompactFallback: true,
      ),
    );
  }

  Stream<String> generate({
    required String prompt,
    int maxTokens = 512,
  }) async* {
    if (!llama.isReady()) {
      throw StateError('gguf_model_not_loaded');
    }
    await for (final event in llama.generateCompletion(
      prompt: prompt,
      maxOutputTokens: maxTokens,
    )) {
      switch (event) {
        case llama.GenerationEvent_Generating(:final text):
          yield text;
        case llama.GenerationEvent_MinutesReady():
        case llama.GenerationEvent_Cancelled():
          return;
      }
    }
  }

  Future<void> stop() async {
    if (!isLlamaLoaded) return;
    llama.cancelGeneration();
  }

  Future<void> unload() async {
    if (!isLlamaLoaded) return;
    llama.unloadGeneration();
  }

  /// True when the Rust generation slot is initialised.
  ///
  /// Safe in tests that never called `RustLib.init` — FRB throws, and we
  /// treat that as not ready rather than crashing the ModelPort.
  bool get isEngineReady {
    try {
      return llama.isReady();
    } on Object {
      return false;
    }
  }

  /// Stats from the most recently completed [generate] / `generateCompletion`.
  GenerationBenchSample lastBenchSample() {
    final s = llama.generationStats();
    return GenerationBenchSample(
      prefillMs: s.prefillMs.toInt(),
      prefillTokens: s.prefillTokens,
      generationMs: s.generationMs.toInt(),
      generatedTokens: s.generatedTokens,
      tokensPerSecond: s.tokensPerSecond,
      peakRssBytes: s.peakRssBytes.toInt(),
    );
  }
}
