import '../../agent_chat/data/services/assistant_runtime_service.dart';
import '../../agent_chat/domain/models/assistant_runtime_ids.dart';
import '../../runtime/models/model_models.dart';
import '../../runtime/ports/model_port.dart';
import '../domain/services/entity_extractor.dart';
import '../domain/services/model_entity_extractor.dart';

/// Completes a NER prompt on the loaded local GGUF with GBNF grammar.
///
/// Never Gemini Cloud, Gemini Nano, or LiteRT. A caller that pointed
/// [AssistantRuntimeService.generateText] at a remote id has already
/// broken the [EntityExtractor] contract; this adapter still refuses
/// that path by selecting `offline-<loaded.id>` only.
NerComplete localGgufNerComplete({
  required ModelPort models,
  required AssistantRuntimeService runtime,
}) {
  return ({required String prompt, required String grammar}) async {
    final catalog = await models.all();
    MindModel? loaded;
    for (final model in catalog) {
      if (model.residency == ModelResidency.loaded) {
        loaded = model;
        break;
      }
    }
    if (loaded == null) {
      throw const EntityExtractionUnavailable('no model loaded');
    }
    try {
      return await runtime.generateText(
        selectedModelId: assistantModelIdForOfflineModel(loaded.id),
        prompt: prompt,
        grammar: grammar,
      );
    } on AssistantRuntimeUnavailableException catch (error) {
      throw EntityExtractionUnavailable(error.message);
    }
  };
}

/// Production [ModelBackedEntityExtractor] bound to [models] residency and
/// the local GGUF complete path.
ModelBackedEntityExtractor productionModelBackedEntityExtractor({
  required ModelPort models,
  required AssistantRuntimeService runtime,
}) {
  return ModelBackedEntityExtractor(
    models: models,
    complete: localGgufNerComplete(models: models, runtime: runtime),
  );
}
