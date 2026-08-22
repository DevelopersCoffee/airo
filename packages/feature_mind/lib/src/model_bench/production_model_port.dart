import '../runtime/ports/model_port.dart';
import '../runtime/rust/rust_mind_runtime.dart';
import '../services/llama_gguf_service.dart';
import 'generation_bench_runner.dart';
import 'generation_engine_controller.dart';
import 'llama_gguf_bench_runner.dart';
import 'llama_gguf_engine_controller.dart';
import 'model_bench_protocol.dart';

/// Production [ModelPort]: real catalog/disk plus GGUF load + warmed median
/// bench when the engine is loaded.
///
/// Lives outside `lib/src/runtime/` so the runtime layer stays free of the
/// generated llama bridge. Tests inject [benchRunner] and [engine] without
/// constructing [LlamaGgufService].
ModelPort createProductionModelPort({
  LlamaGgufService? gguf,
  GenerationBenchRunner? benchRunner,
  GenerationEngineController? engine,
  GenerationBenchMetadata? benchMetadata,
}) {
  late final service = gguf ?? sharedLlamaGgufService();
  return RustMindRuntime(
    benchRunner: benchRunner ?? LlamaGgufBenchRunner(service),
    engine: engine ?? LlamaGgufEngineController(service),
    benchMetadata: benchMetadata ?? productionGenerationBenchMetadata(),
  ).models;
}
