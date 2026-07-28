import 'package:feature_meeting_intelligence/feature_meeting_intelligence.dart';

import 'meeting_audio_metadata.dart';
import 'meeting_record.dart';
import 'meeting_summary.dart';
import 'transcript_chunk.dart';

class MeetingIntelligenceDraft {
  const MeetingIntelligenceDraft({
    required this.record,
    required this.audioMetadata,
    required this.redactedChunks,
    required this.summary,
    required this.searchableText,
    this.embedding,
  });

  final MeetingRecord record;
  final MeetingAudioMetadata audioMetadata;
  final List<TranscriptChunk> redactedChunks;
  final MeetingSummary summary;
  final String searchableText;
  final MeetingEmbeddingProjection? embedding;
}

class MeetingSearchResult {
  const MeetingSearchResult({
    required this.meetingId,
    required this.title,
    required this.snippet,
  });

  final String meetingId;
  final String title;
  final String snippet;
}
