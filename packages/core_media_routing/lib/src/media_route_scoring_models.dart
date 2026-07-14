import 'package:equatable/equatable.dart';

import 'media_routing_models.dart';

const String kAiroMediaRouteScoringSchemaVersion = '1.0.0';

enum AiroMediaRouteScoreComponentId {
  routePriority('route_priority'),
  health('health'),
  bandwidth('bandwidth'),
  latency('latency'),
  battery('battery'),
  thermal('thermal'),
  reliability('reliability'),
  userPreference('user_preference'),
  phoneProxyPenalty('phone_proxy_penalty'),
  blockerPenalty('blocker_penalty');

  const AiroMediaRouteScoreComponentId(this.stableId);

  final String stableId;
}

enum AiroMediaRouteDecisionReasonCode {
  selectedHighestScore('selected_highest_score'),
  selectedByStableTieBreak('selected_by_stable_tie_break'),
  rejectedByPreflight('rejected_by_preflight'),
  directRoutePreferred('direct_route_preferred'),
  phoneProxyPenalized('phone_proxy_penalized'),
  lowBatteryPenalty('low_battery_penalty'),
  thermalPenalty('thermal_penalty'),
  noEligibleRoute('no_eligible_route');

  const AiroMediaRouteDecisionReasonCode(this.stableId);

  final String stableId;
}

class AiroMediaRouteScoreSignals extends Equatable {
  const AiroMediaRouteScoreSignals({
    this.health = 50,
    this.bandwidth = 50,
    this.latency = 50,
    this.battery = 50,
    this.thermal = 50,
    this.reliability = 50,
    this.userPreference = 50,
  });

  final int health;
  final int bandwidth;
  final int latency;
  final int battery;
  final int thermal;
  final int reliability;
  final int userPreference;

  int normalizedHealth() => _clamp(health);
  int normalizedBandwidth() => _clamp(bandwidth);
  int normalizedLatency() => _clamp(latency);
  int normalizedBattery() => _clamp(battery);
  int normalizedThermal() => _clamp(thermal);
  int normalizedReliability() => _clamp(reliability);
  int normalizedUserPreference() => _clamp(userPreference);

  static int _clamp(int value) {
    if (value < 0) return 0;
    if (value > 100) return 100;
    return value;
  }

  @override
  List<Object?> get props => [
    health,
    bandwidth,
    latency,
    battery,
    thermal,
    reliability,
    userPreference,
  ];
}

class AiroMediaRouteScoreComponent extends Equatable {
  const AiroMediaRouteScoreComponent({
    required this.componentId,
    required this.value,
    required this.weight,
    required this.weightedValue,
  });

  final AiroMediaRouteScoreComponentId componentId;
  final int value;
  final int weight;
  final int weightedValue;

  @override
  List<Object?> get props => [componentId, value, weight, weightedValue];
}

class AiroMediaRouteScoreBreakdown extends Equatable {
  AiroMediaRouteScoreBreakdown({
    required this.candidateId,
    required this.routeKind,
    required this.eligible,
    required this.totalScore,
    required Iterable<AiroMediaRouteBlockerCode> blockers,
    required Iterable<AiroMediaRouteScoreComponent> components,
    required Iterable<AiroMediaRouteDecisionReasonCode> reasonCodes,
    this.schemaVersion = kAiroMediaRouteScoringSchemaVersion,
  }) : blockers = List.unmodifiable(blockers),
       components = List.unmodifiable(components),
       reasonCodes = List.unmodifiable(reasonCodes);

  final String schemaVersion;
  final String candidateId;
  final AiroMediaRouteKind routeKind;
  final bool eligible;
  final int totalScore;
  final List<AiroMediaRouteBlockerCode> blockers;
  final List<AiroMediaRouteScoreComponent> components;
  final List<AiroMediaRouteDecisionReasonCode> reasonCodes;

  @override
  List<Object?> get props => [
    schemaVersion,
    candidateId,
    routeKind,
    eligible,
    totalScore,
    blockers,
    components,
    reasonCodes,
  ];
}

class AiroMediaRouteDecisionLogEntry extends Equatable {
  AiroMediaRouteDecisionLogEntry({
    required this.candidateId,
    required this.routeKind,
    required this.eligible,
    required this.selected,
    required this.totalScore,
    required Iterable<AiroMediaRouteBlockerCode> blockers,
    required Iterable<AiroMediaRouteDecisionReasonCode> reasonCodes,
  }) : blockers = List.unmodifiable(blockers),
       reasonCodes = List.unmodifiable(reasonCodes);

  final String candidateId;
  final AiroMediaRouteKind routeKind;
  final bool eligible;
  final bool selected;
  final int totalScore;
  final List<AiroMediaRouteBlockerCode> blockers;
  final List<AiroMediaRouteDecisionReasonCode> reasonCodes;

  @override
  String toString() {
    return 'AiroMediaRouteDecisionLogEntry('
        'candidateId: $candidateId, '
        'routeKind: ${routeKind.stableId}, '
        'eligible: $eligible, '
        'selected: $selected, '
        'totalScore: $totalScore, '
        'blockers: ${blockers.map((code) => code.stableId).toList()}, '
        'reasonCodes: ${reasonCodes.map((code) => code.stableId).toList()}'
        ')';
  }

  @override
  List<Object?> get props => [
    candidateId,
    routeKind,
    eligible,
    selected,
    totalScore,
    blockers,
    reasonCodes,
  ];
}

class AiroMediaRouteDecisionLog extends Equatable {
  AiroMediaRouteDecisionLog({
    required this.requestId,
    required this.generatedAt,
    required this.selectedCandidateId,
    required Iterable<AiroMediaRouteDecisionLogEntry> entries,
    this.schemaVersion = kAiroMediaRouteScoringSchemaVersion,
  }) : entries = List.unmodifiable(entries);

  final String schemaVersion;
  final String requestId;
  final DateTime generatedAt;
  final String? selectedCandidateId;
  final List<AiroMediaRouteDecisionLogEntry> entries;

  @override
  String toString() {
    return 'AiroMediaRouteDecisionLog('
        'requestId: $requestId, '
        'generatedAt: $generatedAt, '
        'selectedCandidateId: $selectedCandidateId, '
        'entries: $entries'
        ')';
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    requestId,
    generatedAt,
    selectedCandidateId,
    entries,
  ];
}

class AiroScoredMediaRouteDecision extends Equatable {
  AiroScoredMediaRouteDecision({
    required this.requestId,
    required Iterable<AiroMediaRouteScoreBreakdown> scores,
    required this.selected,
    required this.decisionLog,
    this.schemaVersion = kAiroMediaRouteScoringSchemaVersion,
  }) : scores = List.unmodifiable(scores);

  final String schemaVersion;
  final String requestId;
  final List<AiroMediaRouteScoreBreakdown> scores;
  final AiroMediaRouteScoreBreakdown? selected;
  final AiroMediaRouteDecisionLog decisionLog;

  bool get hasRoute => selected != null;

  @override
  List<Object?> get props => [
    schemaVersion,
    requestId,
    scores,
    selected,
    decisionLog,
  ];
}

class AiroMediaRouteScoringPolicy {
  const AiroMediaRouteScoringPolicy();

  AiroScoredMediaRouteDecision scoreDecision({
    required AiroMediaRouteDecision decision,
    required Map<String, AiroMediaRouteScoreSignals> signalsByCandidateId,
    required DateTime generatedAt,
  }) {
    final scores = [
      for (final evaluation in decision.evaluations)
        _scoreEvaluation(
          evaluation: evaluation,
          signals:
              signalsByCandidateId[evaluation.candidate.candidateId] ??
              const AiroMediaRouteScoreSignals(),
        ),
    ];

    final eligibleScores = scores.where((score) => score.eligible).toList()
      ..sort(_compareScores);
    final selected = eligibleScores.isEmpty ? null : eligibleScores.first;
    final selectedWithReason = selected == null
        ? null
        : _withSelectionReason(selected, eligibleScores);
    final noEligibleRoute = eligibleScores.isEmpty;
    final finalScores = [
      for (final score in scores)
        if (score.candidateId == selectedWithReason?.candidateId)
          selectedWithReason!
        else if (noEligibleRoute)
          _withNoEligibleRouteReason(score)
        else
          score,
    ];

    final log = AiroMediaRouteDecisionLog(
      requestId: decision.requestId,
      generatedAt: generatedAt,
      selectedCandidateId: selectedWithReason?.candidateId,
      entries: [
        for (final score in finalScores)
          AiroMediaRouteDecisionLogEntry(
            candidateId: score.candidateId,
            routeKind: score.routeKind,
            eligible: score.eligible,
            selected: score.candidateId == selectedWithReason?.candidateId,
            totalScore: score.totalScore,
            blockers: score.blockers,
            reasonCodes: score.reasonCodes,
          ),
      ],
    );

    return AiroScoredMediaRouteDecision(
      requestId: decision.requestId,
      scores: finalScores,
      selected: selectedWithReason,
      decisionLog: log,
    );
  }

  AiroMediaRouteScoreBreakdown _scoreEvaluation({
    required AiroMediaRouteEvaluation evaluation,
    required AiroMediaRouteScoreSignals signals,
  }) {
    final candidate = evaluation.candidate;
    final components = [
      _component(
        AiroMediaRouteScoreComponentId.routePriority,
        _routePriority(candidate.kind),
        6,
      ),
      _component(
        AiroMediaRouteScoreComponentId.health,
        signals.normalizedHealth(),
        3,
      ),
      _component(
        AiroMediaRouteScoreComponentId.bandwidth,
        signals.normalizedBandwidth(),
        3,
      ),
      _component(
        AiroMediaRouteScoreComponentId.latency,
        signals.normalizedLatency(),
        2,
      ),
      _component(
        AiroMediaRouteScoreComponentId.battery,
        signals.normalizedBattery(),
        2,
      ),
      _component(
        AiroMediaRouteScoreComponentId.thermal,
        signals.normalizedThermal(),
        2,
      ),
      _component(
        AiroMediaRouteScoreComponentId.reliability,
        signals.normalizedReliability(),
        3,
      ),
      _component(
        AiroMediaRouteScoreComponentId.userPreference,
        signals.normalizedUserPreference(),
        1,
      ),
      if (candidate.kind.isPhoneProxy)
        _component(AiroMediaRouteScoreComponentId.phoneProxyPenalty, -80, 1),
      if (!evaluation.eligible)
        _component(AiroMediaRouteScoreComponentId.blockerPenalty, -1000, 1),
    ];
    final reasons = <AiroMediaRouteDecisionReasonCode>[
      if (!evaluation.eligible)
        AiroMediaRouteDecisionReasonCode.rejectedByPreflight,
      if (!candidate.kind.isPhoneProxy &&
          candidate.kind != AiroMediaRouteKind.cloudCommandOnly)
        AiroMediaRouteDecisionReasonCode.directRoutePreferred,
      if (candidate.kind.isPhoneProxy)
        AiroMediaRouteDecisionReasonCode.phoneProxyPenalized,
      if (signals.normalizedBattery() < 20)
        AiroMediaRouteDecisionReasonCode.lowBatteryPenalty,
      if (signals.normalizedThermal() < 30)
        AiroMediaRouteDecisionReasonCode.thermalPenalty,
    ];

    return AiroMediaRouteScoreBreakdown(
      candidateId: candidate.candidateId,
      routeKind: candidate.kind,
      eligible: evaluation.eligible,
      totalScore: components.fold(
        0,
        (total, component) => total + component.weightedValue,
      ),
      blockers: evaluation.blockers,
      components: components,
      reasonCodes: reasons,
    );
  }

  AiroMediaRouteScoreComponent _component(
    AiroMediaRouteScoreComponentId componentId,
    int value,
    int weight,
  ) {
    return AiroMediaRouteScoreComponent(
      componentId: componentId,
      value: value,
      weight: weight,
      weightedValue: value * weight,
    );
  }

  AiroMediaRouteScoreBreakdown _withSelectionReason(
    AiroMediaRouteScoreBreakdown selected,
    List<AiroMediaRouteScoreBreakdown> ranked,
  ) {
    final tied =
        ranked.length > 1 && ranked[1].totalScore == selected.totalScore;
    return AiroMediaRouteScoreBreakdown(
      candidateId: selected.candidateId,
      routeKind: selected.routeKind,
      eligible: selected.eligible,
      totalScore: selected.totalScore,
      blockers: selected.blockers,
      components: selected.components,
      reasonCodes: [
        ...selected.reasonCodes,
        if (tied)
          AiroMediaRouteDecisionReasonCode.selectedByStableTieBreak
        else
          AiroMediaRouteDecisionReasonCode.selectedHighestScore,
      ],
    );
  }

  AiroMediaRouteScoreBreakdown _withNoEligibleRouteReason(
    AiroMediaRouteScoreBreakdown score,
  ) {
    return AiroMediaRouteScoreBreakdown(
      candidateId: score.candidateId,
      routeKind: score.routeKind,
      eligible: score.eligible,
      totalScore: score.totalScore,
      blockers: score.blockers,
      components: score.components,
      reasonCodes: [
        ...score.reasonCodes,
        AiroMediaRouteDecisionReasonCode.noEligibleRoute,
      ],
    );
  }

  int _compareScores(
    AiroMediaRouteScoreBreakdown left,
    AiroMediaRouteScoreBreakdown right,
  ) {
    final scoreOrder = right.totalScore.compareTo(left.totalScore);
    if (scoreOrder != 0) return scoreOrder;
    return left.candidateId.compareTo(right.candidateId);
  }

  int _routePriority(AiroMediaRouteKind kind) {
    return switch (kind) {
      AiroMediaRouteKind.receiverDirect => 100,
      AiroMediaRouteKind.lanDirect => 90,
      AiroMediaRouteKind.serverDirect => 80,
      AiroMediaRouteKind.desktopRelay => 70,
      AiroMediaRouteKind.phoneProxy => 10,
      AiroMediaRouteKind.cloudCommandOnly => -100,
    };
  }
}
