import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/app_theme_provider.dart';

/// Theme picker for the TV settings screen (CV-022). Reuses the same
/// [appThemeProvider] the phone profile screen's theme picker already
/// consumes — no new persistence.
class TvThemeSection extends ConsumerWidget {
  const TvThemeSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(appThemeProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return ListView.separated(
      itemCount: AppThemeId.values.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final id = AppThemeId.values[index];
        final definition = AppTheme.byId(id);
        final isSelected = id == current;
        return TvFocusable(
          autofocus: index == 0,
          onSelect: () => ref.read(appThemeProvider.notifier).setTheme(id),
          semanticLabel: definition.name,
          semanticButton: true,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isSelected
                  ? colorScheme.primaryContainer
                  : colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    definition.name,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  if (isSelected) Icon(Icons.check, color: colorScheme.primary),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
