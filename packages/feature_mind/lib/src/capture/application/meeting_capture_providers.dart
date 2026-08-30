/// Wiring for #1656's capture + processing seam. Kept in one file, the same
/// way `mindRuntimeProvider` is the one place `AudioScribeScreen` looks for
/// its runtime — a screen that wants to record a meeting only ever reads
/// these providers, never constructs `AudioRecorderPort` or
/// `MeetingProcessingQueue` itself.
library;

import 'dart:io';

import 'package:core_ai/core_ai.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/audio_recorder_port.dart';
import '../data/meeting_processing_queue_store.dart';
import '../data/meeting_recording_service_gateway.dart';
import '../domain/meeting_processing_job.dart';
import 'meeting_capture_controller.dart';
import 'meeting_live_session_coordinator.dart';
import 'meeting_processing_queue.dart';
import '../../mind_store_paths.dart';

/// Factory for one microphone encoder per capture session. Widget tests
/// return the same fake every call so Start can be asserted.
final audioRecorderPortProvider = Provider<AudioRecorderPort Function()>(
  (ref) =>
      () => PlatformAudioRecorderPort(),
);

/// Resolves the next session's `.m4a` path. Widget tests override this so
/// capture does not need a platform `path_provider` channel.
final meetingRecordingPathProvider = Provider<Future<String> Function()>(
  (ref) => nextMeetingRecordingPath,
);

/// Android foreground-service notification gateway. `NoopMeetingRecordingServiceGateway`
/// on platforms with no such concept (see the gateway's own doc).
final meetingRecordingServiceGatewayProvider =
    Provider<MeetingRecordingServiceGateway>(
      (ref) => const PlatformMeetingRecordingServiceGateway(),
    );

/// One controller per recording session. Not `autoDispose`: popping this
/// screen while `_stop` is still running must not dispose the encoder under
/// a live `stop()` call — that was tripping `_dependents.isEmpty` and losing
/// the recording. Call [invalidateMeetingCaptureController] after stop to
/// mint a fresh controller for the next session.
final meetingCaptureControllerProvider = Provider<MeetingCaptureController>((
  ref,
) {
  final controller = MeetingCaptureController(
    recorder: ref.watch(audioRecorderPortProvider)(),
    serviceGateway: ref.watch(meetingRecordingServiceGatewayProvider),
  );
  ref.onDispose(controller.dispose);
  return controller;
});

/// Drops the terminal controller so the next capture session gets a new one.
void invalidateMeetingCaptureController(ProviderContainer container) {
  container.invalidate(meetingCaptureControllerProvider);
}

/// Where a session's `.m4a` is written. One file per session, named by
/// start time so two sessions never collide even if the app is killed
/// between them without a clean stop.
Future<String> nextMeetingRecordingPath() async {
  final dir = await getApplicationSupportDirectory();
  final recordingsDir = Directory(p.join(dir.path, 'mind_recordings'));
  await recordingsDir.create(recursive: true);
  final stamp = DateTime.now().millisecondsSinceEpoch;
  return p.join(recordingsDir.path, 'meeting-$stamp.m4a');
}

/// WAV path the native live fan-out writes. Must stay in lock-step with
/// `airo_mind_whisper::api::meetings::live_fanout_path`:
/// `{store_path.parent}/mind_recordings/{meetingId}.wav`.
///
/// That parent is `{applicationSupport}/airo_mind`, not application support
/// itself — see [mindStoreParentDirectory]. This resolved against plain
/// application support, one segment short, so every live session handed the
/// processing queue a path Rust had never written to.
Future<String> nextLiveFanoutRecordingPath(String meetingId) async {
  final dir = await mindStoreParentDirectory();
  final recordingsDir = Directory(p.join(dir.path, 'mind_recordings'));
  await recordingsDir.create(recursive: true);
  return p.join(recordingsDir.path, '$meetingId.wav');
}

final liveFanoutRecordingPathProvider =
    Provider<Future<String> Function(String)>(
      (ref) => nextLiveFanoutRecordingPath,
    );

/// Builds a live STT coordinator. Tests replace this to simulate admission
/// refusal without loading the whisper cdylib.
final meetingLiveSessionCoordinatorFactoryProvider =
    Provider<MeetingLiveSessionCoordinator Function()>(
      (ref) =>
          () => MeetingLiveSessionCoordinator(),
    );

Future<String> _processingQueuePath() async {
  final dir = await getApplicationSupportDirectory();
  return p.join(dir.path, 'mind_recordings', 'processing_queue.json');
}

/// The resumable post-meeting processing queue (AC4). `FutureProvider`
/// because construction needs an async path lookup and, on first read, a call
/// to `restore()` to reconcile any jobs left over from a previous run —
/// exactly the "survives an app restart" behaviour the design note on
/// `MeetingProcessingQueue` describes.
///
/// Not `autoDispose`: Stop pops the capture screen, and that was the only
/// watcher. Disposing the queue there cancelled the job before
/// `MindService.process` could write the meeting, so the library looked empty.
///
/// [processJob] is supplied by the app shell (it wires the real
/// `transcribeRecording` + `saveMeeting` pipeline from `meetings.dart`, plus
/// the retention-policy cleanup) rather than being hardcoded here, so this
/// package stays free of a compile-time dependency on any one processing
/// strategy — the same reasoning `MindConfig` keeps model/store paths
/// injected rather than assumed.
final meetingProcessingQueueProvider = FutureProvider<MeetingProcessingQueue>((
  ref,
) async {
  // Survives leaving the capture screen — otherwise the queue disposes mid-job
  // and the library never gets the meeting.
  ref.keepAlive();
  final path = await _processingQueuePath();
  final queue = MeetingProcessingQueue(
    store: FileMeetingProcessingQueueStore(path),
    deviceSignalsProbe: RealLlmDeviceSignalsProbe(
      // No platform channel in this codebase exposes free filesystem
      // bytes yet (see `RealLlmDeviceSignalsProbe`'s own doc on
      // `availableStorageMb` -- this is the first real caller and hits
      // that documented gap directly). A fixed generous headroom rather
      // than a fabricated precise reading: this queue's thermal gate
      // (`LlmThermalPolicy`) only ever reads `thermalPressure`, so
      // storage headroom being approximate here does not affect AC4's
      // pause/resume behaviour -- it only matters once a caller adds a
      // storage-pressure policy, which does not exist today.
      availableStorageMb: () async => 4096,
    ),
    processJob: (MeetingProcessingJob job) async {
      // Overridden by the app shell's own provider override once a real
      // processing pipeline is wired in. Left as a no-op-that-throws
      // here rather than silently "succeeding" a job it never processed,
      // so a missing override fails loudly instead of marking every
      // meeting completed without a transcript.
      throw UnimplementedError(
        'meetingProcessingQueueProvider needs a processJob override — '
        'see meetingProcessingQueueProvider doc comment.',
      );
    },
  );
  ref.onDispose(() {
    // ignore: discarded_futures
    queue.dispose();
  });
  await queue.restore();
  return queue;
});
