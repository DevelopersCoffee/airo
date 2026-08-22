import 'package:core_domain/core_domain.dart';

import '../../../provenance/domain/models/extracted_entity.dart';
import '../models/chat_entity_graph.dart';
import 'chat_entity_graph_projector.dart';

/// Deterministic "what's pending" answer from stored chat entities.
///
/// Does not invent tasks. It reports what is on the graph and which usual
/// template fields are still absent, including cross-links (hospital, policy)
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
        lower.contains('policy') ||
        lower.contains('hospital') ||
        lower.contains('surgery') ||
        lower.contains('recovery') ||
        lower.contains('flat') ||
        lower.contains('rera') ||
        lower.contains('property');
  }

  String format({required ChatEntityGraph graph, required String query}) {
    if (graph.nodes.isEmpty) {
      return 'I have no stored chat entities yet. Paste the details you have '
          '— I will extract them from this chat.';
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

    final selected = _select(journeys, query);
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
        buffer.writeln(
          'No usual ${_usualLabel(journey.templateId)} fields are missing '
          'from the graph.',
        );
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

  List<ProjectedChatJourney> _select(
    List<ProjectedChatJourney> journeys,
    String query,
  ) {
    final needle = query.toLowerCase();
    final templateId = _templateForQuery(needle);
    final matched = journeys
        .where((journey) {
          if (templateId != null) return journey.templateId == templateId;
          return needle.contains(
                (journey.facts['Claim ID'] ?? '').toLowerCase(),
              ) ||
              needle.contains((journey.facts['Insurer'] ?? '').toLowerCase()) ||
              needle.contains(
                (journey.facts['Hospital'] ?? '').toLowerCase(),
              ) ||
              needle.contains(
                (journey.facts['RERA Registration Number'] ?? '').toLowerCase(),
              );
        })
        .toList(growable: false);
    return matched.isEmpty ? journeys : matched;
  }

  String? _templateForQuery(String needle) {
    if (needle.contains('hospital') ||
        needle.contains('surgery') ||
        needle.contains('recovery')) {
      return 'medical_surgery_v1';
    }
    if (needle.contains('flat') ||
        needle.contains('rera') ||
        needle.contains('property')) {
      return 'real_estate_under_construction_v1';
    }
    if (needle.contains('claim') ||
        needle.contains('insurance') ||
        needle.contains('insurer') ||
        needle.contains('reimbursement') ||
        needle.contains('policy')) {
      return 'insurance_claim_v1';
    }
    return null;
  }

  String _usualLabel(String templateId) {
    switch (templateId) {
      case 'medical_surgery_v1':
        return 'hospital';
      case 'real_estate_under_construction_v1':
        return 'property';
      default:
        return 'claim';
    }
  }

  List<String> _missing(ProjectedChatJourney journey) {
    switch (journey.templateId) {
      case 'medical_surgery_v1':
        return [
          if (!journey.facts.containsKey('Required Tests List'))
            'Required Tests List',
          if (!journey.facts.containsKey('Insurance Authorization Reference'))
            'Insurance Authorization Reference',
          if (!journey.facts.containsKey('Hospital Checklist'))
            'Hospital Checklist',
          if (!journey.facts.containsKey('Recovery Notes')) 'Recovery Notes',
        ];
      case 'real_estate_under_construction_v1':
        return [
          if (!journey.facts.containsKey('RERA Registration Number'))
            'RERA Registration Number',
          if (!journey.facts.containsKey('Builder Track Record Notes'))
            'Builder Track Record Notes',
          if (!journey.facts.containsKey('Your Target Floor'))
            'Your Target Floor',
          if (!journey.facts.containsKey('Promised Amenities List'))
            'Promised Amenities List',
        ];
      default:
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
  }

  List<String> _crossLinks(ChatEntityGraph graph, String subjectId) {
    final lines = <String>[];
    for (final edge in graph.edgesFor(subjectId)) {
      if (edge.predicate != ChatEntityRelation.relatedTo) continue;
      final otherId = edge.fromId == subjectId ? edge.toId : edge.fromId;
      final other = graph.nodeById(otherId);
      if (other == null) continue;
      if (other.type == EntityType.identifier) continue;
      lines.add('${other.name} (${other.type.name})');
    }
    return lines;
  }
}
