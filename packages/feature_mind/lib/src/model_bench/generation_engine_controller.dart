import 'package:core_ai/core_ai.dart' as core_ai;

/// Loads a catalog GGUF into inference memory and unloads it.
///
/// Kept free of the generated llama bridge so [RustMindRuntime] can take an
/// injected controller (tests, or [LlamaGgufEngineController] in production)
/// without compiling FRB output into every ModelPort construction.
abstract interface class GenerationEngineController {
  bool get isLoaded;

  /// Catalog id currently in inference memory, or null if none.
  String? get loadedModelId;

  Future<void> load(core_ai.OfflineModelInfo model);

  Future<void> unload();
}
