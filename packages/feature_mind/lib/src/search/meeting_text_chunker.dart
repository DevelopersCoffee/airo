import 'package:flutter/foundation.dart';

/// One text window ready to embed for semantic search.
///
/// Sized for EmbeddingGemma's `seq256` context
/// (`docs/superpowers/specs/2026-08-09-mind-scribe-semantic-search.md`): a
/// single whole-meeting embed truncates long transcripts, so topics that
/// appear after the first ~256 tokens never enter the vector. Chunking
/// keeps each window short enough to fit, and overlapping windows keep a
/// fact that sits on a boundary inside at least one chunk.
@immutable
class MeetingTextChunk {
  const MeetingTextChunk({required this.id, required this.text});

  final String id;
  final String text;
}

/// Splits meeting text into overlapping windows for [EmbeddingService].
///
/// Prefers ASR [segments] when present (the same evidence units
/// `airo_mind_transcript`'s chunker consumes in Rust — no FFI to that crate
/// yet, so this is a Dart-side reuse of the segment list, not a second
/// algorithm invented from scratch). Falls back to paragraph/sentence
/// windows over [fallbackText] when segments are empty.
///
/// Pure and isolate-safe: no I/O, no Flutter bindings beyond `@immutable`.
class MeetingTextChunker {
  const MeetingTextChunker({
    this.maxChars = 700,
    this.overlapChars = 120,
  });

  /// Soft ceiling per chunk. ~700 Latin characters is comfortably under
  /// EmbeddingGemma's 256-token window for English meeting prose; keep it
  /// conservative rather than packing to the hard limit.
  final int maxChars;

  /// Characters of previous-chunk tail prepended to the next chunk so a
  /// topic straddling a boundary is not lost.
  final int overlapChars;

  /// Builds embeddable chunks from [segments] and/or [fallbackText].
  ///
  /// Empty input yields an empty list — callers treat that as "nothing to
  /// embed," not an error.
  List<MeetingTextChunk> chunk({
    List<String> segments = const [],
    String fallbackText = '',
  }) {
    final cleanedSegments = [
      for (final segment in segments)
        if (segment.trim().isNotEmpty) segment.trim(),
    ];
    if (cleanedSegments.isNotEmpty) {
      return _chunkParts(cleanedSegments);
    }

    final text = fallbackText.trim();
    if (text.isEmpty) return const [];

    final parts = _splitFallback(text);
    return _chunkParts(parts);
  }

  List<MeetingTextChunk> _chunkParts(List<String> parts) {
    final chunks = <MeetingTextChunk>[];
    var start = 0;
    var chunkNo = 0;

    while (start < parts.length) {
      final buffer = StringBuffer();
      var end = start;
      while (end < parts.length) {
        final piece = parts[end];
        final nextLength =
            buffer.length + (buffer.isEmpty ? 0 : 1) + piece.length;
        if (buffer.isNotEmpty && nextLength > maxChars) break;
        if (buffer.isNotEmpty) buffer.write(' ');
        buffer.write(piece);
        end++;
        if (buffer.length >= maxChars) break;
      }

      final text = buffer.toString().trim();
      if (text.isNotEmpty) {
        chunks.add(MeetingTextChunk(id: 'chunk-$chunkNo', text: text));
        chunkNo++;
      }

      if (end >= parts.length) break;

      // Walk back ~overlapChars of content for the next window start.
      var overlapBudget = overlapChars;
      var nextStart = end;
      while (nextStart > start + 1 && overlapBudget > 0) {
        nextStart--;
        overlapBudget -= parts[nextStart].length + 1;
      }
      start = nextStart <= start ? start + 1 : nextStart;
    }

    return chunks;
  }

  /// Paragraphs first, then sentences, then hard splits — enough structure
  /// for a flat transcript/minutes string without inventing a second
  /// semantic-boundary heuristic beyond what segments already give us.
  List<String> _splitFallback(String text) {
    final paragraphs = text
        .split(RegExp(r'\n\s*\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    final parts = <String>[];
    for (final paragraph in paragraphs) {
      if (paragraph.length <= maxChars) {
        parts.add(paragraph);
        continue;
      }
      final sentences = paragraph
          .split(RegExp(r'(?<=[.!?])\s+'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty);
      for (final sentence in sentences) {
        if (sentence.length <= maxChars) {
          parts.add(sentence);
          continue;
        }
        for (var i = 0; i < sentence.length; i += maxChars) {
          final end = (i + maxChars).clamp(0, sentence.length);
          parts.add(sentence.substring(i, end));
        }
      }
    }
    return parts;
  }
}
