import 'dart:math' as math;

import 'package:core_ai/core_ai.dart';

import '../whisper/api/meetings.dart' as rust;
import 'meeting_embedding_store.dart';

/// Adds semantic ranking on top of `searchMeetings`'s keyword hits.
///
/// **Union, never replacement**: every keyword hit is returned, regardless
/// of its semantic similarity to the query — a keyword match a query didn't
/// resemble semantically is still a real match
/// (`docs/superpowers/specs/2026-08-09-mind-scribe-semantic-search.md`).
/// Semantic-only matches (no keyword overlap) are appended after, ranked by
/// similarity, only when they clear [similarityThreshold].
///
/// Falls back to keyword-only, silently and correctly, when no embedding
/// model is installed — the expected common state before a user downloads
/// one, not an error condition this class treats specially.
class SemanticSearchRanker {
  SemanticSearchRanker({
    required EmbeddingService embeddingService,
    required MeetingEmbeddingStore embeddingStore,
    this.similarityThreshold = 0.6,
  }) : _embeddingService = embeddingService,
       _embeddingStore = embeddingStore;

  final EmbeddingService _embeddingService;
  final MeetingEmbeddingStore _embeddingStore;

  /// Cosine similarity (0–1) a semantic-only match must clear to appear.
  /// 0.6 is a starting point, not a value tuned against this app's own
  /// usage yet — revisit once there is real search history to measure
  /// against, the same "don't build ahead of evidence" stance the spec
  /// takes on skipping an ANN index.
  final double similarityThreshold;

  /// Ranks [meetings] against [query], returning [keywordHits] plus any
  /// semantically similar meeting not already among them.
  ///
  /// Embeddings for meetings not yet in [MeetingEmbeddingStore] are computed
  /// here, lazily, and cached for next time — there is no separate
  /// save-time indexing step yet. That means the search *after* recording a
  /// new meeting pays for embedding it; a background/save-time job would
  /// remove that cost, and is a reasonable follow-up once this is real
  /// usage, not a v1 requirement.
  Future<List<rust.SearchHit>> rank({
    required String query,
    required List<rust.SearchHit> keywordHits,
    required List<rust.MeetingRecord> meetings,
  }) async {
    final queryResult = await _embeddingService.embed(query);
    if (!queryResult.isReady) return keywordHits;
    final queryVector = queryResult.vector!;

    final keywordIds = keywordHits.map((hit) => hit.meetingId).toSet();
    final scored = <(double similarity, rust.SearchHit hit)>[];

    for (final meeting in meetings) {
      if (keywordIds.contains(meeting.id)) continue;

      final vector = await _vectorFor(meeting);
      if (vector == null) continue;

      final similarity = _cosineSimilarity(queryVector, vector);
      if (similarity < similarityThreshold) continue;

      scored.add((similarity, _hitFor(meeting)));
    }

    scored.sort((a, b) => b.$1.compareTo(a.$1));
    return [...keywordHits, for (final entry in scored) entry.$2];
  }

  Future<List<double>?> _vectorFor(rust.MeetingRecord meeting) async {
    final stored = await _embeddingStore.get(meeting.id);
    if (stored != null) return stored.vector;

    final text = _embeddableText(meeting);
    if (text.isEmpty) return null;

    final result = await _embeddingService.embed(text);
    if (!result.isReady) return null;

    await _embeddingStore.put(meeting.id, result.modelId!, result.vector!);
    return result.vector;
  }

  /// The text embedded and cached per meeting.
  ///
  /// `ADR-0022 §3`: extends `'${transcript} ${minutes}'` with the same IR
  /// text `SearchIndex::insert` (`rust/airo_mind_core/src/search.rs`) feeds
  /// its lexical index -- decision statements and action-item task/owner
  /// text -- one extra string concatenated into the same embed call, not a
  /// second embedding path. Metrics are not included, matching the FTS
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
    final source = meeting.minutes.trim().isNotEmpty
        ? meeting.minutes.trim()
        : meeting.transcript.trim();
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
}
