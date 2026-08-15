import 'package:feature_mind/src/meeting_ir/meeting_ir_status_writer.dart';
import 'package:feature_mind/src/whisper/api/meetings.dart' as rust;
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_bridges.dart';

void main() {
  test('recordedAtMsFor parses m{ms} ids', () {
    final meeting = rust.MeetingRecord(
      id: 'm1700000000123',
      title: 't',
      recordedAt: BigInt.from(1700000000),
      transcript: '',
      minutes: '',
      model: 'm',
      decisions: const [],
      actionItems: const [],
      metrics: const [],
    );
    expect(MeetingIrStatusWriter.recordedAtMsFor(meeting), 1700000000123);
  });

  test('updateActionStatus re-saves through the speech bridge', () async {
    final speech = FakeMindSpeechBridge()
      ..transcriptDocumentToReturn = rust.TranscriptDocumentRecord(
        meetingId: 'm1700000000123',
        audioPath: '/tmp/a.wav',
        modelVersion: 'w',
        segments: [
          rust.TranscriptSegmentRecord(
            id: 's0',
            startMs: BigInt.zero,
            endMs: BigInt.from(100),
            text: 'hi',
          ),
        ],
      );

    final meeting = rust.MeetingRecord(
      id: 'm1700000000123',
      title: 'Standup',
      recordedAt: BigInt.from(1700000000),
      transcript: 'hi',
      minutes: '- x',
      model: 'qwen',
      decisions: const [],
      actionItems: const [
        rust.MeetingActionItemRecord(
          id: 'a1',
          task: 'Ship it',
          owner: 'Dev',
          status: rust.MeetingActionStatus.open,
          evidenceSegmentIds: ['s0'],
        ),
      ],
      metrics: const [],
    );

    final updated = await MeetingIrStatusWriter(speech).updateActionStatus(
      meeting: meeting,
      actionItemId: 'a1',
      status: rust.MeetingActionStatus.done,
    );

    expect(updated.actionItems.single.status, rust.MeetingActionStatus.done);
    expect(
      speech.savedActionItems!.single.status,
      rust.MeetingActionStatus.done,
    );
    expect(speech.savedWavPath, '/tmp/a.wav');
    expect(speech.savedSegments, isNotEmpty);
  });
}
