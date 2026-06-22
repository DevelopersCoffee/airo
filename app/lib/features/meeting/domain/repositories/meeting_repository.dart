import '../entities/meeting.dart';
import '../entities/meeting_intelligence.dart';
import '../entities/transcript_chunk.dart';

class MeetingSearchResult {
  const MeetingSearchResult({
    required this.meetingId,
    required this.chunkId,
    required this.matchedText,
    required this.score,
  });

  final String meetingId;
  final String chunkId;
  final String matchedText;
  final double score;
}

abstract class MeetingRepository {
  Future<void> saveMeeting(Meeting meeting);
  Future<Meeting?> getMeeting(String meetingId);
  Future<List<Meeting>> listMeetings();
  Future<void> saveTranscriptChunk(TranscriptChunk chunk);
  Future<List<TranscriptChunk>> getTranscriptChunks(String meetingId);
  Future<void> saveIntelligence(MeetingIntelligence intelligence);
  Future<MeetingIntelligence?> getIntelligence(String meetingId);
  Future<void> saveActionItems(List<MeetingActionItem> actionItems);
  Future<void> saveEmbedding({
    required String meetingId,
    required String chunkId,
    required List<double> vector,
    required String searchableText,
  });
  Future<List<MeetingSearchResult>> search(String query, {int limit = 10});
}
