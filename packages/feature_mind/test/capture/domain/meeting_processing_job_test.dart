import 'package:feature_mind/src/capture/domain/meeting_processing_job.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('MeetingProcessingJob round-trips through JSON', () {
    const job = MeetingProcessingJob(
      id: 'm1',
      audioPath: '/tmp/m1.m4a',
      title: 'Standup',
      enqueuedAtMs: 12345,
      status: MeetingProcessingStatus.paused,
      attempt: 2,
      lastError: 'thermal pause',
    );

    final decoded = MeetingProcessingJob.fromJson(job.toJson());

    expect(decoded.id, job.id);
    expect(decoded.audioPath, job.audioPath);
    expect(decoded.title, job.title);
    expect(decoded.enqueuedAtMs, job.enqueuedAtMs);
    expect(decoded.status, job.status);
    expect(decoded.attempt, job.attempt);
    expect(decoded.lastError, job.lastError);
  });

  test('an unrecognised status in storage falls back to queued', () {
    final decoded = MeetingProcessingJob.fromJson({
      'id': 'm1',
      'audioPath': '/tmp/m1.m4a',
      'title': 'Standup',
      'enqueuedAtMs': 1,
      'status': 'something-future-code-added',
    });

    expect(decoded.status, MeetingProcessingStatus.queued);
  });

  test('isTerminal is true only for completed/failed', () {
    expect(MeetingProcessingStatus.queued.isTerminal, isFalse);
    expect(MeetingProcessingStatus.processing.isTerminal, isFalse);
    expect(MeetingProcessingStatus.paused.isTerminal, isFalse);
    expect(MeetingProcessingStatus.completed.isTerminal, isTrue);
    expect(MeetingProcessingStatus.failed.isTerminal, isTrue);
  });
}
