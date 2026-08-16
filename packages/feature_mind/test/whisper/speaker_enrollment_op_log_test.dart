import 'package:feature_mind/src/runtime/models/log_models.dart';
import 'package:feature_mind/src/whisper/speaker_enrollment_op_log.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/recording_operation_log.dart';

void main() {
  test('appendSpeakerEnrolledOp records speakerEnrolled kind', () async {
    final log = RecordingOperationLog();

    final sequence = await appendSpeakerEnrolledOp(
      log: log,
      profileId: 'enrolled_0',
      displayName: 'Alice',
      contextId: 'meeting-capture',
    );

    expect(sequence, 1);
    expect(log.appended.single.kind, MindOpKind.speakerEnrolled);
    expect(log.appended.single.title, 'Remembered Alice');
    expect(log.appended.single.detail, 'enrolled_0;Alice');
    expect(log.appended.single.contextId, 'meeting-capture');
  });
}
