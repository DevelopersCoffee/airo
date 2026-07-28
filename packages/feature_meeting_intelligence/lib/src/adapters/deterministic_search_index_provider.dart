import '../domain/meeting_intelligence_contracts.dart';

abstract interface class MeetingSearchIndexStageProvider {
  MeetingIntelligenceStage get stage;

  MeetingSearchIndexProjection process(MeetingIntelligenceJobRequest request);
}

class MeetingSearchIndexProjection {
  const MeetingSearchIndexProjection({required this.searchableText});

  final String searchableText;
}

class DeterministicMeetingSearchIndexProvider
    implements MeetingSearchIndexStageProvider {
  const DeterministicMeetingSearchIndexProvider();

  @override
  MeetingIntelligenceStage get stage => MeetingIntelligenceStage.searchIndexing;

  @override
  MeetingSearchIndexProjection process(MeetingIntelligenceJobRequest request) {
    return MeetingSearchIndexProjection(
      searchableText: request.redactedTranscriptSegments.join('\n'),
    );
  }
}
