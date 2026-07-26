import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_playlist_export/platform_playlist_export.dart';

import '../../application/providers/backup_providers.dart';
import '../../application/providers/content_source_management_providers.dart';
import '../../application/providers/guide_providers.dart';
import '../../application/providers/iptv_providers.dart';

class BackupRestoreSection extends ConsumerStatefulWidget {
  const BackupRestoreSection({super.key});

  @override
  ConsumerState<BackupRestoreSection> createState() =>
      _BackupRestoreSectionState();
}

class _BackupRestoreSectionState extends ConsumerState<BackupRestoreSection> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Backup and restore',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Backup and restore',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Move playlist sources, favorites, guide setup, and IPTV settings '
            'between devices.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          if (_busy)
            const LinearProgressIndicator(
              semanticsLabel: 'Backup operation in progress',
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: const ValueKey('backup-save-button'),
                onPressed: _busy ? null : () => _run(_save),
                icon: const Icon(Icons.save_alt),
                label: const Text('Save file'),
              ),
              OutlinedButton.icon(
                key: const ValueKey('backup-share-button'),
                onPressed: _busy ? null : () => _run(_share),
                icon: const Icon(Icons.share),
                label: const Text('Share'),
              ),
              FilledButton.icon(
                key: const ValueKey('backup-import-button'),
                onPressed: _busy ? null : () => _run(_import),
                icon: const Icon(Icons.restore),
                label: const Text('Import'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    await ref.read(iptvBackupDocumentControllerProvider).saveBackup();
    _announce('Backup file saved.');
  }

  Future<void> _share() async {
    await ref.read(iptvBackupDocumentControllerProvider).shareBackup();
  }

  Future<void> _import() async {
    final preview = await ref
        .read(iptvBackupDocumentControllerProvider)
        .pickAndPreview();
    if (preview == null || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _BackupPreviewDialog(preview: preview),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(iptvBackupServiceProvider).apply(preview);
    ref
      ..invalidate(configuredContentSourcesProvider)
      ..invalidate(favoriteChannelIdsProvider)
      ..invalidate(favoriteChannelsProvider)
      ..invalidate(xmltvSourceConfigProvider);
    _announce('Backup imported successfully.');
  }

  Future<void> _run(Future<void> Function() operation) async {
    setState(() => _busy = true);
    try {
      await operation();
    } on AiroBackupException catch (error) {
      _announce(_messageFor(error.code));
    } on Object {
      _announce('The backup operation could not be completed.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _announce(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _messageFor(AiroBackupRejection code) => switch (code) {
    AiroBackupRejection.oversized => 'This backup file is too large.',
    AiroBackupRejection.malformed => 'This backup file is malformed.',
    AiroBackupRejection.unsupportedSchema =>
      'This backup version is not supported.',
    AiroBackupRejection.invalidRecord => 'This backup contains invalid data.',
    AiroBackupRejection.conflictingRecord =>
      'This backup contains conflicting records.',
  };
}

class _BackupPreviewDialog extends StatelessWidget {
  const _BackupPreviewDialog({required this.preview});

  final AiroBackupPreview preview;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const ValueKey('backup-import-preview-dialog'),
      title: const Text('Import this backup?'),
      content: Text(
        '${preview.playlistAdditions} playlist sources, '
        '${preview.favoriteAdditions} favorites, '
        '${preview.epgAdditions} guide sources, and '
        '${preview.settingChanges} settings will be added or changed. '
        'Existing matching items stay in place.',
      ),
      actions: [
        TextButton(
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('backup-import-confirm-button'),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Import'),
        ),
      ],
    );
  }
}
