import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/control_row_visibility_provider.dart';
import '../../widgets/backup_restore_section.dart';

Future<void> showAiroTvShellSettingsDialog(
  BuildContext context, {
  VoidCallback? onPlaylistSourceTap,
  VoidCallback? onGuideSourceTap,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => AiroTvShellSettingsDialog(
      onPlaylistSourceTap: onPlaylistSourceTap,
      onGuideSourceTap: onGuideSourceTap,
    ),
  );
}

class AiroTvShellSettingsDialog extends ConsumerWidget {
  const AiroTvShellSettingsDialog({
    super.key,
    this.onPlaylistSourceTap,
    this.onGuideSourceTap,
  });

  /// Opens the playlist-source sheet. Re-homed here from the phone app bar
  /// / TV info bar (revamp Task 10) so it's reachable from the Explorer-rows
  /// settings sheet too. Null hides the row, matching every other optional
  /// entry point in this codebase.
  final VoidCallback? onPlaylistSourceTap;

  /// Opens the XMLTV guide-source sheet. Null hides the row.
  final VoidCallback? onGuideSourceTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visibility = ref.watch(controlRowVisibilityProvider);
    return AlertDialog(
      key: const ValueKey('airo-tv-shell-settings-dialog'),
      title: const Text('Explorer rows'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
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
              if (onPlaylistSourceTap != null)
                TvFocusable(
                  key: const ValueKey('shell-settings-playlist-source'),
                  semanticLabel: 'Playlist source',
                  onSelect: onPlaylistSourceTap,
                  child: ListTile(
                    leading: const Icon(Icons.link),
                    title: const Text('Playlist source'),
                    onTap: onPlaylistSourceTap,
                  ),
                ),
              if (onGuideSourceTap != null)
                TvFocusable(
                  key: const ValueKey('shell-settings-guide-source'),
                  semanticLabel: 'Guide URL',
                  onSelect: onGuideSourceTap,
                  child: ListTile(
                    leading: const Icon(Icons.calendar_month_outlined),
                    title: const Text('Guide URL'),
                    onTap: onGuideSourceTap,
                  ),
                ),
              const Divider(height: 32),
              const BackupRestoreSection(),
            ],
          ),
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
