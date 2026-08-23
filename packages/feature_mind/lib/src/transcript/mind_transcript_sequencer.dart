import 'package:flutter/foundation.dart';

/// Streaming transcript phases (spec §4). `partial` is a frequently-changing
/// hypothesis, `stable` should not be rewritten during normal streaming, and
/// `finalized` is a committed segment.
enum TranscriptPhase {
  partial,
  stable,
  finalized;

  /// Ordered so a segment may only advance, never regress.
  int get rank => index;

  /// Maps the Rust wire enum name (`partial` / `stable` / `final_`) without
  /// importing the generated bridge, keeping this a pure domain utility.
  static TranscriptPhase fromWireName(String name) => switch (name) {
    'partial' => TranscriptPhase.partial,
    'stable' => TranscriptPhase.stable,
    'final_' || 'final' || 'finalized' => TranscriptPhase.finalized,
    _ => throw ArgumentError('Unknown transcript phase: $name'),
  };
}

/// An incoming transcript update, before sequencing. This is the platform-
/// neutral shape the sequencer consumes; adapters map `TranscriptDelta` (the
/// FRB bridge type) onto it.
@immutable
class TranscriptUpdate {
  const TranscriptUpdate({
    required this.segmentId,
    required this.phase,
    required this.text,
    required this.startMs,
    required this.endMs,
    this.speakerId,
    this.confidence,
  });

  final String segmentId;
  final TranscriptPhase phase;
  final String text;
  final int startMs;
  final int endMs;
  final String? speakerId;
  final double? confidence;
}

/// A committed transcript segment carrying its monotonic sequence number and
/// provenance. `sequenceNumber` increases across the whole session and never
/// repeats (spec §5).
@immutable
class SequencedSegment {
  const SequencedSegment({
    required this.sequenceNumber,
    required this.segmentId,
    required this.phase,
    required this.text,
    required this.startMs,
    required this.endMs,
    this.speakerId,
    this.confidence,
  });

  final int sequenceNumber;
  final String segmentId;
  final TranscriptPhase phase;
  final String text;
  final int startMs;
  final int endMs;
  final String? speakerId;
  final double? confidence;
}

/// Why an update was rejected or absorbed without a new sequence number.
enum TranscriptIngestOutcome {
  /// Accepted and assigned a new monotonic sequence number.
  accepted,

  /// Identical to the current state of the segment; dropped (spec §5: no
  /// duplicate events).
  duplicate,

  /// Phase regressed (e.g. a partial after the segment was finalized); dropped
  /// so a late hypothesis cannot rewrite committed text.
  outOfOrder,
}

/// Result of ingesting one update.
@immutable
class TranscriptIngestResult {
  const TranscriptIngestResult({
    required this.outcome,
    required this.sequenceNumber,
    required this.segment,
  });

  final TranscriptIngestOutcome outcome;

  /// The assigned sequence number when [outcome] is
  /// [TranscriptIngestOutcome.accepted]; otherwise null.
  final int? sequenceNumber;

  /// The resulting segment when accepted; otherwise null.
  final SequencedSegment? segment;

  bool get accepted => outcome == TranscriptIngestOutcome.accepted;
}

/// Reconciles a stream of partial/stable/final updates into an ordered,
/// deduplicated, monotonically-sequenced transcript (spec §5). Pure and
/// deterministic — no timers, no I/O — so it is fully unit-testable.
class MindTranscriptSequencer {
  MindTranscriptSequencer();

  int _sequence = 0;

  /// Committed (stable/finalized) segments in first-seen order.
  final List<SequencedSegment> _committed = [];
  final Map<String, int> _committedIndex = {};

  /// The current live partial tail, if any.
  SequencedSegment? _partial;

  /// The highest phase reached per segment id, to reject regressions.
  final Map<String, TranscriptPhase> _phaseBySegment = {};

  /// Last committed sequence number issued (0 when none).
  int get lastSequence => _sequence;

  /// Committed segments, ordered. Excludes the live partial tail.
  List<SequencedSegment> get committedSegments => List.unmodifiable(_committed);

  /// The live partial tail, or null.
  SequencedSegment? get partial => _partial;

  /// All lines to render: committed segments followed by the partial tail.
  List<SequencedSegment> get lines => [..._committed, ?_partial];

  TranscriptIngestResult ingest(TranscriptUpdate update) {
    final currentPhase = _phaseBySegment[update.segmentId];

    // Reject a regression: once a segment reaches a phase it cannot go back.
    if (currentPhase != null && update.phase.rank < currentPhase.rank) {
      return const TranscriptIngestResult(
        outcome: TranscriptIngestOutcome.outOfOrder,
        sequenceNumber: null,
        segment: null,
      );
    }

    // Dedup: identical phase + text to what we already hold for this segment.
    if (_isDuplicate(update)) {
      return const TranscriptIngestResult(
        outcome: TranscriptIngestOutcome.duplicate,
        sequenceNumber: null,
        segment: null,
      );
    }

    final seq = ++_sequence;
    _phaseBySegment[update.segmentId] = update.phase;

    // Carry provenance forward: an update that omits speaker/confidence keeps
    // whatever the segment already had (spec §5: preserve provenance metadata).
    final prior = _priorSegment(update.segmentId);
    final segment = SequencedSegment(
      sequenceNumber: seq,
      segmentId: update.segmentId,
      phase: update.phase,
      text: update.text,
      startMs: update.startMs,
      endMs: update.endMs,
      speakerId: update.speakerId ?? prior?.speakerId,
      confidence: update.confidence ?? prior?.confidence,
    );

    if (update.phase == TranscriptPhase.partial) {
      _partial = segment;
    } else {
      // Stable / finalized commit: replace in place (preserve id + order) or
      // append. Clears any matching partial tail.
      final existing = _committedIndex[update.segmentId];
      if (existing != null) {
        _committed[existing] = segment;
      } else {
        _committedIndex[update.segmentId] = _committed.length;
        _committed.add(segment);
      }
      if (_partial?.segmentId == update.segmentId) {
        _partial = null;
      }
    }

    return TranscriptIngestResult(
      outcome: TranscriptIngestOutcome.accepted,
      sequenceNumber: seq,
      segment: segment,
    );
  }

  /// The segment currently held for [segmentId] (committed or partial tail),
  /// used to carry provenance forward across phase transitions.
  SequencedSegment? _priorSegment(String segmentId) {
    final index = _committedIndex[segmentId];
    if (index != null) return _committed[index];
    if (_partial?.segmentId == segmentId) return _partial;
    return null;
  }

  bool _isDuplicate(TranscriptUpdate update) {
    if (update.phase == TranscriptPhase.partial) {
      return _partial != null &&
          _partial!.segmentId == update.segmentId &&
          _partial!.text == update.text;
    }
    final existing = _committedIndex[update.segmentId];
    if (existing == null) return false;
    final current = _committed[existing];
    return current.phase == update.phase && current.text == update.text;
  }
}
