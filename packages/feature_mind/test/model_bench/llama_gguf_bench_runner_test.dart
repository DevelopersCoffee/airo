import 'package:feature_mind/src/model_bench/llama_gguf_bench_runner.dart';
import 'package:feature_mind/src/model_bench/model_bench_protocol.dart';
import 'package:feature_mind/src/services/llama_gguf_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'LlamaGgufBenchRunner refuses to sample when the engine is not loaded',
    () async {
      final runner = LlamaGgufBenchRunner(_UnloadedGguf());
      await expectLater(runner.sample(), throwsStateError);
    },
  );

  test(
    'LlamaGgufBenchRunner forwards collectBenchSample when loaded',
    () async {
      final gguf = _LoadedGguf();
      final sample = await LlamaGgufBenchRunner(gguf).sample();
      expect(sample.tokensPerSecond, 18);
      expect(gguf.collectCalls, 1);
    },
  );
}

class _UnloadedGguf extends LlamaGgufService {
  @override
  bool get isLoaded => false;
}

class _LoadedGguf extends LlamaGgufService {
  var collectCalls = 0;

  @override
  bool get isLoaded => true;

  @override
  Future<GenerationBenchSample> collectBenchSample({
    String prompt = kModelBenchPrompt,
    int maxOutputTokens = kModelBenchMaxOutputTokens,
  }) async {
    collectCalls += 1;
    return const GenerationBenchSample(
      prefillMs: 90,
      prefillTokens: 8,
      generationMs: 200,
      generatedTokens: 16,
      tokensPerSecond: 18,
      peakRssBytes: 0,
    );
  }
}
