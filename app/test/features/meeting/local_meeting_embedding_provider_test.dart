import 'package:airo_app/features/meeting/infrastructure/embeddings/local_meeting_embedding_provider.dart';
import 'package:core_ai/core_ai.dart';
import 'package:feature_meeting_intelligence/feature_meeting_intelligence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalMeetingEmbeddingProvider', () {
    test(
      'embeds only the redacted transcript and preserves model identity',
      () async {
        final coreProvider = _FakeCoreProvider(
          outcome: TextEmbeddingSuccess(
            model: _model,
            values: List.filled(384, 0.125),
          ),
        );
        final provider = LocalMeetingEmbeddingProvider(coreProvider);

        final result = await provider.process(_request);

        expect(
          coreProvider.lastText,
          'Call [REDACTED_PHONE].\nBudget approved.',
        );
        expect(result, isA<MeetingEmbeddingProviderSuccess>());
        final projection =
            (result as MeetingEmbeddingProviderSuccess).projection;
        expect(projection.modelId, _model.modelId);
        expect(projection.revision, _model.revision);
        expect(projection.modelSha256, _model.sha256);
        expect(projection.values, hasLength(384));
        expect(result.toString(), isNot(contains('0.125')));
      },
    );

    test('maps core failures to stable meeting outcomes', () async {
      const expected = {
        TextEmbeddingFailureCode.platformUnavailable:
            MeetingIntelligenceOutcomeCode.providerUnavailable,
        TextEmbeddingFailureCode.modelMissing:
            MeetingIntelligenceOutcomeCode.providerUnavailable,
        TextEmbeddingFailureCode.modelIntegrityMismatch:
            MeetingIntelligenceOutcomeCode.workerFailure,
        TextEmbeddingFailureCode.unsupportedDimensions:
            MeetingIntelligenceOutcomeCode.providerUnavailable,
        TextEmbeddingFailureCode.invalidInput:
            MeetingIntelligenceOutcomeCode.invalidInput,
        TextEmbeddingFailureCode.initializationFailed:
            MeetingIntelligenceOutcomeCode.providerUnavailable,
        TextEmbeddingFailureCode.inferenceFailed:
            MeetingIntelligenceOutcomeCode.workerFailure,
        TextEmbeddingFailureCode.cancelled:
            MeetingIntelligenceOutcomeCode.cancelled,
        TextEmbeddingFailureCode.providerClosed:
            MeetingIntelligenceOutcomeCode.providerUnavailable,
      };

      for (final entry in expected.entries) {
        final provider = LocalMeetingEmbeddingProvider(
          _FakeCoreProvider(outcome: TextEmbeddingFailure(code: entry.key)),
        );

        final result = await provider.process(_request);

        expect(
          (result as MeetingEmbeddingProviderFailure).code,
          entry.value,
          reason: entry.key.stableId,
        );
      }
    });
  });
}

final _model = TextEmbeddingModelDescriptor(
  modelId: 'sentence-transformers/all-MiniLM-L6-v2',
  revision: 'approved-revision',
  dimensions: 384,
  sha256: 'b' * 64,
);

final _request = MeetingIntelligenceJobRequest(
  jobId: 'job-1',
  meetingId: 'meeting-1',
  stages: const {MeetingIntelligenceStage.embedding},
  redactedTranscriptSegments: const [
    'Call [REDACTED_PHONE].',
    'Budget approved.',
  ],
);

class _FakeCoreProvider implements LocalTextEmbeddingProvider {
  _FakeCoreProvider({required this.outcome});

  final TextEmbeddingOutcome outcome;
  String? lastText;

  @override
  TextEmbeddingModelDescriptor get model => _model;

  @override
  Future<TextEmbeddingOutcome> embed(String text) async {
    lastText = text;
    return outcome;
  }

  @override
  Future<void> close() async {}
}
