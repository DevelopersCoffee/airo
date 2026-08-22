import 'package:feature_mind/src/meeting_list_metadata.dart';
import 'package:feature_mind/src/whisper/api/meetings.dart' as rust;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('preview skips the empty minutes template and uses the transcript', () {
    final meeting = rust.MeetingRecord(
      id: 'm1',
      title: 'Meeting 2026-08-23 03:01:00.086253',
      recordedAt: BigInt.from(1755900660),
      transcript:
          '[00:00:00] sp0: So my name is Quintang. I was a chemist before.',
      minutes:
          '# Minutes of Meeting\n\nNo objective was recorded for this meeting.\n'
          '_No decisions recorded._',
      model: 'qwen',
      decisions: const [],
      actionItems: const [],
      metrics: const [],
    );

    final meta = meetingListMetadata(meeting, audioBytes: 2 * 1024 * 1024);
    expect(meta.title, contains('Quintang'));
    expect(meta.preview, contains('chemist'));
    expect(meta.preview, isNot(contains('Minutes of Meeting')));
    expect(meta.metaLine, contains('1 speaker'));
    expect(meta.metaLine, contains('2.0 MB'));
    expect(meta.metaLine, contains('s'));
  });

  test('duration is read from the last transcript timestamp', () {
    expect(
      durationFromTranscript('[00:00:00] hi\n[00:01:40] bye'),
      const Duration(minutes: 1, seconds: 40),
    );
    expect(
      formatMeetingDuration(const Duration(minutes: 1, seconds: 40)),
      '1m 40s',
    );
  });
}
