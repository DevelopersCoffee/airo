import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/app_theme_provider.dart';

/// Compact theme picker kept separate from the Settings destination list.
class ThemeSettingsScreen extends ConsumerWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Theme')),
      body: RadioGroup<AppThemeId>(
        groupValue: ref.watch(appThemeProvider),
        onChanged: (themeId) {
          if (themeId != null) {
            ref.read(appThemeProvider.notifier).setTheme(themeId);
          }
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final theme in AiroTheme.themes)
              RadioListTile<AppThemeId>(
                value: theme.id,
                title: Text(theme.name),
                subtitle: Text(theme.description),
              ),
          ],
        ),
      ),
    );
  }
}
