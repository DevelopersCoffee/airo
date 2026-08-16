import 'package:feature_mind/src/bridges/mind_speech_bridge.dart';
import 'package:feature_mind/src/meeting_ir/evidence_resolver.dart';
import 'package:feature_mind/src/whisper/api/meetings.dart' as rust;
import 'package:flutter_test/flutter_test.dart';

void main() {
  const resolver = EvidenceResolver();

  test('indexFromDocument maps segment ids', () {
    final doc = rust.TranscriptDocumentRecord(
      meetingId: 'm1',
      audioPath: '/tmp/a.wav',
      modelVersion: 'whisper@1',
      segments: [
        rust.TranscriptSegmentRecord(
          id: 's0',
          startMs: BigInt.from(0),
          endMs: BigInt.from(500),
          text: 'hello',
        ),
        rust.TranscriptSegmentRecord(
          id: 's1',
          startMs: BigInt.from(500),
          endMs: BigInt.from(900),
          text: 'world',
        ),
      ],
    );
    final byId = resolver.indexFromDocument(doc);
    expect(byId.keys, ['s0', 's1']);
    expect(byId['s1']!.text, 'world');
  });

  test('resolve skips unknown evidence ids and preserves order', () {
    final byId = resolver.indexFromSegments(const [
      TranscriptSegment(id: 's0', startMs: 0, endMs: 100, text: 'a'),
      TranscriptSegment(id: 's2', startMs: 200, endMs: 300, text: 'c'),
    ]);
    final hits = resolver.resolve(
      evidenceSegmentIds: const ['s2', 'missing', 's0'],
      byId: byId,
    );
    expect(hits.map((h) => h.segmentId), ['s2', 's0']);
    expect(hits.first.startMs, 200);
  });

  test('firstStartMs is null when nothing resolves', () {
    expect(
      resolver.firstStartMs(evidenceSegmentIds: const ['x'], byId: const {}),
      isNull,
    );
  });
}
