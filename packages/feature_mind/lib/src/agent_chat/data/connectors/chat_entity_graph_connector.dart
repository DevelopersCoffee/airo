import '../../../addons/graph_workflow/graph_workflow_coordinator.dart';
import '../../domain/models/agent_skill.dart';
import '../../domain/models/chat_entity_graph.dart';
import '../../domain/services/agent_connector.dart';
import '../../domain/services/chat_entity_graph_pending.dart';
import '../repositories/chat_entity_graph_session.dart';

class ChatEntityGraphConnector implements AgentConnector {
  ChatEntityGraphConnector({
    ChatEntityGraphSession? session,
    GraphWorkflowCoordinator? graphCoordinator,
  }) : _session = session ?? chatEntityGraphSession,
       _graphCoordinator = graphCoordinator;

  final ChatEntityGraphSession _session;
  final GraphWorkflowCoordinator? _graphCoordinator;

  @override
  String get name => 'query_entity_graph';

  @override
  Set<SkillCapability> get requiredCapabilities => const {
    SkillCapability.memoryRead,
  };

  @override
  Future<ConnectorResult> execute(Map<String, dynamic> arguments) async {
    final query = (arguments['query'] as String?)?.trim() ?? '';
    if (query.isEmpty) {
      return const ConnectorResult.error(
        code: 'missing_query',
        message: 'Entity graph queries require a non-empty query.',
      );
    }

    final graph = await _session.ensureLoaded();
    final intent = (arguments['intent'] as String?)?.trim().toLowerCase();
    final markdown = _formatMarkdown(
      graph: graph,
      query: query,
      pendingIntent: intent == 'pending',
    );
    return ConnectorResult(
      data: {
        'source': 'local_chat_entity_graph',
        'markdown': markdown,
        'node_count': graph.nodes.length,
        'edge_count': graph.edges.length,
      },
      message: markdown,
    );
  }

  String _formatMarkdown({
    required ChatEntityGraph graph,
    required String query,
    required bool pendingIntent,
  }) {
    final coordinator = _graphCoordinator;
    if (coordinator != null) {
      if (pendingIntent || coordinator.wantsPending(query)) {
        return coordinator.formatPending(graph: graph, query: query);
      }
    } else {
      final pendingFormatter = ChatEntityGraphPending();
      if (pendingIntent || pendingFormatter.wantsPending(query)) {
        return pendingFormatter.format(graph: graph, query: query);
      }
    }
    return formatGraphListing(graph: graph, query: query);
  }

  static String formatGraphListing({
    required ChatEntityGraph graph,
    required String query,
  }) {
    if (graph.nodes.isEmpty) {
      return 'I have no stored chat entities yet. I will extract them from what you type.';
    }

    final needle = _normalize(query);
    final matched = graph.nodes
        .where((node) {
          if (needle.isEmpty) return true;
          final haystack = _normalize(
            '${node.name} ${node.id} ${node.attributes}',
          );
          return haystack.contains(needle) ||
              needle
                  .split(' ')
                  .any((part) => part.length > 2 && haystack.contains(part));
        })
        .toList(growable: false);
    final nodes = matched.isEmpty ? graph.nodes : matched;
    final ids = nodes.map((node) => node.id).toSet();

    final buffer = StringBuffer('Chat entity graph')
      ..writeln()
      ..writeln();
    for (final node in nodes) {
      buffer.writeln('- ${node.name} (${node.type.name})');
      for (final edge in graph.edges) {
        if (edge.fromId != node.id && edge.toId != node.id) continue;
        if (!ids.contains(edge.fromId) && !ids.contains(edge.toId)) continue;
        final otherId = edge.fromId == node.id ? edge.toId : edge.fromId;
        final other = graph.nodeById(otherId);
        if (other == null) continue;
        final direction = edge.fromId == node.id ? '→' : '←';
        buffer.writeln('  $direction ${edge.predicate} ${other.name}');
      }
    }
    return buffer.toString().trimRight();
  }

  static String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}
