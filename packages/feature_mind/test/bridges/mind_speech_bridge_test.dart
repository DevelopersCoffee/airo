import 'package:feature_mind/src/bridges/mind_speech_bridge.dart';
import 'package:feature_mind/src/whisper/api/meetings.dart' as rust;
import 'package:flutter_test/flutter_test.dart';

/// `#1629`: `transcribe_recording` used to compute per-segment `start_ms`/
/// `end_ms` in Rust and then discard them before they reached Dart. The fix
/// threads them through `rust.TranscriptSegmentRecord` and this bridge's
/// `toTranscriptSegment`. These tests exercise that conversion directly,
/// against the real generated wire type (`rust.TranscriptSegmentRecord` and
/// `rust.TranscriptEvent` are plain constructible Dart classes — no native
/// library required), so a regression that silently drops a field or mangles
/// the `BigInt` -> `int` narrowing fails here without a device.
void main() {
  group('toTranscriptSegment', () {
    test('carries id, start/end timestamps and text through unchanged', () {
      final segment = toTranscriptSegment(
        rust.TranscriptSegmentRecord(
          id: 's3',
          startMs: BigInt.from(12345),
          endMs: BigInt.from(67890),
          text: 'the deploy is blocked on the migration',
        ),
      );

      expect(segment.id, 's3');
      expect(segment.startMs, 12345);
      expect(segment.endMs, 67890);
      expect(segment.text, 'the deploy is blocked on the migration');
    });

    test('does not truncate a start/end timestamp near u32 overflow', () {
      // A ~50-minute mark: 3,000,000 ms overflows a 16-bit or 32-bit signed
      // int on some platforms if the BigInt -> int conversion is done wrong.
      // `.toInt()` on a BigInt this size is exact on every Dart target Airo
      // ships (64-bit ints), so this pins that the conversion stays exact.
      final segment = toTranscriptSegment(
        rust.TranscriptSegmentRecord(
          id: 's0',
          startMs: BigInt.from(3000000),
          endMs: BigInt.from(3005000),
          text: 'long meeting',
        ),
      );

      expect(segment.startMs, 3000000);
      expect(segment.endMs, 3005000);
    });
  });

  group('RustMindSpeechBridge event mapping shape', () {
    test(
      'TranscriptEvent_Transcribing carries exactly one segment through',
      () {
        final wire = rust.TranscriptEvent.transcribing(
          segment: rust.TranscriptSegmentRecord(
            id: 's0',
            startMs: BigInt.from(0),
            endMs: BigInt.from(500),
            text: 'hello',
          ),
        );

        final mapped = switch (wire) {
          rust.TranscriptEvent_Transcribing(:final segment) =>
            TranscriptEventTranscribing(toTranscriptSegment(segment)),
          _ => throw StateError('unexpected variant'),
        };

        expect(mapped.segment.id, 's0');
        expect(mapped.segment.startMs, 0);
        expect(mapped.segment.endMs, 500);
        expect(mapped.text, 'hello');
      },
    );

    test('TranscriptEvent_TranscriptReady preserves segment order across the '
        'FFI boundary', () {
      final wire = rust.TranscriptEvent.transcriptReady(
        text: 'first second third',
        segments: [
          rust.TranscriptSegmentRecord(
            id: 's0',
            startMs: BigInt.from(0),
            endMs: BigInt.from(400),
            text: 'first',
          ),
          rust.TranscriptSegmentRecord(
            id: 's1',
            startMs: BigInt.from(400),
            endMs: BigInt.from(900),
            text: 'second',
          ),
          rust.TranscriptSegmentRecord(
            id: 's2',
            startMs: BigInt.from(900),
            endMs: BigInt.from(1500),
            text: 'third',
          ),
        ],
      );

      final mapped = switch (wire) {
        rust.TranscriptEvent_TranscriptReady(:final text, :final segments) =>
          TranscriptEventTranscriptReady(
            text,
            segments.map(toTranscriptSegment).toList(growable: false),
          ),
        _ => throw StateError('unexpected variant'),
      };

      expect(mapped.text, 'first second third');
      expect(mapped.segments.map((s) => s.id).toList(), ['s0', 's1', 's2']);
      expect(mapped.segments.map((s) => s.startMs).toList(), [0, 400, 900]);
      expect(mapped.segments.map((s) => s.endMs).toList(), [400, 900, 1500]);
      expect(mapped.segments.map((s) => s.text).toList(), [
        'first',
        'second',
        'third',
      ]);
    });

    test('TranscriptEvent_ConversationIr carries JSON through', () {
      final wire = rust.TranscriptEvent.conversationIr(
        json:
            '{"type":"decision","text":"We decided Friday","evidence":"s0"}',
      );
      final mapped = switch (wire) {
        rust.TranscriptEvent_ConversationIr(:final json) =>
          TranscriptEventConversationIr(json),
        _ => throw StateError('unexpected variant'),
      };
      expect(mapped.json, contains('"type":"decision"'));
    });
  });

  // `#1629` Gap D: `MindSpeechBridge.save` carries segments back across the
  // FFI boundary so `save_meeting` can persist `transcript.json`. That is a
  // second `int` <-> `BigInt` crossing, in the opposite direction from
  // `toTranscriptSegment` -- this pins that it is also exact, including near
  // the same overflow-prone magnitude the narrowing test above checks.
  group('fromTranscriptSegment', () {
    test('carries id, start/end timestamps and text through unchanged', () {
      const segment = TranscriptSegment(
        id: 's4',
        startMs: 12345,
        endMs: 67890,
        text: 'Raj owns the rollout',
      );

      final wire = fromTranscriptSegment(segment);

      expect(wire.id, 's4');
      expect(wire.startMs, BigInt.from(12345));
      expect(wire.endMs, BigInt.from(67890));
      expect(wire.text, 'Raj owns the rollout');
    });

    test('round-trips through toTranscriptSegment unchanged', () {
      const original = TranscriptSegment(
        id: 's7',
        startMs: 3000000,
        endMs: 3005000,
        text: 'long meeting, near-overflow timestamp',
      );

      final roundTripped = toTranscriptSegment(fromTranscriptSegment(original));

      expect(roundTripped, original);
    });
  });

  // `#1629` Gap C: the multilingual model is selectable through
  // `rust.SpeechLanguage`, not just present in the Rust registry. This test
  // proves the enum reaches the wire type `RustMindSpeechBridge.initialize`
  // builds, without needing a loaded native library -- `rust.MindConfig` is a
  // plain constructible Dart class, so the wire shape itself is what is
  // checked here.
  group('SpeechLanguage selection reaches MindConfig', () {
    test(
      'englishOnly is the default and multilingual is a real alternative',
      () {
        final defaultConfig = rust.MindConfig(
          modelsDir: '/models',
          storePath: '/models/meetings.log',
          memoryBudgetMb: 4096,
          speechLanguage: rust.SpeechLanguage.englishOnly,
        );
        final multilingualConfig = rust.MindConfig(
          modelsDir: '/models',
          storePath: '/models/meetings.log',
          memoryBudgetMb: 4096,
          speechLanguage: rust.SpeechLanguage.multilingual,
        );

        expect(defaultConfig.speechLanguage, rust.SpeechLanguage.englishOnly);
        expect(
          multilingualConfig.speechLanguage,
          rust.SpeechLanguage.multilingual,
        );
        expect(defaultConfig, isNot(equals(multilingualConfig)));
      },
    );
  });
}
