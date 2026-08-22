import 'package:flutter/foundation.dart';

import '../../models/research_event.dart';
import '../../models/research_request.dart';

/// Durable job snapshot. Payload for the operation log — not a sidecar DB.
@immutable
class ResearchCheckpoint {
  const ResearchCheckpoint({
    required this.jobId,
    required this.question,
    required this.state,
    this.pausedFrom,
    required this.searchesUsed,
    required this.iterationsUsed,
    this.completedNodeIds = const [],
    this.mode = ResearchMode.deep,
    this.policy = SearchPolicy.balanced,
  });

  final String jobId;
  final String question;
  final ResearchPhase state;
  final ResearchPhase? pausedFrom;
  final int searchesUsed;
  final int iterationsUsed;
  final List<String> completedNodeIds;
  final ResearchMode mode;
  final SearchPolicy policy;

  PrivacyProfile get privacy => switch (policy) {
    SearchPolicy.localOnly ||
    SearchPolicy.privacyFirst => PrivacyProfile.private,
    SearchPolicy.maximumQuality => PrivacyProfile.cloud,
    SearchPolicy.balanced || SearchPolicy.academic => PrivacyProfile.balanced,
  };

  bool get isTerminal =>
      state == ResearchPhase.completed ||
      state == ResearchPhase.cancelled ||
      state == ResearchPhase.failed;

  ResearchCheckpoint copyWith({
    ResearchPhase? state,
    ResearchPhase? pausedFrom,
    int? searchesUsed,
    int? iterationsUsed,
    List<String>? completedNodeIds,
    ResearchMode? mode,
    SearchPolicy? policy,
  }) {
    return ResearchCheckpoint(
      jobId: jobId,
      question: question,
      state: state ?? this.state,
      pausedFrom: pausedFrom ?? this.pausedFrom,
      searchesUsed: searchesUsed ?? this.searchesUsed,
      iterationsUsed: iterationsUsed ?? this.iterationsUsed,
      completedNodeIds: completedNodeIds ?? this.completedNodeIds,
      mode: mode ?? this.mode,
      policy: policy ?? this.policy,
    );
  }

  String toRecord() {
    return [
      'v2',
      jobId,
      question.replaceAll('\u{1f}', ' '),
      researchPhaseWire(state),
      pausedFrom == null ? '' : researchPhaseWire(pausedFrom!),
      '$searchesUsed',
      '$iterationsUsed',
      completedNodeIds.join(','),
      mode.name,
      researchPolicyWire(policy),
    ].join('\u{1f}');
  }

  factory ResearchCheckpoint.fromRecord(String record) {
    final parts = record.split('\u{1f}');
    final legacy = parts.length == 8 && parts[0] == 'v1';
    final current = parts.length == 10 && parts[0] == 'v2';
    if (!legacy && !current) {
      throw const FormatException('invalid research checkpoint');
    }
    final state = parseResearchPhase(parts[3]);
    if (state == null) {
      throw const FormatException('invalid research checkpoint state');
    }
    final pausedFrom = parts[4].isEmpty ? null : parseResearchPhase(parts[4]);
    final mode = legacy ? ResearchMode.deep : parseResearchMode(parts[8]);
    final policy = legacy
        ? SearchPolicy.privacyFirst
        : parseResearchPolicy(parts[9]);
    if (mode == null || policy == null) {
      throw const FormatException('invalid research checkpoint policy');
    }
    return ResearchCheckpoint(
      jobId: parts[1],
      question: parts[2],
      state: state,
      pausedFrom: pausedFrom,
      searchesUsed: int.parse(parts[5]),
      iterationsUsed: int.parse(parts[6]),
      completedNodeIds: parts[7].isEmpty ? const [] : parts[7].split(','),
      mode: mode,
      policy: policy,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ResearchCheckpoint &&
      other.jobId == jobId &&
      other.question == question &&
      other.state == state &&
      other.pausedFrom == pausedFrom &&
      other.searchesUsed == searchesUsed &&
      other.iterationsUsed == iterationsUsed &&
      other.mode == mode &&
      other.policy == policy &&
      listEquals(other.completedNodeIds, completedNodeIds);

  @override
  int get hashCode => Object.hash(
    jobId,
    question,
    state,
    pausedFrom,
    searchesUsed,
    iterationsUsed,
    mode,
    policy,
    Object.hashAll(completedNodeIds),
  );
}

String researchPolicyWire(SearchPolicy policy) => switch (policy) {
  SearchPolicy.localOnly => 'local_only',
  SearchPolicy.privacyFirst => 'privacy_first',
  SearchPolicy.balanced => 'balanced',
  SearchPolicy.maximumQuality => 'maximum_quality',
  SearchPolicy.academic => 'academic',
};

ResearchMode? parseResearchMode(String value) {
  for (final mode in ResearchMode.values) {
    if (mode.name == value) {
      return mode;
    }
  }
  return null;
}

SearchPolicy? parseResearchPolicy(String value) => switch (value) {
  'local_only' => SearchPolicy.localOnly,
  'privacy_first' => SearchPolicy.privacyFirst,
  'balanced' => SearchPolicy.balanced,
  'maximum_quality' => SearchPolicy.maximumQuality,
  'academic' => SearchPolicy.academic,
  _ => null,
};

String researchPhaseWire(ResearchPhase phase) {
  switch (phase) {
    case ResearchPhase.gapAnalysis:
      return 'gap_analysis';
    default:
      return phase.name;
  }
}

ResearchPhase? parseResearchPhase(String value) {
  if (value == 'gap_analysis') {
    return ResearchPhase.gapAnalysis;
  }
  for (final phase in ResearchPhase.values) {
    if (phase.name == value) {
      return phase;
    }
  }
  return null;
}
