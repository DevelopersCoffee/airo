import 'package:feature_mind/src/bridges/mind_speech_bridge.dart';
import 'package:feature_mind/src/capture/domain/live_refine_reconciliation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reconcileLiveRefineTranscript keeps baseline ids with refined text', () {
    const baseline = [
      TranscriptSegment(
        id: 's0',
        startMs: 0,
        endMs: 1000,
        text: 'hello',
      ),
      TranscriptSegment(
        id: 's1',
        startMs: 1000,
        endMs: 2000,
        text: 'world',
      ),
    ];
    const refined = [
      TranscriptSegment(
        id: 'r0',
        startMs: 0,
        endMs: 1100,
        text: 'hello there',
      ),
      TranscriptSegment(
        id: 'r1',
        startMs: 1100,
        endMs: 2200,
        text: 'wonderful world',
      ),
    ];

    final reconciled = reconcileLiveRefineTranscript(
      baseline: baseline,
      refined: refined,
    );

    expect(reconciled.map((s) => s.id), ['s0', 's1']);
    expect(reconciled[0].text, 'hello there');
    expect(reconciled[0].startMs, 0);
    expect(reconciled[0].endMs, 1100);
    expect(reconciled[1].text, 'wonderful world');
    expect(joinTranscriptSegments(reconciled), 'hello there wonderful world');
  });

  test('reconcileLiveRefineTranscript keeps baseline when refined has no overlap', () {
    const baseline = [
      TranscriptSegment(
        id: 's0',
        startMs: 0,
        endMs: 500,
        text: 'live only',
      ),
    ];
    const refined = [
      TranscriptSegment(
        id: 'r0',
        startMs: 5000,
        endMs: 5500,
        text: 'file only',
      ),
    ];

    final reconciled = reconcileLiveRefineTranscript(
      baseline: baseline,
      refined: refined,
    );

    expect(reconciled.single.text, 'live only');
    expect(reconciled.single.id, 's0');
  });
}
