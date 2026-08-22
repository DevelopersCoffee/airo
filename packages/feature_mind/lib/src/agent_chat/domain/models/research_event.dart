import 'package:flutter/foundation.dart';

import 'research_request.dart';

/// Structured execution events. The UI renders these; it never shows
/// model scratchpad or chain-of-thought.
enum ResearchEventKind {
  jobAdmitted,
  planningStarted,
  intentClassified,
  planCreated,
  searchStarted,
  searchCompleted,
  sourceDiscovered,
  sourceFetched,
  sourceRejected,
  documentParsed,
  analyzingStarted,
  claimCreated,
  conflictDetected,
  gapDetected,
  counterResearchStarted,
  synthesisStarted,
  reportSectionCompleted,
  researchCompleted,
  researchFailed,
  researchPaused,
  researchCancelled,
}

enum ResearchPhase {
  created,
  planning,
  searching,
  collecting,
  analyzing,
  verifying,
  gapAnalysis,
  synthesizing,
  validating,
  completed,
  paused,
  cancelled,
  failed,
}

@immutable
class ResearchEvent {
  const ResearchEvent({
    required this.kind,
    this.jobId = '',
    this.label = '',
    this.detail = '',
  });

  final ResearchEventKind kind;
  final String jobId;
  final String label;
  final String detail;

  bool get isTerminal =>
      kind == ResearchEventKind.researchCompleted ||
      kind == ResearchEventKind.researchFailed ||
      kind == ResearchEventKind.researchCancelled;
}

@immutable
class ResearchSession {
  const ResearchSession({required this.request, this.events = const []});

  final ResearchRequest request;
  final List<ResearchEvent> events;

  ResearchEvent? get last => events.isEmpty ? null : events.last;

  bool get isComplete =>
      events.any((event) => event.kind == ResearchEventKind.researchCompleted);

  bool get isFailed =>
      events.any((event) => event.kind == ResearchEventKind.researchFailed);

  bool get isCancelled =>
      events.any((event) => event.kind == ResearchEventKind.researchCancelled);

  bool get isPaused => last?.kind == ResearchEventKind.researchPaused;

  String get report {
    for (final event in events.reversed) {
      if (event.kind == ResearchEventKind.researchCompleted) {
        return event.detail;
      }
    }
    return '';
  }

  ResearchSession append(ResearchEvent event) {
    return ResearchSession(request: request, events: [...events, event]);
  }
}
