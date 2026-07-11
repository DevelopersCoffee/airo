import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../../core/database/app_database_native.dart' as db;
import '../../domain/entities/meeting_audio_metadata.dart' as domain_audio;
import '../../domain/entities/meeting_intelligence.dart';
import '../../domain/entities/meeting_record.dart' as domain_record;
import '../../domain/entities/meeting_summary.dart' as domain_summary;
import '../../domain/entities/transcript_chunk.dart' as domain_transcript;
import '../../domain/repositories/meeting_repository.dart';
import '../../domain/services/meeting_redaction_service.dart';

class DriftMeetingRepository implements MeetingRepository {
  DriftMeetingRepository(this._db, {MeetingRedactionService? redactionService})
    : _redactionService = redactionService ?? MeetingRedactionService();

  final db.AppDatabase _db;
  final MeetingRedactionService _redactionService;

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
    final meetingId = draft.record.id;
    final redactedChunks = draft.redactedChunks
        .where((chunk) => chunk.isFinal)
        .map(_redactChunk)
        .toList(growable: false);
    final redactedSummary = _redactSummary(draft.summary);
    final redactedSearchableText = _redactionService.redact(
      [
        draft.searchableText,
        for (final chunk in redactedChunks) chunk.text,
      ].where((text) => text.trim().isNotEmpty).join('\n'),
    );

    await _db.transaction(() async {
      await _db
          .into(_db.meetingRecords)
          .insertOnConflictUpdate(
            db.MeetingRecordsCompanion.insert(
              id: draft.record.id,
              title: draft.record.title,
              startedAt: draft.record.startedAt,
              endedAt: Value(draft.record.endedAt),
              durationMs: Value(_durationMs(draft.record)),
              state: draft.record.state.name,
              languageCode: draft.record.languageCode ?? '',
            ),
          );

      await (_db.delete(
        _db.meetingEmbeddings,
      )..where((row) => row.meetingId.equals(meetingId))).go();
      await (_db.delete(
        _db.meetingAudioMetadata,
      )..where((row) => row.meetingId.equals(meetingId))).go();
      await (_db.delete(
        _db.meetingSummaries,
      )..where((row) => row.meetingId.equals(meetingId))).go();
      await (_db.delete(
        _db.meetingActionItems,
      )..where((row) => row.meetingId.equals(meetingId))).go();
      await (_db.delete(
        _db.transcriptChunks,
      )..where((row) => row.meetingId.equals(meetingId))).go();
      await (_db.delete(
        _db.meetingSegments,
      )..where((row) => row.meetingId.equals(meetingId))).go();

      for (final chunk in redactedChunks) {
        await _db
            .into(_db.meetingSegments)
            .insert(
              db.MeetingSegmentsCompanion.insert(
                id: chunk.id,
                meetingId: chunk.meetingId,
                speakerLabel: Value(chunk.speakerLabel),
                startMs: chunk.startMs,
                endMs: chunk.endMs,
              ),
            );
        await _db
            .into(_db.transcriptChunks)
            .insert(
              db.TranscriptChunksCompanion.insert(
                id: chunk.id,
                meetingId: chunk.meetingId,
                segmentId: Value(chunk.id),
                transcriptText: chunk.text,
                startMs: chunk.startMs,
                endMs: chunk.endMs,
                isFinal: chunk.isFinal,
                speakerLabel: Value(chunk.speakerLabel),
                confidence: Value(chunk.confidence),
              ),
            );
      }

      for (final actionItem in redactedSummary.actionItems) {
        await _db
            .into(_db.meetingActionItems)
            .insert(
              db.MeetingActionItemsCompanion.insert(
                id: actionItem.id,
                meetingId: actionItem.meetingId,
                owner: Value(actionItem.owner),
                description: actionItem.description,
                dueDateText: Value(actionItem.dueDateText),
                isCompleted: Value(actionItem.isCompleted),
              ),
            );
      }

      await _db
          .into(_db.meetingSummaries)
          .insert(
            db.MeetingSummariesCompanion.insert(
              meetingId: redactedSummary.meetingId,
              executiveSummary: redactedSummary.executiveSummary,
              detailedSummary: redactedSummary.detailedSummary,
              keyDecisionsJson: _encodeStringList(redactedSummary.keyDecisions),
              risksJson: _encodeStringList(redactedSummary.risks),
              openQuestionsJson: _encodeStringList(
                redactedSummary.openQuestions,
              ),
              followUpsJson: _encodeStringList(redactedSummary.followUps),
              blockersJson: _encodeStringList(redactedSummary.blockers),
              dependenciesJson: _encodeStringList(redactedSummary.dependencies),
              nextStepsJson: _encodeStringList(redactedSummary.nextSteps),
              isCloudSyncEligible: const Value(false),
            ),
          );

      await _db
          .into(_db.meetingAudioMetadata)
          .insert(
            db.MeetingAudioMetadataCompanion.insert(
              meetingId: draft.audioMetadata.meetingId,
              filePath: draft.audioMetadata.filePath,
              codec: draft.audioMetadata.codec,
              sampleRateHz: draft.audioMetadata.sampleRateHz,
              channelCount: draft.audioMetadata.channelCount,
              sizeBytes: draft.audioMetadata.sizeBytes,
              sha256: Value(draft.audioMetadata.sha256),
            ),
          );

      await _db
          .into(_db.meetingEmbeddings)
          .insert(
            db.MeetingEmbeddingsCompanion.insert(
              id: '$meetingId-search',
              meetingId: meetingId,
              chunkId: const Value.absent(),
              dimensions: 0,
              vectorJson: '[]',
              searchableText: redactedSearchableText,
            ),
          );
    });
  }

  @override
  Future<domain_record.MeetingRecord?> meetingById(String meetingId) async {
    final row = await (_db.select(
      _db.meetingRecords,
    )..where((record) => record.id.equals(meetingId))).getSingleOrNull();
    if (row == null) return null;
    return _recordFromRow(row);
  }

  @override
  Future<List<domain_transcript.TranscriptChunk>> transcriptChunksForMeeting(
    String meetingId,
  ) async {
    final rows =
        await (_db.select(_db.transcriptChunks)
              ..where((chunk) => chunk.meetingId.equals(meetingId))
              ..orderBy([
                (chunk) => OrderingTerm(expression: chunk.startMs),
                (chunk) => OrderingTerm(expression: chunk.endMs),
                (chunk) => OrderingTerm(expression: chunk.id),
              ]))
            .get();
    return rows.map(_chunkFromRow).toList(growable: false);
  }

  @override
  Future<domain_summary.MeetingSummary?> summaryForMeeting(
    String meetingId,
  ) async {
    final summaryRow =
        await (_db.select(_db.meetingSummaries)
              ..where((summary) => summary.meetingId.equals(meetingId)))
            .getSingleOrNull();
    if (summaryRow == null) return null;

    final actionRows =
        await (_db.select(_db.meetingActionItems)
              ..where((action) => action.meetingId.equals(meetingId))
              ..orderBy([(action) => OrderingTerm(expression: action.id)]))
            .get();

    return domain_summary.MeetingSummary(
      meetingId: summaryRow.meetingId,
      executiveSummary: summaryRow.executiveSummary,
      detailedSummary: summaryRow.detailedSummary,
      actionItems: actionRows.map(_actionItemFromRow).toList(growable: false),
      keyDecisions: _decodeStringList(summaryRow.keyDecisionsJson),
      risks: _decodeStringList(summaryRow.risksJson),
      openQuestions: _decodeStringList(summaryRow.openQuestionsJson),
      followUps: _decodeStringList(summaryRow.followUpsJson),
      blockers: _decodeStringList(summaryRow.blockersJson),
      dependencies: _decodeStringList(summaryRow.dependenciesJson),
      nextSteps: _decodeStringList(summaryRow.nextStepsJson),
      isCloudSyncEligible: summaryRow.isCloudSyncEligible,
    );
  }

  @override
  Future<domain_audio.MeetingAudioMetadata?> audioMetadataForMeeting(
    String meetingId,
  ) async {
    final row = await (_db.select(
      _db.meetingAudioMetadata,
    )..where((audio) => audio.meetingId.equals(meetingId))).getSingleOrNull();
    if (row == null) return null;
    return domain_audio.MeetingAudioMetadata(
      meetingId: row.meetingId,
      filePath: row.filePath,
      codec: row.codec,
      sampleRateHz: row.sampleRateHz,
      channelCount: row.channelCount,
      sizeBytes: row.sizeBytes,
      sha256: row.sha256 ?? '',
    );
  }

  @override
  Future<List<MeetingSearchResult>> searchMeetings(String query) async {
    final queryTerms = _tokenize(_normalize(query));
    if (queryTerms.isEmpty) return const [];

    final records = await _db.select(_db.meetingRecords).get();
    final chunks = await _db.select(_db.transcriptChunks).get();
    final embeddings = await _db.select(_db.meetingEmbeddings).get();

    final recordsById = {for (final record in records) record.id: record};
    final chunksByMeeting = <String, List<db.TranscriptChunk>>{};
    for (final chunk in chunks) {
      chunksByMeeting.putIfAbsent(chunk.meetingId, () => []).add(chunk);
    }
    final searchableTextByMeeting = {
      for (final embedding in embeddings)
        embedding.meetingId: embedding.searchableText,
    };

    final ranked =
        records
            .map(
              (record) => _rankEntry(
                record.id,
                queryTerms,
                recordsById,
                chunksByMeeting,
                searchableTextByMeeting,
              ),
            )
            .whereType<_RankedMeetingResult>()
            .toList(growable: false)
          ..sort((left, right) {
            final scoreCompare = right.score.compareTo(left.score);
            if (scoreCompare != 0) return scoreCompare;

            final leftRecord = recordsById[left.meetingId];
            final rightRecord = recordsById[right.meetingId];
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
          final record = recordsById[result.meetingId];
          final searchableText =
              searchableTextByMeeting[result.meetingId] ?? '';
          return MeetingSearchResult(
            meetingId: result.meetingId,
            title: record?.title ?? 'Untitled meeting',
            snippet: _snippetFor(searchableText, result.matchedTerm),
          );
        })
        .toList(growable: false);
  }

  domain_transcript.TranscriptChunk _redactChunk(
    domain_transcript.TranscriptChunk chunk,
  ) {
    return chunk.copyWith(
      text: _redactionService.redact(chunk.text),
      redactionStatus: domain_transcript.TranscriptRedactionStatus.redacted,
    );
  }

  domain_summary.MeetingSummary _redactSummary(
    domain_summary.MeetingSummary summary,
  ) {
    return domain_summary.MeetingSummary(
      meetingId: summary.meetingId,
      executiveSummary: _redactionService.redact(summary.executiveSummary),
      detailedSummary: _redactionService.redact(summary.detailedSummary),
      actionItems: summary.actionItems
          .map(
            (action) => domain_summary.MeetingActionItem(
              id: action.id,
              meetingId: action.meetingId,
              owner: action.owner == null
                  ? null
                  : _redactionService.redact(action.owner!),
              description: _redactionService.redact(action.description),
              dueDateText: action.dueDateText == null
                  ? null
                  : _redactionService.redact(action.dueDateText!),
              isCompleted: action.isCompleted,
            ),
          )
          .toList(growable: false),
      keyDecisions: _redactList(summary.keyDecisions),
      risks: _redactList(summary.risks),
      openQuestions: _redactList(summary.openQuestions),
      followUps: _redactList(summary.followUps),
      blockers: _redactList(summary.blockers),
      dependencies: _redactList(summary.dependencies),
      nextSteps: _redactList(summary.nextSteps),
      isCloudSyncEligible: false,
    );
  }

  List<String> _redactList(List<String> values) {
    return values.map(_redactionService.redact).toList(growable: false);
  }

  int? _durationMs(domain_record.MeetingRecord record) {
    final endedAt = record.endedAt;
    if (endedAt == null) return null;
    return endedAt.difference(record.startedAt).inMilliseconds;
  }

  domain_record.MeetingRecord _recordFromRow(db.MeetingRecord row) {
    return domain_record.MeetingRecord(
      id: row.id,
      title: row.title,
      startedAt: row.startedAt.toUtc(),
      endedAt: row.endedAt?.toUtc(),
      state: domain_record.MeetingState.values.byName(row.state),
      languageCode: row.languageCode,
    );
  }

  domain_transcript.TranscriptChunk _chunkFromRow(db.TranscriptChunk row) {
    return domain_transcript.TranscriptChunk(
      id: row.id,
      meetingId: row.meetingId,
      text: row.transcriptText,
      startMs: row.startMs,
      endMs: row.endMs,
      isFinal: row.isFinal,
      speakerLabel: row.speakerLabel,
      confidence: row.confidence,
      redactionStatus: domain_transcript.TranscriptRedactionStatus.redacted,
    );
  }

  domain_summary.MeetingActionItem _actionItemFromRow(
    db.MeetingActionItem row,
  ) {
    return domain_summary.MeetingActionItem(
      id: row.id,
      meetingId: row.meetingId,
      owner: row.owner,
      description: row.description,
      dueDateText: row.dueDateText,
      isCompleted: row.isCompleted,
    );
  }

  String _encodeStringList(List<String> values) => jsonEncode(values);

  List<String> _decodeStringList(String encoded) {
    final decoded = jsonDecode(encoded);
    if (decoded is! List) return const [];
    return decoded.whereType<String>().toList(growable: false);
  }

  _RankedMeetingResult? _rankEntry(
    String meetingId,
    List<String> queryTerms,
    Map<String, db.MeetingRecord> recordsById,
    Map<String, List<db.TranscriptChunk>> chunksByMeeting,
    Map<String, String> searchableTextByMeeting,
  ) {
    final record = recordsById[meetingId];
    final chunks = chunksByMeeting[meetingId] ?? const <db.TranscriptChunk>[];
    final searchableText = searchableTextByMeeting[meetingId] ?? '';

    final searchCorpus = _normalize(
      [
        record?.title ?? '',
        searchableText,
        for (final chunk in chunks) chunk.speakerLabel ?? '',
        for (final chunk in chunks) chunk.transcriptText,
      ].where((part) => part.trim().isNotEmpty).join('\n'),
    );
    final corpusTerms = _tokenize(searchCorpus);
    if (corpusTerms.isEmpty) return null;

    var score = 0;
    String? matchedTerm;

    for (final queryTerm in queryTerms) {
      final termScore = _scoreQueryTerm(queryTerm, corpusTerms);
      if (termScore.score == 0) return null;
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
