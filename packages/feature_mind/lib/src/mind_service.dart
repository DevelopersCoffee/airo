import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'api/mind.dart' as rust;
import 'library_loader.dart';
import 'model_installer.dart';

/// Why Airo Mind cannot start. Each case is one the user can act on, which is
/// the reason this is a type and not a string.
enum MindUnavailable {
  /// The platform has no Rust library — web, or a build without the native
  /// artefact linked in.
  bridgeMissing,

  /// The models are not on disk. Expected on first run.
  modelsMissing,

  /// The library loaded and the models are present, but loading them failed.
  loadFailed,
}

/// The result of trying to start.
@immutable
class MindStatus {
  const MindStatus.ready() : unavailable = null, detail = '';
  const MindStatus.unavailable(this.unavailable, this.detail);

  final MindUnavailable? unavailable;
  final String detail;

  bool get isReady => unavailable == null;
}

/// Progress through the pipeline, as the models produce it.
///
/// Mirrors `ProcessingEvent` on the Rust side into something a widget can hold:
/// the accumulated text so far, plus which stage produced it.
enum MindStage {
  idle,
  recording,
  transcribing,
  generating,
  saving,
  done,
  failed,
}

@immutable
class MindProgress {
  const MindProgress({
    required this.stage,
    this.transcript = '',
    this.minutes = '',
    this.meetingId,
    this.error,
  });

  final MindStage stage;
  final String transcript;
  final String minutes;
  final String? meetingId;
  final String? error;

  MindProgress copyWith({
    MindStage? stage,
    String? transcript,
    String? minutes,
    String? meetingId,
    String? error,
  }) {
    return MindProgress(
      stage: stage ?? this.stage,
      transcript: transcript ?? this.transcript,
      minutes: minutes ?? this.minutes,
      meetingId: meetingId ?? this.meetingId,
      error: error ?? this.error,
    );
  }
}

/// Everything the UI is allowed to do.
///
/// The screens never touch the generated bindings. That keeps the widget tests
/// runnable without a Rust library present, and it means the day the bridge
/// changes shape, one file changes.
class MindService {
  MindService({AudioRecorder? recorder, ModelInstaller? installer})
    : _recorder = recorder ?? AudioRecorder(),
      _installer = installer ?? const ModelInstaller();

  final AudioRecorder _recorder;
  final ModelInstaller _installer;
  String? _recordingPath;

  /// Loads the native library and the models.
  ///
  /// Returns a status rather than throwing: on a real device "the models are
  /// not downloaded yet" is the ordinary first-run state, and an exception
  /// would make the app's normal opening move look like a crash.
  Future<MindStatus> initialize() async {
    try {
      await initializeMindBridge();
    } on Object catch (e) {
      return MindStatus.unavailable(MindUnavailable.bridgeMissing, '$e');
    }

    final dir = await modelsDirectory();

    // `ADR-0018 §2`, Bundled: copy out of the app's own asset bundle. Not from
    // the checkout -- that made a developer machine work and a device fail.
    if (!await _installer.isInstalled(dir)) {
      final failed = await _installer.install(
        dir,
        onProgress: onInstallProgress,
      );
      if (failed.isNotEmpty) {
        return MindStatus.unavailable(
          MindUnavailable.modelsMissing,
          'This build does not carry ${failed.join(', ')}.',
        );
      }
    }

    try {
      // `ADR-0018 §1`: hand over a DIRECTORY and a budget. Which model serves
      // which task is the Model Manager's decision, not this layer's.
      await rust.initialize(
        config: rust.MindConfig(
          modelsDir: dir.path,
          storePath: p.join(dir.path, 'meetings.log'),
          // Admission ceiling, not an allocation. The Supervisor refuses a
          // model it cannot afford before anything is loaded.
          memoryBudgetMb: 4096,
        ),
      );
      return const MindStatus.ready();
    } on Object catch (e) {
      return MindStatus.unavailable(MindUnavailable.loadFailed, '$e');
    }
  }

  /// Where models and the meeting log live. Application support rather than
  /// documents: these are not the user's files, and on iOS the documents
  /// directory is user-visible.
  Future<Directory> modelsDirectory() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'airo_mind'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// Reports asset-copy progress on first launch. Half a gigabyte takes long
  /// enough that a silent first launch reads as a hang.
  void Function(String fileName, int copied, int total)? onInstallProgress;

  /// Hashes every installed model against the digest pinned in Rust source.
  Future<List<dynamic>> verifyModels() async =>
      _installer.verify(await modelsDirectory());

  Future<bool> hasMicrophonePermission() => _recorder.hasPermission();

  /// Starts capture at exactly what whisper wants: 16 kHz mono 16-bit PCM.
  ///
  /// Converting later would mean resampling in Dart on the main isolate. Asking
  /// the platform for the right format costs nothing and removes that entirely.
  Future<void> startRecording() async {
    final dir = await modelsDirectory();
    final path = p.join(
      dir.path,
      'recording-${DateTime.now().millisecondsSinceEpoch}.wav',
    );
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: path,
    );
    _recordingPath = path;
  }

  Future<bool> get isRecording => _recorder.isRecording();

  /// Stops capture and returns the file. Null if nothing was recording.
  Future<String?> stopRecording() async {
    final path = await _recorder.stop();
    return path ?? _recordingPath;
  }

  /// Transcribe → summarise → save, streaming.
  ///
  /// Each event folds into the previous [MindProgress], so a widget can render
  /// the latest value and nothing accumulates in two places.
  Stream<MindProgress> process({
    required String wavPath,
    required String title,
  }) async* {
    var progress = const MindProgress(stage: MindStage.transcribing);
    yield progress;

    final stream = rust.processRecording(
      wavPath: wavPath,
      title: title,
      recordedAtMs: BigInt.from(DateTime.now().millisecondsSinceEpoch),
    );

    try {
      await for (final event in stream) {
        progress = switch (event) {
          rust.ProcessingEvent_Transcribing(:final text) => progress.copyWith(
            stage: MindStage.transcribing,
            transcript: _append(progress.transcript, text),
          ),
          // The joined transcript from Rust replaces what was accumulated, so a
          // dropped segment cannot leave the two out of step.
          rust.ProcessingEvent_TranscriptReady(:final text) =>
            progress.copyWith(stage: MindStage.generating, transcript: text),
          rust.ProcessingEvent_Generating(:final text) => progress.copyWith(
            stage: MindStage.generating,
            minutes: progress.minutes + text,
          ),
          rust.ProcessingEvent_MinutesReady(:final text) => progress.copyWith(
            stage: MindStage.saving,
            minutes: text,
          ),
          rust.ProcessingEvent_Saved(:final meetingId) => progress.copyWith(
            stage: MindStage.done,
            meetingId: meetingId,
          ),
          rust.ProcessingEvent_Cancelled() => progress.copyWith(
            stage: MindStage.idle,
          ),
        };
        yield progress;
      }
    } on Object catch (e) {
      yield progress.copyWith(stage: MindStage.failed, error: '$e');
    }
  }

  static String _append(String existing, String segment) {
    final piece = segment.trim();
    if (piece.isEmpty) return existing;
    return existing.isEmpty ? piece : '$existing $piece';
  }

  /// Stops the in-flight job at the next segment or token.
  void cancelProcessing() => rust.cancelProcessing();

  Future<List<rust.MeetingRecord>> meetings() => rust.listMeetings();

  Future<List<rust.SearchHit>> search(String query) =>
      rust.searchMeetings(query: query);

  Future<rust.MeetingRecord?> meeting(String id) => rust.getMeeting(id: id);

  Future<void> dispose() => _recorder.dispose();
}
