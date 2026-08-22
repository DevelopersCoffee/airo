import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../agent_chat/data/services/assistant_runtime_service.dart';
import '../../model_bench/production_model_port.dart';
import '../../provenance/data/local_gguf_ner_complete.dart';
import '../../provenance/domain/services/model_entity_extractor.dart';
import '../../runtime/persistent/persistent_operation_log.dart';
import '../../runtime/scribe_mind_runtime.dart';
import '../../runtime/mind_runtime.dart';
import '../../services/llama_gguf_service.dart';

/// The [MindRuntime] Audio Scribe (and, as they land, other assistant
/// surfaces) writes operations against.
///
/// Uses [ScribeMindRuntime] with [RustPreferredOperationLog] and
/// [RustMindRuntimeVault] shared with [MindService] (`sharedMindOperationLog`).
/// [ModelPort] is the production GGUF-backed port (load + warmed median bench),
/// not the fixture catalog.
final mindRuntimeProvider = Provider<MindRuntime>(
  (ref) => ScribeMindRuntime(
    log: sharedMindOperationLog(),
    models: createProductionModelPort(),
  ),
);

/// Local GGUF complete used by provenance NER. Shares the mapped engine
/// with [createProductionModelPort].
final mindNerRuntimeProvider = Provider<AssistantRuntimeService>(
  (ref) => AssistantRuntimeService(llamaGguf: sharedLlamaGgufService()),
);

/// Inspector hosts inject this as `ProvenanceInspector.model`. Tests keep
/// passing a scripted [ModelBackedEntityExtractor] instead.
final modelBackedEntityExtractorProvider = Provider<ModelBackedEntityExtractor>(
  (ref) => productionModelBackedEntityExtractor(
    models: ref.watch(mindRuntimeProvider).models,
    runtime: ref.watch(mindNerRuntimeProvider),
  ),
);
