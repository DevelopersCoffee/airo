import 'package:flutter/foundation.dart';

import '../../models/research_event.dart';

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
  });

  final String jobId;
  final String question;
  final ResearchPhase state;
  final ResearchPhase? pausedFrom;
  final int searchesUsed;
  final int iterationsUsed;
  final List<String> completedNodeIds;

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
  }) {
    return ResearchCheckpoint(
      jobId: jobId,
      question: question,
      state: state ?? this.state,
      pausedFrom: pausedFrom ?? this.pausedFrom,
      searchesUsed: searchesUsed ?? this.searchesUsed,
      iterationsUsed: iterationsUsed ?? this.iterationsUsed,
      completedNodeIds: completedNodeIds ?? this.completedNodeIds,
    );
  }

  String toRecord() {
    return [
      'v1',
      jobId,
      question.replaceAll('\u{1f}', ' '),
      researchPhaseWire(state),
      pausedFrom == null ? '' : researchPhaseWire(pausedFrom!),
      '$searchesUsed',
      '$iterationsUsed',
      completedNodeIds.join(','),
    ].join('\u{1f}');
  }

  factory ResearchCheckpoint.fromRecord(String record) {
    final parts = record.split('\u{1f}');
    if (parts.length != 8 || parts[0] != 'v1') {
      throw const FormatException('invalid research checkpoint');
    }
    final state = parseResearchPhase(parts[3]);
    if (state == null) {
      throw const FormatException('invalid research checkpoint state');
    }
    final pausedFrom = parts[4].isEmpty ? null : parseResearchPhase(parts[4]);
    return ResearchCheckpoint(
      jobId: parts[1],
      question: parts[2],
      state: state,
      pausedFrom: pausedFrom,
      searchesUsed: int.parse(parts[5]),
      iterationsUsed: int.parse(parts[6]),
      completedNodeIds: parts[7].isEmpty ? const [] : parts[7].split(','),
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
      listEquals(other.completedNodeIds, completedNodeIds);

  @override
  int get hashCode => Object.hash(
    jobId,
    question,
    state,
    pausedFrom,
    searchesUsed,
    iterationsUsed,
    Object.hashAll(completedNodeIds),
  );
}

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
