import 'package:flutter_test/flutter_test.dart';
import 'package:feature_mind/src/transcript/mind_transcript_sequencer.dart';

TranscriptUpdate _u(
  String id,
  TranscriptPhase phase,
  String text, {
  int startMs = 0,
  int endMs = 100,
  String? speakerId,
  double? confidence,
}) => TranscriptUpdate(
  segmentId: id,
  phase: phase,
  text: text,
  startMs: startMs,
  endMs: endMs,
  speakerId: speakerId,
  confidence: confidence,
);

void main() {
  group('TranscriptPhase.fromWireName', () {
    test('maps wire names including final_', () {
      expect(TranscriptPhase.fromWireName('partial'), TranscriptPhase.partial);
      expect(TranscriptPhase.fromWireName('stable'), TranscriptPhase.stable);
      expect(TranscriptPhase.fromWireName('final_'), TranscriptPhase.finalized);
    });

    test('throws on an unknown phase', () {
      expect(() => TranscriptPhase.fromWireName('bogus'), throwsArgumentError);
    });
  });

  group('monotonic sequence numbers', () {
    test('every accepted update gets a strictly increasing sequence', () {
      final s = MindTranscriptSequencer();
      final a = s.ingest(_u('s0', TranscriptPhase.partial, 'he'));
      final b = s.ingest(_u('s0', TranscriptPhase.partial, 'hello'));
      final c = s.ingest(_u('s0', TranscriptPhase.stable, 'hello there'));
      expect(a.sequenceNumber, 1);
      expect(b.sequenceNumber, 2);
      expect(c.sequenceNumber, 3);
      expect(s.lastSequence, 3);
    });

    test('duplicates and out-of-order updates do not consume a sequence', () {
      final s = MindTranscriptSequencer();
      s.ingest(_u('s0', TranscriptPhase.stable, 'hello'));
      final dup = s.ingest(_u('s0', TranscriptPhase.stable, 'hello'));
      expect(dup.outcome, TranscriptIngestOutcome.duplicate);
      expect(dup.sequenceNumber, isNull);
      expect(s.lastSequence, 1);
    });
  });

  group('partial -> stable -> final reconciliation', () {
    test('partial becomes the live tail then commits on stable', () {
      final s = MindTranscriptSequencer();
      s.ingest(_u('s0', TranscriptPhase.partial, 'hel'));
      expect(s.partial, isNotNull);
      expect(s.committedSegments, isEmpty);

      s.ingest(_u('s0', TranscriptPhase.stable, 'hello'));
      expect(s.partial, isNull);
      expect(s.committedSegments.length, 1);
      expect(s.committedSegments.single.text, 'hello');
      expect(s.committedSegments.single.phase, TranscriptPhase.stable);
    });

    test(
      'final replaces the stable text in place, preserving id and order',
      () {
        final s = MindTranscriptSequencer();
        s.ingest(_u('s0', TranscriptPhase.stable, 'hello'));
        s.ingest(_u('s1', TranscriptPhase.stable, 'world'));
        s.ingest(_u('s0', TranscriptPhase.finalized, 'Hello,'));

        final committed = s.committedSegments;
        expect(committed.length, 2);
        expect(committed[0].segmentId, 's0');
        expect(committed[0].text, 'Hello,');
        expect(committed[0].phase, TranscriptPhase.finalized);
        expect(committed[1].segmentId, 's1');
      },
    );

    test('lines returns committed segments followed by the partial tail', () {
      final s = MindTranscriptSequencer();
      s.ingest(_u('s0', TranscriptPhase.stable, 'hello'));
      s.ingest(_u('s1', TranscriptPhase.partial, 'wor'));
      final lines = s.lines;
      expect(lines.map((l) => l.segmentId), ['s0', 's1']);
      expect(lines.last.phase, TranscriptPhase.partial);
    });
  });

  group('no rewrite of committed text (spec §4/§5)', () {
    test('a partial after finalize is rejected as out of order', () {
      final s = MindTranscriptSequencer();
      s.ingest(_u('s0', TranscriptPhase.finalized, 'Committed.'));
      final late = s.ingest(_u('s0', TranscriptPhase.partial, 'garbage'));
      expect(late.outcome, TranscriptIngestOutcome.outOfOrder);
      expect(s.committedSegments.single.text, 'Committed.');
    });

    test('a stable after finalize is rejected as out of order', () {
      final s = MindTranscriptSequencer();
      s.ingest(_u('s0', TranscriptPhase.finalized, 'Committed.'));
      final late = s.ingest(_u('s0', TranscriptPhase.stable, 'other'));
      expect(late.outcome, TranscriptIngestOutcome.outOfOrder);
    });
  });

  group('provenance metadata is carried through', () {
    test('speaker and confidence are preserved', () {
      final s = MindTranscriptSequencer();
      final r = s.ingest(
        _u(
          's0',
          TranscriptPhase.stable,
          'hello',
          speakerId: 'sp0',
          confidence: 0.92,
        ),
      );
      expect(r.segment!.speakerId, 'sp0');
      expect(r.segment!.confidence, 0.92);
    });

    test('a later update without speaker keeps the prior speaker', () {
      final s = MindTranscriptSequencer();
      s.ingest(_u('s0', TranscriptPhase.stable, 'hello', speakerId: 'sp0'));
      s.ingest(_u('s0', TranscriptPhase.finalized, 'Hello.'));
      expect(s.committedSegments.single.speakerId, 'sp0');
    });
  });

  group('duplicate detection per phase', () {
    test('identical partial text is deduped', () {
      final s = MindTranscriptSequencer();
      s.ingest(_u('s0', TranscriptPhase.partial, 'hel'));
      final dup = s.ingest(_u('s0', TranscriptPhase.partial, 'hel'));
      expect(dup.outcome, TranscriptIngestOutcome.duplicate);
    });

    test('changed partial text is accepted', () {
      final s = MindTranscriptSequencer();
      s.ingest(_u('s0', TranscriptPhase.partial, 'hel'));
      final next = s.ingest(_u('s0', TranscriptPhase.partial, 'hell'));
      expect(next.accepted, isTrue);
    });
  });
}
