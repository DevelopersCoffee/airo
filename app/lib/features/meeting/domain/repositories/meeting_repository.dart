import '../entities/meeting_audio_metadata.dart';
import '../entities/meeting_intelligence.dart';
import '../entities/meeting_record.dart';
import '../entities/meeting_summary.dart';
import '../entities/transcript_chunk.dart';

abstract interface class MeetingRepository {
  Future<void> saveIntelligence(MeetingIntelligenceDraft draft);

  Future<MeetingRecord?> meetingById(String meetingId);

  Future<List<TranscriptChunk>> transcriptChunksForMeeting(String meetingId);

  Future<MeetingSummary?> summaryForMeeting(String meetingId);

  Future<MeetingAudioMetadata?> audioMetadataForMeeting(String meetingId);

  Future<List<MeetingSearchResult>> searchMeetings(String query);
}
