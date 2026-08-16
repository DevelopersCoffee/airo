import 'package:flutter/foundation.dart';

import '../library_loader.dart';
import '../llama/api/minutes.dart' as llama;

/// Timing and memory from the most recently completed [MindGenerationBridge.
/// generate] call. All zero before anything has generated -- a state the
/// caller can act on (nothing to show yet) rather than a lie about a
/// generation that never happened.
@immutable
class GenerationStats {
  const GenerationStats({
    required this.prefillMs,
    required this.prefillTokens,
    required this.generationMs,
    required this.generatedTokens,
    required this.tokensPerSecond,
    required this.peakRssBytes,
  });

  final int prefillMs;
  final int prefillTokens;
  final int generationMs;
  final int generatedTokens;
  final double tokensPerSecond;
  final int peakRssBytes;
}

@immutable
sealed class GenerationEvent {
  const GenerationEvent();
}

final class GenerationEventGenerating extends GenerationEvent {
  const GenerationEventGenerating(this.text);
  final String text;
}

final class GenerationEventMinutesReady extends GenerationEvent {
  const GenerationEventMinutesReady(this.text);
  final String text;
}

final class GenerationEventCancelled extends GenerationEvent {
  const GenerationEventCancelled();
}

/// The generation half of the pipeline. See `MindSpeechBridge` for why this is
/// an interface rather than a direct call.
///
/// [ensureLoaded] makes the lazy load — 48 MB that only minutes need,
/// currently an inline guard in `library_loader.dart` — an observable, testable
/// step rather than something buried inside `generate`.
abstract interface class MindGenerationBridge {
  bool get isLoaded;

  /// Idempotent: loads the generation library and model on first call only.
  Future<void> ensureLoaded({
    required String modelsDir,
    required int memoryBudgetMb,
    bool preferIndicGeneration = false,
    bool allowCompactFallback = true,
  });

  /// [grammar] is a GBNF grammar (start symbol `root`) constraining the
  /// token stream, or `null` for the model's normal unconstrained output.
  /// Plumbing only -- this bridge does not know or care what the grammar
  /// encodes.
  Stream<GenerationEvent> generate({required String transcript, String? grammar});

  /// What produced the last minutes, for [MindSpeechBridge.save] to record
  /// (`ADR-0018 §5`). Empty before anything has been generated.
  String modelId();

  /// Timing and memory from the most recently completed [generate] call.
  GenerationStats stats();

  /// Releases the loaded generation model. Safe to call when nothing is
  /// loaded.
  void unload();

  void cancel();
}

/// Delegates to the generated llama bridge, owning the lazy-load guard that
/// used to live inline in `MindService.process`.
class RustMindGenerationBridge implements MindGenerationBridge {
  RustMindGenerationBridge();

  var _loaded = false;

  @override
  bool get isLoaded => _loaded;

  @override
  Future<void> ensureLoaded({
    required String modelsDir,
    required int memoryBudgetMb,
    bool preferIndicGeneration = false,
    bool allowCompactFallback = true,
  }) async {
    await initializeLlamaBridge();
    if (llama.isReady()) {
      _loaded = true;
      return;
    }
    await llama.initialize(
      config: llama.GenerationConfig(
        modelsDir: modelsDir,
        memoryBudgetMb: memoryBudgetMb,
        preferIndicGeneration: preferIndicGeneration,
        allowCompactFallback: allowCompactFallback,
      ),
    );
    _loaded = true;
  }

  @override
  Stream<GenerationEvent> generate({
    required String transcript,
    String? grammar,
  }) =>
      llama
          .generateMinutes(transcript: transcript, grammar: grammar)
          .map((event) {
            return switch (event) {
              llama.GenerationEvent_Generating(:final text) =>
                GenerationEventGenerating(text),
              llama.GenerationEvent_MinutesReady(:final text) =>
                GenerationEventMinutesReady(text),
              llama.GenerationEvent_Cancelled() =>
                const GenerationEventCancelled(),
            };
          });

  @override
  String modelId() => llama.generationModelId();

  @override
  GenerationStats stats() {
    final s = llama.generationStats();
    return GenerationStats(
      prefillMs: s.prefillMs.toInt(),
      prefillTokens: s.prefillTokens,
      generationMs: s.generationMs.toInt(),
      generatedTokens: s.generatedTokens,
      tokensPerSecond: s.tokensPerSecond,
      peakRssBytes: s.peakRssBytes.toInt(),
    );
  }

  @override
  void unload() => llama.unloadGeneration();

  @override
  void cancel() => llama.cancelGeneration();
}
