import '../models/context_models.dart';

/// The hypergraph.
abstract interface class ContextPort {
  Future<List<MindContext>> all();

  Future<MindContext?> byId(String id);

  Future<List<ContextLink>> linksFor(String contextId);

  Future<MindContext> create({required String label});

  Future<void> link(String fromId, String toId);

  Future<void> unlink(String fromId, String toId);

  /// Labels of the contexts that would survive destroying [contextId].
  ///
  /// Returned before the destroy, not after: the survival preview is the whole
  /// difference between unlinking and shredding, and a person must see it
  /// while the choice is still theirs.
  Future<List<String>> survivorsIfDestroyed(String contextId);
}
