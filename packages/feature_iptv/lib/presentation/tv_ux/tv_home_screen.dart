import 'dart:async';

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_media/platform_media.dart';

import '../../application/providers/iptv_providers.dart';
import '../../product_identity.dart';
import '../widgets/channel_initials.dart';
import '../widgets/channel_load_error_view.dart';
import '../widgets/tv_playlist_qr_dialog.dart';
import 'tv_playlist_import_success_dialog.dart';
import 'tv_playlist_url_dialog.dart';

const _liveTvRailLimit = 12;

/// 10-foot Home: QR-primary landing when there is no playlist, silent
/// dashboard rails once channels exist. Play and Guide navigation are
/// callbacks so the app router can wire [TvRouteNames].
class TvHomeScreen extends ConsumerWidget {
  const TvHomeScreen({super.key, this.onPlayChannel, this.onSeeAllLiveTv});

  /// OK on a rail card. The host typically `go`s to Watch after playback
  /// starts. Must not be invoked by import success.
  final ValueChanged<IPTVChannel>? onPlayChannel;

  /// See all on the Live TV rail. The host typically `go`s to Guide.
  final VoidCallback? onSeeAllLiveTv;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channelsAsync = ref.watch(iptvChannelsProvider);
    final recentsAsync = ref.watch(recentlyWatchedChannelsProvider);
    final favoritesAsync = ref.watch(favoriteChannelsProvider);

    return AiroResponsiveScaffold(
      overrideFormFactor: AiroFormFactor.tv,
      useResponsiveCenter: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      padding: EdgeInsets.zero,
      body: channelsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ChannelLoadErrorView(
          message: 'Could not load channels: $error',
          onRetry: () => invalidateChannelLibraries(ref),
        ),
        data: (channels) {
          if (channels.isEmpty) {
            return _TvHomeEmptyLanding(onPlayChannel: onPlayChannel);
          }
          if (recentsAsync.isLoading || favoritesAsync.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          return _TvHomeDashboard(
            channels: channels,
            recents: recentsAsync.value ?? const [],
            favorites: favoritesAsync.value ?? const [],
            onPlayChannel: onPlayChannel,
            onSeeAllLiveTv: onSeeAllLiveTv,
          );
        },
      ),
    );
  }
}

class _TvHomeEmptyLanding extends ConsumerWidget {
  const _TvHomeEmptyLanding({this.onPlayChannel});

  final ValueChanged<IPTVChannel>? onPlayChannel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final capabilities = ref
        .watch(localMediaLibraryCapabilitiesProvider)
        .asData
        ?.value;

    return TvOverscanSafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AiroSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      TvStoreProduct.displayName,
                      style: AiroTypography.headlineMedium.copyWith(
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: AiroSpacing.sm),
                    Text(
                      'Your media. Your player.',
                      style: AiroTypography.bodyLarge.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AiroSpacing.lg),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: colors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(
                              AiroSpacing.radiusMd,
                            ),
                            border: Border.all(color: colors.outlineVariant),
                          ),
                          child: TvPlaylistQrPanel(
                            showHeading: false,
                            showCancel: false,
                            onUrlSubmitted: (url) {
                              if (!context.mounted) return;
                              unawaited(
                                _openUrlImport(context, initialUrl: url),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AiroSpacing.lg),
                    Wrap(
                      spacing: AiroSpacing.md,
                      runSpacing: AiroSpacing.md,
                      children: [
                        _SecondaryAction(
                          autofocus: true,
                          label: 'Or enter URL manually',
                          icon: Icons.link,
                          onSelect: () => unawaited(_openUrlImport(context)),
                        ),
                        if (capabilities?.removableStorage == true)
                          _SecondaryAction(
                            label: 'Browse USB',
                            icon: Icons.usb,
                            onSelect: () => unawaited(
                              _browseUsb(context, ref, onPlayChannel),
                            ),
                          ),
                        if (capabilities?.dlnaUpnp == true)
                          _SecondaryAction(
                            label: 'Browse network',
                            icon: Icons.devices_other,
                            onSelect: () => unawaited(
                              _browseNetwork(context, ref, onPlayChannel),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SecondaryAction extends StatelessWidget {
  const _SecondaryAction({
    required this.label,
    required this.icon,
    required this.onSelect,
    this.autofocus = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onSelect;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return TvFocusable(
      autofocus: autofocus,
      semanticLabel: label,
      semanticButton: true,
      onSelect: onSelect,
      borderRadius: AiroSpacing.radiusMd,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AiroSpacing.tvMinTarget),
        child: OutlinedButton.icon(
          onPressed: onSelect,
          icon: Icon(icon),
          label: Text(
            label,
            style: AiroTypography.labelLarge.copyWith(color: colors.onSurface),
          ),
        ),
      ),
    );
  }
}

class _TvHomeDashboard extends ConsumerWidget {
  const _TvHomeDashboard({
    required this.channels,
    required this.recents,
    required this.favorites,
    this.onPlayChannel,
    this.onSeeAllLiveTv,
  });

  final List<IPTVChannel> channels;
  final List<IPTVChannel> recents;
  final List<IPTVChannel> favorites;
  final ValueChanged<IPTVChannel>? onPlayChannel;
  final VoidCallback? onSeeAllLiveTv;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveTv = channels.take(_liveTvRailLimit).toList(growable: false);
    // Recently Added stays hidden until a recency signal exists (import
    // timestamp or stable new ids). Do not invent popularity.
    final rails = <_HomeRailSpec>[
      if (recents.isNotEmpty)
        _HomeRailSpec(title: 'Continue Watching', channels: recents),
      if (liveTv.isNotEmpty)
        _HomeRailSpec(
          title: 'Live TV',
          channels: liveTv,
          onSeeAll: () => onSeeAllLiveTv?.call(),
        ),
      if (favorites.isNotEmpty)
        _HomeRailSpec(title: 'Your Favorites', channels: favorites),
    ];

    var assignedAutofocus = false;
    final railWidgets = [
      for (final rail in rails)
        _HomeRail(
          title: rail.title,
          onSeeAll: rail.onSeeAll,
          children: [
            for (final channel in rail.channels)
              MediaCard(
                name: channel.name,
                subtitle: channel.group,
                logoUrl: channel.logoUrl,
                initials: channelInitials(channel.name),
                isLive: true,
                autofocus: () {
                  final autofocus = !assignedAutofocus;
                  assignedAutofocus = true;
                  return autofocus;
                }(),
                onTap: () => _play(ref, channel),
              ),
          ],
        ),
    ];

    return TvOverscanSafeArea(
      child: ListView(
        padding: const EdgeInsets.only(top: AiroSpacing.md),
        children: railWidgets,
      ),
    );
  }

  void _play(WidgetRef ref, IPTVChannel channel) {
    // Watch owns the decoder after OK; Home has no preview player.
    ref.read(iptvStreamingServiceProvider).playChannel(channel);
    onPlayChannel?.call(channel);
  }
}

class _HomeRailSpec {
  const _HomeRailSpec({
    required this.title,
    required this.channels,
    this.onSeeAll,
  });

  final String title;
  final List<IPTVChannel> channels;
  final VoidCallback? onSeeAll;
}

class _HomeRail extends StatelessWidget {
  const _HomeRail({required this.title, required this.children, this.onSeeAll});

  final String title;
  final List<Widget> children;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AiroSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AiroSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: AiroTypography.titleLarge.copyWith(
                      color: colors.onSurface,
                    ),
                  ),
                ),
                if (onSeeAll != null)
                  TvFocusable(
                    semanticLabel: 'See all Live TV',
                    semanticButton: true,
                    onSelect: onSeeAll,
                    borderRadius: AiroSpacing.radiusSm,
                    child: TextButton(
                      onPressed: onSeeAll,
                      child: Text(
                        'See all',
                        style: AiroTypography.labelLarge.copyWith(
                          color: colors.primary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: MediaCard.railHeightFor(MediaCardVariant.standard),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: children.length,
              separatorBuilder: (_, _) => const SizedBox(width: AiroSpacing.md),
              itemBuilder: (context, index) => children[index],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _openUrlImport(BuildContext context, {String? initialUrl}) async {
  final navigator = Navigator.of(context);
  final summary = await showDialog<TvPlaylistImportSummary>(
    context: context,
    builder: (dialogContext) {
      final viewInsets = MediaQuery.viewInsetsOf(dialogContext);
      final size = MediaQuery.sizeOf(dialogContext);
      return Dialog(
        insetPadding: const EdgeInsets.all(AiroSpacing.lg),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: 560,
          height: (size.height - viewInsets.bottom - 96).clamp(320.0, 560.0),
          child: TvPlaylistUrlDialog(initialUrl: initialUrl),
        ),
      );
    },
  );
  if (!navigator.mounted || summary == null) return;
  await showDialog<void>(
    context: navigator.context,
    builder: (_) => TvPlaylistImportSuccessDialog.fromSummary(summary),
  );
}

Future<void> _browseUsb(
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
  final selected = await _selectLocalMedia(
    context,
    initialRoot: root,
    title: 'Choose USB media',
    browse: adapter.browse,
  );
  if (!context.mounted || selected == null) return;
  _playLocalMedia(ref, selected, onPlayChannel);
}

Future<void> _browseNetwork(
  BuildContext context,
  WidgetRef ref,
  ValueChanged<IPTVChannel>? onPlayChannel,
) async {
  final adapter = ref.read(dlnaUpnpLibraryAdapterProvider);
  const discoveryRoot = 'dlna://discover';
  final selected = await _selectLocalMedia(
    context,
    initialRoot: discoveryRoot,
    title: 'Choose network media',
    browse: (root) =>
        root == discoveryRoot ? adapter.discover() : adapter.browse(root),
  );
  if (!context.mounted || selected == null) return;
  _playLocalMedia(ref, selected, onPlayChannel);
}

Future<LocalMediaEntry?> _selectLocalMedia(
  BuildContext context, {
  required String initialRoot,
  required String title,
  required Future<List<LocalMediaEntry>> Function(String root) browse,
}) async {
  var currentRoot = initialRoot;
  while (context.mounted) {
    final selected = await showDialog<LocalMediaEntry>(
      context: context,
      builder: (_) => _TvLocalMediaBrowserDialog(
        title: title,
        loadEntries: () => browse(currentRoot),
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

void _playLocalMedia(
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

class _TvLocalMediaBrowserDialog extends StatefulWidget {
  const _TvLocalMediaBrowserDialog({
    required this.title,
    required this.loadEntries,
  });

  final String title;
  final Future<List<LocalMediaEntry>> Function() loadEntries;

  @override
  State<_TvLocalMediaBrowserDialog> createState() =>
      _TvLocalMediaBrowserDialogState();
}

class _TvLocalMediaBrowserDialogState
    extends State<_TvLocalMediaBrowserDialog> {
  late Future<List<LocalMediaEntry>> _entries;

  @override
  void initState() {
    super.initState();
    _entries = widget.loadEntries();
  }

  void _retry() {
    setState(() => _entries = widget.loadEntries());
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
              return Text(
                'Find media shared on your network.',
                style: AiroTypography.bodyMedium,
              );
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
