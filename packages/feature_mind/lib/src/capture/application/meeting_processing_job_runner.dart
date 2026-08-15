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
    if (_retentionPolicy() == AudioRetentionPolicy.deleteAfterTranscript) {
      final file = File(job.audioPath);
      if (file.existsSync()) {
        await file.delete();
      }
    }
  }
}
