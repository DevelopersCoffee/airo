import 'package:core_domain/core_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('EntityGraph round-trips chat graph JSON shape', () {
    final json = {
      'nodes': [
        {
          'id': 'organization:niva-bupa',
          'type': 'organization',
          'name': 'Niva Bupa',
          'attributes': {},
        },
        {
          'id': 'identifier:9001001',
          'type': 'identifier',
          'name': '9001001',
          'attributes': {'kind': 'claim'},
        },
      ],
      'edges': [
        {
          'from_id': 'identifier:9001001',
          'to_id': 'organization:niva-bupa',
          'predicate': 'insured_by',
        },
      ],
      'recent_node_ids': ['identifier:9001001'],
    };

    final graph = EntityGraph.fromJson(json);
    expect(graph.toJson(), json);
  });

  test('EntityGraphPatch preserves provenance refs', () {
    final patch = EntityGraphPatch(
      nodes: [
        const EntityGraphNode(
          id: 'identifier:subject-1',
          typeKey: 'identifier',
          name: 'subject',
          attributes: {'kind': 'subject'},
        ),
      ],
      provenance: [
        const GraphProvenanceRef(
          sourceMessageRevision: 'rev-1',
          manifestDigest: 'manifest-sha',
          adapterDigest: 'adapter-sha',
          extractionContractVersion: 'graph_workflow_v1',
        ),
      ],
    );

    final restored = EntityGraphPatch.fromJson(patch.toJson());
    expect(restored.provenance.single.manifestDigest, 'manifest-sha');
  });
}
