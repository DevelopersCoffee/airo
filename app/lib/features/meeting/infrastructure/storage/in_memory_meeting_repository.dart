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

  static const _synonyms = <String, Set<String>>{
    'budget': {'finance', 'cost'},
    'finance': {'budget', 'cost'},
    'project': {'roadmap', 'initiative'},
    'roadmap': {'project', 'plan'},
    'speaker': {'participant'},
    'participant': {'speaker'},
    'risk': {'issue', 'blocker'},
    'issue': {'risk', 'blocker'},
  };

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
    final normalizedQuery = _normalize(query);
    final queryTerms = _tokenize(normalizedQuery);
    if (queryTerms.isEmpty) {
      return const [];
    }

    final ranked =
        _searchTextByMeeting.entries
            .map((entry) => _rankEntry(entry.key, queryTerms))
            .whereType<_RankedMeetingResult>()
            .toList(growable: false)
          ..sort((left, right) {
            final scoreCompare = right.score.compareTo(left.score);
            if (scoreCompare != 0) return scoreCompare;

            final leftRecord = _records[left.meetingId];
            final rightRecord = _records[right.meetingId];
            final timeCompare =
                (rightRecord?.startedAt ??
                        DateTime.fromMillisecondsSinceEpoch(0))
                    .compareTo(
                      leftRecord?.startedAt ??
                          DateTime.fromMillisecondsSinceEpoch(0),
                    );
            if (timeCompare != 0) return timeCompare;

            return left.meetingId.compareTo(right.meetingId);
          });

    return ranked
        .map((result) {
          final record = _records[result.meetingId];
          final searchableText = _searchTextByMeeting[result.meetingId] ?? '';
          return MeetingSearchResult(
            meetingId: result.meetingId,
            title: record?.title ?? 'Untitled meeting',
            snippet: _snippetFor(searchableText, result.matchedTerm),
          );
        })
        .toList(growable: false);
  }

  _RankedMeetingResult? _rankEntry(String meetingId, List<String> queryTerms) {
    final record = _records[meetingId];
    final chunks = _chunksByMeeting[meetingId] ?? const <TranscriptChunk>[];
    final searchableText = _searchTextByMeeting[meetingId] ?? '';

    final searchCorpus = _normalize(
      [
        record?.title ?? '',
        searchableText,
        for (final chunk in chunks) chunk.speakerLabel ?? '',
        for (final chunk in chunks) chunk.text,
      ].where((part) => part.trim().isNotEmpty).join('\n'),
    );
    final corpusTerms = _tokenize(searchCorpus);
    if (corpusTerms.isEmpty) return null;

    var score = 0;
    String? matchedTerm;

    for (final queryTerm in queryTerms) {
      final termScore = _scoreQueryTerm(queryTerm, corpusTerms);
      if (termScore.score == 0) {
        return null;
      }
      score += termScore.score;
      matchedTerm ??= termScore.matchedTerm;
    }

    return _RankedMeetingResult(
      meetingId: meetingId,
      score: score,
      matchedTerm: matchedTerm ?? queryTerms.first,
    );
  }

  _TermScore _scoreQueryTerm(String queryTerm, List<String> corpusTerms) {
    final relatedTerms = {queryTerm, ...?_synonyms[queryTerm]};

    var bestScore = 0;
    String? matchedTerm;

    for (final corpusTerm in corpusTerms) {
      if (relatedTerms.contains(corpusTerm)) {
        return _TermScore(score: 4, matchedTerm: corpusTerm);
      }
      if (corpusTerm.contains(queryTerm) || queryTerm.contains(corpusTerm)) {
        if (bestScore < 3) {
          bestScore = 3;
          matchedTerm = corpusTerm;
        }
      } else if (_isFuzzyMatch(queryTerm, corpusTerm)) {
        if (bestScore < 2) {
          bestScore = 2;
          matchedTerm = corpusTerm;
        }
      }
    }

    return _TermScore(score: bestScore, matchedTerm: matchedTerm);
  }

  bool _isFuzzyMatch(String query, String corpusTerm) {
    if (query.length < 4 || corpusTerm.length < 4) return false;
    final distance = _levenshteinDistance(query, corpusTerm);
    return distance <= 1 || (query.length >= 6 && distance <= 2);
  }

  int _levenshteinDistance(String left, String right) {
    if (left == right) return 0;
    if (left.isEmpty) return right.length;
    if (right.isEmpty) return left.length;

    final previous = List<int>.generate(right.length + 1, (index) => index);
    final current = List<int>.filled(right.length + 1, 0);

    for (var i = 0; i < left.length; i += 1) {
      current[0] = i + 1;
      for (var j = 0; j < right.length; j += 1) {
        final substitutionCost = left[i] == right[j] ? 0 : 1;
        current[j + 1] = [
          current[j] + 1,
          previous[j + 1] + 1,
          previous[j] + substitutionCost,
        ].reduce((a, b) => a < b ? a : b);
      }
      for (var j = 0; j < previous.length; j += 1) {
        previous[j] = current[j];
      }
    }

    return previous.last;
  }

  List<String> _tokenize(String text) {
    final matches = RegExp(r'[\p{L}\p{N}]+', unicode: true).allMatches(text);
    return matches
        .map((match) => match.group(0)!)
        .where((term) => term.isNotEmpty)
        .toList(growable: false);
  }

  String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAllMapped(RegExp(r'[áàâäãå]'), (_) => 'a')
        .replaceAllMapped(RegExp(r'[éèêë]'), (_) => 'e')
        .replaceAllMapped(RegExp(r'[íìîï]'), (_) => 'i')
        .replaceAllMapped(RegExp(r'[óòôöõ]'), (_) => 'o')
        .replaceAllMapped(RegExp(r'[úùûü]'), (_) => 'u')
        .replaceAllMapped(RegExp(r'[ç]'), (_) => 'c')
        .replaceAllMapped(RegExp(r'[ñ]'), (_) => 'n');
  }

  String _snippetFor(String searchableText, String normalizedQuery) {
    final lowerText = searchableText.toLowerCase();
    final index = lowerText.indexOf(normalizedQuery.toLowerCase());
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

class _RankedMeetingResult {
  const _RankedMeetingResult({
    required this.meetingId,
    required this.score,
    required this.matchedTerm,
  });

  final String meetingId;
  final int score;
  final String matchedTerm;
}

class _TermScore {
  const _TermScore({required this.score, this.matchedTerm});

  final int score;
  final String? matchedTerm;
}
