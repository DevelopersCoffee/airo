import 'package:core_domain/core_domain.dart';

import '../../../provenance/domain/models/extracted_entity.dart';
import '../models/chat_entity_graph.dart';
import 'chat_entity_graph_projector.dart';

/// Deterministic "what's pending" answer from stored chat entities.
///
/// Does not invent tasks. It reports what is on the graph and which usual
/// claim fields are still absent, including cross-links (hospital, policy)
/// so a bill can sit on more than one journey at once.
class ChatEntityGraphPending {
  const ChatEntityGraphPending();

  static const _projector = ChatEntityGraphProjector();

  bool wantsPending(String query) {
    final lower = query.toLowerCase();
    final asks =
        lower.contains('pending') ||
        lower.contains('status') ||
        lower.contains('missing') ||
        lower.contains('next step') ||
        lower.contains("what's next") ||
        lower.contains('whats next');
    if (!asks) return false;
    return lower.contains('claim') ||
        lower.contains('insurance') ||
        lower.contains('insurer') ||
        lower.contains('document') ||
        lower.contains('reimbursement') ||
        lower.contains('policy');
  }

  String format({required ChatEntityGraph graph, required String query}) {
    if (graph.nodes.isEmpty) {
      return 'I have no stored claim entities yet. Paste the insurer, claim ID, '
          'and whether documents were received — I will extract them from this chat.';
    }

    final journeys = _projector.project(graph);
    if (journeys.isEmpty) {
      final buffer = StringBuffer('Chat entity graph')
        ..writeln()
        ..writeln();
      for (final node in graph.nodes) {
        buffer.writeln('- ${node.name} (${node.type.name})');
      }
      return buffer.toString().trimRight();
    }

    final needle = query.toLowerCase();
    final matched = journeys
        .where((journey) {
          if (needle.trim().isEmpty) return true;
          return needle.contains(
                (journey.facts['Claim ID'] ?? '').toLowerCase(),
              ) ||
              needle.contains((journey.facts['Insurer'] ?? '').toLowerCase()) ||
              needle.contains('claim') ||
              needle.contains('insurance');
        })
        .toList(growable: false);
    final selected = matched.isEmpty ? journeys : matched;

    final buffer = StringBuffer();
    for (final journey in selected) {
      buffer.writeln('Stored for ${journey.title}');
      buffer.writeln();
      for (final entry in journey.facts.entries) {
        if (entry.key == LifeTrackFactPatch.documentsReceivedKey) {
          buffer.writeln('- Documents: ${entry.value}');
          continue;
        }
        if (entry.key.startsWith('_')) continue;
        buffer.writeln('- ${entry.key}: ${entry.value}');
      }

      final missing = _missing(journey);
      buffer.writeln();
      if (missing.isEmpty) {
        buffer.writeln('No usual claim fields are missing from the graph.');
      } else {
        buffer.writeln('Not on the graph yet');
        for (final item in missing) {
          buffer.writeln('- $item');
        }
      }

      final linked = _crossLinks(graph, journey.subjectNodeId);
      if (linked.isNotEmpty) {
        buffer.writeln();
        buffer.writeln('Also linked');
        for (final line in linked) {
          buffer.writeln('- $line');
        }
      }
      buffer.writeln();
    }
    return buffer.toString().trimRight();
  }

  List<String> _missing(ProjectedChatJourney journey) {
    final missing = <String>[];
    if (!journey.facts.containsKey('Insurer')) missing.add('Insurer');
    if (!journey.facts.containsKey('Broker / Intermediary')) {
      missing.add('Broker / intermediary');
    }
    if (!journey.facts.containsKey('Policy Number')) {
      missing.add('Policy number');
    }
    if (!journey.facts.containsKey('Follow-up Log')) {
      missing.add('Follow-up log');
    }
    final docs = journey.facts[LifeTrackFactPatch.documentsReceivedKey];
    if (docs == null || docs.trim().isEmpty) {
      missing.add('Claim documents (not marked received)');
    }
    if (!journey.facts.containsKey('Settlement Notes')) {
      missing.add('Settlement outcome');
    }
    return missing;
  }

  List<String> _crossLinks(ChatEntityGraph graph, String claimId) {
    final lines = <String>[];
    for (final edge in graph.edgesFor(claimId)) {
      if (edge.predicate != ChatEntityRelation.relatedTo) continue;
      final otherId = edge.fromId == claimId ? edge.toId : edge.fromId;
      final other = graph.nodeById(otherId);
      if (other == null) continue;
      if (other.type == EntityType.identifier) continue;
      lines.add('${other.name} (${other.type.name})');
    }
    return lines;
  }
}
