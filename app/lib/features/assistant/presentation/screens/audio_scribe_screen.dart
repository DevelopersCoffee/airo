import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/voice_search_service.dart';

/// Audio Scribe entry point for capturing a transcript and handing it to the
/// normal Airo runtime for optional translation or summarisation.
class AudioScribeScreen extends ConsumerStatefulWidget {
  const AudioScribeScreen({super.key});

  @override
  ConsumerState<AudioScribeScreen> createState() => _AudioScribeScreenState();
}

class _AudioScribeScreenState extends ConsumerState<AudioScribeScreen> {
  final _transcriptController = TextEditingController();
  String _targetLanguage = 'English';
  bool _capturing = false;
  String? _error;
  int _captureEpoch = 0;

  @override
  void dispose() {
    _transcriptController.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    final service = ref.read(voiceSearchServiceProvider);
    final captureEpoch = ++_captureEpoch;
    setState(() {
      _capturing = true;
      _error = null;
    });
    final result = await service.startListening();
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
    final canCapture = speechReady || _capturing;
    return Scaffold(
      appBar: AppBar(title: const Text('Audio Scribe')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          const Text(
            'Capture speech, review the transcript, then send it to an installed model for translation or summarisation.',
          ),
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
