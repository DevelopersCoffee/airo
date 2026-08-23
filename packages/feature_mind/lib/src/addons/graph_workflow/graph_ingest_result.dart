import 'package:core_ai/core_ai.dart';

import '../../agent_chat/domain/models/chat_entity_graph.dart';

/// Outcome of graph-workflow ingest through add-on adapters.
class GraphIngestResult {
  const GraphIngestResult({
    required this.graph,
    this.cancelled = false,
    this.errorCode,
  });

  static const cancelledCode = AddonInvocationEpoch.cancelledCode;

  final ChatEntityGraph graph;
  final bool cancelled;
  final String? errorCode;

  factory GraphIngestResult.success(ChatEntityGraph graph) =>
      GraphIngestResult(graph: graph);

  factory GraphIngestResult.cancelled(ChatEntityGraph graph) => GraphIngestResult(
    graph: graph,
    cancelled: true,
    errorCode: cancelledCode,
  );
}
