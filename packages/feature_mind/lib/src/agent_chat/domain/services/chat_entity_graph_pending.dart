import 'package:core_domain/core_domain.dart';

import '../../../addons/workflow/addon_workflow_policy.dart';
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
  ChatEntityGraphPending({AddonWorkflowPolicy? policy})
    : _policy = policy ?? AddonWorkflowPolicy.defaults();

  final AddonWorkflowPolicy _policy;
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
    for (final policy in _policy.templatePolicies) {
      if (_policy.queryMatchesTemplate(lower, policy.templateId)) return true;
    }
    return false;
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
      final missing = missingFieldsFor(journey);
      if (missing.isNotEmpty) {
        buffer.writeln();
        for (final line in missing) {
          buffer.writeln('Not on the graph yet: $line');
        }
      }
      final crossLinks = crossLinksFor(graph, journey.subjectNodeId);
      if (crossLinks.isNotEmpty) {
        buffer.writeln();
        buffer.writeln('Also linked in this chat:');
        for (final line in crossLinks) {
          buffer.writeln('- $line');
        }
      }
      buffer.writeln();
    }
    return buffer.toString().trimRight();
  }

  bool _matchesQuery(ProjectedChatJourney journey, String needle) {
    if (needle.trim().isEmpty) return true;
    final policy = _policy.forTemplate(journey.templateId);
    if (policy != null &&
        _policy.queryMatchesTemplate(needle, journey.templateId)) {
      return true;
    }
    return journey.facts.entries.any(
      (entry) =>
          entry.value.isNotEmpty && needle.contains(entry.value.toLowerCase()),
    );
  }

  String _emptyMessage(String query) {
    final lower = query.toLowerCase();
    for (final policy in _policy.templatePolicies) {
      if (_policy.queryMatchesTemplate(lower, policy.templateId) &&
          policy.pendingEmptyMessage.trim().isNotEmpty) {
        return policy.pendingEmptyMessage.trim();
      }
    }
    return 'I have no stored workflow entities yet for that question.';
  }

  List<String> missingFieldsFor(ProjectedChatJourney journey) {
    final policy = _policy.forTemplate(journey.templateId);
    if (policy == null || policy.pendingUsualOptionalFields.isEmpty) {
      return const [];
    }
    final missing = <String>[
      for (final label in policy.pendingUsualOptionalFields)
        if (!journey.facts.containsKey(label)) label,
    ];
    if (journey.templateId == 'insurance_claim_v1') {
      final docs = journey.facts[LifeTrackFactPatch.documentsReceivedKey];
      if (docs == null || docs.trim().isEmpty) {
        missing.add('Claim documents (not marked received)');
      }
    }
    return missing;
  }

  List<String> crossLinksFor(ChatEntityGraph graph, String claimId) {
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

  bool looksInsurance(String text) =>
      _policy.queryMatchesTemplate(text.toLowerCase(), 'insurance_claim_v1');

  bool looksHospital(String text) =>
      _policy.queryMatchesTemplate(text.toLowerCase(), 'medical_surgery_v1');

  bool looksProperty(String text) =>
      _policy.queryMatchesTemplate(
        text.toLowerCase(),
        'real_estate_under_construction_v1',
      );
}
