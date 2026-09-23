import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/caption_preference_provider.dart';
import '../../../application/providers/tv_font_mode_provider.dart';

/// Shared Accessibility pane for Aika Stream settings (Slice 1).
///
/// Text size writes [tvFontModeProvider]; captions write
/// [captionPreferenceProvider]. TV uses D-pad [TvFocusable] rows (no
/// Material [Switch]); phone uses a [Switch] for captions.
class AccessibilitySettingsSection extends ConsumerWidget {
  const AccessibilitySettingsSection({super.key, required this.forTv});

  final bool forTv;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fontMode = ref.watch(tvFontModeProvider);
    final captions = ref.watch(captionPreferenceProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final modes = TvFontMode.values;

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
          child: Text(
            'Text size applies to channel names in the library.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        for (var index = 0; index < modes.length; index++)
          Padding(
            padding: EdgeInsets.only(
              bottom: index == modes.length - 1 ? 16 : 8,
            ),
            child: _SelectableOption(
              label: _labelFor(modes[index]),
              isSelected: modes[index] == fontMode,
              autofocus: forTv && index == 0,
              onSelect: () => ref
                  .read(tvFontModeProvider.notifier)
                  .setTvFontMode(modes[index]),
              colorScheme: colorScheme,
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
          child: Text(
            'On reapplies the last language you picked in the player. '
            'If you have not picked one yet, captions stay off until you do.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        if (forTv) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _SelectableOption(
              label: 'Off',
              semanticLabel: 'Captions off',
              isSelected: !captions.enabled,
              onSelect: () => ref
                  .read(captionPreferenceProvider.notifier)
                  .setCaptionsEnabled(false),
              colorScheme: colorScheme,
            ),
          ),
          _SelectableOption(
            label: 'On',
            semanticLabel: 'Captions on',
            isSelected: captions.enabled,
            onSelect: () => ref
                .read(captionPreferenceProvider.notifier)
                .setCaptionsEnabled(true),
            colorScheme: colorScheme,
          ),
        ] else
          SwitchListTile(
            title: const Text('Captions'),
            value: captions.enabled,
            onChanged: (value) => ref
                .read(captionPreferenceProvider.notifier)
                .setCaptionsEnabled(value),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
          child: Text(
            captions.languageCode == null
                ? 'No language saved — pick one in the player.'
                : 'Saved language: ${captions.languageCode}.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  String _labelFor(TvFontMode mode) {
    return switch (mode) {
      TvFontMode.standard => 'Standard',
      TvFontMode.large => 'Large',
      TvFontMode.extraLarge => 'Extra large',
    };
  }
}

class _SelectableOption extends StatelessWidget {
  const _SelectableOption({
    required this.label,
    required this.isSelected,
    required this.onSelect,
    required this.colorScheme,
    this.autofocus = false,
    this.semanticLabel,
  });

  final String label;
  final String? semanticLabel;
  final bool isSelected;
  final bool autofocus;
  final VoidCallback onSelect;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      autofocus: autofocus,
      onSelect: onSelect,
      semanticLabel: semanticLabel ?? label,
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
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
                ),
              ),
              if (isSelected) Icon(Icons.check, color: colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
