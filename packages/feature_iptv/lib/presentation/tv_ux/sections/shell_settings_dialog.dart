import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/control_row_visibility_provider.dart';

Future<void> showAiroTvShellSettingsDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const AiroTvShellSettingsDialog(),
  );
}

class AiroTvShellSettingsDialog extends ConsumerWidget {
  const AiroTvShellSettingsDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visibility = ref.watch(controlRowVisibilityProvider);
    return AlertDialog(
      key: const ValueKey('airo-tv-shell-settings-dialog'),
      title: const Text('Explorer rows'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Choose which controls appear below the video. Changes apply '
              'immediately and stay set after restart.',
            ),
            const SizedBox(height: 12),
            for (final row in AiroTvControlRow.values)
              TvFocusable(
                key: ValueKey('airo-tv-row-toggle-${row.storageName}'),
                semanticLabel: '${row.label} row',
                onSelect: () => ref
                    .read(controlRowVisibilityProvider.notifier)
                    .setVisible(row, !visibility.isVisible(row)),
                child: SwitchListTile(
                  title: Text(row.label),
                  value: visibility.isVisible(row),
                  onChanged: (value) => ref
                      .read(controlRowVisibilityProvider.notifier)
                      .setVisible(row, value),
                ),
              ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          key: const ValueKey('airo-tv-shell-settings-done'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
