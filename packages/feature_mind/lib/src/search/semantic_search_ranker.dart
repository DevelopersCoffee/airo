import 'dart:math' as math;

import 'package:core_ai/core_ai.dart';
import 'package:core_workers/core_workers.dart';

import '../whisper/api/meetings.dart' as rust;
import 'meeting_embedding_store.dart';
import 'meeting_text_chunker.dart';

/// Union of keyword + semantic hits, plus lexical/embedding provenance.
///
/// [hits] keep the product contract: keyword matches always survive.
/// [alignments] say when cosine disagrees with keyword (PM-05). Cosine is
/// not proof of relevance.
class SemanticRankResult {
  const SemanticRankResult({required this.hits, required this.alignments});

  final List<rust.SearchHit> hits;
  final List<RetrievalAlignment> alignments;

  bool get hasEmbeddingMismatch =>
      alignments.any((alignment) => alignment.isMismatch);
}

/// Adds semantic ranking on top of `searchMeetings`'s keyword hits.
///
/// **Union, never replacement**: every keyword hit is returned, regardless
/// of its semantic similarity to the query — a keyword match a query didn't
/// resemble semantically is still a real match
/// (`docs/superpowers/specs/2026-08-09-mind-scribe-semantic-search.md`).
/// Keyword hits are re-ordered by descending semantic score when vectors
/// exist; semantic-only matches (no keyword overlap) are appended after,
/// ranked by similarity, only when they clear [similarityThreshold].
///
/// Falls back to keyword-only, silently and correctly, when no embedding
/// model is installed — the expected common state before a user downloads
/// one, not an error condition this class treats specially.
///
/// Meetings are chunked before embedding (`MeetingTextChunker`) so long
/// transcripts fit EmbeddingGemma's `seq256` window. A meeting's score is
/// the **max** cosine similarity across its chunk vectors — one on-topic
/// chunk is enough to surface it.
class SemanticSearchRanker {
  SemanticSearchRanker({
    required EmbeddingService embeddingService,
    required MeetingEmbeddingStore embeddingStore,
    MeetingTextChunker chunker = const MeetingTextChunker(),
    this.similarityThreshold = 0.6,
    this.offMainCorpusSize = 32,
  }) : _embeddingService = embeddingService,
       _embeddingStore = embeddingStore,
       _chunker = chunker;

  final EmbeddingService _embeddingService;
  final MeetingEmbeddingStore _embeddingStore;
  final MeetingTextChunker _chunker;

  /// Cosine similarity (0–1) a semantic-only match must clear to appear.
  /// 0.6 is a starting point, not a value tuned against this app's own
  /// usage yet — revisit once there is real search history to measure
  /// against, the same "don't build ahead of evidence" stance the spec
  /// takes on skipping an ANN index.
  final double similarityThreshold;

  /// When at least this many meetings need cosine scoring, ranking runs via
  /// [runOffMain] so a large local corpus cannot stall the UI isolate.
  /// Embedding inference itself already leaves the main isolate through the
  /// native plugin's IO dispatcher.
  final int offMainCorpusSize;

  /// Ranks [meetings] against [query], returning [keywordHits] (re-ordered
  /// by semantic score when available) plus any semantically similar
  /// meeting not already among them.
  ///
  /// Optional [segmentTextsByMeetingId] feeds [MeetingTextChunker] the same
  /// ASR segment units the Rust transcript processor chunks. Absent for
  /// meetings that predate `#1629` Gap D — those fall back to flat text.
  Future<List<rust.SearchHit>> rank({
    required String query,
    required List<rust.SearchHit> keywordHits,
    required List<rust.MeetingRecord> meetings,
    Map<String, List<String>> segmentTextsByMeetingId = const {},
  }) async {
    final result = await rankWithAlignment(
      query: query,
      keywordHits: keywordHits,
      meetings: meetings,
      segmentTextsByMeetingId: segmentTextsByMeetingId,
    );
    return result.hits;
  }

  /// Same ranking as [rank], with retrieval vs embedding scores attached.
  Future<SemanticRankResult> rankWithAlignment({
    required String query,
    required List<rust.SearchHit> keywordHits,
    required List<rust.MeetingRecord> meetings,
    Map<String, List<String>> segmentTextsByMeetingId = const {},
  }) async {
    final queryResult = await _embeddingService.embed(
      query,
      taskType: EmbeddingTaskType.retrievalQuery,
    );
    if (!queryResult.isReady) {
      return SemanticRankResult(hits: keywordHits, alignments: const []);
    }
    final queryVector = queryResult.vector!;
    final activeModelId = queryResult.modelId!;

    final meetingsById = {for (final m in meetings) m.id: m};
    final keywordIds = keywordHits.map((hit) => hit.meetingId).toSet();

    final keywordCandidates = <_ScoredCandidate>[];
    for (final hit in keywordHits) {
      final meeting = meetingsById[hit.meetingId];
      final vectors = meeting == null
          ? null
          : await _vectorsFor(
              meeting,
              activeModelId: activeModelId,
              segmentTexts: segmentTextsByMeetingId[meeting.id] ?? const [],
            );
      keywordCandidates.add(
        _ScoredCandidate(
          meetingId: hit.meetingId,
          chunkVectors: vectors ?? const [],
          hit: hit,
          keywordMatched: true,
        ),
      );
    }

    final semanticCandidates = <_ScoredCandidate>[];
    for (final meeting in meetings) {
      if (keywordIds.contains(meeting.id)) continue;
      final vectors = await _vectorsFor(
        meeting,
        activeModelId: activeModelId,
        segmentTexts: segmentTextsByMeetingId[meeting.id] ?? const [],
      );
      if (vectors == null || vectors.isEmpty) continue;
      semanticCandidates.add(
        _ScoredCandidate(
          meetingId: meeting.id,
          chunkVectors: vectors,
          hit: _hitFor(meeting),
          keywordMatched: false,
        ),
      );
    }

    final keywordScored = List<(double, _ScoredCandidate)>.of(
      await _scoreCandidates(
        queryVector,
        keywordCandidates,
        applyThreshold: false,
      ),
    );
    keywordScored.sort((a, b) => b.$1.compareTo(a.$1));

    final semanticScored = List<(double, _ScoredCandidate)>.of(
      await _scoreCandidates(
        queryVector,
        semanticCandidates,
        applyThreshold: true,
      ),
    );
    semanticScored.sort((a, b) => b.$1.compareTo(a.$1));

    final ordered = [...keywordScored, ...semanticScored];
    return SemanticRankResult(
      hits: [for (final entry in ordered) entry.$2.hit],
      alignments: [
        for (final entry in ordered)
          RetrievalAlignment(
            meetingId: entry.$2.meetingId,
            keywordMatched: entry.$2.keywordMatched,
            semanticScore: entry.$1,
          ),
      ],
    );
  }

  /// Eagerly embeds [meeting] so a later [rank] call does not pay for it.
  ///
  /// Returns `false` when no embedding model is installed — the caller
  /// (Wave 2 Agent G / `MindService.indexMeetingForSearch`) treats that as
  /// "keyword search still works," not an error.
  Future<bool> indexMeeting(
    rust.MeetingRecord meeting, {
    List<String> segmentTexts = const [],
  }) async {
    final vectors = await _computeAndStore(meeting, segmentTexts: segmentTexts);
    return vectors != null;
  }

  Future<List<(double, _ScoredCandidate)>> _scoreCandidates(
    List<double> queryVector,
    List<_ScoredCandidate> candidates, {
    required bool applyThreshold,
  }) async {
    if (candidates.isEmpty) return <(double, _ScoredCandidate)>[];

    if (candidates.length < offMainCorpusSize) {
      final scored = <(double, _ScoredCandidate)>[];
      for (final candidate in candidates) {
        final similarity = candidate.chunkVectors.isEmpty
            ? 0.0
            : _maxCosineSimilarity(queryVector, candidate.chunkVectors);
        if (applyThreshold && similarity < similarityThreshold) continue;
        scored.add((similarity, candidate));
      }
      return scored;
    }

    final payload = (
      query: List<double>.from(queryVector),
      threshold: applyThreshold ? similarityThreshold : double.negativeInfinity,
      meetings: [
        for (final candidate in candidates)
          (
            id: candidate.meetingId,
            chunks: [
              for (final vector in candidate.chunkVectors)
                List<double>.from(vector),
            ],
          ),
      ],
    );

    final ranked = await runOffMain(() {
      final scored = <(double, String)>[];
      for (final meeting in payload.meetings) {
        final similarity = meeting.chunks.isEmpty
            ? 0.0
            : _maxCosineSimilarity(payload.query, meeting.chunks);
        if (similarity >= payload.threshold) {
          scored.add((similarity, meeting.id));
        }
      }
      return scored;
    });

    final byId = {for (final c in candidates) c.meetingId: c};
    return [
      for (final entry in ranked)
        if (byId.containsKey(entry.$2)) (entry.$1, byId[entry.$2]!),
    ];
  }

  Future<List<List<double>>?> _vectorsFor(
    rust.MeetingRecord meeting, {
    required String activeModelId,
    required List<String> segmentTexts,
  }) async {
    final stored = await _embeddingStore.get(meeting.id);
    if (stored != null && stored.modelId == activeModelId) {
      return stored.vectors;
    }

    return _computeAndStore(meeting, segmentTexts: segmentTexts);
  }

  Future<List<List<double>>?> _computeAndStore(
    rust.MeetingRecord meeting, {
    required List<String> segmentTexts,
  }) async {
    final chunks = _chunker.chunk(
      segments: segmentTexts,
      fallbackText: _embeddableText(meeting),
    );
    if (chunks.isEmpty) return null;

    final vectors = <List<double>>[];
    String? modelId;
    for (final chunk in chunks) {
      final result = await _embeddingService.embed(
        chunk.text,
        taskType: EmbeddingTaskType.retrievalDocument,
      );
      if (!result.isReady) return null;
      modelId = result.modelId;
      vectors.add(result.vector!);
    }

    await _embeddingStore.putChunks(meeting.id, modelId!, vectors);
    return vectors;
  }

  /// The text embedded and cached per meeting when segments are unavailable.
  ///
  /// `ADR-0022 §3`: extends `'${transcript} ${minutes}'` with the same IR
  /// text `SearchIndex::insert` (`rust/airo_mind_core/src/search.rs`) feeds
  /// its lexical index -- decision statements and action-item task/owner
  /// text -- one extra string concatenated into the same embed path, not a
  /// second embedding pipeline. Metrics are not included, matching the FTS
  /// extension's scope exactly.
  String _embeddableText(rust.MeetingRecord meeting) {
    final parts = [meeting.transcript, meeting.minutes];
    for (final decision in meeting.decisions) {
      parts.add(decision.statement);
    }
    for (final item in meeting.actionItems) {
      final owner = item.owner;
      parts.add(owner == null ? item.task : '${item.task} $owner');
    }
    return parts.join(' ').trim();
  }

  static const _maxSnippetLength = 160;

  rust.SearchHit _hitFor(rust.MeetingRecord meeting) {
    final source = _snippetSource(meeting);
    final snippet = source.length > _maxSnippetLength
        ? '${source.substring(0, _maxSnippetLength)}…'
        : source;
    return rust.SearchHit(
      meetingId: meeting.id,
      title: meeting.title,
      recordedAt: meeting.recordedAt,
      snippet: snippet,
    );
  }

  /// Prefer minutes, then first action/decision, then transcript — same cheap
  /// order as the meeting list preview so IR-only meetings still show why
  /// they matched.
  String _snippetSource(rust.MeetingRecord meeting) {
    final minutes = meeting.minutes.trim();
    if (minutes.isNotEmpty) return minutes;
    if (meeting.actionItems.isNotEmpty) {
      return meeting.actionItems.first.task.trim();
    }
    if (meeting.decisions.isNotEmpty) {
      return meeting.decisions.first.statement.trim();
    }
    return meeting.transcript.trim();
  }
}

class _ScoredCandidate {
  const _ScoredCandidate({
    required this.meetingId,
    required this.chunkVectors,
    required this.hit,
    required this.keywordMatched,
  });

  final String meetingId;
  final List<List<double>> chunkVectors;
  final rust.SearchHit hit;
  final bool keywordMatched;
}

/// Max cosine similarity of [query] against any vector in [chunks].
///
/// Top-level so [runOffMain] / `Isolate.run` can invoke it without capturing
/// instance state.
double _maxCosineSimilarity(List<double> query, List<List<double>> chunks) {
  var best = 0.0;
  for (final chunk in chunks) {
    final score = _cosineSimilarity(query, chunk);
    if (score > best) best = score;
  }
  return best;
}

double _cosineSimilarity(List<double> a, List<double> b) {
  if (a.isEmpty || a.length != b.length) return 0;
  var dot = 0.0;
  var normA = 0.0;
  var normB = 0.0;
  for (var i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    normA += a[i] * a[i];
    normB += b[i] * b[i];
  }
  if (normA == 0 || normB == 0) return 0;
  return dot / (math.sqrt(normA) * math.sqrt(normB));
}
