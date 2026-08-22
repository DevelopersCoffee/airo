import 'package:feature_mind/src/capture/application/meeting_capture_controller.dart';
import 'package:feature_mind/src/capture/data/audio_recorder_port.dart';
import 'package:feature_mind/src/capture/domain/meeting_recording_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_audio_recorder_port.dart';

void main() {
  group('MeetingCaptureController', () {
    late FakeAudioRecorderPort recorder;
    late MeetingCaptureController controller;

    setUp(() {
      recorder = FakeAudioRecorderPort();
      controller = MeetingCaptureController(
        recorder: recorder,
        tickInterval: const Duration(milliseconds: 5),
      );
    });

    tearDown(() async {
      await controller.dispose();
    });

    test('idle before start', () {
      expect(controller.current.lifecycle, MeetingRecordingLifecycle.idle);
      expect(controller.isRecording, isFalse);
    });

    test('start begins encoding immediately -- no buffering step', () async {
      await controller.start('/tmp/meeting.m4a');

      expect(recorder.calls, contains('start:/tmp/meeting.m4a'));
      expect(recorder.startedPath, '/tmp/meeting.m4a');
      expect(controller.current.lifecycle, MeetingRecordingLifecycle.recording);
      expect(controller.current.filePath, '/tmp/meeting.m4a');
      expect(controller.isRecording, isTrue);
    });

    test('start refuses when microphone permission is not granted', () async {
      recorder.permissionGranted = false;

      await controller.start('/tmp/meeting.m4a');

      expect(recorder.calls, isNot(contains('start:/tmp/meeting.m4a')));
      expect(controller.current.lifecycle, MeetingRecordingLifecycle.failed);
      expect(controller.current.error, isNotNull);
    });

    test('start twice on one controller throws', () async {
      await controller.start('/tmp/a.m4a');

      expect(() => controller.start('/tmp/b.m4a'), throwsStateError);
    });

    test('pause then resume round-trips through the port', () async {
      await controller.start('/tmp/meeting.m4a');

      await controller.pause();
      expect(recorder.calls, contains('pause'));
      expect(controller.current.lifecycle, MeetingRecordingLifecycle.paused);
      expect(controller.current.pausedByOs, isFalse);

      await controller.resume();
      expect(recorder.calls, contains('resume'));
      expect(controller.current.lifecycle, MeetingRecordingLifecycle.recording);
    });

    test('mic levels land on the snapshot while recording', () async {
      await controller.start('/tmp/meeting.m4a');
      recorder.emitLevel(0.7);
      await pumpEventQueue();
      expect(controller.current.amplitude, closeTo(0.7, 0.001));
    });

    test(
      'elapsed follows wall clock instead of compounding each tick',
      () async {
        await controller.start('/tmp/meeting.m4a');
        await Future<void>.delayed(const Duration(milliseconds: 40));
        final elapsed = controller.current.elapsedMs;
        // The old ticker wrote live elapsed back into the base it added to, so
        // ~8 ticks in 40ms compounded to ~180ms and ran ahead of a real clock.
        expect(elapsed, lessThan(90));
        expect(elapsed, greaterThanOrEqualTo(20));
      },
    );

    test('elapsed time accumulates across a pause/resume cycle', () async {
      await controller.start('/tmp/meeting.m4a');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await controller.pause();
      final pausedElapsed = controller.current.elapsedMs;
      expect(pausedElapsed, greaterThan(0));

      // Time passing while paused must not count.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(controller.current.elapsedMs, pausedElapsed);

      await controller.resume();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final resumedElapsed = controller.current.elapsedMs;
      expect(resumedElapsed, greaterThan(pausedElapsed));
    });

    test('stop finalises the file and returns its path', () async {
      await controller.start('/tmp/meeting.m4a');

      final path = await controller.stop();

      expect(path, '/tmp/meeting.m4a');
      expect(recorder.calls, contains('stop'));
      expect(controller.current.lifecycle, MeetingRecordingLifecycle.stopped);
    });

    test('stop before start returns null and does not call the port', () async {
      final path = await controller.stop();

      expect(path, isNull);
      expect(recorder.calls, isEmpty);
    });

    test(
      'an OS-driven pause (call/Siri interruption) is reflected as pausedByOs',
      () async {
        await controller.start('/tmp/meeting.m4a');

        recorder.emitOsEvent(RecorderOsEvent.osPaused);
        await pumpEventQueue();

        expect(controller.current.lifecycle, MeetingRecordingLifecycle.paused);
        expect(controller.current.pausedByOs, isTrue);
      },
    );

    test(
      'the OS resuming after an interruption returns to recording',
      () async {
        await controller.start('/tmp/meeting.m4a');
        recorder.emitOsEvent(RecorderOsEvent.osPaused);
        await pumpEventQueue();

        recorder.emitOsEvent(RecorderOsEvent.osResumed);
        await pumpEventQueue();

        expect(
          controller.current.lifecycle,
          MeetingRecordingLifecycle.recording,
        );
        expect(controller.current.pausedByOs, isFalse);
      },
    );

    test('a user-initiated pause is not mistaken for an OS pause', () async {
      await controller.start('/tmp/meeting.m4a');

      await controller.pause();

      expect(controller.current.pausedByOs, isFalse);
    });
  });
}
