import '../bridges/mind_generation_bridge.dart';
import 'generation_bench_runner.dart';
import 'model_bench_protocol.dart';

/// Drains one [MindGenerationBridge.complete] call and reads [stats].
class BridgeGenerationBenchRunner implements GenerationBenchRunner {
  BridgeGenerationBenchRunner(
    this._bridge, {
    this.prompt = kModelBenchPrompt,
    this.maxOutputTokens = kModelBenchMaxOutputTokens,
  });

  final MindGenerationBridge _bridge;
  final String prompt;
  final int maxOutputTokens;

  @override
  Future<GenerationBenchSample> sample() async {
    await _bridge
        .complete(prompt: prompt, maxOutputTokens: maxOutputTokens)
        .drain<void>();
    final stats = _bridge.stats();
    return GenerationBenchSample(
      prefillMs: stats.prefillMs,
      prefillTokens: stats.prefillTokens,
      generationMs: stats.generationMs,
      generatedTokens: stats.generatedTokens,
      tokensPerSecond: stats.tokensPerSecond,
      peakRssBytes: stats.peakRssBytes,
    );
  }
}
