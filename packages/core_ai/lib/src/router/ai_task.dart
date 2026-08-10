import '../models/offline_model_info.dart';

/// A distinct kind of AI work a model can be routed to serve.
///
/// This is the axis `AIRouter`/`AIRoutingStrategy` (`ai_router.dart`) does not
/// cover: that router decides *where* a request runs (on-device, cloud, user
/// choice); `AiTask` plus `TaskModelRouter` decides *which model*, once the
/// caller already knows the answer is on-device.
///
/// Two values -- [speechToText] and [textToSpeech] -- have no
/// [requiredCapability] and are never resolvable by `TaskModelRouter` against
/// `ModelCatalog`: Airo's speech engines are `feature_mind`'s whisper.cpp and
/// llama.cpp Rust bridges, not `OfflineModelInfo` catalog entries. They are
/// listed here so a caller can express "I need TTS" in the same vocabulary as
/// every other task, and get a clear, typed refusal
/// (`UnroutableTaskException`) rather than a silent wrong answer.
enum AiTask {
  chat(ModelCapability.chat),
  meetingSummarization(ModelCapability.meetingSummarization),
  translation(ModelCapability.translation),
  embeddings(ModelCapability.embeddings),
  ocr(ModelCapability.ocr),
  speechToText(null),
  textToSpeech(null);

  const AiTask(this.requiredCapability);

  /// The `ModelCapability` a catalog model must declare to serve this task.
  /// Null for tasks `TaskModelRouter` cannot resolve from `ModelCatalog` at
  /// all -- see [isCatalogResolvable].
  final ModelCapability? requiredCapability;

  /// Whether `TaskModelRouter.resolve` can answer this task from a list of
  /// `OfflineModelInfo`. False for the speech tasks, which are served by
  /// `feature_mind`'s Rust engines instead.
  bool get isCatalogResolvable => requiredCapability != null;
}
