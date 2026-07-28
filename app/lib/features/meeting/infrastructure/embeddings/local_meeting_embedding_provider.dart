import 'package:core_ai/core_ai.dart';
import 'package:feature_meeting_intelligence/feature_meeting_intelligence.dart';

/// Maps the framework embedding contract into meeting-domain outcomes.
///
/// The wrapped platform provider is responsible for native worker execution.
final class LocalMeetingEmbeddingProvider
    implements MeetingEmbeddingStageProvider {
  const LocalMeetingEmbeddingProvider(this._provider);

  final LocalTextEmbeddingProvider _provider;

  @override
  MeetingIntelligenceStage get stage => MeetingIntelligenceStage.embedding;

  @override
  Future<MeetingEmbeddingProviderResult> process(
    MeetingIntelligenceJobRequest request,
  ) async {
    final outcome = await _provider.embed(
      request.redactedTranscriptSegments.join('\n'),
    );
    return switch (outcome) {
      TextEmbeddingSuccess(:final model, :final values) =>
        MeetingEmbeddingProviderSuccess(
          projection: MeetingEmbeddingProjection(
            modelId: model.modelId,
            revision: model.revision,
            modelSha256: model.sha256,
            dimensions: model.dimensions,
            values: values,
          ),
        ),
      TextEmbeddingFailure(:final code) => MeetingEmbeddingProviderFailure(
        code: _mapFailure(code),
      ),
    };
  }

  static MeetingIntelligenceOutcomeCode _mapFailure(
    TextEmbeddingFailureCode code,
  ) {
    return switch (code) {
      TextEmbeddingFailureCode.platformUnavailable ||
      TextEmbeddingFailureCode.modelMissing ||
      TextEmbeddingFailureCode.unsupportedDimensions ||
      TextEmbeddingFailureCode.initializationFailed ||
      TextEmbeddingFailureCode.providerClosed =>
        MeetingIntelligenceOutcomeCode.providerUnavailable,
      TextEmbeddingFailureCode.modelIntegrityMismatch ||
      TextEmbeddingFailureCode.inferenceFailed =>
        MeetingIntelligenceOutcomeCode.workerFailure,
      TextEmbeddingFailureCode.invalidInput =>
        MeetingIntelligenceOutcomeCode.invalidInput,
      TextEmbeddingFailureCode.cancelled =>
        MeetingIntelligenceOutcomeCode.cancelled,
    };
  }
}
