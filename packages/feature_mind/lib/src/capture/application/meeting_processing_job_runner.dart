import 'dart:io';

import '../../mind_service.dart';
import '../domain/audio_retention_policy.dart';
import '../domain/meeting_processing_job.dart';

/// Adapts [MindService.process] (the existing "transcribe → minutes → save"
/// pipeline, `mind_service.dart`) into the
/// `Future<void> Function(MeetingProcessingJob)` shape
/// `MeetingProcessingQueue` calls. This is the piece that closes the loop
/// #1656 opens with: the pipeline "starts from an existing .m4a file"
/// (`MindService.process(wavPath: ...)`), and this runner is what hands it
/// the file [MeetingCaptureController] just recorded, one queued job at a
/// time.
///
/// Also applies AC5's retention policy: once a job completes, the source
/// audio file is deleted if [retentionPolicy] currently says
/// [AudioRetentionPolicy.deleteAfterTranscript]. Read fresh on every job
/// (not captured at construction) so a person can change the Settings toggle
/// mid-queue and have it apply to the very next meeting that finishes, not
/// just ones enqueued after the change.
///
/// [cleanupAfterTerminalFailure] applies the same policy when a job instead
/// exhausts its retry budget and is never going to produce a transcript
/// (chief-security-officer review, #1656): without it, a
/// `deleteAfterTranscript` user's raw audio for an untranscribable recording
/// would sit on disk forever, since the success-only path above never runs
/// for a job that keeps failing. Wire it as
/// `MeetingProcessingQueue(onTerminalFailure: runner.cleanupAfterTerminalFailure)`.
class MeetingProcessingJobRunner {
  MeetingProcessingJobRunner({
    required MindService mindService,
    required AudioRetentionPolicy Function() retentionPolicy,
  }) : _mindService = mindService,
       _retentionPolicy = retentionPolicy;

  final MindService _mindService;
  final AudioRetentionPolicy Function() _retentionPolicy;

  Future<void> call(MeetingProcessingJob job) async {
    MindProgress? last;
    await for (final progress in _mindService.process(
      wavPath: job.audioPath,
      title: job.title,
    )) {
      last = progress;
    }
    if (last == null || last.stage == MindStage.failed) {
      throw StateError(last?.error ?? 'Processing produced no result.');
    }
    await _deleteAudioIfPolicySaysDelete(job);
  }

  /// See the class doc's note on [cleanupAfterTerminalFailure] — applies
  /// AC5's retention policy to a job that will never produce a transcript,
  /// the same way [call] does for one that just did.
  Future<void> cleanupAfterTerminalFailure(MeetingProcessingJob job) =>
      _deleteAudioIfPolicySaysDelete(job);

  Future<void> _deleteAudioIfPolicySaysDelete(MeetingProcessingJob job) async {
    if (_retentionPolicy() == AudioRetentionPolicy.deleteAfterTranscript) {
      final file = File(job.audioPath);
      if (file.existsSync()) {
        await file.delete();
      }
    }
  }
}
