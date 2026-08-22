import 'package:core_ai/core_ai.dart';
import 'package:core_domain/core_domain.dart';

import '../../agent_chat/domain/models/chat_entity_graph.dart';
import '../../agent_chat/domain/models/entity_graph_bridge.dart';
import '../../agent_chat/domain/services/chat_entity_graph_pending.dart';

/// Graph-workflow adapter for the Car Purchase built-in add-on.
class CarPurchaseGraphAdapter implements GraphWorkflowAddonAdapter {
  CarPurchaseGraphAdapter({
    ChatEntityGraphPending pending = const ChatEntityGraphPending(),
  }) : _pending = pending;

  static const addonId = 'car-purchase-planner';
  static const templateId = 'car_purchase_v1';
  static const subjectKind = 'car_purchase';
  static const activeSubjectId = 'car_purchase:active';

  static const _vehicleFields = ['Shortlisted Cars', 'Test Drive Notes'];
  static const _decisionFields = [
    'Budget Range',
    'Loan Offers',
    'Parking Plan',
  ];

  final ChatEntityGraphPending _pending;

  @override
  AddonIdentity get identity =>
      const AddonIdentity(id: AddonId(addonId), version: '1.0.0');

  @override
  bool accepts(GraphIngestContext input) {
    if (_isGenericNeedOnly(input.text)) return false;
    if (!_mentionsVehicleDomain(input.text)) return false;
    return _hasVehicleSignal(input.text) || _hasDecisionSignal(input.text);
  }

  @override
  Future<EntityGraphPatch> extract(GraphIngestContext input) async {
    if (!accepts(input)) return const EntityGraphPatch();

    final facts = _factsFromText(input.text);
    if (facts.isEmpty) return const EntityGraphPatch();

    final existing = input.graph.nodeById(activeSubjectId);
    final mergedFacts = {
      ...existing?.attributes ?? const {},
      ...facts,
    };

    final nodes = <EntityGraphNode>[
      EntityGraphNode(
        id: activeSubjectId,
        typeKey: 'identifier',
        name: 'Car purchase',
        attributes: {
          'kind': subjectKind,
          ...mergedFacts,
        },
      ),
    ];
    final edges = <EntityGraphEdge>[];
    final vehicle = facts['Shortlisted Cars'];
    if (vehicle != null) {
      final vehicleId = _vehicleNodeId(vehicle);
      nodes.add(
        EntityGraphNode(
          id: vehicleId,
          typeKey: 'term',
          name: vehicle,
          attributes: {'kind': 'vehicle_candidate'},
        ),
      );
      edges.add(
        EntityGraphEdge(
          fromId: activeSubjectId,
          toId: vehicleId,
          predicate: 'relatedTo',
        ),
      );
    }

    return EntityGraphPatch(
      nodes: nodes,
      edges: edges,
      mentionedNodeIds: [activeSubjectId],
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
    for (final field in [..._vehicleFields, ..._decisionFields]) {
      final value = node.attributes[field];
      if (value != null && value.trim().isNotEmpty) {
        facts[field] = value.trim();
      }
    }
    return facts;
  }

  Map<String, String> _factsFromText(String text) {
    final facts = <String, String>{};
    final vehicle = _vehicleName(text);
    if (vehicle != null) facts['Shortlisted Cars'] = vehicle;

    final budget = _firstMatch(
      text,
      RegExp(
        r'(?:budget|price range)\s*(?:is|of|around|about)?\s*([\d.,]+\s*(?:k|lakh|lac|cr|million)?)',
        caseSensitive: false,
      ),
    );
    if (budget != null) facts['Budget Range'] = budget;

    final parking = _firstMatch(
      text,
      RegExp(r'parking\s+(?:plan|slot|space)\s*(?:is|:)?\s*([^.;\n]+)',
        caseSensitive: false),
    );
    if (parking != null) facts['Parking Plan'] = parking.trim();

    if (RegExp(r'test drive', caseSensitive: false).hasMatch(text)) {
      facts['Test Drive Notes'] = 'Test drive mentioned';
    }

    final loan = _firstMatch(
      text,
      RegExp(r'loan\s+(?:offer|pre-approval|approval)\s*(?:from|at)?\s*([^.;\n]+)',
        caseSensitive: false),
    );
    if (loan != null) facts['Loan Offers'] = loan.trim();

    return facts;
  }

  bool _isOfferable(Map<String, String> facts) {
    final hasVehicle = _vehicleFields.any(
      (field) => facts[field]?.trim().isNotEmpty ?? false,
    );
    final hasDecision = _decisionFields.any(
      (field) => facts[field]?.trim().isNotEmpty ?? false,
    );
    return hasVehicle && hasDecision;
  }

  List<String> _missingRequired(Map<String, String> facts) {
    if (_isOfferable(facts)) return const [];
    return ['Shortlisted Cars', 'Budget Range'];
  }

  String _titleFor(Map<String, String> facts) {
    final vehicle = facts['Shortlisted Cars'];
    if (vehicle != null) return 'Car purchase — $vehicle';
    return 'Car purchase';
  }

  bool _mentionsVehicleDomain(String text) {
    final lower = text.toLowerCase();
    return lower.contains('car') ||
        lower.contains('vehicle') ||
        lower.contains('automobile') ||
        lower.contains('auto') ||
        lower.contains('test drive') ||
        lower.contains('parking') ||
        lower.contains('loan');
  }

  bool _hasVehicleSignal(String text) =>
      _vehicleName(text) != null ||
      RegExp(r'\b(make|model|suv|sedan|hatchback)\b', caseSensitive: false)
          .hasMatch(text);

  bool _hasDecisionSignal(String text) {
    final lower = text.toLowerCase();
    return lower.contains('budget') ||
        lower.contains('parking') ||
        lower.contains('test drive') ||
        lower.contains('loan') ||
        lower.contains('financ');
  }

  bool _isGenericNeedOnly(String text) {
    final normalized = text.trim().toLowerCase();
    return RegExp(r'^i need a car[.!]?$').hasMatch(normalized) ||
        RegExp(r'^need a car[.!]?$').hasMatch(normalized);
  }

  String? _vehicleName(String text) {
    final patterns = [
      RegExp(
        r'\b(?:buying|buy|considering|shortlisted|looking at|test drive(?: for)?)\s+(?:a\s+)?([A-Za-z][A-Za-z0-9 -]{2,40})',
        caseSensitive: false,
      ),
      RegExp(
        r'\b([A-Za-z]{2,15}\s+[A-Za-z0-9]{2,20}(?:\s+\d{4})?)\b',
      ),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match == null) continue;
      final candidate = match.group(1)?.trim();
      if (candidate == null || candidate.isEmpty) continue;
      if (_isNoiseToken(candidate)) continue;
      return candidate;
    }
    return null;
  }

  bool _isNoiseToken(String value) {
    final lower = value.toLowerCase();
    return lower == 'car' ||
        lower == 'vehicle' ||
        lower == 'new car' ||
        lower == 'a car';
  }

  String _vehicleNodeId(String vehicle) {
    final normalized = vehicle
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .trim();
    return 'vehicle:$normalized';
  }

  String? _firstMatch(String text, RegExp pattern) {
    final match = pattern.firstMatch(text);
    if (match == null) return null;
    final group = match.groupCount >= 1 ? match.group(1) : match.group(0);
    if (group == null || group.trim().isEmpty) return null;
    return group.trim();
  }
}
