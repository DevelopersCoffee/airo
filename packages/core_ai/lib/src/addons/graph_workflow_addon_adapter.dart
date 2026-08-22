import 'package:core_domain/core_domain.dart';

import 'graph_ingest_context.dart';

abstract interface class GraphWorkflowAddonAdapter {
  AddonIdentity get identity;

  bool accepts(GraphIngestContext input);

  Future<EntityGraphPatch> extract(GraphIngestContext input);

  Iterable<WorkflowProjection> project(EntityGraph graph);

  PendingAssessment assessPending(
    EntityGraph graph,
    WorkflowProjection projection,
  );
}
