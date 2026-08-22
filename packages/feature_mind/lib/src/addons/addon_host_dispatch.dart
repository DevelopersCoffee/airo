import 'package:core_ai/core_ai.dart';
import 'package:core_domain/core_domain.dart';

/// Thin host wrapper that routes add-on behavior through the registry without
/// switching on add-on IDs. Production chat will adopt this in later increments.
class AddonHostDispatch {
  AddonHostDispatch(this._registry);

  final AddonRegistry _registry;

  AddonPrompt? buildGenerativePrompt(AddonConversation conversation) {
    for (final adapter in _registry.eligibleGenerativeAdapters()) {
      if (adapter.accepts(conversation)) {
        return adapter.buildPrompt(conversation);
      }
    }
    return null;
  }

  Future<EntityGraphPatch?> extractGraphPatch(GraphIngestContext context) async {
    for (final adapter in _registry.eligibleGraphAdapters()) {
      if (adapter.accepts(context)) {
        return adapter.extract(context);
      }
    }
    return null;
  }

  List<WorkflowProjection> projectGraph(EntityGraph graph) {
    final projections = <WorkflowProjection>[];
    for (final adapter in _registry.eligibleGraphAdapters()) {
      projections.addAll(adapter.project(graph));
    }
    return projections;
  }
}
