import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../assistant/consent/audio_scribe_consent_gate.dart';
import '../../assistant/consent/jurisdiction_consent_rules.dart';
import '../../assistant/consent/mind_runtime_provider.dart';
import '../../assistant/consent/recording_consent_prompt.dart';
import '../../trust/scribe_trust_state.dart';
import '../application/live_capture_preferences.dart';
import '../application/meeting_capture_controller.dart';
import '../application/meeting_capture_providers.dart';
import '../application/meeting_live_session_coordinator.dart';
import '../application/speech_language_preference.dart';
import '../application/transcription_mode_preference.dart';
import '../data/fanout_backed_audio_recorder_port.dart';
import '../domain/live_transcription_support.dart';
import '../domain/meeting_processing_job.dart';
import '../domain/meeting_recording_state.dart';
import '../domain/transcription_mode.dart';
import 'compact_trust_status_bar.dart';
import 'live_capture_controls.dart';
import 'live_insights_rail.dart';
import 'live_transcript_view.dart';
import 'meeting_recording_visualizer.dart';

/// In-app meeting capture (#1656 AC1, AC6) with live-transcript-first layout
/// while recording.
///
/// Reuses `AudioScribeConsentGate` — the same gate `AudioScribeScreen` uses
/// for live dictation — as the one door to the encoder.
class MeetingCaptureScreen extends ConsumerStatefulWidget {
  const MeetingCaptureScreen({super.key});

  @override
  ConsumerState<MeetingCaptureScreen> createState() =>
      _MeetingCaptureScreenState();
}

class _MeetingCaptureScreenState extends ConsumerState<MeetingCaptureScreen> {
  static const _contextId = 'meeting-capture';

  final _consentGate = AudioScribeConsentGate();
  ConsentJurisdiction _jurisdiction = unselectedJurisdiction;
  bool _allPartiesAck = false;
  bool _consentBusy = false;
  String? _consentError;

  bool _implicitConsentFailed = false;

  StreamSubscription<MeetingRecordingSnapshot>? _snapshotSub;
  StreamSubscription<List<MeetingProcessingJob>>? _jobsSub;
  MeetingCaptureController? _controller;
  MeetingLiveSessionCoordinator? _liveCoordinator;
  String? _meetingId;
  MeetingRecordingSnapshot _snapshot = MeetingRecordingSnapshot.idle;
  String? _startError;
  String? _liveWarning;
  bool _followLive = true;
  bool _insightsExpanded = false;

  MeetingProcessingJob? _processing;
  bool _processed = false;
  String? _processingError;

  @override
  void initState() {
    super.initState();
    if (!ref.read(recordingConsentPromptProvider)) {
      unawaited(_grantImplicitConsent());
    }
  }

  @override
  void dispose() {
    _liveCoordinator?.dispose();
    unawaited(_controller?.dispose());
    _snapshotSub?.cancel();
    _jobsSub?.cancel();
    super.dispose();
  }

  Future<void> _grantImplicitConsent() async {
    try {
      await _consentGate.grant(
        log: ref.read(mindRuntimeProvider).log,
        contextId: _contextId,
        jurisdiction: implicitConsentJurisdiction,
        allPartiesNotified: false,
        nowMs: DateTime.now().millisecondsSinceEpoch,
      );
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _implicitConsentFailed = true;
        _consentError = '$error';
      });
      return;
    }
    if (mounted) setState(() {});
  }

  Future<void> _confirmConsent() async {
    setState(() {
      _consentBusy = true;
      _consentError = null;
    });
    try {
      await _consentGate.grant(
        log: ref.read(mindRuntimeProvider).log,
        contextId: _contextId,
        jurisdiction: _jurisdiction,
        allPartiesNotified: _allPartiesAck,
        nowMs: DateTime.now().millisecondsSinceEpoch,
      );
    } on ConsentRequiredException catch (error) {
      if (!mounted) return;
      setState(() => _consentError = error.reason);
      return;
    } finally {
      if (mounted) setState(() => _consentBusy = false);
    }
    if (mounted) setState(() {});
  }

  Future<void> _start() async {
    if (!_consentGate.isGranted) return;
    setState(() {
      _startError = null;
      _liveWarning = null;
      _followLive = true;
    });
    final meetingId = 'meeting-${DateTime.now().millisecondsSinceEpoch}';
    _meetingId = meetingId;
    final transcriptionMode = ref.read(transcriptionModeProvider);
    final languageMode = ref.read(speechLanguageModeProvider);
    var useFanoutRecorder = false;
    var path = await ref.read(meetingRecordingPathProvider)();
    if (transcriptionMode.usesLivePipeline &&
        liveTranscriptionPreviewSupported()) {
      _liveCoordinator = ref.read(
        meetingLiveSessionCoordinatorFactoryProvider,
      )();
      final intelligence = ref.read(liveIntelligenceModeProvider);
      final insightsEnabled = ref.read(liveInsightsEnabledProvider);
      _liveCoordinator!.collectInsights =
          insightsEnabled && intelligence.collectInsights;
      _insightsExpanded = ref.read(liveInsightsAutoExpandProvider);
      await persistLiveIntelligenceModeToNative(intelligence);
      _liveCoordinator!.onTranscriptChanged = () {
        if (mounted) setState(() {});
      };
      try {
        await _liveCoordinator!.start(
          meetingId: meetingId,
          language: languageMode.processLanguageCode,
        );
        path = await ref.read(liveFanoutRecordingPathProvider)(meetingId);
        useFanoutRecorder = true;
      } on Object catch (error) {
        if (!mounted) return;
        setState(() {
          _liveWarning =
              'Live transcription could not start ($error). '
              'Recording will continue — the file will be transcribed after you stop.';
        });
        await _liveCoordinator?.dispose();
        _liveCoordinator = null;
      }
    }

    final recorder = useFanoutRecorder
        ? FanoutBackedAudioRecorderPort(path: path)
        : ref.read(audioRecorderPortProvider)();
    final controller = MeetingCaptureController(
      recorder: recorder,
      serviceGateway: ref.read(meetingRecordingServiceGatewayProvider),
    );
    _controller = controller;
    await _snapshotSub?.cancel();
    _snapshotSub = controller.snapshots.listen((snapshot) {
      if (mounted) setState(() => _snapshot = snapshot);
    });

    try {
      await _consentGate.startRecording(() => controller.start(path));
    } on ConsentRequiredException catch (error) {
      if (!mounted) return;
      setState(() => _startError = error.reason);
      return;
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _startError = '$error');
      return;
    }
    if (!mounted) return;
    setState(() => _snapshot = controller.current);
    if (_snapshot.lifecycle == MeetingRecordingLifecycle.failed) {
      setState(
        () => _startError = _snapshot.error ?? 'Could not start recording.',
      );
    }
  }

  Future<void> _pause() async {
    await _controller?.pause();
    await _liveCoordinator?.pause();
  }

  Future<void> _resume() async {
    await _controller?.resume();
    await _liveCoordinator?.resume();
  }

  Future<void> _stop() async {
    final controller = _controller;
    if (controller == null) return;
    final path = await controller.stop();
    if (path == null) return;

    MeetingLiveSessionResult? liveResult;
    if (_liveCoordinator != null) {
      try {
        liveResult = await _liveCoordinator!.finish(audioPath: path);
      } on Object catch (error) {
        if (mounted) {
          setState(() => _startError = '$error');
        }
      }
      await _liveCoordinator!.dispose();
      _liveCoordinator = null;
    }

    final transcriptionMode = ref.read(transcriptionModeProvider);
    final meetingId =
        _meetingId ?? 'meeting-${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now();
    final title = 'Meeting ${now.toLocal()}';
    final isLiveOnly = transcriptionMode == TranscriptionMode.live;
    final isLiveRefine = transcriptionMode == TranscriptionMode.liveRefine;
    final job = MeetingProcessingJob(
      id: meetingId,
      audioPath: path,
      title: title,
      enqueuedAtMs: now.millisecondsSinceEpoch,
      source: MeetingProcessingSource.live,
      completedTranscript: isLiveOnly ? liveResult?.text : null,
      completedSegments: isLiveOnly ? liveResult?.segments : null,
      refineBaselineSegments: isLiveRefine ? liveResult?.segments : null,
    );
    if (!mounted) return;
    setState(() {
      _processing = job;
      _processed = false;
      _processingError = null;
    });
    final queue = await ref.read(meetingProcessingQueueProvider.future);
    await _jobsSub?.cancel();
    _jobsSub = queue.jobs.listen((jobs) => _onJobsChanged(job.id, jobs));
    await queue.enqueue(job);
  }

  void _onJobsChanged(String jobId, List<MeetingProcessingJob> jobs) {
    if (!mounted) return;
    MeetingProcessingJob? mine;
    for (final candidate in jobs) {
      if (candidate.id == jobId) mine = candidate;
    }
    if (mine == null) {
      setState(() {
        _processing = null;
        _processed = true;
      });
      return;
    }
    if (mine.status == MeetingProcessingStatus.failed) {
      setState(() {
        _processing = null;
        _processingError = mine?.lastError ?? 'Transcription failed.';
      });
      return;
    }
    setState(() => _processing = mine);
  }

  @override
  Widget build(BuildContext context) {
    final showConsentUi =
        ref.watch(recordingConsentPromptProvider) || _implicitConsentFailed;
    final consentGranted = _consentGate.isGranted;
    final lifecycle = _snapshot.lifecycle;
    final recording = lifecycle == MeetingRecordingLifecycle.recording;
    final paused = lifecycle == MeetingRecordingLifecycle.paused;
    final active = recording || paused;
    final languageMode = ref.watch(speechLanguageModeProvider);
    final transcriptionMode = ref.watch(transcriptionModeProvider);
    final trustState = ScribeTrustState.fromSpeechLanguageMode(languageMode);
    final showLive =
        active &&
        transcriptionMode.usesLivePipeline &&
        _liveCoordinator != null;
    final showInsights =
        showLive &&
        ref.watch(liveInsightsEnabledProvider) &&
        ref.watch(liveIntelligenceModeProvider).collectInsights;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Record meeting'),
        actions: active
            ? [
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 10,
                        color: paused
                            ? Theme.of(context).colorScheme.outline
                            : Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        paused ? 'PAUSED' : 'LIVE',
                        key: const Key('meeting_capture_live_badge'),
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatElapsed(_snapshot.elapsedMs),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ]
            : null,
      ),
      body: active
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (paused && _snapshot.pausedByOs)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Text(
                      key: Key('meeting_capture_os_pause_notice'),
                      'Paused automatically — a call or Siri interrupted the '
                      'microphone. Recording will resume when it ends.',
                    ),
                  ),
                CompactTrustStatusBar(state: trustState),
                if (_liveWarning != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      _liveWarning!,
                      key: const Key('meeting_capture_live_warning'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.tertiary,
                      ),
                    ),
                  ),
                if (showLive && _liveCoordinator!.degradedMessage != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: Text(
                      _liveCoordinator!.degradedMessage!,
                      key: const Key('meeting_capture_live_degraded'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: showLive ? 7 : 1,
                        child: showLive
                            ? LiveTranscriptView(
                                lines: _liveCoordinator!.transcriptLines,
                                followLive: _followLive,
                                onFollowLiveChanged: (value) =>
                                    setState(() => _followLive = value),
                              )
                            : const Center(
                                child: Text('Recording — transcript after stop'),
                              ),
                      ),
                      if (showInsights)
                        LiveInsightsRail(
                          expanded: _insightsExpanded,
                          insights: _liveCoordinator!.insights,
                          onToggle: () => setState(
                            () => _insightsExpanded = !_insightsExpanded,
                          ),
                        ),
                    ],
                  ),
                ),
                LiveCaptureControls(
                  elapsedLabel: _formatElapsed(_snapshot.elapsedMs),
                  isPaused: paused,
                  followLive: _followLive,
                  onFollowLiveChanged: (value) =>
                      setState(() => _followLive = value),
                  onPause: _pause,
                  onResume: _resume,
                  onStop: _stop,
                  amplitudeSamples: showLive
                      ? _liveCoordinator!.amplitudeSamples
                      : const [],
                  speakerActivitySpans: showLive
                      ? _liveCoordinator!.speakerActivitySpans
                      : const [],
                  speakerTimelineEndMs: _snapshot.elapsedMs,
                  activeSpeakerIndex: showLive
                      ? _liveCoordinator!.activeSpeakerIndex
                      : null,
                ),
              ],
            )
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    children: [
                      if (showConsentUi) ...[
                        const _ConsentReminder(),
                        const SizedBox(height: 12),
                      ],
                      CompactTrustStatusBar(state: trustState),
                      const SizedBox(height: 12),
                      if (showConsentUi)
                        _ConsentJurisdictionPicker(
                          jurisdiction: _jurisdiction,
                          allPartiesAck: _allPartiesAck,
                          granted: consentGranted,
                          busy: _consentBusy,
                          error: _consentError,
                          onJurisdictionChanged: (jurisdiction) => setState(() {
                            _jurisdiction = jurisdiction;
                            if (!jurisdiction.requiresAllPartyNotification) {
                              _allPartiesAck = false;
                            }
                          }),
                          onAllPartiesAckChanged: (value) =>
                              setState(() => _allPartiesAck = value),
                          onConfirm: _confirmConsent,
                        ),
                      _ProcessingStatus(
                        job: _processing,
                        processed: _processed,
                        error: _processingError,
                        onOpenLibrary: () => Navigator.of(context).maybePop(),
                      ),
                    ],
                  ),
                ),
                Material(
                  elevation: 8,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        MeetingRecordingVisualizer(
                          recording: recording,
                          amplitude: _snapshot.amplitude,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _formatElapsed(_snapshot.elapsedMs),
                          key: const Key('meeting_capture_elapsed'),
                          style: Theme.of(context).textTheme.displaySmall,
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          key: const Key('meeting_capture_start_button'),
                          onPressed: consentGranted ? _start : null,
                          icon: const Icon(Icons.mic),
                          label: const Text('Start recording'),
                        ),
                        if (_startError != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _startError!,
                            key: const Key('meeting_capture_error'),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  static String _formatElapsed(int elapsedMs) {
    final seconds = elapsedMs ~/ 1000;
    final minutes = seconds ~/ 60;
    final remSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remSeconds.toString().padLeft(2, '0')}';
  }
}

/// What happened to the recording after Stop.
class _ProcessingStatus extends StatelessWidget {
  const _ProcessingStatus({
    required this.job,
    required this.processed,
    required this.error,
    required this.onOpenLibrary,
  });

  final MeetingProcessingJob? job;
  final bool processed;
  final String? error;
  final VoidCallback onOpenLibrary;

  @override
  Widget build(BuildContext context) {
    final job = this.job;
    final error = this.error;
    if (job == null && !processed && error == null) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Card(
        color: scheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (job != null)
                const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  processed ? Icons.check_circle : Icons.error_outline,
                  color: processed ? null : scheme.error,
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  job != null
                      ? 'Processing your sound on this device. Airo is '
                            'turning it into a named meeting you can search '
                            'and replay — leave whenever you want.'
                      : processed
                      ? 'Your meeting is ready in Scribe. Airo named it '
                            'from what was said — open it to listen and read.'
                      : 'Could not process this recording: '
                            '${error ?? 'unknown error'}',
                  key: const Key('meeting_capture_processing_status'),
                ),
              ),
              if (processed) ...[
                const SizedBox(width: 8),
                TextButton(
                  key: const Key('meeting_capture_open_library_button'),
                  onPressed: onOpenLibrary,
                  child: const Text('Open'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// AC6's explicit consent-reminder copy. Not a legal gate — see class doc on
/// [MeetingCaptureScreen].
class _ConsentReminder extends StatelessWidget {
  const _ConsentReminder();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Before you record',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Recording a conversation without telling the other people in '
              'it is illegal in some places — Airo Mind cannot know the law '
              'where you are, so checking it is on you. Pick where this '
              'meeting is happening below; if it requires telling everyone '
              'first, do that before you start.',
              key: Key('meeting_capture_consent_reminder_copy'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConsentJurisdictionPicker extends StatelessWidget {
  const _ConsentJurisdictionPicker({
    required this.jurisdiction,
    required this.allPartiesAck,
    required this.granted,
    required this.busy,
    required this.error,
    required this.onJurisdictionChanged,
    required this.onAllPartiesAckChanged,
    required this.onConfirm,
  });

  final ConsentJurisdiction jurisdiction;
  final bool allPartiesAck;
  final bool granted;
  final bool busy;
  final String? error;
  final ValueChanged<ConsentJurisdiction> onJurisdictionChanged;
  final ValueChanged<bool> onAllPartiesAckChanged;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    if (granted) {
      return Text(
        'Consent recorded for ${jurisdiction.label}.',
        key: const Key('meeting_capture_consent_granted'),
      );
    }
    final requiresAck = jurisdiction.requiresAllPartyNotification;
    final canConfirm =
        !busy &&
        jurisdiction.code != unselectedJurisdiction.code &&
        (!requiresAck || allPartiesAck);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<ConsentJurisdiction>(
          key: const Key('meeting_capture_jurisdiction_dropdown'),
          initialValue: jurisdiction,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Where is this meeting taking place?',
            border: OutlineInputBorder(),
          ),
          items: [unselectedJurisdiction, ...knownJurisdictions]
              .map(
                (j) => DropdownMenuItem(
                  value: j,
                  child: Text(j.label, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) onJurisdictionChanged(value);
          },
        ),
        if (requiresAck)
          CheckboxListTile(
            key: const Key('meeting_capture_all_parties_checkbox'),
            value: allPartiesAck,
            onChanged: (value) => onAllPartiesAckChanged(value ?? false),
            title: const Text(
              'I have told everyone in this meeting they are being recorded',
            ),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        const SizedBox(height: 8),
        FilledButton(
          key: const Key('meeting_capture_confirm_consent_button'),
          onPressed: canConfirm ? onConfirm : null,
          child: const Text('Confirm and enable recording'),
        ),
        if (error != null) ...[
          const SizedBox(height: 8),
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }
}
