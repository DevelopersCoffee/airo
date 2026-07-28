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

const _stageProviderOutcomeCodes = {
  MeetingIntelligenceOutcomeCode.providerUnavailable,
  MeetingIntelligenceOutcomeCode.cancelled,
  MeetingIntelligenceOutcomeCode.invalidInput,
  MeetingIntelligenceOutcomeCode.workerFailure,
};

/// Local audio metadata for a stage provider. It intentionally has no
/// diagnostic serializer or field-bearing string representation.
final class MeetingLocalAudioInput {
  factory MeetingLocalAudioInput({
    required String localPath,
    required String codec,
    required int sampleRateHz,
    required int channelCount,
    required int sizeBytes,
    required String sha256,
  }) {
    final normalizedPath = localPath.trim();
    final normalizedCodec = codec.trim();
    if (normalizedPath.isEmpty) {
      throw ArgumentError.value(localPath, 'localPath', 'must not be blank');
    }
    if (normalizedCodec.isEmpty) {
      throw ArgumentError.value(codec, 'codec', 'must not be blank');
    }
    if (sampleRateHz <= 0) {
      throw ArgumentError.value(sampleRateHz, 'sampleRateHz', 'must be > 0');
    }
    if (channelCount <= 0) {
      throw ArgumentError.value(channelCount, 'channelCount', 'must be > 0');
    }
    if (sizeBytes < 0) {
      throw ArgumentError.value(sizeBytes, 'sizeBytes', 'must be >= 0');
    }
    return MeetingLocalAudioInput._(
      localPath: normalizedPath,
      codec: normalizedCodec,
      sampleRateHz: sampleRateHz,
      channelCount: channelCount,
      sizeBytes: sizeBytes,
      sha256: sha256.trim().toLowerCase(),
    );
  }

  const MeetingLocalAudioInput._({
    required this.localPath,
    required this.codec,
    required this.sampleRateHz,
    required this.channelCount,
    required this.sizeBytes,
    required this.sha256,
  });

  final String localPath;
  final String codec;
  final int sampleRateHz;
  final int channelCount;
  final int sizeBytes;
  final String sha256;

  @override
  String toString() => 'MeetingLocalAudioInput(redacted)';
}

class MeetingIntelligenceJobRequest {
  MeetingIntelligenceJobRequest({
    required String jobId,
    required String meetingId,
    required Set<MeetingIntelligenceStage> stages,
    required List<String> redactedTranscriptSegments,
    this.localAudio,
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
  final MeetingLocalAudioInput? localAudio;

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

/// A validated embedding projection without transcript or vector diagnostics.
final class MeetingEmbeddingProjection {
  factory MeetingEmbeddingProjection({
    required String modelId,
    required String revision,
    required String modelSha256,
    required int dimensions,
    required List<double> values,
  }) {
    final normalizedModelId = modelId.trim();
    final normalizedRevision = revision.trim();
    final normalizedSha256 = modelSha256.trim().toLowerCase();
    if (normalizedModelId.isEmpty) {
      throw ArgumentError.value(modelId, 'modelId', 'must not be blank');
    }
    if (normalizedRevision.isEmpty) {
      throw ArgumentError.value(revision, 'revision', 'must not be blank');
    }
    if (!_sha256Pattern.hasMatch(normalizedSha256)) {
      throw ArgumentError.value(
        modelSha256,
        'modelSha256',
        'must be a 64-character hexadecimal digest',
      );
    }
    if (!supportedDimensions.contains(dimensions)) {
      throw ArgumentError.value(
        dimensions,
        'dimensions',
        'must be one of $supportedDimensions',
      );
    }
    if (values.length != dimensions) {
      throw ArgumentError.value(
        values.length,
        'values.length',
        'must equal dimensions',
      );
    }
    if (values.any((value) => !value.isFinite)) {
      throw ArgumentError.value(values, 'values', 'must be finite');
    }

    return MeetingEmbeddingProjection._(
      modelId: normalizedModelId,
      revision: normalizedRevision,
      modelSha256: normalizedSha256,
      dimensions: dimensions,
      values: List.unmodifiable(values),
    );
  }

  const MeetingEmbeddingProjection._({
    required this.modelId,
    required this.revision,
    required this.modelSha256,
    required this.dimensions,
    required this.values,
  });

  static const supportedDimensions = {256, 384};
  static final _sha256Pattern = RegExp(r'^[0-9a-f]{64}$');

  final String modelId;
  final String revision;
  final String modelSha256;
  final int dimensions;
  final List<double> values;

  @override
  String toString() {
    return 'MeetingEmbeddingProjection('
        'modelId: $modelId, revision: $revision, dimensions: $dimensions)';
  }
}

sealed class MeetingEmbeddingProviderResult {
  const MeetingEmbeddingProviderResult();
}

final class MeetingEmbeddingProviderSuccess
    extends MeetingEmbeddingProviderResult {
  const MeetingEmbeddingProviderSuccess({required this.projection});

  final MeetingEmbeddingProjection projection;

  @override
  String toString() => 'MeetingEmbeddingProviderSuccess($projection)';
}

final class MeetingEmbeddingProviderFailure
    extends MeetingEmbeddingProviderResult {
  factory MeetingEmbeddingProviderFailure({
    required MeetingIntelligenceOutcomeCode code,
  }) {
    if (!_stageProviderOutcomeCodes.contains(code)) {
      throw ArgumentError.value(code, 'code', 'unsupported provider outcome');
    }
    return MeetingEmbeddingProviderFailure._(code);
  }

  const MeetingEmbeddingProviderFailure._(this.code);

  final MeetingIntelligenceOutcomeCode code;

  @override
  String toString() => 'MeetingEmbeddingProviderFailure(${code.stableId})';
}

/// Application adapter for a local provider whose implementation owns its
/// native/off-main worker boundary.
abstract interface class MeetingEmbeddingStageProvider {
  MeetingIntelligenceStage get stage;

  Future<MeetingEmbeddingProviderResult> process(
    MeetingIntelligenceJobRequest request,
  );
}

/// One anonymous speaker cluster assignment. Overlapping ranges are valid.
final class MeetingSpeakerClusterRange {
  factory MeetingSpeakerClusterRange({
    required String clusterId,
    required int startMs,
    required int endMs,
    required double confidence,
  }) {
    final normalizedClusterId = clusterId.trim();
    if (normalizedClusterId.isEmpty) {
      throw ArgumentError.value(clusterId, 'clusterId', 'must not be blank');
    }
    if (startMs < 0 || endMs <= startMs) {
      throw ArgumentError(
        'Speaker cluster range must have 0 <= startMs < endMs.',
      );
    }
    if (!confidence.isFinite || confidence < 0 || confidence > 1) {
      throw ArgumentError.value(
        confidence,
        'confidence',
        'must be finite and between 0 and 1',
      );
    }
    return MeetingSpeakerClusterRange._(
      clusterId: normalizedClusterId,
      startMs: startMs,
      endMs: endMs,
      confidence: confidence,
    );
  }

  const MeetingSpeakerClusterRange._({
    required this.clusterId,
    required this.startMs,
    required this.endMs,
    required this.confidence,
  });

  final String clusterId;
  final int startMs;
  final int endMs;
  final double confidence;
}

final class MeetingSpeakerClusteringProjection {
  factory MeetingSpeakerClusteringProjection({
    required String providerId,
    required String revision,
    required List<MeetingSpeakerClusterRange> ranges,
  }) {
    final normalizedProviderId = providerId.trim();
    final normalizedRevision = revision.trim();
    if (normalizedProviderId.isEmpty) {
      throw ArgumentError.value(providerId, 'providerId', 'must not be blank');
    }
    if (normalizedRevision.isEmpty) {
      throw ArgumentError.value(revision, 'revision', 'must not be blank');
    }
    if (ranges.isEmpty) {
      throw ArgumentError.value(ranges, 'ranges', 'must not be empty');
    }
    return MeetingSpeakerClusteringProjection._(
      providerId: normalizedProviderId,
      revision: normalizedRevision,
      ranges: List.unmodifiable(ranges),
    );
  }

  const MeetingSpeakerClusteringProjection._({
    required this.providerId,
    required this.revision,
    required this.ranges,
  });

  final String providerId;
  final String revision;
  final List<MeetingSpeakerClusterRange> ranges;

  @override
  String toString() {
    return 'MeetingSpeakerClusteringProjection('
        'providerId: $providerId, revision: $revision, '
        'rangeCount: ${ranges.length})';
  }
}

sealed class MeetingSpeakerClusteringProviderResult {
  const MeetingSpeakerClusteringProviderResult();
}

final class MeetingSpeakerClusteringProviderSuccess
    extends MeetingSpeakerClusteringProviderResult {
  const MeetingSpeakerClusteringProviderSuccess({required this.projection});

  final MeetingSpeakerClusteringProjection projection;

  @override
  String toString() => 'MeetingSpeakerClusteringProviderSuccess($projection)';
}

final class MeetingSpeakerClusteringProviderFailure
    extends MeetingSpeakerClusteringProviderResult {
  factory MeetingSpeakerClusteringProviderFailure({
    required MeetingIntelligenceOutcomeCode code,
  }) {
    if (!_stageProviderOutcomeCodes.contains(code)) {
      throw ArgumentError.value(code, 'code', 'unsupported provider outcome');
    }
    return MeetingSpeakerClusteringProviderFailure._(code);
  }

  const MeetingSpeakerClusteringProviderFailure._(this.code);

  final MeetingIntelligenceOutcomeCode code;

  @override
  String toString() {
    return 'MeetingSpeakerClusteringProviderFailure(${code.stableId})';
  }
}

/// Application adapter for an anonymous speaker clustering implementation.
abstract interface class MeetingSpeakerClusteringStageProvider {
  MeetingIntelligenceStage get stage;

  Future<MeetingSpeakerClusteringProviderResult> process(
    MeetingIntelligenceJobRequest request,
  );
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
