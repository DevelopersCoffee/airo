import 'package:flutter_test/flutter_test.dart';
import 'package:feature_mind/src/governor/mind_capture_health.dart';

void main() {
  group('CaptureHealth.recording', () {
    test('starts active, healthy, file valid', () {
      final h = CaptureHealth.recording();
      expect(h.captureState, CaptureState.active);
      expect(h.liveIntelligence, LiveIntelligenceHealth.healthy);
      expect(h.recordedFileValid, isTrue);
      expect(h.postRecordingPipelineAvailable, isTrue);
      expect(h.recordingLine, 'Recording: Active');
      expect(h.liveIntelligenceLine, 'Live intelligence: Healthy');
    });
  });

  group('spec §22 invariant: intelligence failure never destroys capture', () {
    // Every non-capture failure must keep capture active, file valid, and the
    // post-recording pipeline available.
    final intelligenceFailures = MindLiveFailure.values
        .where((f) => !f.isCaptureEvent)
        .toList();

    for (final failure in intelligenceFailures) {
      test('$failure keeps capture active and file valid', () {
        final h = CaptureHealth.recording().applyFailure(failure);
        expect(
          h.captureState,
          CaptureState.active,
          reason: '$failure must not stop capture',
        );
        expect(
          h.recordedFileValid,
          isTrue,
          reason: '$failure must not invalidate the recorded file',
        );
        expect(
          h.postRecordingPipelineAvailable,
          isTrue,
          reason: '$failure must leave the post-recording fallback',
        );
        expect(
          h.isLiveDegraded,
          isTrue,
          reason: '$failure must degrade live intelligence',
        );
      });
    }

    test('no failure ever invalidates the recorded file', () {
      var h = CaptureHealth.recording();
      for (final failure in MindLiveFailure.values) {
        h = h.applyFailure(failure);
      }
      expect(h.recordedFileValid, isTrue);
      expect(h.postRecordingPipelineAvailable, isTrue);
    });
  });

  group('hard vs soft degradation', () {
    test('STT init failure makes live unavailable', () {
      final h = CaptureHealth.recording().applyFailure(
        MindLiveFailure.sttInitFailure,
      );
      expect(h.liveIntelligence, LiveIntelligenceHealth.unavailable);
    });

    test('ring overflow degrades but stays recoverable', () {
      final h = CaptureHealth.recording().applyFailure(
        MindLiveFailure.ringBufferOverflow,
      );
      expect(h.liveIntelligence, LiveIntelligenceHealth.degraded);
    });

    test('a soft failure does not upgrade a prior hard failure', () {
      final h = CaptureHealth.recording()
          .applyFailure(MindLiveFailure.nativeWorkerCrash)
          .applyFailure(MindLiveFailure.ringBufferOverflow);
      expect(h.liveIntelligence, LiveIntelligenceHealth.unavailable);
    });
  });

  group('capture-side interruptions pause, never lose the meeting', () {
    test('microphone interruption pauses capture, file still valid', () {
      final h = CaptureHealth.recording().applyFailure(
        MindLiveFailure.microphoneInterruption,
      );
      expect(h.captureState, CaptureState.paused);
      expect(h.recordedFileValid, isTrue);
      // Live intelligence is not degraded merely by a mic pause.
      expect(h.liveIntelligence, LiveIntelligenceHealth.healthy);
    });

    test('resume returns to active', () {
      final h = CaptureHealth.recording()
          .applyFailure(MindLiveFailure.audioDeviceInterruption)
          .resumeCapture();
      expect(h.captureState, CaptureState.active);
    });

    test('stop then interruption stays stopped', () {
      final h = CaptureHealth.recording().stopCapture().applyFailure(
        MindLiveFailure.appPaused,
      );
      expect(h.captureState, CaptureState.stopped);
    });
  });

  group('reasons', () {
    test('accumulate distinct messages', () {
      final h = CaptureHealth.recording()
          .applyFailure(MindLiveFailure.thermalDegradation)
          .applyFailure(MindLiveFailure.ringBufferOverflow)
          .applyFailure(MindLiveFailure.ringBufferOverflow);
      expect(h.reasons.length, 2);
      expect(h.reasons, contains(MindLiveFailure.thermalDegradation.message));
    });
  });

  group('UI lines reflect the two-line degraded banner (spec §3)', () {
    test('recording active + live degraded', () {
      final h = CaptureHealth.recording().applyFailure(
        MindLiveFailure.sttRuntimeFailure,
      );
      expect(h.recordingLine, 'Recording: Active');
      expect(h.liveIntelligenceLine, 'Live intelligence: Degraded');
    });
  });
}
