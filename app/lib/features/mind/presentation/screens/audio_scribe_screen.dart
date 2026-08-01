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

  @override
  void dispose() {
    _transcriptController.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    final service = ref.read(voiceSearchServiceProvider);
    setState(() {
      _capturing = true;
      _error = null;
    });
    final result = await service.startListening();
    if (!mounted) return;
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
    await ref.read(voiceSearchServiceProvider).stopListening();
    if (mounted) setState(() => _capturing = false);
  }

  void _translate() {
    final transcript = _transcriptController.text.trim();
    if (transcript.isEmpty) return;
    final prompt =
        'Translate the following transcript into $_targetLanguage. '
        'Preserve names, numbers, and speaker intent.\n\n$transcript';
    context.push('/mind/chat?prefill=${Uri.encodeComponent(prompt)}');
  }

  @override
  Widget build(BuildContext context) {
    final available = ref.watch(voiceSearchAvailableProvider);
    final hasTranscript = _transcriptController.text.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('Audio Scribe')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          const Text(
            'Capture speech, review the transcript, then send it to an installed model for translation or summarisation.',
          ),
          const SizedBox(height: 12),
          available.when(
            data: (isAvailable) =>
                _AvailabilityBanner(isAvailable: isAvailable),
            loading: () => const LinearProgressIndicator(),
            error: (_, error) => const _AvailabilityBanner(isAvailable: false),
          ),
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
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const Key('audio_scribe_capture_button'),
            onPressed: _capturing ? _stop : _capture,
            icon: Icon(_capturing ? Icons.stop : Icons.mic),
            label: Text(_capturing ? 'Stop capture' : 'Start capture'),
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
            onPressed: () => context.push('/mind/models'),
            icon: const Icon(Icons.download_outlined),
            label: const Text('Manage local models'),
          ),
        ],
      ),
    );
  }
}

class _AvailabilityBanner extends StatelessWidget {
  const _AvailabilityBanner({required this.isAvailable});

  final bool isAvailable;

  @override
  Widget build(BuildContext context) {
    final color = isAvailable
        ? Theme.of(context).colorScheme.primaryContainer
        : Theme.of(context).colorScheme.errorContainer;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(isAvailable ? Icons.mic : Icons.mic_off),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isAvailable
                  ? 'Speech recognition is ready on this device.'
                  : 'Speech recognition is unavailable. Install or enable a speech service to capture audio.',
            ),
          ),
        ],
      ),
    );
  }
}
