import 'dart:io';

import 'package:core_ai/core_ai.dart';

import '../../mind_service.dart';
import '../domain/audio_retention_policy.dart';
import '../domain/meeting_processing_job.dart';
import '../domain/speech_language_mode.dart';
import '../../processing/application/adaptive_processing_planner.dart';
import '../../processing/application/processing_profile_bridge.dart';
import '../../processing/domain/processing_plan.dart';
import '../../processing/domain/processing_profile.dart';
import 'meeting_processing_progress.dart';
import 'speech_language_preference.dart';

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
    SpeechLanguageMode Function()? languageMode,
    ProcessingProfile Function()? processingProfile,
    MeetingProcessedCallback? onProcessed,
    MeetingJobProgressCallback? onProgress,
    MeetingProcessingPlanCallback? onPlan,
  }) : _mindService = mindService,
       _retentionPolicy = retentionPolicy,
       _languageMode = languageMode ?? (() => SpeechLanguageMode.fallback),
       _processingProfile = processingProfile ?? (() => ProcessingProfile.balanced),
       _onProcessed = onProcessed,
       _onProgress = onProgress,
       _onPlan = onPlan;

  final MindService _mindService;
  final AudioRetentionPolicy Function() _retentionPolicy;
  final SpeechLanguageMode Function() _languageMode;
  final ProcessingProfile Function() _processingProfile;
  final MeetingProcessedCallback? _onProcessed;
  final MeetingJobProgressCallback? _onProgress;
  final MeetingProcessingPlanCallback? _onPlan;
  static const _planner = AdaptiveProcessingPlanner();

  Future<void> call(MeetingProcessingJob job) async {
    final mode = _languageMode();
    final ready = await _mindService.ensureReady(
      speechLanguage: mode.speechLanguage,
    );
    if (!ready.isReady) {
      throw StateError(
        ready.detail.isNotEmpty ? ready.detail : 'Mind is not ready.',
      );
    }

    final file = File(job.audioPath);
    final audioBytes = file.existsSync() ? await file.length() : null;
    final memory = await DeviceCapabilityService().getMemoryInfo();
    final plan = await _planner.plan(
      intent: ProcessingIntent.finalTranscript,
      userProfile: _processingProfile(),
      memoryInfo: memory,
      audioBytes: audioBytes,
    );
    _mindService.applyFinalProcessingPlan(plan);
    _onPlan?.call(job, plan);
    MindProgress? last;
    if (job.hasCompletedTranscript) {
      await for (final progress in _mindService.processWithTranscript(
        wavPath: job.audioPath,
        title: job.title,
        transcript: job.completedTranscript!,
        segments: job.completedSegments!,
        language: mode.processLanguageCode,
      )) {
        last = progress;
        _onProgress?.call(job, progress);
      }
    } else if (job.hasRefineBaseline) {
      await for (final progress in _mindService.processWithRefine(
        wavPath: job.audioPath,
        title: job.title,
        baselineSegments: job.refineBaselineSegments!,
        language: mode.processLanguageCode,
      )) {
        last = progress;
        _onProgress?.call(job, progress);
      }
    } else {
      await for (final progress in _mindService.process(
        wavPath: job.audioPath,
        title: job.title,
        language: mode.processLanguageCode,
      )) {
        last = progress;
        _onProgress?.call(job, progress);
      }
    }
    if (last == null || last.stage == MindStage.failed) {
      throw StateError(last?.error ?? 'Processing produced no result.');
    }
    if (last.transcript.trim().isEmpty) {
      throw StateError(
        'No speech was detected in this audio. The file may be empty, '
        'still downloading, or in an unsupported format.',
      );
    }
    final onProcessed = _onProcessed;
    if (onProcessed != null) {
      await onProcessed(job, last);
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

/// Called after a job's transcription + minutes pipeline succeeds, before
/// retention cleanup. Notebook ingest hooks in here so a live recording, an
/// uploaded file, and a podcast URL all become searchable notes.
typedef MeetingProcessedCallback =
    Future<void> Function(MeetingProcessingJob job, MindProgress last);

typedef MeetingJobProgressCallback =
    void Function(MeetingProcessingJob job, MindProgress progress);

typedef MeetingProcessingPlanCallback =
    void Function(MeetingProcessingJob job, ProcessingPlan plan);
