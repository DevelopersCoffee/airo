import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_media/platform_media.dart';

import '../../application/providers/iptv_providers.dart';
import '../../product_identity.dart';

/// Folder-walking USB/DLNA picker used by 10-foot Home and Explorer.
Future<LocalMediaEntry?> showTvLocalMediaBrowser(
  BuildContext context, {
  required String initialRoot,
  required String title,
  required Future<List<LocalMediaEntry>> Function(String root) browse,
  bool isNetworkBrowse = false,
}) async {
  var currentRoot = initialRoot;
  while (context.mounted) {
    final selected = await showDialog<LocalMediaEntry>(
      context: context,
      builder: (_) => TvLocalMediaBrowserDialog(
        title: title,
        loadEntries: () => browse(currentRoot),
        isNetworkBrowse: isNetworkBrowse,
      ),
    );
    if (!context.mounted || selected == null) return null;
    if (selected.kind == LocalMediaEntryKind.folder) {
      final nextRoot = selected.childrenUri;
      if (nextRoot == null) return null;
      currentRoot = nextRoot;
      continue;
    }
    return selected;
  }
  return null;
}

Future<void> browseTvUsb(
  BuildContext context,
  WidgetRef ref,
  ValueChanged<IPTVChannel>? onPlayChannel,
) async {
  final adapter = ref.read(localMediaLibraryAdapterProvider);
  String? root;
  try {
    root = await adapter.requestRemovableStorageRoot();
  } on LocalMediaAccessException {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'The selected media folder could not be opened. '
          'Choose the folder again and allow read access.',
        ),
      ),
    );
    return;
  }
  if (!context.mounted || root == null) return;
  final selected = await showTvLocalMediaBrowser(
    context,
    initialRoot: root,
    title: 'Choose USB media',
    browse: adapter.browse,
  );
  if (!context.mounted || selected == null) return;
  playTvLocalMedia(ref, selected, onPlayChannel);
}

Future<void> browseTvNetwork(
  BuildContext context,
  WidgetRef ref,
  ValueChanged<IPTVChannel>? onPlayChannel,
) async {
  final adapter = ref.read(dlnaUpnpLibraryAdapterProvider);
  const discoveryRoot = 'dlna://discover';
  final selected = await showTvLocalMediaBrowser(
    context,
    initialRoot: discoveryRoot,
    title: 'Choose network media',
    isNetworkBrowse: true,
    browse: (root) =>
        root == discoveryRoot ? adapter.discover() : adapter.browse(root),
  );
  if (!context.mounted || selected == null) return;
  playTvLocalMedia(ref, selected, onPlayChannel);
}

void playTvLocalMedia(
  WidgetRef ref,
  LocalMediaEntry selected,
  ValueChanged<IPTVChannel>? onPlayChannel,
) {
  final channel = IPTVChannel(
    id: stableLocalMediaChannelId(selected.id),
    name: selected.name,
    streamUrl: selected.accessUri,
    group: 'Local media',
    isAudioOnly: selected.kind == LocalMediaEntryKind.audio,
  );
  ref.read(iptvStreamingServiceProvider).playChannel(channel);
  onPlayChannel?.call(channel);
}

void showTvNetworkBrowseHowItWorks(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('How it works'),
        content: Text(
          'Share a folder from a Windows PC, Mac, NAS, or media server. '
          'Keep this TV on the same network, then scan again so '
          '${TvStoreProduct.displayName} can find it.',
        ),
        actions: [
          TvFocusable(
            autofocus: true,
            semanticLabel: 'Close',
            onSelect: () => Navigator.of(dialogContext).pop(),
            child: TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ),
        ],
      );
    },
  );
}

/// Browse Network empty: find-media copy plus Scan again / How it works.
class TvNetworkBrowseEmpty extends StatelessWidget {
  const TvNetworkBrowseEmpty({
    super.key,
    required this.onScanAgain,
    required this.onHowItWorks,
  });

  final VoidCallback onScanAgain;
  final VoidCallback onHowItWorks;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Find media shared on your network',
          style: AiroTypography.titleMedium.copyWith(color: colors.onSurface),
        ),
        const SizedBox(height: AiroSpacing.sm),
        Text(
          'Windows / Mac / NAS / media server; same network',
          style: AiroTypography.bodyMedium.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AiroSpacing.lg),
        Row(
          children: [
            TvFocusable(
              autofocus: true,
              semanticLabel: 'Scan again',
              semanticButton: true,
              onSelect: onScanAgain,
              child: FilledButton.icon(
                onPressed: onScanAgain,
                icon: const Icon(Icons.refresh),
                label: const Text('Scan again'),
              ),
            ),
            const SizedBox(width: AiroSpacing.md),
            TvFocusable(
              semanticLabel: 'How it works',
              semanticButton: true,
              onSelect: onHowItWorks,
              child: OutlinedButton(
                onPressed: onHowItWorks,
                child: const Text('How it works'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class TvLocalMediaBrowserDialog extends StatefulWidget {
  const TvLocalMediaBrowserDialog({
    super.key,
    required this.title,
    required this.loadEntries,
    this.isNetworkBrowse = false,
  });

  final String title;
  final Future<List<LocalMediaEntry>> Function() loadEntries;
  final bool isNetworkBrowse;

  @override
  State<TvLocalMediaBrowserDialog> createState() =>
      _TvLocalMediaBrowserDialogState();
}

class _TvLocalMediaBrowserDialogState extends State<TvLocalMediaBrowserDialog> {
  late Future<List<LocalMediaEntry>> _entries;

  @override
  void initState() {
    super.initState();
    _entries = widget.loadEntries();
  }

  void _retry() {
    final next = widget.loadEntries();
    setState(() {
      _entries = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    return AlertDialog(
      title: Text(widget.title, style: AiroTypography.titleLarge),
      content: SizedBox(
        width: (screenSize.width * 0.72).clamp(280.0, 720.0).toDouble(),
        height: (screenSize.height * 0.64).clamp(240.0, 480.0).toDouble(),
        child: FutureBuilder<List<LocalMediaEntry>>(
          future: _entries,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'This media library could not be reached. Check the '
                    'connection or permission, then try again.',
                    style: AiroTypography.bodyMedium,
                  ),
                  const SizedBox(height: AiroSpacing.md),
                  TvFocusable(
                    autofocus: true,
                    semanticLabel: 'Try again',
                    onSelect: _retry,
                    child: OutlinedButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try again'),
                    ),
                  ),
                ],
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final entries = snapshot.data!;
            if (entries.isEmpty) {
              if (widget.isNetworkBrowse) {
                return TvNetworkBrowseEmpty(
                  onScanAgain: _retry,
                  onHowItWorks: () => showTvNetworkBrowseHowItWorks(context),
                );
              }
              return const Text('No supported media was found here.');
            }
            return ListView.builder(
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                return TvFocusable(
                  autofocus: index == 0,
                  semanticLabel: entry.name,
                  onSelect: () => Navigator.of(context).pop(entry),
                  child: ListTile(
                    leading: Icon(
                      entry.kind == LocalMediaEntryKind.folder
                          ? Icons.folder
                          : Icons.movie_outlined,
                    ),
                    title: Text(
                      entry.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => Navigator.of(context).pop(entry),
                  ),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TvFocusable(
          semanticLabel: 'Cancel',
          onSelect: () => Navigator.of(context).pop(),
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ),
      ],
    );
  }
}
