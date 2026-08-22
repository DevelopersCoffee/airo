import 'package:meta/meta.dart';

import 'entity_graph_edge.dart';
import 'entity_graph_node.dart';
import 'graph_provenance.dart';

/// Validated patch returned by a graph-workflow adapter before merge.
@immutable
class EntityGraphPatch {
  const EntityGraphPatch({
    this.nodes = const [],
    this.edges = const [],
    this.mentionedNodeIds = const [],
    this.provenance = const [],
  });

  final List<EntityGraphNode> nodes;
  final List<EntityGraphEdge> edges;
  final List<String> mentionedNodeIds;
  final List<GraphProvenanceRef> provenance;

  bool get isEmpty =>
      nodes.isEmpty && edges.isEmpty && mentionedNodeIds.isEmpty;

  factory EntityGraphPatch.fromJson(Map<String, dynamic> json) =>
      EntityGraphPatch(
        nodes: ((json['nodes'] as List?) ?? const [])
            .map(
              (item) => EntityGraphNode.fromJson(item as Map<String, dynamic>),
            )
            .toList(growable: false),
        edges: ((json['edges'] as List?) ?? const [])
            .map(
              (item) => EntityGraphEdge.fromJson(item as Map<String, dynamic>),
            )
            .toList(growable: false),
        mentionedNodeIds: ((json['mentioned_node_ids'] as List?) ?? const [])
            .map((item) => item.toString())
            .toList(growable: false),
        provenance: ((json['provenance'] as List?) ?? const [])
            .map(
              (item) =>
                  GraphProvenanceRef.fromJson(item as Map<String, dynamic>),
            )
            .toList(growable: false),
      );

  Map<String, dynamic> toJson() => {
    'nodes': nodes.map((node) => node.toJson()).toList(growable: false),
    'edges': edges.map((edge) => edge.toJson()).toList(growable: false),
    'mentioned_node_ids': mentionedNodeIds,
    'provenance': provenance.map((ref) => ref.toJson()).toList(growable: false),
  };
}
