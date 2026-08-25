import 'package:feature_mind/src/bridges/mind_speech_bridge.dart';
import 'package:feature_mind/src/processing/application/segment_transcription_retry.dart';
import 'package:feature_mind/src/processing/application/transcript_quality_evaluator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_bridges.dart';

void main() {
  group('SegmentTranscriptionRetryService', () {
    test('retries suspicious segments and keeps better text', () async {
      const service = SegmentTranscriptionRetryService();
      final speech = FakeMindSpeechBridge();
      final segments = [
        const TranscriptSegment(
          id: 's0',
          startMs: 0,
          endMs: 5_000,
          text: 'We need to migrate the database by Friday.',
        ),
        const TranscriptSegment(
          id: 's1',
          startMs: 5_000,
          endMs: 12_000,
          text: 'Marwangsthe Goudoon discussed the migration timeline.',
        ),
      ];

      final result = await service.retryIfNeeded(
        speech: speech,
        wavPath: '/tmp/meeting.m4a',
        segments: segments,
      );

      expect(result.retriedSegmentIds, contains('s1'));
      expect(result.segments[1].text, 'retried segment');
      expect(result.report.retryCount, 1);
    });

    test('skips retry when all segments look clean', () async {
      const service = SegmentTranscriptionRetryService();
      final segments = [
        const TranscriptSegment(
          id: 's0',
          startMs: 0,
          endMs: 5_000,
          text: 'We need to migrate the database by Friday.',
        ),
      ];

      final result = await service.retryIfNeeded(
        speech: FakeMindSpeechBridge(),
        wavPath: '/tmp/meeting.m4a',
        segments: segments,
      );

      expect(result.retriedSegmentIds, isEmpty);
      expect(result.report.needsReview, isFalse);
    });
  });
}
