import 'package:core_ai/core_ai.dart';
import 'package:core_domain/core_domain.dart';

class SyntheticGraphWorkflowAdapter implements GraphWorkflowAddonAdapter {
  SyntheticGraphWorkflowAdapter({this.trigger = 'sample-extract'});

  final String trigger;

  @override
  AddonIdentity get identity =>
      const AddonIdentity(id: AddonId('sample-graph'), version: '1.0.0');

  @override
  bool accepts(GraphIngestContext input) => input.text.contains(trigger);

  @override
  Future<EntityGraphPatch> extract(GraphIngestContext input) async {
    return EntityGraphPatch(
      nodes: [
        EntityGraphNode(
          id: 'identifier:subject-1',
          typeKey: 'identifier',
          name: 'subject',
          attributes: {'kind': 'subject'},
        ),
      ],
      mentionedNodeIds: ['identifier:subject-1'],
      provenance: [
        GraphProvenanceRef(
          sourceMessageRevision: input.turnRevision,
          manifestDigest: 'sample-manifest',
          adapterDigest: 'sample-adapter',
          extractionContractVersion: 'graph_workflow_v1',
        ),
      ],
    );
  }

  @override
  Iterable<WorkflowProjection> project(EntityGraph graph) {
    final subject = graph.nodes.where(
      (node) => node.attributes['kind'] == 'subject',
    );
    return subject.map(
      (node) => WorkflowProjection(
        identity: identity,
        subjectNodeId: node.id,
        destinationKind: 'lifetrack',
        templateId: 'sample-template',
        templateVersion: '1',
        title: 'Sample subject',
        factsByFieldId: {'field_a': 'value_a'},
        identityKey: node.id,
        offer: const OfferDecision(kind: OfferDecisionKind.offerable),
      ),
    );
  }

  @override
  PendingAssessment assessPending(
    EntityGraph graph,
    WorkflowProjection projection,
  ) => PendingAssessment(
    identity: identity,
    subjectNodeId: projection.subjectNodeId,
    storedFacts: projection.factsByFieldId,
    missingRequired: const ['field_b'],
    missingOptional: const [],
    summary: 'missing field_b',
  );
}
