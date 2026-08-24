import 'package:core_ai/core_ai.dart';
import 'package:core_domain/core_domain.dart';

import '../../agent_chat/domain/models/chat_entity_graph.dart';
import '../../agent_chat/domain/models/entity_graph_bridge.dart';
import '../../agent_chat/domain/services/chat_entity_graph_pending.dart';

/// Graph-workflow adapter for the University Admission built-in add-on.
class UniversityAdmissionGraphAdapter implements GraphWorkflowAddonAdapter {
  UniversityAdmissionGraphAdapter({
    ChatEntityGraphPending? pending,
  }) : _pending = pending ?? ChatEntityGraphPending();

  static const addonId = 'university-admission-planner';
  static const templateId = 'university_admission_v1';
  static const subjectKind = 'admission_cycle';
  static const activeSubjectId = 'admission_cycle:active';

  static final _trackingIntentPattern = RegExp(
    r'\b(apply\w*|application|admission|track\w*|enroll\w*)\b',
    caseSensitive: false,
  );
  static final _infoOnlyPattern = RegExp(
    r'\bwhat\b.*\b(program|offer)\b',
    caseSensitive: false,
  );

  final ChatEntityGraphPending _pending;

  @override
  AddonIdentity get identity =>
      const AddonIdentity(id: AddonId(addonId), version: '1.0.0');

  @override
  bool accepts(GraphIngestContext input) {
    if (_infoOnlyPattern.hasMatch(input.text)) return false;
    if (!_hasTrackingIntent(input.text)) return false;
    return _hasInstitutionOrProgram(input.text) || _hasIntakeTerm(input.text);
  }

  @override
  Future<EntityGraphPatch> extract(GraphIngestContext input) async {
    if (!accepts(input)) return const EntityGraphPatch();

    final facts = _factsFromText(input.text);
    if (facts.isEmpty) return const EntityGraphPatch();

    final subjectId = _subjectIdFor(facts);
    final existing = input.graph.nodeById(subjectId);
    final mergedFacts = {
      ...existing?.attributes ?? const {},
      ...facts,
      'kind': subjectKind,
    };

    final nodes = <EntityGraphNode>[
      EntityGraphNode(
        id: subjectId,
        typeKey: 'identifier',
        name: 'Admission cycle',
        attributes: mergedFacts,
      ),
    ];
    final edges = <EntityGraphEdge>[];
    final institution = facts['University Shortlist'];
    if (institution != null) {
      final institutionId = _institutionNodeId(institution);
      nodes.add(
        EntityGraphNode(
          id: institutionId,
          typeKey: 'organization',
          name: institution,
          attributes: {'kind': 'university', 'role': 'university'},
        ),
      );
      edges.add(
        EntityGraphEdge(
          fromId: subjectId,
          toId: institutionId,
          predicate: 'relatedTo',
        ),
      );
    }

    return EntityGraphPatch(
      nodes: nodes,
      edges: edges,
      mentionedNodeIds: [subjectId],
    );
  }

  @override
  Iterable<WorkflowProjection> project(EntityGraph graph) {
    final chatGraph = ChatEntityGraphBridge.fromEntityGraph(graph);
    return graph.nodes
        .where((node) => node.attributes['kind'] == subjectKind)
        .map((node) {
          final facts = _factsForSubject(node);
          final offerable = _isOfferable(facts);
          return WorkflowProjection(
            identity: identity,
            subjectNodeId: node.id,
            destinationKind: 'lifetrack',
            templateId: templateId,
            templateVersion: '1',
            title: _titleFor(facts),
            factsByFieldId: facts,
            identityKey: node.id,
            offer: _offered(chatGraph, node.id)
                ? const OfferDecision(kind: OfferDecisionKind.alreadyOffered)
                : offerable
                ? const OfferDecision(kind: OfferDecisionKind.offerable)
                : const OfferDecision(
                    kind: OfferDecisionKind.notOfferable,
                    reason: 'missing_required_facts',
                  ),
          );
        });
  }

  @override
  PendingAssessment assessPending(
    EntityGraph graph,
    WorkflowProjection projection,
  ) {
    final chatGraph = ChatEntityGraphBridge.fromEntityGraph(graph);
    final node = graph.nodeById(projection.subjectNodeId);
    final facts = node == null
        ? projection.factsByFieldId
        : _factsForSubject(node);
    return PendingAssessment(
      identity: identity,
      subjectNodeId: projection.subjectNodeId,
      storedFacts: facts,
      missingRequired: _missingRequired(facts),
      missingOptional: const [],
      crossLinks: _pending.crossLinksFor(chatGraph, projection.subjectNodeId),
    );
  }

  bool _offered(ChatEntityGraph graph, String nodeId) =>
      graph.nodeById(nodeId)?.attributes['journey_offered'] == 'true';

  Map<String, String> _factsForSubject(EntityGraphNode node) {
    final facts = <String, String>{};
    for (final field in const [
      'University Shortlist',
      'Document Checklist',
      'Submitted Programs',
      'Visa or Enrollment Notes',
      'Intake Term',
    ]) {
      final value = node.attributes[field];
      if (value != null && value.trim().isNotEmpty) {
        facts[field] = value.trim();
      }
    }
    return facts;
  }

  Map<String, String> _factsFromText(String text) {
    final facts = <String, String>{};
    final institution = _institutionName(text);
    if (institution != null) facts['University Shortlist'] = institution;

    final intake = _intakeTerm(text);
    if (intake != null) facts['Intake Term'] = intake;

    if (_hasTrackingIntent(text) && institution != null) {
      facts['Submitted Programs'] = institution;
    }

    if (RegExp(r'\bvisa\b', caseSensitive: false).hasMatch(text)) {
      facts['Visa or Enrollment Notes'] = 'Visa step mentioned';
    }

    if (RegExp(r'\b(document|transcript|essay|recommendation)\b',
        caseSensitive: false).hasMatch(text)) {
      facts['Document Checklist'] = 'Documents mentioned';
    }

    return facts;
  }

  bool _isOfferable(Map<String, String> facts) {
    final hasInstitution =
        facts['University Shortlist']?.trim().isNotEmpty ?? false;
    final hasIntake = facts['Intake Term']?.trim().isNotEmpty ?? false;
    final hasProgram =
        facts['Submitted Programs']?.trim().isNotEmpty ?? false;
    return hasInstitution || hasIntake || hasProgram;
  }

  List<String> _missingRequired(Map<String, String> facts) {
    if (_isOfferable(facts)) return const [];
    return ['University Shortlist'];
  }

  String _titleFor(Map<String, String> facts) {
    final institution = facts['University Shortlist'];
    final intake = facts['Intake Term'];
    if (institution != null && intake != null) {
      return '$institution — $intake';
    }
    if (institution != null) return institution;
    if (intake != null) return 'Admission — $intake';
    return 'University admission';
  }

  String _subjectIdFor(Map<String, String> facts) {
    final intake = facts['Intake Term'];
    if (intake == null) return activeSubjectId;
    final normalized = intake
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .trim();
    return 'admission_cycle:$normalized';
  }

  bool _hasTrackingIntent(String text) => _trackingIntentPattern.hasMatch(text);

  bool _hasInstitutionOrProgram(String text) =>
      _institutionName(text) != null ||
      RegExp(r'\b(program|degree|course)\b', caseSensitive: false)
          .hasMatch(text);

  bool _hasIntakeTerm(String text) => _intakeTerm(text) != null;

  String? _institutionName(String text) {
    final applying = RegExp(
      r'\b(?:applying to|application to|admission to|track(?:ing)?\s+for)\s+([A-Za-z][A-Za-z0-9.& -]{1,40})',
      caseSensitive: false,
    ).firstMatch(text);
    if (applying != null) {
      final candidate = applying.group(1)?.trim();
      if (candidate != null && candidate.isNotEmpty) {
        return _cleanInstitution(candidate);
      }
    }

    final acronym = RegExp(r'\b(MIT|UCLA|NYU|CMU|ETH)\b').firstMatch(text);
    if (acronym != null) return acronym.group(1);

    return null;
  }

  String? _intakeTerm(String text) {
    final match = RegExp(
      r'\b((?:fall|spring|summer|winter)\s+\d{4})\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (match != null) return match.group(1);

    final yearOnly = RegExp(r'\b(20\d{2})\b').firstMatch(text);
    return yearOnly?.group(1);
  }

  String _cleanInstitution(String value) {
    return value
        .replaceAll(RegExp(r'\s+for\s+.*$', caseSensitive: false), '')
        .trim();
  }

  String _institutionNodeId(String institution) {
    final normalized = institution
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .trim();
    return 'university:$normalized';
  }
}
