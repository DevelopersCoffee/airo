import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/notebook_locale_preference.dart';
import '../domain/notebook_l10n.dart';

/// Profile control for notebook UI language (separate from transcription).
class NotebookLocaleSettingsTile extends ConsumerWidget {
  const NotebookLocaleSettingsTile({super.key});

  static const _labels = <String, String>{
    'en': 'English',
    'hi': 'Hindi · हिन्दी',
    'mr': 'Marathi · मराठी',
    'es': 'Spanish · Español',
    'fr': 'French · Français',
    'de': 'German · Deutsch',
    'pt': 'Portuguese · Português',
    'ja': 'Japanese · 日本語',
    'zh': 'Chinese · 中文',
    'ar': 'Arabic · العربية',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(notebookUiLocaleProvider);
    final l10n = NotebookL10n.of(locale);

    return ListTile(
      key: const Key('notebook_locale_settings_tile'),
      title: Text(l10n.uiLanguage),
      subtitle: Text(_labels[locale] ?? locale),
      trailing: DropdownButton<String>(
        key: const Key('notebook_locale_settings_dropdown'),
        value: locale,
        onChanged: (value) {
          if (value == null) return;
          ref.read(notebookUiLocaleProvider.notifier).select(value);
        },
        items: [
          for (final code in NotebookL10n.supported)
            DropdownMenuItem(value: code, child: Text(_labels[code] ?? code)),
        ],
      ),
    );
  }
}
