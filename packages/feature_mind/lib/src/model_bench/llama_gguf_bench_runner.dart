import '../services/llama_gguf_service.dart';
import 'generation_bench_runner.dart';
import 'model_bench_protocol.dart';

/// Samples the GGUF engine currently loaded by [LlamaGgufService].
///
/// Desktop uses llama.cpp [RuntimeStats] (prefill vs decode). Android has no
/// engine-side split, so the sample is wall-clock TTFT (first chunk) and a
/// chunk-rate for decode — never a spec-sheet figure, and never invented
/// when the engine is not loaded.
class LlamaGgufBenchRunner implements GenerationBenchRunner {
  LlamaGgufBenchRunner(
    this._gguf, {
    this.prompt = kModelBenchPrompt,
    this.maxOutputTokens = kModelBenchMaxOutputTokens,
  });

  final LlamaGgufService _gguf;
  final String prompt;
  final int maxOutputTokens;

  @override
  Future<GenerationBenchSample> sample() {
    if (!_gguf.isLoaded) {
      throw StateError('gguf_model_not_loaded');
    }
    return _gguf.collectBenchSample(
      prompt: prompt,
      maxOutputTokens: maxOutputTokens,
    );
  }
}
