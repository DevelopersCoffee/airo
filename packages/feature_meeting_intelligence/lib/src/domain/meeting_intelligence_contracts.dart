import 'package:platform_worker_jobs/platform_worker_jobs.dart';

enum MeetingIntelligenceStage {
  summary('summary', AiroWorkerJobKind.meetingSummary),
  searchIndexing('search_indexing', AiroWorkerJobKind.meetingSearchIndexing),
  embedding('embedding', AiroWorkerJobKind.meetingEmbedding),
  speakerClustering(
    'speaker_clustering',
    AiroWorkerJobKind.meetingSpeakerClustering,
  ),
  memoryUpdate('memory_update', AiroWorkerJobKind.meetingMemoryUpdate);

  const MeetingIntelligenceStage(this.stableId, this.workerJobKind);

  final String stableId;
  final AiroWorkerJobKind workerJobKind;
}

enum MeetingIntelligenceStageState {
  queued('queued'),
  running('running'),
  completed('completed'),
  failed('failed'),
  cancelled('cancelled'),
  unavailable('unavailable');

  const MeetingIntelligenceStageState(this.stableId);

  final String stableId;
}

class MeetingIntelligenceStageProgress {
  const MeetingIntelligenceStageProgress({
    required this.stage,
    required this.state,
    this.code,
  });

  factory MeetingIntelligenceStageProgress.fromOutcome(
    MeetingIntelligenceStageOutcome outcome,
  ) {
    return MeetingIntelligenceStageProgress(
      stage: outcome.stage,
      state: outcome.state,
      code: outcome.code,
    );
  }

  final MeetingIntelligenceStage stage;
  final MeetingIntelligenceStageState state;
  final MeetingIntelligenceOutcomeCode? code;

  Map<String, String> toDiagnosticMap() => {
    'stage': stage.stableId,
    'state': state.stableId,
    if (code case final code?) 'code': code.stableId,
  };
}

enum MeetingIntelligenceOutcomeCode {
  completed('completed'),
  providerUnavailable('provider_unavailable'),
  cancelled('cancelled'),
  invalidInput('invalid_input'),
  workerFailure('worker_failure'),
  persistenceFailure('persistence_failure');

  const MeetingIntelligenceOutcomeCode(this.stableId);

  final String stableId;
}

const _failureOutcomeCodes = {
  MeetingIntelligenceOutcomeCode.invalidInput,
  MeetingIntelligenceOutcomeCode.workerFailure,
  MeetingIntelligenceOutcomeCode.persistenceFailure,
};

class MeetingIntelligenceJobRequest {
  MeetingIntelligenceJobRequest({
    required String jobId,
    required String meetingId,
    required Set<MeetingIntelligenceStage> stages,
    required List<String> redactedTranscriptSegments,
  }) : jobId = _requireIdentifier(jobId, 'jobId'),
       meetingId = _requireIdentifier(meetingId, 'meetingId'),
       stages = Set.unmodifiable(stages),
       redactedTranscriptSegments = List.unmodifiable(
         redactedTranscriptSegments,
       ) {
    if (stages.isEmpty) {
      throw ArgumentError.value(stages, 'stages', 'must not be empty');
    }
  }

  final String jobId;
  final String meetingId;
  final Set<MeetingIntelligenceStage> stages;

  /// Transcript text after the application-owned redaction boundary.
  final List<String> redactedTranscriptSegments;

  static String _requireIdentifier(String value, String name) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(value, name, 'must not be empty');
    }
    return trimmed;
  }
}

class MeetingIntelligenceStageOutcome {
  const MeetingIntelligenceStageOutcome._({
    required this.stage,
    required this.state,
    required this.code,
  });

  const MeetingIntelligenceStageOutcome.completed({
    required MeetingIntelligenceStage stage,
  }) : this._(
         stage: stage,
         state: MeetingIntelligenceStageState.completed,
         code: MeetingIntelligenceOutcomeCode.completed,
       );

  const MeetingIntelligenceStageOutcome.unavailable({
    required MeetingIntelligenceStage stage,
  }) : this._(
         stage: stage,
         state: MeetingIntelligenceStageState.unavailable,
         code: MeetingIntelligenceOutcomeCode.providerUnavailable,
       );

  const MeetingIntelligenceStageOutcome.cancelled({
    required MeetingIntelligenceStage stage,
  }) : this._(
         stage: stage,
         state: MeetingIntelligenceStageState.cancelled,
         code: MeetingIntelligenceOutcomeCode.cancelled,
       );

  factory MeetingIntelligenceStageOutcome.failed({
    required MeetingIntelligenceStage stage,
    required MeetingIntelligenceOutcomeCode code,
  }) {
    if (!_failureOutcomeCodes.contains(code)) {
      throw ArgumentError.value(code, 'code', 'must be a failure code');
    }
    return MeetingIntelligenceStageOutcome._(
      stage: stage,
      state: MeetingIntelligenceStageState.failed,
      code: code,
    );
  }

  final MeetingIntelligenceStage stage;
  final MeetingIntelligenceStageState state;
  final MeetingIntelligenceOutcomeCode code;

  Map<String, String> toDiagnosticMap() => {
    'stage': stage.stableId,
    'state': state.stableId,
    'code': code.stableId,
  };
}

abstract interface class MeetingIntelligenceCancellationSignal {
  bool get isCancelled;
}

class MeetingIntelligenceCancellationToken
    implements MeetingIntelligenceCancellationSignal {
  bool _isCancelled = false;

  @override
  bool get isCancelled => _isCancelled;

  void cancel() {
    _isCancelled = true;
  }
}
