import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_playlist_export/platform_playlist_export.dart';

import '../../application/providers/backup_providers.dart';
import '../../application/providers/iptv_providers.dart';
import 'backup_restore_section.dart';

enum _FavoritesBackupAction { exportM3u, backupRestore }

class FavoritesBackupMenu extends ConsumerWidget {
  const FavoritesBackupMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<_FavoritesBackupAction>(
      key: const ValueKey('favorites-backup-overflow'),
      tooltip: 'Favorites backup options',
      icon: const Icon(Icons.more_vert),
      onSelected: (action) => _handle(context, ref, action),
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: _FavoritesBackupAction.exportM3u,
          child: ListTile(
            leading: Icon(Icons.playlist_add_check),
            title: Text('Share favorites as M3U'),
          ),
        ),
        PopupMenuItem(
          value: _FavoritesBackupAction.backupRestore,
          child: ListTile(
            leading: Icon(Icons.settings_backup_restore),
            title: Text('Backup and restore'),
          ),
        ),
      ],
    );
  }

  Future<void> _handle(
    BuildContext context,
    WidgetRef ref,
    _FavoritesBackupAction action,
  ) async {
    switch (action) {
      case _FavoritesBackupAction.exportM3u:
        final channels = await ref.read(favoriteChannelsProvider.future);
        final contents = exportFavoritesM3u([
          for (final channel in channels)
            AiroBackupFavorite(
              channelId: channel.id,
              name: channel.name,
              url: channel.streamUrl,
              group: channel.group,
            ),
        ]);
        final shared = await ref
            .read(iptvBackupDocumentGatewayProvider)
            .share(
              AiroBackupDocument(
                fileName: 'airo_tv_favorites.m3u',
                mediaType: 'audio/x-mpegurl',
                contents: contents,
              ),
            );
        // Silent on success — the share sheet already confirmed. On TV
        // `share_plus` is stubbed, so without this the menu item looks
        // like a dead control.
        if (shared || !context.mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Favorites were not shared.')),
          );
        return;
      case _FavoritesBackupAction.backupRestore:
        if (!context.mounted) return;
        await showDialog<void>(
          context: context,
          builder: (context) => const AlertDialog(
            title: Text('Favorites backup'),
            content: SingleChildScrollView(child: BackupRestoreSection()),
          ),
        );
    }
  }
}
