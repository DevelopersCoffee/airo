import 'dart:async';

import 'package:core_ai/core_ai.dart';

import '../data/meeting_processing_queue_store.dart';
import '../domain/meeting_processing_job.dart';

/// # Design note — post-meeting processing job orchestration (#1656 AC4)
///
/// This is the "job orchestration design = Claude" half of #1656's
/// delegation split. It is deliberately a comment block, not an ADR: the
/// issue asks for "a page, not an ADR", and the shape below is small enough
/// that a page of prose next to the class it describes is more useful than a
/// separate document that can drift from the code.
///
/// ## Why a queue exists at all
///
/// A meeting can run 90 minutes; ASR + extraction over that much audio is
/// itself a multi-minute job on-device. Two things can go wrong if this runs
/// naively: (1) the user records a second meeting before the first finishes
/// processing, and a naive implementation starts both transcriptions at once
/// — competing for the same CPU/NPU budget, doubling thermal load, and
/// finishing both *later* than running them back to back would have; (2) the
/// app is killed (OS memory pressure, user swipe-away, crash) mid-job, and a
/// naive implementation has no record that the job ever existed, silently
/// dropping a recording the user believes is "processing".
///
/// ## 1. Surviving an app restart
///
/// Every mutation to the queue (`enqueue`, and every status transition
/// `_advance` makes) is followed by a call to
/// [MeetingProcessingQueueStore.save], which writes the *entire* job list —
/// not a delta — to one JSON file via a write-to-temp-then-rename (see
/// `FileMeetingProcessingQueueStore.save`), so a process death mid-write
/// cannot leave a half-written, unparsable queue file behind. On
/// construction, [MeetingProcessingQueue.restore] reads that file back and
/// resumes: any job that was `processing` when the app died is demoted to
/// `queued` (`_reconcileAfterRestart`) rather than resumed mid-transcription,
/// because whisper.cpp's `transcribeRecording` (`meetings.dart`) has no
/// mid-stream checkpoint to resume *from* — the resumable unit is "process
/// this recording", not "process this recording from segment 40". A job is
/// therefore resumable at job granularity: nothing is lost (the audio file
/// referenced by `MeetingProcessingJob.audioPath` is untouched by a partial
/// attempt), but a job that was 90% through transcription before the kill
/// restarts from 0% rather than 90%. `attempt` increments each time a job is
/// picked up, and a job that fails [_maxAttempts] times moves to `failed`
/// terminally rather than looping forever on an audio file that will never
/// transcribe (e.g. corrupt file, model uninstalled mid-job).
///
/// ## 2. Queueing rather than concurrently processing
///
/// [_advance] holds an internal `_processing` guard: at most one job may be
/// in [MeetingProcessingStatus.processing] at a time, full stop — not "one
/// job per core" or "N jobs throttled to fit a budget". A second recording
/// finishing while the first is still transcribing enqueues behind it
/// ([MeetingProcessingStatus.queued]) and waits. This is the literal AC4
/// requirement ("queue rather than crawl") applied one level up from where
/// `LlmThermalPolicy`'s own doc comment applies it (that policy already
/// rejects *throttling a single running job's rate*; this queue's job is to
/// make sure a second job never starts throttling turns with it in the first
/// place).
///
/// ## 3. Consulting thermal/device-tier gating
///
/// Before starting or continuing any job, [_advance] asks
/// [LlmDeviceSignalsProbe.probe] for current signals and runs them through
/// the *existing*, already-shipped `LlmThermalPolicy.decide` (MIND-LLM-4,
/// `packages/core_ai/lib/src/device_tier/llm_thermal_policy.dart`) — this
/// queue does not reimplement thermal gating, it is a second caller of the
/// same policy the local/cloud router already uses. `LlmBatchJobAction.pause`
/// demotes the in-flight job to [MeetingProcessingStatus.paused] and stops
/// the queue's advance loop entirely (no job starts, no job continues) until
/// a later probe reports `LlmBatchJobAction.resume`, at which point the
/// paused job re-enters `processing` from job-granularity zero, per §1. This
/// queue polls the probe on every `enqueue` and every job completion, plus a
/// timer (`_thermalPollInterval`) while a job is paused, so a queue stuck
/// paused behind sustained thermal pressure notices the moment pressure
/// eases instead of waiting for the next unrelated queue event.
///
/// ## Non-goals
///
/// - No priority ordering — FIFO by `enqueuedAtMs`. Nothing in #1656 asks
///   for "most recent meeting first", and guessing at a priority scheme here
///   would be speculative.
/// - No cross-process locking. This queue assumes one Dart isolate owns it
///   (the app's main isolate); it is not safe to construct two instances
///   against the same store file concurrently. Nothing in this codebase does
///   that today.
class MeetingProcessingQueue {
  MeetingProcessingQueue({
    required MeetingProcessingQueueStore store,
    required LlmDeviceSignalsProbe deviceSignalsProbe,
    required Future<void> Function(MeetingProcessingJob job) processJob,
    LlmThermalPolicy thermalPolicy = const LlmThermalPolicy(),
    int maxAttempts = 3,
    Duration thermalPollInterval = const Duration(seconds: 30),
  }) : _store = store,
       _deviceSignalsProbe = deviceSignalsProbe,
       _processJob = processJob,
       _thermalPolicy = thermalPolicy,
       _maxAttempts = maxAttempts,
       _thermalPollInterval = thermalPollInterval;

  final MeetingProcessingQueueStore _store;
  final LlmDeviceSignalsProbe _deviceSignalsProbe;
  final Future<void> Function(MeetingProcessingJob job) _processJob;
  final LlmThermalPolicy _thermalPolicy;
  final int _maxAttempts;
  final Duration _thermalPollInterval;

  final _jobsController = StreamController<List<MeetingProcessingJob>>.broadcast();
  List<MeetingProcessingJob> _jobs = const [];
  bool _running = false;
  bool _thermallyPaused = false;
  Timer? _thermalPollTimer;

  Stream<List<MeetingProcessingJob>> get jobs => _jobsController.stream;

  List<MeetingProcessingJob> get current => List.unmodifiable(_jobs);

  /// Loads any jobs left over from a previous run and reconciles them. Call
  /// once at startup before [enqueue].
  Future<void> restore() async {
    final loaded = await _store.load();
    _jobs = _reconcileAfterRestart(loaded);
    await _persist();
    unawaited(_advance());
  }

  List<MeetingProcessingJob> _reconcileAfterRestart(
    List<MeetingProcessingJob> loaded,
  ) {
    return [
      for (final job in loaded)
        if (job.status == MeetingProcessingStatus.processing)
          // See §1: no mid-job resume point, so a job that was actively
          // processing when the app died goes back to the end of the queue.
          job.copyWith(status: MeetingProcessingStatus.queued)
        else
          job,
    ];
  }

  /// Adds a newly recorded meeting to the queue. Safe to call while other
  /// jobs are queued or processing — this job simply waits its turn.
  Future<void> enqueue(MeetingProcessingJob job) async {
    _jobs = [..._jobs, job];
    await _persist();
    unawaited(_advance());
  }

  /// Runs (at most) the queue's forward progress: probes thermal state,
  /// pauses the whole queue if pressure demands it, otherwise starts the next
  /// queued job if nothing is currently processing.
  Future<void> _advance() async {
    if (_running) return;
    _running = true;
    try {
      while (true) {
        final signals = await _deviceSignalsProbe.probe();
        final action = _thermalPolicy.decide(
          pressure: signals.thermalPressure,
          jobCurrentlyPaused: _thermallyPaused,
        );
        if (action == LlmBatchJobAction.pause) {
          await _pauseForThermal();
          return;
        }
        if (action == LlmBatchJobAction.resume) {
          _thermallyPaused = false;
          _stopThermalPolling();
        }

        if (_jobs.any((j) => j.status == MeetingProcessingStatus.processing)) {
          // A job is already running — §2's one-at-a-time invariant. Nothing
          // more to do until it finishes and calls `_advance` again.
          return;
        }

        final nextIndex = _jobs.indexWhere(
          (j) =>
              j.status == MeetingProcessingStatus.queued ||
              j.status == MeetingProcessingStatus.paused,
        );
        if (nextIndex == -1) return; // Nothing left to do.

        var job = _jobs[nextIndex].copyWith(
          status: MeetingProcessingStatus.processing,
          attempt: _jobs[nextIndex].attempt + 1,
        );
        _jobs = _replace(nextIndex, job);
        await _persist();

        try {
          await _processJob(job);
          _jobs = _replace(
            _jobs.indexWhere((j) => j.id == job.id),
            job.copyWith(status: MeetingProcessingStatus.completed),
          );
        } catch (error) {
          final failedTerminally = job.attempt >= _maxAttempts;
          _jobs = _replace(
            _jobs.indexWhere((j) => j.id == job.id),
            job.copyWith(
              status: failedTerminally
                  ? MeetingProcessingStatus.failed
                  : MeetingProcessingStatus.queued,
              lastError: error.toString(),
            ),
          );
        }
        await _persist();
        // Loop again: another job may be waiting, and thermal state may have
        // changed while this one ran.
      }
    } finally {
      _running = false;
    }
  }

  Future<void> _pauseForThermal() async {
    _thermallyPaused = true;
    final processingIndex = _jobs.indexWhere(
      (j) => j.status == MeetingProcessingStatus.processing,
    );
    if (processingIndex != -1) {
      _jobs = _replace(
        processingIndex,
        _jobs[processingIndex].copyWith(status: MeetingProcessingStatus.paused),
      );
      await _persist();
    }
    _startThermalPolling();
  }

  void _startThermalPolling() {
    _thermalPollTimer ??= Timer.periodic(_thermalPollInterval, (_) {
      unawaited(_advance());
    });
  }

  void _stopThermalPolling() {
    _thermalPollTimer?.cancel();
    _thermalPollTimer = null;
  }

  List<MeetingProcessingJob> _replace(int index, MeetingProcessingJob job) {
    final next = [..._jobs];
    next[index] = job;
    return next;
  }

  Future<void> _persist() async {
    await _store.save(_jobs);
    if (!_jobsController.isClosed) _jobsController.add(current);
  }

  Future<void> dispose() async {
    _stopThermalPolling();
    await _jobsController.close();
  }
}
