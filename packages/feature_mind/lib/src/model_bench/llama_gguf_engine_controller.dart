import 'package:core_ai/core_ai.dart' as core_ai;

import '../services/llama_gguf_service.dart';
import 'generation_engine_controller.dart';

/// [GenerationEngineController] over the existing GGUF adapter.
///
/// Desktop load initialises the Rust llama slot ([DesktopGgufBackend]);
/// Android load uses `llama_flutter_android`. Either path is enough for
/// [LlamaGgufBenchRunner] to sample the same engine.
class LlamaGgufEngineController implements GenerationEngineController {
  LlamaGgufEngineController(this._gguf);

  final LlamaGgufService _gguf;
  String? _loadedModelId;

  @override
  bool get isLoaded => _gguf.isLoaded;

  @override
  String? get loadedModelId => isLoaded ? _loadedModelId : null;

  @override
  Future<void> load(core_ai.OfflineModelInfo model) async {
    final outcome = await _gguf.loadModelOutcome(model);
    if (!outcome.succeeded) {
      final detail =
          outcome.technicalDetail ?? outcome.reasonCode ?? 'load_failed';
      throw StateError(detail);
    }
    _loadedModelId = model.id;
  }

  @override
  Future<void> unload() async {
    await _gguf.unload();
    _loadedModelId = null;
  }
}
