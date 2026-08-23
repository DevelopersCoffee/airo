import 'package:core_ai/core_ai.dart';

/// Redacts add-on sensitive fields before trace persistence or volume measurement.
class AddonTraceRedaction {
  const AddonTraceRedaction();

  static Map<String, dynamic> connectorParameters(
    String tool,
    Map<String, dynamic> arguments,
  ) {
    if (tool == 'record_lifetrack_facts') {
      final facts = arguments['facts'];
      return {
        'template_id': arguments['template_id'],
        'title_length': (arguments['title'] as String?)?.length ?? 0,
        'fact_count': facts is Map ? facts.length : 0,
        'has_confirmation_token': arguments['confirmation_token'] != null,
      };
    }
    if (tool == 'query_entity_graph') {
      return {
        'query_length': (arguments['query'] as String?)?.length ?? 0,
        'intent': arguments['intent'],
      };
    }
    return arguments;
  }

  static Map<String, dynamic> connectorResult(
    String tool,
    Map<String, dynamic> data,
    bool isError,
  ) {
    if (isError) {
      return {'error': data['error'] ?? true};
    }
    if (tool == 'record_lifetrack_facts') {
      return {
        'created': data['created'],
        'track_id': data['track_id'],
        'template_id': data['template_id'],
      };
    }
    if (tool == 'query_entity_graph') {
      return {
        'node_count': data['node_count'],
        'edge_count': data['edge_count'],
        'markdown_length': (data['markdown'] as String?)?.length ?? 0,
      };
    }
    return data;
  }

  static ChatTurnTrace redactTraceForPersistence(ChatTurnTrace trace) {
    final redactor = const AiTraceRedactor();
    final nodes = trace.trajectory.nodes
        .map(
          (node) => AiTrajectoryNode(
            sequence: node.sequence,
            kind: node.kind,
            status: node.status,
            label: node.label,
            ref: node.ref,
            summary: node.summary == null
                ? null
                : _redactSummary(redactor, node.summary!),
            errorCode: node.errorCode,
          ),
        )
        .toList(growable: false);
    return ChatTurnTrace(
      runId: trace.runId,
      parentRunId: trace.parentRunId,
      startedAt: trace.startedAt,
      endedAt: trace.endedAt,
      lifecycle: trace.lifecycle,
      stopReason: trace.stopReason,
      runtimeId: trace.runtimeId,
      routing: trace.routing,
      pluginId: trace.pluginId,
      skillId: trace.skillId,
      constraint: trace.constraint,
      inertia: trace.inertia,
      stats: trace.stats,
      trajectory: AiTrajectoryTrace(runId: trace.trajectory.runId, nodes: nodes),
      promptRef: trace.promptRef,
      systemRef: trace.systemRef,
      answerRef: trace.answerRef,
    );
  }

  static String _redactSummary(AiTraceRedactor redactor, String summary) {
    var redacted = redactor.redact(summary);
    redacted = redacted.replaceAll(
      RegExp(r'Claim ID\s*:?\s*[A-Za-z0-9-]+', caseSensitive: false),
      'Claim ID [redacted]',
    );
    return redacted.replaceAll(RegExp(r'\b[A-Z]{2,}\d{3,}\b'), '[redacted:id]');
  }
}
