import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/speech_language_preference.dart';
import '../domain/speech_language_mode.dart';

/// Settings control for #1664 / #1774 — a real language catalog, not only
/// Auto vs English.
///
/// Drop into the Mind Profile / capture settings surface next to
/// [AudioRetentionSettingsTile]. Choosing English skips the multilingual
/// whisper download on the next model acquisition; Auto keeps mixed-language
/// auto-detect; every other row pins a whisper.cpp language code.
class SpeechLanguageSettingsTile extends ConsumerWidget {
  const SpeechLanguageSettingsTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(speechLanguageModeProvider);

    return ListTile(
      key: const Key('speech_language_settings_tile'),
      title: const Text('Meeting transcription language'),
      subtitle: Text(mode.settingsSubtitle),
      trailing: DropdownButton<SpeechLanguageMode>(
        key: const Key('speech_language_settings_dropdown'),
        value: mode,
        onChanged: (value) {
          if (value == null) return;
          ref.read(speechLanguageModeProvider.notifier).select(value);
        },
        items: [
          for (final item in SpeechLanguageMode.values)
            DropdownMenuItem(value: item, child: Text(item.menuLabel)),
        ],
      ),
    );
  }
}
