import '../../domain/entities/meeting_intelligence.dart';
import '../../domain/entities/meeting_record.dart';
import '../../domain/entities/meeting_summary.dart';
import '../../domain/entities/transcript_chunk.dart';
import '../../domain/repositories/meeting_repository.dart';

class InMemoryMeetingRepository implements MeetingRepository {
  final Map<String, MeetingRecord> _records = {};
  final Map<String, List<TranscriptChunk>> _chunksByMeeting = {};
  final Map<String, MeetingSummary> _summaries = {};
  final Map<String, String> _searchTextByMeeting = {};

  @override
  Future<void> saveIntelligence(MeetingIntelligenceDraft draft) async {
    _records[draft.record.id] = draft.record;
    _chunksByMeeting[draft.record.id] = List.unmodifiable(draft.redactedChunks);
    _summaries[draft.record.id] = draft.summary;
    _searchTextByMeeting[draft.record.id] = draft.searchableText;
  }

  @override
  Future<MeetingRecord?> meetingById(String meetingId) async {
    return _records[meetingId];
  }

  @override
  Future<List<TranscriptChunk>> transcriptChunksForMeeting(
    String meetingId,
  ) async {
    return List.unmodifiable(_chunksByMeeting[meetingId] ?? const []);
  }

  @override
  Future<MeetingSummary?> summaryForMeeting(String meetingId) async {
    return _summaries[meetingId];
  }

  @override
  Future<List<MeetingSearchResult>> searchMeetings(String query) async {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return const [];
    }

    return _searchTextByMeeting.entries
        .where((entry) => entry.value.toLowerCase().contains(normalizedQuery))
        .map((entry) {
          final record = _records[entry.key];
          return MeetingSearchResult(
            meetingId: entry.key,
            title: record?.title ?? 'Untitled meeting',
            snippet: _snippetFor(entry.value, normalizedQuery),
          );
        })
        .toList(growable: false);
  }

  String _snippetFor(String searchableText, String normalizedQuery) {
    final lowerText = searchableText.toLowerCase();
    final index = lowerText.indexOf(normalizedQuery);
    if (index < 0) {
      return searchableText.length <= 120
          ? searchableText
          : searchableText.substring(0, 120);
    }
    final start = index - 40 < 0 ? 0 : index - 40;
    final end = index + normalizedQuery.length + 40;
    return searchableText.substring(
      start,
      end > searchableText.length ? searchableText.length : end,
    );
  }
}
