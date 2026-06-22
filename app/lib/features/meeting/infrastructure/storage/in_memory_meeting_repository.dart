import '../../domain/entities/meeting.dart';
import '../../domain/entities/meeting_intelligence.dart';
import '../../domain/entities/transcript_chunk.dart';
import '../../domain/repositories/meeting_repository.dart';

class InMemoryMeetingRepository implements MeetingRepository {
  final Map<String, Meeting> _meetings = {};
  final Map<String, List<TranscriptChunk>> _chunks = {};
  final Map<String, MeetingIntelligence> _intelligence = {};
  final List<MeetingActionItem> _actionItems = [];
  final List<_EmbeddingRecord> _embeddings = [];

  @override
  Future<void> saveMeeting(Meeting meeting) async {
    _meetings[meeting.id] = meeting;
  }

  @override
  Future<Meeting?> getMeeting(String meetingId) async => _meetings[meetingId];

  @override
  Future<List<Meeting>> listMeetings() async {
    final meetings = _meetings.values.toList(growable: false);
    meetings.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return meetings;
  }

  @override
  Future<void> saveTranscriptChunk(TranscriptChunk chunk) async {
    _chunks.putIfAbsent(chunk.meetingId, () => []).add(chunk);
  }

  @override
  Future<List<TranscriptChunk>> getTranscriptChunks(String meetingId) async {
    return List.unmodifiable(_chunks[meetingId] ?? const []);
  }

  @override
  Future<void> saveIntelligence(MeetingIntelligence intelligence) async {
    _intelligence[intelligence.meetingId] = intelligence;
    await saveEmbedding(
      meetingId: intelligence.embedding.meetingId,
      chunkId: intelligence.embedding.chunkId,
      vector: intelligence.embedding.vector,
      searchableText: intelligence.embedding.searchableText,
    );
    await saveActionItems(intelligence.actionItems);
  }

  @override
  Future<MeetingIntelligence?> getIntelligence(String meetingId) async =>
      _intelligence[meetingId];

  @override
  Future<void> saveActionItems(List<MeetingActionItem> actionItems) async {
    _actionItems.removeWhere(
      (item) => actionItems.any(
        (incoming) =>
            incoming.id == item.id && incoming.meetingId == item.meetingId,
      ),
    );
    _actionItems.addAll(actionItems);
  }

  @override
  Future<void> saveEmbedding({
    required String meetingId,
    required String chunkId,
    required List<double> vector,
    required String searchableText,
  }) async {
    _embeddings.removeWhere(
      (record) => record.meetingId == meetingId && record.chunkId == chunkId,
    );
    _embeddings.add(
      _EmbeddingRecord(meetingId, chunkId, vector, searchableText),
    );
  }

  @override
  Future<List<MeetingSearchResult>> search(
    String query, {
    int limit = 10,
  }) async {
    final queryTokens = _tokens(query);
    final results = _embeddings
        .map((record) {
          final recordTokens = _tokens(record.searchableText);
          final overlap = queryTokens.intersection(recordTokens).length;
          final score = queryTokens.isEmpty
              ? 0.0
              : overlap / queryTokens.length;
          return MeetingSearchResult(
            meetingId: record.meetingId,
            chunkId: record.chunkId,
            matchedText: record.searchableText,
            score: score,
          );
        })
        .where((result) => result.score > 0)
        .toList();
    results.sort((a, b) => b.score.compareTo(a.score));
    return results.take(limit).toList(growable: false);
  }

  Set<String> _tokens(String value) => value
      .toLowerCase()
      .split(RegExp(r'[^a-z0-9]+'))
      .where((token) => token.length > 2)
      .toSet();
}

class _EmbeddingRecord {
  const _EmbeddingRecord(
    this.meetingId,
    this.chunkId,
    this.vector,
    this.searchableText,
  );

  final String meetingId;
  final String chunkId;
  final List<double> vector;
  final String searchableText;
}
