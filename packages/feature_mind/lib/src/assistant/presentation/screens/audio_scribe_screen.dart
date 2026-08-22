import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../services/voice_search_service.dart';
import '../../../trust/scribe_trust_signals.dart';
import '../../../trust/scribe_trust_state.dart';
import '../../consent/audio_scribe_consent_gate.dart';
import '../../consent/jurisdiction_consent_rules.dart';
import '../../consent/mind_runtime_provider.dart';
import '../../consent/recording_consent_prompt.dart';

/// Audio Scribe entry point for capturing a transcript and handing it to the
/// normal Airo runtime for optional translation or summarisation.
///
/// Recording a conversation is a legal act, so the consent banner sits
/// directly under the app bar and blocks capture: [AudioScribeConsentGate]
/// is the only object this screen holds that can reach the microphone
/// encoder, and it refuses to run it until [AudioScribeConsentGate.grant] has
/// recorded a signed consent op on the Mind log.
class AudioScribeScreen extends ConsumerStatefulWidget {
  const AudioScribeScreen({super.key});

  @override
  ConsumerState<AudioScribeScreen> createState() => _AudioScribeScreenState();
}

class _AudioScribeScreenState extends ConsumerState<AudioScribeScreen> {
  static const _contextId = 'audio-scribe';

  final _transcriptController = TextEditingController();
  final _consentGate = AudioScribeConsentGate();
  String _targetLanguage = 'English';
  bool _capturing = false;
  String? _error;
  int _captureEpoch = 0;

  ConsentJurisdiction _jurisdiction = unselectedJurisdiction;
  bool _allPartiesAck = false;
  bool _consentBusy = false;
  String? _consentError;
  bool _partialTranscript = false;
  bool _implicitConsentFailed = false;

  @override
  void initState() {
    super.initState();
    if (!ref.read(recordingConsentPromptProvider)) {
      unawaited(_grantImplicitConsent());
    }
  }

  @override
  void dispose() {
    _transcriptController.dispose();
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
    } on Object {
      if (!mounted) return;
      setState(() => _implicitConsentFailed = true);
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

  Future<void> _revokeConsent() async {
    final wasCapturing = _capturing;
    await _consentGate.revoke(
      log: ref.read(mindRuntimeProvider).log,
      contextId: _contextId,
      nowMs: DateTime.now().millisecondsSinceEpoch,
    );
    if (wasCapturing) {
      // Advancing the epoch makes any in-flight `startListening()` result a
      // no-op when it lands, the same guard `_stop()` relies on below.
      _captureEpoch++;
      await ref.read(voiceSearchServiceProvider).stopListening();
    }
    if (!mounted) return;
    setState(() {
      if (wasCapturing) {
        _capturing = false;
        _partialTranscript = true;
      }
      _allPartiesAck = false;
    });
  }

  Future<void> _capture() async {
    // The gate call below is what actually enforces the rule; this early
    // return only keeps the button's disabled state and the guard in sync.
    if (!_consentGate.isGranted) return;
    final service = ref.read(voiceSearchServiceProvider);
    final captureEpoch = ++_captureEpoch;
    setState(() {
      _capturing = true;
      _error = null;
      _partialTranscript = false;
    });
    VoiceSearchResult result;
    try {
      result = await _consentGate.startRecording(
        () => service.startListening(),
      );
    } on ConsentRequiredException catch (error) {
      if (!mounted || captureEpoch != _captureEpoch) return;
      setState(() {
        _capturing = false;
        _error = error.reason;
      });
      return;
    }
    if (!mounted || captureEpoch != _captureEpoch) return;
    setState(() {
      _capturing = false;
      if (result.isSuccess && result.text != null) {
        final existing = _transcriptController.text.trim();
        _transcriptController.text = existing.isEmpty
            ? result.text!
            : '$existing\n\n${result.text!}';
        _transcriptController.selection = TextSelection.collapsed(
          offset: _transcriptController.text.length,
        );
      } else {
        _error = result.errorMessage ?? 'No speech was recognized.';
      }
    });
  }

  Future<void> _stop() async {
    _captureEpoch++;
    await ref.read(voiceSearchServiceProvider).stopListening();
    if (mounted) setState(() => _capturing = false);
  }

  void _translate() {
    final transcript = _transcriptController.text.trim();
    if (transcript.isEmpty) return;
    final prompt =
        'Translate the following transcript into $_targetLanguage. '
        'Preserve names, numbers, and speaker intent.\n\n$transcript';
    context.push('/assistant/chat?prefill=${Uri.encodeComponent(prompt)}');
  }

  @override
  Widget build(BuildContext context) {
    final available = ref.watch(voiceSearchAvailableProvider);
    final hasTranscript = _transcriptController.text.trim().isNotEmpty;
    final speechReady = available.value == true;
    final showConsentUi =
        ref.watch(recordingConsentPromptProvider) || _implicitConsentFailed;
    final consentGranted = _consentGate.isGranted;
    final canCapture = (speechReady && consentGranted) || _capturing;
    return Scaffold(
      appBar: AppBar(title: const Text('Audio Scribe')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          if (showConsentUi) ...[
            _ConsentGateBanner(
              consent: _consentGate.consent,
              isGranted: consentGranted,
              jurisdiction: _jurisdiction,
              allPartiesAck: _allPartiesAck,
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
              onRevoke: _revokeConsent,
            ),
            const SizedBox(height: 12),
          ],
          const Text(
            'Capture speech, review the transcript, then send it to an installed model for translation or summarisation.',
          ),
          const SizedBox(height: 12),
          // #1774: listen-mode prefers India locales (#1769); capture itself
          // is on-device. Translation is a separate, explicit hand-off.
          const ScribeTrustSignals(state: ScribeTrustState.audioScribeListen()),
          const SizedBox(height: 12),
          _VoiceHealthPanel(
            availability: available,
            capturing: _capturing,
            hasTranscript: hasTranscript,
            lastError: _error,
            onRetry: () => ref.invalidate(voiceSearchAvailableProvider),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const Key('audio_scribe_capture_button'),
            onPressed: canCapture ? (_capturing ? _stop : _capture) : null,
            icon: Icon(_capturing ? Icons.stop : Icons.mic),
            label: Text(_capturing ? 'Stop capture' : 'Start capture'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (_partialTranscript) ...[
            const SizedBox(height: 8),
            Text(
              'Consent was revoked mid-recording. The transcript above is partial.',
              key: const Key('audio_scribe_partial_notice'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _transcriptController,
            minLines: 10,
            maxLines: 18,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Transcript',
              hintText: 'Your recognized speech will appear here…',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _targetLanguage,
                  decoration: const InputDecoration(
                    labelText: 'Translate to',
                    border: OutlineInputBorder(),
                  ),
                  items: const ['English', 'Hindi', 'Spanish', 'French']
                      .map(
                        (language) => DropdownMenuItem(
                          value: language,
                          child: Text(language),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() {
                    if (value != null) _targetLanguage = value;
                  }),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: hasTranscript
                    ? () => Clipboard.setData(
                        ClipboardData(text: _transcriptController.text),
                      )
                    : null,
                icon: const Icon(Icons.copy_outlined),
                label: const Text('Copy'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: hasTranscript ? _translate : null,
            icon: const Icon(Icons.translate),
            label: const Text('Translate with Airo'),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => context.push('/assistant/models'),
            icon: const Icon(Icons.download_outlined),
            label: const Text('Manage local models'),
          ),
        ],
      ),
    );
  }
}

/// The blocking consent gate banner, directly under the app bar.
///
/// Not a settings toggle: while [isGranted] is false the capture button
/// above stays disabled, because [AudioScribeConsentGate] refuses to reach
/// the encoder without a grant. This widget only presents that state and
/// forwards intent — it holds no path to the encoder of its own.
class _ConsentGateBanner extends StatelessWidget {
  const _ConsentGateBanner({
    required this.consent,
    required this.isGranted,
    required this.jurisdiction,
    required this.allPartiesAck,
    required this.busy,
    required this.error,
    required this.onJurisdictionChanged,
    required this.onAllPartiesAckChanged,
    required this.onConfirm,
    required this.onRevoke,
  });

  final ConsentRecord? consent;
  final bool isGranted;
  final ConsentJurisdiction jurisdiction;
  final bool allPartiesAck;
  final bool busy;
  final String? error;
  final ValueChanged<ConsentJurisdiction> onJurisdictionChanged;
  final ValueChanged<bool> onAllPartiesAckChanged;
  final VoidCallback onConfirm;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    if (isGranted) {
      final record = consent!;
      final timestamp = DateTime.fromMillisecondsSinceEpoch(record.grantedAtMs);
      final statement = record.allPartiesNotified
          ? 'All parties were notified this conversation may be recorded.'
          : 'One-party consent jurisdiction — recorded for the record.';
      return Card(
        key: const Key('audio_scribe_consent_granted'),
        color: Theme.of(context).colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.verified_user_outlined),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Recording consent confirmed ${_formatTimestamp(timestamp)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(statement),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  key: const Key('audio_scribe_revoke_consent_button'),
                  onPressed: onRevoke,
                  icon: const Icon(Icons.mic_off_outlined),
                  label: const Text('Revoke consent'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final needsNotification = jurisdiction.requiresAllPartyNotification;
    final canConfirm =
        !busy &&
        jurisdiction.code != unselectedJurisdiction.code &&
        (!needsNotification || allPartiesAck);
    return Card(
      key: const Key('audio_scribe_consent_request'),
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.mic_external_on_outlined),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Recording requires consent before it can start.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              key: const Key('audio_scribe_jurisdiction_dropdown'),
              initialValue: jurisdiction.code,
              decoration: const InputDecoration(
                labelText: 'Where is this conversation taking place?',
                border: OutlineInputBorder(),
              ),
              items: [unselectedJurisdiction, ...knownJurisdictions]
                  .map(
                    (option) => DropdownMenuItem(
                      value: option.code,
                      child: Text(option.label),
                    ),
                  )
                  .toList(),
              onChanged: (code) {
                if (code == null) return;
                onJurisdictionChanged(jurisdictionByCode(code));
              },
            ),
            if (needsNotification) ...[
              const SizedBox(height: 4),
              CheckboxListTile(
                key: const Key('audio_scribe_all_parties_checkbox'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: allPartiesAck,
                onChanged: (value) => onAllPartiesAckChanged(value ?? false),
                title: const Text(
                  'All parties in this conversation have been notified it may be recorded.',
                ),
              ),
            ] else if (jurisdiction.code != unselectedJurisdiction.code) ...[
              const SizedBox(height: 4),
              const Text(
                'This is a one-party consent jurisdiction. Recording is still '
                'logged as a signed consent event for the record.',
              ),
            ],
            if (error != null) ...[
              const SizedBox(height: 4),
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                key: const Key('audio_scribe_confirm_consent_button'),
                onPressed: canConfirm ? onConfirm : null,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Confirm consent'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatTimestamp(DateTime timestamp) {
  final local = timestamp.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

class _VoiceHealthPanel extends StatelessWidget {
  const _VoiceHealthPanel({
    required this.availability,
    required this.capturing,
    required this.hasTranscript,
    required this.lastError,
    required this.onRetry,
  });

  final AsyncValue<bool> availability;
  final bool capturing;
  final bool hasTranscript;
  final String? lastError;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final serviceReady = availability.value == true;
    final serviceLoading = availability.isLoading;
    final availabilityError = availability.hasError
        ? _voiceAvailabilityError(availability.error)
        : null;
    final summary = serviceLoading
        ? 'Checking speech recognition…'
        : serviceReady
        ? 'Speech recognition is ready on this device.'
        : 'Speech recognition is unavailable. Install or enable a speech service to capture audio.';
    final reason = availabilityError ?? lastError;
    final color = serviceReady
        ? Theme.of(context).colorScheme.primaryContainer
        : serviceLoading
        ? Theme.of(context).colorScheme.surfaceContainerHighest
        : Theme.of(context).colorScheme.errorContainer;
    final status = serviceLoading
        ? 'checking'
        : serviceReady
        ? 'ready'
        : 'unavailable';
    return Semantics(
      container: true,
      label:
          'Audio Scribe voice health. Speech service $status. '
          'Capture ${capturing ? 'listening' : 'idle'}. '
          'Transcript ${hasTranscript ? 'ready' : 'empty'}. '
          'Model handoff ${hasTranscript ? 'ready' : 'waiting for transcript'}.'
          '${reason == null ? '' : ' Reason: $reason'}',
      child: Card(
        key: const Key('audio_scribe_voice_health'),
        color: color,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: serviceLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(serviceReady ? Icons.mic : Icons.mic_off),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(summary)),
                ],
              ),
              const SizedBox(height: 8),
              _VoiceHealthRow(
                label: 'Speech service',
                value: serviceLoading
                    ? 'Checking'
                    : serviceReady
                    ? 'Ready'
                    : 'Unavailable',
              ),
              _VoiceHealthRow(
                label: 'Capture',
                value: capturing ? 'Listening' : 'Idle',
              ),
              _VoiceHealthRow(
                label: 'Transcript',
                value: hasTranscript ? 'Ready' : 'Empty',
              ),
              _VoiceHealthRow(
                label: 'Model handoff',
                value: hasTranscript ? 'Ready' : 'Waiting for transcript',
              ),
              if (reason != null) ...[
                const SizedBox(height: 8),
                Text('Reason: $reason'),
              ],
              if (!serviceReady && !serviceLoading) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    key: const Key('audio_scribe_retry_voice_check'),
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry voice check'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _VoiceHealthRow extends StatelessWidget {
  const _VoiceHealthRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Text(value),
        ],
      ),
    );
  }
}

String _voiceAvailabilityError(Object? error) {
  if (error == null) return 'The speech service did not provide details.';
  final message = error.toString().trim();
  return message.isEmpty
      ? 'The speech service did not provide details.'
      : message;
}
