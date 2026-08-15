import 'package:flutter/foundation.dart';

import '../bridges/mind_speech_bridge.dart';
import '../whisper/api/meetings.dart' as rust;

/// Resolves Meeting-IR evidence segment ids against a transcript document
/// (`ADR-0022 §4`). Pure lookup — no I/O.
@immutable
class EvidenceHit {
  const EvidenceHit({
    required this.segmentId,
    required this.startMs,
    required this.endMs,
    required this.text,
  });

  final String segmentId;
  final int startMs;
  final int endMs;
  final String text;
}

/// Maps `evidenceSegmentIds` → transcript segments for highlighting / seek.
class EvidenceResolver {
  const EvidenceResolver();

  /// Builds an id → segment index from a structured transcript document.
  Map<String, TranscriptSegment> indexFromDocument(
    rust.TranscriptDocumentRecord? doc,
  ) {
    if (doc == null) return const {};
    return {for (final s in doc.segments) s.id: toTranscriptSegment(s)};
  }

  /// Builds an id → segment index from in-memory [TranscriptSegment]s
  /// (live processing before `transcript.json` exists).
  Map<String, TranscriptSegment> indexFromSegments(
    List<TranscriptSegment> segments,
  ) => {for (final s in segments) s.id: s};

  /// Resolves [evidenceSegmentIds] in order, skipping unknown ids.
  List<EvidenceHit> resolve({
    required List<String> evidenceSegmentIds,
    required Map<String, TranscriptSegment> byId,
  }) {
    final hits = <EvidenceHit>[];
    for (final id in evidenceSegmentIds) {
      final segment = byId[id];
      if (segment == null) continue;
      hits.add(
        EvidenceHit(
          segmentId: id,
          startMs: segment.startMs,
          endMs: segment.endMs,
          text: segment.text,
        ),
      );
    }
    return hits;
  }

  /// First hit's start ms — for optional audio seek. Null when unresolved.
  int? firstStartMs({
    required List<String> evidenceSegmentIds,
    required Map<String, TranscriptSegment> byId,
  }) {
    final hits = resolve(evidenceSegmentIds: evidenceSegmentIds, byId: byId);
    return hits.isEmpty ? null : hits.first.startMs;
  }
}
