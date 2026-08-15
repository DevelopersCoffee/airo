import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../assistant/consent/audio_scribe_consent_gate.dart';
import '../../assistant/consent/jurisdiction_consent_rules.dart';
import '../../assistant/consent/mind_runtime_provider.dart';
import '../application/meeting_capture_controller.dart';
import '../application/meeting_capture_providers.dart';
import '../domain/meeting_processing_job.dart';
import '../domain/meeting_recording_state.dart';

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

  MeetingCaptureController? _controller;
  MeetingRecordingSnapshot _snapshot = MeetingRecordingSnapshot.idle;
  String? _startError;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
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
    controller.snapshots.listen((snapshot) {
      if (mounted) setState(() => _snapshot = snapshot);
    });
    final path = await nextMeetingRecordingPath();
    try {
      await _consentGate.startRecording(() => controller.start(path));
    } on ConsentRequiredException catch (error) {
      if (!mounted) return;
      setState(() => _startError = error.reason);
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
    final queue = await ref.read(meetingProcessingQueueProvider.future);
    await queue.enqueue(
      MeetingProcessingJob(
        id: 'meeting-${DateTime.now().millisecondsSinceEpoch}',
        audioPath: path,
        title: 'Meeting ${DateTime.now().toLocal()}',
        enqueuedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final consentGranted = _consentGate.isGranted;
    final lifecycle = _snapshot.lifecycle;
    final recording = lifecycle == MeetingRecordingLifecycle.recording;
    final paused = lifecycle == MeetingRecordingLifecycle.paused;
    final active = recording || paused;

    return Scaffold(
      appBar: AppBar(title: const Text('Record meeting')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          const _ConsentReminder(),
          const SizedBox(height: 12),
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
          const SizedBox(height: 20),
          if (paused && _snapshot.pausedByOs)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                key: Key('meeting_capture_os_pause_notice'),
                'Paused automatically — a call or Siri interrupted the '
                'microphone. Recording will resume when it ends.',
              ),
            ),
          Text(
            _formatElapsed(_snapshot.elapsedMs),
            key: const Key('meeting_capture_elapsed'),
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
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
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
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
    final canConfirm = !busy && (!requiresAck || allPartiesAck);
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
            title: const Text('I have told everyone in this meeting they are being recorded'),
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
          Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
      ],
    );
  }
}
