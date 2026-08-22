import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/transcription_mode_preference.dart';
import '../domain/live_transcription_support.dart';
import '../domain/transcription_mode.dart';

/// Settings control for live vs post-recording transcription (ADR-0025 §3.1).
class TranscriptionModeSettingsTile extends ConsumerWidget {
  const TranscriptionModeSettingsTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(transcriptionModeProvider);
    final livePreview = liveTranscriptionPreviewSupported();
    final selectableModes = livePreview
        ? TranscriptionMode.values
        : [TranscriptionMode.afterRecording];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          key: const Key('transcription_mode_settings_tile'),
          title: const Text('Meeting transcription timing'),
          subtitle: Text(
            livePreview
                ? '${mode.settingsSubtitle}\n$liveTranscriptionPreviewDisclaimer'
                : liveTranscriptionUnavailableMessage(),
          ),
          trailing: DropdownButton<TranscriptionMode>(
            key: const Key('transcription_mode_settings_dropdown'),
            value: mode,
            onChanged: (value) {
              if (value == null) return;
              ref.read(transcriptionModeProvider.notifier).select(value);
            },
            items: [
              for (final item in selectableModes)
                DropdownMenuItem(value: item, child: Text(item.menuLabel)),
            ],
          ),
        ),
      ],
    );
  }
}
