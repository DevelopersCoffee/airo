import 'package:core_domain/core_domain.dart';

import '../../../provenance/domain/models/extracted_entity.dart';
import '../models/chat_entity_graph.dart';
import 'chat_entity_graph_projector.dart';
import 'projected_chat_journey.dart';

/// Deterministic "what's pending" answer from stored chat entities.
///
/// Does not invent tasks. It reports what is on the graph and which usual
/// template fields are still absent, including cross-links (hospital, policy)
/// so a bill can sit on more than one journey at once.
class ChatEntityGraphPending {
  const ChatEntityGraphPending();

  static const _projector = ChatEntityGraphProjector();

  static const _hospitalUsual = [
    'Required Tests List',
    'Insurance Authorization Reference',
    'Hospital Checklist',
    'Recovery Notes',
  ];

  static const _propertyUsual = [
    'RERA Registration Number',
    'Builder Track Record Notes',
    'Your Target Floor',
    'Promised Amenities List',
  ];

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
    return _looksInsurance(lower) ||
        _looksHospital(lower) ||
        _looksProperty(lower);
  }

  String format({required ChatEntityGraph graph, required String query}) {
    if (graph.nodes.isEmpty) {
      return _emptyMessage(query);
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
        .where((journey) => _matchesQuery(journey, needle))
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
        buffer.writeln(
          'No usual ${_usualName(journey.templateId)} fields are missing from the graph.',
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

  bool _matchesQuery(ProjectedChatJourney journey, String needle) {
    if (needle.trim().isEmpty) return true;
    switch (journey.templateId) {
      case 'insurance_claim_v1':
        return _looksInsurance(needle) ||
            _containsFact(needle, journey, 'Claim ID') ||
            _containsFact(needle, journey, 'Insurer');
      case 'medical_surgery_v1':
        return _looksHospital(needle) ||
            _containsFact(needle, journey, 'Hospital');
      case 'real_estate_under_construction_v1':
        return _looksProperty(needle) ||
            _containsFact(needle, journey, 'RERA Registration Number') ||
            _containsFact(needle, journey, 'Project');
      default:
        return true;
    }
  }

  bool _containsFact(String needle, ProjectedChatJourney journey, String key) {
    final value = (journey.facts[key] ?? '').toLowerCase();
    return value.isNotEmpty && needle.contains(value);
  }

  bool _looksInsurance(String lower) =>
      lower.contains('claim') ||
      lower.contains('insurance') ||
      lower.contains('insurer') ||
      lower.contains('document') ||
      lower.contains('reimbursement') ||
      lower.contains('policy');

  bool _looksHospital(String lower) =>
      lower.contains('hospital') ||
      lower.contains('surgery') ||
      lower.contains('recovery') ||
      lower.contains('pre-op') ||
      lower.contains('operation') ||
      lower.contains('medical');

  bool _looksProperty(String lower) =>
      lower.contains('flat') ||
      lower.contains('rera') ||
      lower.contains('property') ||
      lower.contains('builder') ||
      lower.contains('tower') ||
      lower.contains('apartment');

  String _emptyMessage(String query) {
    final lower = query.toLowerCase();
    if (_looksHospital(lower)) {
      return 'I have no stored hospital or surgery entities yet. Paste the '
          'hospital, surgery date, required tests, and authorization reference '
          '— I will extract them from this chat.';
    }
    if (_looksProperty(lower)) {
      return 'I have no stored property entities yet. Paste the RERA number, '
          'builder, project, and floor — I will extract them from this chat.';
    }
    return 'I have no stored claim entities yet. Paste the insurer, claim ID, '
        'and whether documents were received — I will extract them from this chat.';
  }

  String _usualName(String templateId) {
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
          for (final label in _hospitalUsual)
            if (!journey.facts.containsKey(label)) label,
        ];
      case 'real_estate_under_construction_v1':
        return [
          for (final label in _propertyUsual)
            if (!journey.facts.containsKey(label)) label,
        ];
      default:
        return _missingClaim(journey);
    }
  }

  List<String> _missingClaim(ProjectedChatJourney journey) {
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

  bool looksInsurance(String text) => _looksInsurance(text.toLowerCase());

  bool looksHospital(String text) => _looksHospital(text.toLowerCase());

  bool looksProperty(String text) => _looksProperty(text.toLowerCase());

  List<String> missingFieldsFor(ProjectedChatJourney journey) => _missing(journey);

  List<String> crossLinksFor(ChatEntityGraph graph, String subjectNodeId) =>
      _crossLinks(graph, subjectNodeId);
}
