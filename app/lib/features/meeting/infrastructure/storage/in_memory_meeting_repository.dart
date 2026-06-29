import '../../domain/entities/meeting_intelligence.dart';
import '../../domain/entities/meeting_record.dart';
import '../../domain/entities/meeting_summary.dart';
import '../../domain/entities/transcript_chunk.dart';
import '../../domain/repositories/meeting_repository.dart';

class InMemoryMeetingRepository implements MeetingRepository {
  final Map<String, MeetingRecord> _records = {};
  final Map<String, List<TranscriptChunk>> _chunksByMeeting = {};
  final Map<String, MeetingSummary> _summaries = {};
  final Map<String, _MeetingSearchDocument> _searchDocsByMeeting = {};

  @override
  Future<void> saveIntelligence(MeetingIntelligenceDraft draft) async {
    _records[draft.record.id] = draft.record;
    _chunksByMeeting[draft.record.id] = List.unmodifiable(draft.redactedChunks);
    _summaries[draft.record.id] = draft.summary;
    _searchDocsByMeeting[draft.record.id] = _MeetingSearchDocument.fromDraft(
      draft,
    );
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
    final queryTerms = _expandQueryTerms(normalizedQuery);
    if (normalizedQuery.isEmpty || queryTerms.isEmpty) {
      return const [];
    }

    final matches = _searchDocsByMeeting.entries
        .map((entry) {
          final doc = entry.value;
          final score = _scoreMatch(doc, normalizedQuery, queryTerms);
          if (score == 0) {
            return null;
          }

          final record = _records[entry.key];
          return (
            score: score,
            record: record,
            result: MeetingSearchResult(
              meetingId: entry.key,
              title: record?.title ?? 'Untitled meeting',
              snippet: _snippetFor(doc, normalizedQuery, queryTerms),
            ),
          );
        })
        .whereType<({
          int score,
          MeetingRecord? record,
          MeetingSearchResult result,
        })>()
        .toList(growable: false);

    matches.sort((a, b) {
      final scoreCompare = b.score.compareTo(a.score);
      if (scoreCompare != 0) return scoreCompare;

      final aStartedAt = a.record?.startedAt;
      final bStartedAt = b.record?.startedAt;
      if (aStartedAt != null && bStartedAt != null) {
        return bStartedAt.compareTo(aStartedAt);
      }
      return a.result.meetingId.compareTo(b.result.meetingId);
    });

    return matches.take(50).map((match) => match.result).toList(growable: false);
  }

  int _scoreMatch(
    _MeetingSearchDocument doc,
    String normalizedQuery,
    Set<String> queryTerms,
  ) {
    var score = 0;

    if (doc.normalizedTitle.contains(normalizedQuery)) score += 12;
    if (doc.normalizedSpeakers.contains(normalizedQuery)) score += 10;
    if (doc.normalizedBody.contains(normalizedQuery)) score += 8;
    if (doc.normalizedLanguageCode.contains(normalizedQuery)) score += 4;

    for (final queryTerm in queryTerms) {
      if (doc.tokens.contains(queryTerm)) {
        score += 6;
        continue;
      }
      if (doc.tokens.any((token) => _isFuzzyMatch(token, queryTerm))) {
        score += 3;
      }
    }

    return score;
  }

  String _snippetFor(
    _MeetingSearchDocument doc,
    String normalizedQuery,
    Set<String> queryTerms,
  ) {
    final lowerText = _normalize(doc.searchableText);
    var index = lowerText.indexOf(normalizedQuery);
    if (index < 0) {
      for (final term in queryTerms) {
        index = lowerText.indexOf(term);
        if (index >= 0) break;
      }
    }
    if (index < 0) {
      return doc.searchableText.length <= 120
          ? doc.searchableText
          : doc.searchableText.substring(0, 120);
    }

    final start = index - 40 < 0 ? 0 : index - 40;
    final end = index + normalizedQuery.length + 40;
    return doc.searchableText.substring(
      start,
      end > doc.searchableText.length ? doc.searchableText.length : end,
    );
  }

  Set<String> _expandQueryTerms(String normalizedQuery) {
    final terms = _tokenize(normalizedQuery).toSet();
    final expanded = <String>{...terms};
    for (final term in terms) {
      expanded.addAll(_synonyms[term] ?? const <String>{});
    }
    return expanded;
  }

  bool _isFuzzyMatch(String token, String queryTerm) {
    if (token == queryTerm) return true;
    if (token.length < 4 || queryTerm.length < 4) return false;
    if ((token.length - queryTerm.length).abs() > 1) return false;
    return _editDistance(token, queryTerm) <= 1;
  }

  int _editDistance(String a, String b) {
    final rows = List.generate(
      a.length + 1,
      (index) => List<int>.filled(b.length + 1, 0),
    );
    for (var i = 0; i <= a.length; i++) {
      rows[i][0] = i;
    }
    for (var j = 0; j <= b.length; j++) {
      rows[0][j] = j;
    }

    for (var i = 1; i <= a.length; i++) {
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        rows[i][j] = [
          rows[i - 1][j] + 1,
          rows[i][j - 1] + 1,
          rows[i - 1][j - 1] + cost,
        ].reduce((left, right) => left < right ? left : right);
      }
    }

    return rows[a.length][b.length];
  }

  static final Map<String, Set<String>> _synonyms = {
    'project': {'proj', 'initiative'},
    'proj': {'project', 'initiative'},
    'roadmap': {'plan'},
    'plan': {'roadmap'},
    'decision': {'decide'},
    'decide': {'decision'},
    'action': {'todo', 'task'},
    'todo': {'action', 'task'},
    'task': {'action', 'todo'},
  };

  String _normalize(String value) {
    return _stripDiacritics(value)
        .toLowerCase()
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]+', unicode: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  List<String> _tokenize(String value) {
    return _normalize(value)
        .split(' ')
        .where((token) => token.isNotEmpty)
        .toList(growable: false);
  }

  String _stripDiacritics(String input) {
    const replacements = {
      'á': 'a',
      'à': 'a',
      'ä': 'a',
      'â': 'a',
      'ã': 'a',
      'å': 'a',
      'é': 'e',
      'è': 'e',
      'ë': 'e',
      'ê': 'e',
      'í': 'i',
      'ì': 'i',
      'ï': 'i',
      'î': 'i',
      'ó': 'o',
      'ò': 'o',
      'ö': 'o',
      'ô': 'o',
      'õ': 'o',
      'ú': 'u',
      'ù': 'u',
      'ü': 'u',
      'û': 'u',
      'ñ': 'n',
      'ç': 'c',
    };

    final buffer = StringBuffer();
    for (final rune in input.runes) {
      final char = String.fromCharCode(rune);
      buffer.write(replacements[char] ?? char);
    }
    return buffer.toString();
  }
}

class _MeetingSearchDocument {
  const _MeetingSearchDocument({
    required this.searchableText,
    required this.normalizedTitle,
    required this.normalizedBody,
    required this.normalizedSpeakers,
    required this.normalizedLanguageCode,
    required this.tokens,
  });

  factory _MeetingSearchDocument.fromDraft(MeetingIntelligenceDraft draft) {
    final repo = InMemoryMeetingRepository();
    final speakers = draft.redactedChunks
        .map((chunk) => chunk.speakerLabel?.trim())
        .whereType<String>()
        .where((label) => label.isNotEmpty)
        .toSet()
        .join(' ');
    final title = draft.record.title;
    final body = draft.searchableText;
    final languageCode = draft.record.languageCode ?? '';
    final aggregate = '$title $speakers $languageCode $body';
    return _MeetingSearchDocument(
      searchableText: body,
      normalizedTitle: repo._normalize(title),
      normalizedBody: repo._normalize(body),
      normalizedSpeakers: repo._normalize(speakers),
      normalizedLanguageCode: repo._normalize(languageCode),
      tokens: repo._tokenize(aggregate).toSet(),
    );
  }

  final String searchableText;
  final String normalizedTitle;
  final String normalizedBody;
  final String normalizedSpeakers;
  final String normalizedLanguageCode;
  final Set<String> tokens;
}
