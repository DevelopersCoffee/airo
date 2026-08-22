import 'dart:async';
import 'dart:io';

import 'package:core_ai/core_ai.dart';
import 'package:flutter/foundation.dart';

import '../library_loader.dart';
import '../llama/api/minutes.dart' as llama;
import '../model_bench/model_bench_protocol.dart';
import 'gguf_artifact_guard.dart';
import 'gguf_load_outcome.dart';
import 'gguf_runtime_stats.dart';

/// FFI session used by [DesktopGgufBackend]. Tests inject a fake so load
/// policy can be proven without the native llama library.
@visibleForTesting
abstract class DesktopLlamaSession {
  const DesktopLlamaSession();

  Future<void> load({required String modelPath, required int memoryBudgetMb});

  bool get isReady;

  void unload();
}

class LiveDesktopLlamaSession extends DesktopLlamaSession {
  const LiveDesktopLlamaSession();

  @override
  Future<void> load({required String modelPath, required int memoryBudgetMb}) {
    return llama.initialize(
      config: llama.GenerationConfig(
        modelsDir: modelPath,
        memoryBudgetMb: memoryBudgetMb,
        preferIndicGeneration: false,
        allowCompactFallback: true,
      ),
    );
  }

  @override
  bool get isReady => llama.isReady();

  @override
  void unload() => llama.unloadGeneration();
}

/// macOS / Windows / Linux GGUF path via the Rust `airo_mind_llama` bridge.
///
/// Android keeps using [LlamaGgufService]'s `llama_flutter_android` adapter.
class DesktopGgufBackend {
  DesktopGgufBackend({
    Future<void> Function()? ensureBridge,
    DesktopLlamaSession? session,
  }) : _ensureBridge = ensureBridge ?? initializeLlamaBridge,
       _session = session ?? const LiveDesktopLlamaSession();

  final Future<void> Function() _ensureBridge;
  final DesktopLlamaSession _session;
  String? _loadedPath;

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
      await _ensureBridge();
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

    try {
      await _ensureBridge();
      if (_session.isReady && _loadedPath == path) {
        return const GgufLoadOutcome.success();
      }
      if (_session.isReady) {
        _session.unload();
        _loadedPath = null;
      }
      await _session.load(modelPath: path, memoryBudgetMb: memoryBudgetMb);
      if (_session.isReady) {
        _loadedPath = path;
        return const GgufLoadOutcome.success();
      }

      _session.unload();
      await _session.load(modelPath: path, memoryBudgetMb: memoryBudgetMb);
      if (_session.isReady) {
        _loadedPath = path;
        return const GgufLoadOutcome.success();
      }
      _loadedPath = null;
      return const GgufLoadOutcome.engineError('engine_not_ready');
    } on Object catch (error) {
      _loadedPath = null;
      return GgufLoadOutcome.engineError(error.toString());
    }
  }

  Stream<String> generate({
    required String prompt,
    int maxTokens = 512,
    String? grammar,
  }) async* {
    if (!_session.isReady) {
      throw StateError('gguf_model_not_loaded');
    }
    await for (final event in llama.generateCompletion(
      prompt: prompt,
      maxOutputTokens: maxTokens,
      grammar: grammar,
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

  GgufRuntimeStats? readLastStats() {
    if (!isLlamaLoaded) return null;
    try {
      final stats = llama.generationStats();
      if (stats.prefillTokens <= 0 && stats.generatedTokens <= 0) {
        return null;
      }
      return GgufRuntimeStats(
        prefillMs: stats.prefillMs.toInt(),
        prefillTokens: stats.prefillTokens,
        generationMs: stats.generationMs.toInt(),
        generatedTokens: stats.generatedTokens,
        tokensPerSecond: stats.tokensPerSecond,
      );
    } on Object {
      return null;
    }
  }

  Future<void> stop() async {
    if (!isLlamaLoaded) return;
    llama.cancelGeneration();
  }

  Future<void> unload() async {
    _loadedPath = null;
    if (!isLlamaLoaded && _session is LiveDesktopLlamaSession) return;
    _session.unload();
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
