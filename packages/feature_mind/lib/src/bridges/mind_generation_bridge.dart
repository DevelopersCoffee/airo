import 'package:flutter/foundation.dart';

import '../library_loader.dart';
import '../llama/api/minutes.dart' as llama;

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
  });

  Stream<GenerationEvent> generate({required String transcript});

  /// What produced the last minutes, for [MindSpeechBridge.save] to record
  /// (`ADR-0018 §5`). Empty before anything has been generated.
  String modelId();

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
      ),
    );
    _loaded = true;
  }

  @override
  Stream<GenerationEvent> generate({required String transcript}) =>
      llama.generateMinutes(transcript: transcript).map((event) {
        return switch (event) {
          llama.GenerationEvent_Generating(:final text) =>
            GenerationEventGenerating(text),
          llama.GenerationEvent_MinutesReady(:final text) =>
            GenerationEventMinutesReady(text),
          llama.GenerationEvent_Cancelled() => const GenerationEventCancelled(),
        };
      });

  @override
  String modelId() => llama.generationModelId();

  @override
  void cancel() => llama.cancelGeneration();
}
