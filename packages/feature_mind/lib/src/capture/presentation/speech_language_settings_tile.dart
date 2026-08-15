import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/speech_language_preference.dart';
import '../domain/speech_language_mode.dart';

/// Settings control for #1664 / #1774 — Primary language vs Auto (mixed).
///
/// Drop into the Mind Profile / capture settings surface next to
/// [AudioRetentionSettingsTile]. Choosing English skips the multilingual
/// whisper download on the next model acquisition; Auto keeps mixed-language
/// auto-detect.
class SpeechLanguageSettingsTile extends ConsumerWidget {
  const SpeechLanguageSettingsTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(speechLanguageModeProvider);

    return ListTile(
      key: const Key('speech_language_settings_tile'),
      title: const Text('Meeting transcription language'),
      subtitle: Text(
        mode == SpeechLanguageMode.auto
            ? 'Auto (mixed) — multilingual model, auto-detect per recording. '
                  'Best for Marathi / Hindi / English code-switching.'
            : 'English — English-only model. Skips the multilingual download.',
      ),
      trailing: DropdownButton<SpeechLanguageMode>(
        key: const Key('speech_language_settings_dropdown'),
        value: mode,
        onChanged: (value) {
          if (value == null) return;
          ref.read(speechLanguageModeProvider.notifier).select(value);
        },
        items: const [
          DropdownMenuItem(
            value: SpeechLanguageMode.auto,
            child: Text('Auto (mixed)'),
          ),
          DropdownMenuItem(
            value: SpeechLanguageMode.english,
            child: Text('English'),
          ),
        ],
      ),
    );
  }
}
