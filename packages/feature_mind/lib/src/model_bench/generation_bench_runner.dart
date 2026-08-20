import 'model_bench_protocol.dart';

/// One generate()+stats() cycle used by [runGenerationBench].
///
/// The catalog ModelPort stays honest when no engine is loaded: it throws
/// rather than inventing tok/s. Tests and a loaded llama engine inject a
/// runner; this file deliberately does not import the generated llama
/// bridge so `RustMindRuntime` can compile in tests without freezed output.
abstract interface class GenerationBenchRunner {
  Future<GenerationBenchSample> sample();
}
