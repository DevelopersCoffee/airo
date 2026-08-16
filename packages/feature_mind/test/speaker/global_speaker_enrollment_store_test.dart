import 'dart:io';

import 'package:feature_mind/src/speaker/speaker_enrollment_operation_log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('operation log replays enroll and remove', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'speaker_enrollment_test_',
    );
    final root = '${tempDir.path}/enrollment';
    final log = await SpeakerEnrollmentOperationLog.open(
      logPath: '$root/ops.jsonl',
      contentDirPath: '$root/content',
    );

    await log.appendEnroll(
      id: 'enrolled_0',
      displayName: 'Alice',
      embedding: [0.1, 0.2, 0.3],
      recordedAtMs: 1000,
    );
    await log.appendEnroll(
      id: 'enrolled_1',
      displayName: 'Bob',
      embedding: [0.4, 0.5],
      recordedAtMs: 2000,
    );
    await log.appendRemove(id: 'enrolled_0', recordedAtMs: 3000);

    final profiles = await log.projectProfiles();
    expect(profiles, hasLength(1));
    expect(profiles.single.id, 'enrolled_1');
    expect(profiles.single.displayName, 'Bob');
    expect(profiles.single.embedding, [0.4, 0.5]);

    await tempDir.delete(recursive: true);
  });
}
