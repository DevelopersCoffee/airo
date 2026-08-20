import 'package:feature_mind/src/bridges/mind_generation_bridge.dart';
import 'package:feature_mind/src/model_bench/bridge_generation_bench_runner.dart';
import 'package:feature_mind/src/model_bench/model_bench_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_bridges.dart';

void main() {
  test('refuses to sample when the generation engine is not loaded', () async {
    final runner = BridgeGenerationBenchRunner(FakeMindGenerationBridge());
    await expectLater(runner.sample(), throwsStateError);
  });

  test('drains complete() and maps stats when the engine is loaded', () async {
    final bridge = FakeMindGenerationBridge()
      ..completeEvents = const []
      ..statsValue = const GenerationStats(
        prefillMs: 80,
        prefillTokens: 8,
        generationMs: 200,
        generatedTokens: 16,
        tokensPerSecond: 22.5,
        peakRssBytes: 4096,
      );
    await bridge.ensureLoaded(modelsDir: '/tmp', memoryBudgetMb: 1024);

    final sample = await BridgeGenerationBenchRunner(bridge).sample();

    expect(sample.prefillMs, 80);
    expect(sample.tokensPerSecond, 22.5);
    expect(bridge.lastCompletePrompt, kModelBenchPrompt);
    expect(bridge.lastCompleteMaxOutputTokens, kModelBenchMaxOutputTokens);
  });
}
