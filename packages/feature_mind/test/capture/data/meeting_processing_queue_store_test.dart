import 'dart:io';

import 'package:feature_mind/src/capture/data/meeting_processing_queue_store.dart';
import 'package:feature_mind/src/capture/domain/meeting_processing_job.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FileMeetingProcessingQueueStore', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('mind_queue_store_test');
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test('load returns empty when no file exists yet', () async {
      final store = FileMeetingProcessingQueueStore(
        '${tempDir.path}/queue.json',
      );

      expect(await store.load(), isEmpty);
    });

    test('save then load round-trips the job list', () async {
      final store = FileMeetingProcessingQueueStore(
        '${tempDir.path}/queue.json',
      );
      final jobs = [
        const MeetingProcessingJob(
          id: 'm1',
          audioPath: '/tmp/m1.m4a',
          title: 'Standup',
          enqueuedAtMs: 1,
          status: MeetingProcessingStatus.queued,
        ),
        const MeetingProcessingJob(
          id: 'm2',
          audioPath: '/tmp/m2.m4a',
          title: '1:1',
          enqueuedAtMs: 2,
          status: MeetingProcessingStatus.completed,
        ),
      ];

      await store.save(jobs);
      final loaded = await store.load();

      expect(loaded.map((j) => j.id), ['m1', 'm2']);
      expect(loaded[1].status, MeetingProcessingStatus.completed);
    });

    test('save leaves no dangling temp file behind', () async {
      final store = FileMeetingProcessingQueueStore(
        '${tempDir.path}/queue.json',
      );

      await store.save(const []);

      expect(File('${tempDir.path}/queue.json.tmp').existsSync(), isFalse);
      expect(File('${tempDir.path}/queue.json').existsSync(), isTrue);
    });
  });
}
