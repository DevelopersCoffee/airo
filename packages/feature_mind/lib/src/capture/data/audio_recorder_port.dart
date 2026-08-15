import 'package:record/record.dart';

/// The seam between [MeetingCaptureController] and the microphone encoder.
///
/// Same shape as `MeetingExportGateway`
/// (`feature_mind/lib/src/export/data/meeting_export_gateway.dart`) and
/// `PlatformBackupDocumentGateway` (`feature_iptv`) — an interface a fake can
/// implement in a test, and a thin platform-plugin adapter implements for
/// real. [PlatformAudioRecorderPort] wraps `package:record`'s `AudioRecorder`,
/// which already streams straight to the file named by `start()` rather than
/// buffering in Dart memory (native `MediaRecorder`/`AVAudioRecorder`
/// encoders write incrementally) — that native behaviour is what makes AC1
/// (a 90-minute recording survives an app kill) true without this layer doing
/// any extra work to get it.
abstract interface class AudioRecorderPort {
  /// Starts encoding to [path]. The file exists and grows from this call
  /// onward — nothing buffers until `stop()`.
  Future<void> start(String path);

  Future<void> pause();

  Future<void> resume();

  /// Finalises the file and returns its path (or null if nothing was
  /// recorded).
  Future<String?> stop();

  /// True if the platform granted microphone access. Callers check this
  /// before `start()` rather than reading the exception `start()` throws
  /// when it's denied, so the UI can show a permission prompt instead of an
  /// error banner.
  Future<bool> hasPermission();

  /// OS-driven state changes — most importantly, an interruption (incoming
  /// call, Siri, another app's recording) pausing or resuming the encoder out
  /// from under the controller. [MeetingCaptureController] listens to this to
  /// keep [MeetingRecordingSnapshot.pausedByOs] accurate.
  Stream<RecorderOsEvent> get osEvents;

  Future<void> dispose();
}

/// One OS-driven transition the port reports, decoupled from
/// `package:record`'s own `RecordState` so nothing outside this file imports
/// that package.
enum RecorderOsEvent { osPaused, osResumed, osStopped }

/// Real microphone capture via `package:record`.
///
/// iOS: `RecordConfig.audioInterruption` is set to
/// `AudioInterruptionMode.pauseResume` below (see `record_ios`'s
/// `RecorderSessionExtension`), which is what makes AC3 (handle interruption
/// — call, Siri) true at the native layer: the plugin pauses the encoder when
/// `AVAudioSession.interruptionNotification` fires with `.began` and resumes
/// it on `.ended` if the OS reports the interruption is resumable. This class
/// only has to *observe* that through [osEvents] and reflect it in the
/// session snapshot, not implement interruption handling itself.
///
/// Android: `package:record`'s own foreground-service option is deprecated in
/// favour of an external package (see `AndroidRecordConfig.service` doc); this
/// codebase's answer to that is `MeetingRecordingServiceGateway`, called
/// alongside this port by `MeetingCaptureController` rather than folded into
/// it — recording and "keep the OS from killing the process while recording"
/// are separate concerns with separate platform surfaces.
class PlatformAudioRecorderPort implements AudioRecorderPort {
  PlatformAudioRecorderPort({AudioRecorder? recorder})
    : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;

  static const _config = RecordConfig(
    encoder: AudioEncoder.aacLc,
    // AAC-LC in an m4a container: matches what `meetings.dart`'s
    // `transcribeRecording` (whisper.cpp via the Rust bridge) already expects
    // from every other entry point into the pipeline.
    bitRate: 128000,
    sampleRate: 16000,
    numChannels: 1,
    androidConfig: AndroidRecordConfig(
      // Mic use must be visible to the OS privacy indicator, so this stays a
      // normal `mic` source rather than anything that could route around it.
      audioSource: AndroidAudioSource.mic,
    ),
    // `RecordConfig.audioInterruption` (not `IosRecordConfig`, despite the
    // doc mentioning iOS most prominently — it applies on Android too, per
    // `record_platform_interface`'s `RecordConfig.audioInterruption` doc).
    // `pauseResume` rather than the plugin default (`pause`, which leaves the
    // session paused forever once a call ends) is what makes AC3's
    // "handles interruption" mean the recording actually continues once the
    // call/Siri session ends, not just that it survives being paused.
    audioInterruption: AudioInterruptionMode.pauseResume,
  );

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<void> start(String path) => _recorder.start(_config, path: path);

  @override
  Future<void> pause() => _recorder.pause();

  @override
  Future<void> resume() => _recorder.resume();

  @override
  Future<String?> stop() => _recorder.stop();

  @override
  Stream<RecorderOsEvent> get osEvents => _recorder.onStateChanged().map((
    state,
  ) {
    switch (state) {
      case RecordState.pause:
        return RecorderOsEvent.osPaused;
      case RecordState.record:
        return RecorderOsEvent.osResumed;
      case RecordState.stop:
        return RecorderOsEvent.osStopped;
    }
  });

  @override
  Future<void> dispose() => _recorder.dispose();
}
