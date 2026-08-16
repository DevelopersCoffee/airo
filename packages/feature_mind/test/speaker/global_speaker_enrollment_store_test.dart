import 'dart:io';

import 'package:feature_mind/src/speaker/global_speaker_enrollment_store.dart';
import 'package:feature_mind/src/speaker/speaker_enrollment_operation_log.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/recording_operation_log.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('speaker_enrollment_test_');
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('operation log replays enroll and remove', () async {
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
  });

  test('GlobalSpeakerEnrollmentStore migrates legacy SharedPreferences', () async {
    SharedPreferences.setMockInitialValues({
      'mind_global_speaker_enrollment_v1':
          '[{"id":"enrolled_0","displayName":"Legacy","embedding":[0.9]}]',
    });
    final prefs = await SharedPreferences.getInstance();

    final root = '${tempDir.path}/store';
    final timeline = RecordingOperationLog();
    final store = GlobalSpeakerEnrollmentStore(
      preferences: prefs,
      logOpener: SpeakerEnrollmentOperationLog.open(
        logPath: '$root/ops.jsonl',
        contentDirPath: '$root/content',
      ),
      timelineLog: timeline,
    );
    final profiles = await store.loadProfiles();
    expect(profiles, hasLength(1));
    expect(profiles.single.displayName, 'Legacy');
    expect(profiles.single.embedding, [0.9]);
    expect(prefs.getString('mind_global_speaker_enrollment_v1'), isNull);
  });
}
