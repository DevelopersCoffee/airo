import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../assistant/consent/audio_scribe_consent_gate.dart';
import '../../assistant/consent/jurisdiction_consent_rules.dart';
import '../../assistant/consent/mind_runtime_provider.dart';
import '../../assistant/consent/recording_consent_prompt.dart';
import '../../trust/scribe_trust_signals.dart';
import '../../trust/scribe_trust_state.dart';
import '../application/meeting_capture_controller.dart';
import '../application/meeting_capture_providers.dart';
import '../application/speech_language_preference.dart';
import '../domain/meeting_processing_job.dart';
import '../domain/meeting_recording_state.dart';
import 'meeting_recording_visualizer.dart';

/// In-app meeting capture (#1656 AC1, AC6).
///
/// Reuses `AudioScribeConsentGate` — the same gate `AudioScribeScreen` uses
/// for live dictation — as the one door to the encoder, per that gate's own
/// doc: "a screen that wants to record audio has no other route to the
/// encoder available to it". This screen's [MeetingCaptureController] is
/// only ever started from inside [AudioScribeConsentGate.startRecording], the
/// same shape `AudioScribeScreen._capture` already uses for the streaming
/// path.
///
/// AC6's "explicit recording-consent UX copy" lives in [_ConsentReminder]
/// below: a plain-language reminder that recording consent law varies by
/// where the meeting happens, and that checking it is the person's
/// responsibility — this screen shows a jurisdiction picker and (for
/// two-party jurisdictions) blocks on an "I notified everyone" acknowledgment
/// before starting, but it is not a legal gate; nothing here verifies the
/// acknowledgment is true.
///
/// That picker is behind [recordingConsentPromptProvider], off by default. With
/// it off the gate is still the only door to the encoder; consent is granted up
/// front under [implicitConsentJurisdiction] so Start works on arrival.
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

  /// Set when the up-front grant (prompt disabled) could not write its op.
  /// Falls back to showing the picker rather than leaving Start dead with no
  /// explanation.
  bool _implicitConsentFailed = false;

  StreamSubscription<MeetingRecordingSnapshot>? _snapshotSub;
  StreamSubscription<List<MeetingProcessingJob>>? _jobsSub;
  MeetingCaptureController? _controller;
  MeetingRecordingSnapshot _snapshot = MeetingRecordingSnapshot.idle;
  String? _startError;

  /// The job this session enqueued, while it is still in the queue. Non-null
  /// means "transcribing" — the screen stays put and reports progress instead
  /// of dropping the person back into a library that will not list the meeting
  /// for another few minutes.
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
    // The provider owns the controller. Disposing it here also disposed the
    // encoder, so returning to this screen after consent left Start dead.
    _snapshotSub?.cancel();
    _jobsSub?.cancel();
    super.dispose();
  }

  /// Records consent without asking, for when [recordingConsentPromptProvider]
  /// is off. Still goes through [AudioScribeConsentGate.grant], so the op log
  /// carries a consent entry for every recording exactly as before.
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
    setState(() => _startError = null);
    final controller = ref.read(meetingCaptureControllerProvider);
    _controller = controller;
    await _snapshotSub?.cancel();
    _snapshotSub = controller.snapshots.listen((snapshot) {
      if (mounted) setState(() => _snapshot = snapshot);
    });
    try {
      final path = await ref.read(meetingRecordingPathProvider)();
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

  Future<void> _pause() async => _controller?.pause();

  Future<void> _resume() async => _controller?.resume();

  Future<void> _stop() async {
    final controller = _controller;
    if (controller == null) return;
    final path = await controller.stop();
    if (path == null) return;
    final now = DateTime.now();
    final job = MeetingProcessingJob(
      id: 'meeting-${now.millisecondsSinceEpoch}',
      audioPath: path,
      title: 'Meeting ${now.toLocal()}',
      enqueuedAtMs: now.millisecondsSinceEpoch,
      source: MeetingProcessingSource.live,
    );
    if (!mounted) return;
    setState(() {
      _processing = job;
      _processed = false;
      _processingError = null;
    });
    final queue = await ref.read(meetingProcessingQueueProvider.future);
    // Subscribed before `enqueue` so the first persisted state is not missed:
    // a short recording can finish transcribing before a later listen lands,
    // and the queue prunes completed jobs, which would look like a job that
    // never existed.
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
      // Gone from the queue means processed: `MeetingProcessingQueue` prunes a
      // job the moment it succeeds, because the meeting lives in the store
      // from then on (see that class's "Retention discipline" note).
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
    // autoDispose: `ref.read` does not keep the controller alive. Watching
    // here is what stops Start from disposing the encoder on the same frame.
    ref.watch(meetingCaptureControllerProvider);
    final showConsentUi =
        ref.watch(recordingConsentPromptProvider) || _implicitConsentFailed;
    final consentGranted = _consentGate.isGranted;
    final lifecycle = _snapshot.lifecycle;
    final recording = lifecycle == MeetingRecordingLifecycle.recording;
    final paused = lifecycle == MeetingRecordingLifecycle.paused;
    final active = recording || paused;
    final languageMode = ref.watch(speechLanguageModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Record meeting')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                if (showConsentUi) ...[
                  const _ConsentReminder(),
                  const SizedBox(height: 12),
                ],
                ScribeTrustSignals(
                  state: ScribeTrustState.fromSpeechLanguageMode(languageMode),
                ),
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
                if (paused && _snapshot.pausedByOs)
                  const Padding(
                    padding: EdgeInsets.only(top: 20),
                    child: Text(
                      key: Key('meeting_capture_os_pause_notice'),
                      'Paused automatically — a call or Siri interrupted the '
                      'microphone. Recording will resume when it ends.',
                    ),
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      if (active)
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: Icon(
                            paused
                                ? Icons.pause_circle_filled
                                : Icons.fiber_manual_record,
                            color: Theme.of(context).colorScheme.error,
                            size: 18,
                          ),
                        ),
                      Text(
                        _formatElapsed(_snapshot.elapsedMs),
                        key: const Key('meeting_capture_elapsed'),
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      if (!active)
                        FilledButton.icon(
                          key: const Key('meeting_capture_start_button'),
                          onPressed: consentGranted ? _start : null,
                          icon: const Icon(Icons.mic),
                          label: const Text('Start recording'),
                        ),
                      if (recording)
                        OutlinedButton.icon(
                          key: const Key('meeting_capture_pause_button'),
                          onPressed: _pause,
                          icon: const Icon(Icons.pause),
                          label: const Text('Pause'),
                        ),
                      if (paused && !_snapshot.pausedByOs)
                        OutlinedButton.icon(
                          key: const Key('meeting_capture_resume_button'),
                          onPressed: _resume,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Resume'),
                        ),
                      if (active)
                        FilledButton.icon(
                          key: const Key('meeting_capture_stop_button'),
                          onPressed: _stop,
                          icon: const Icon(Icons.stop),
                          label: const Text('Stop'),
                        ),
                    ],
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
///
/// Transcription runs on a background queue that can take minutes, so without
/// this the person saw Stop do nothing at all and concluded the meeting was
/// lost — the library genuinely has nothing to show until the job finishes.
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
