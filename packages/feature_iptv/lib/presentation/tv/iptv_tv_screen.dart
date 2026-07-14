import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_player/platform_player.dart';

import '../../application/providers/iptv_providers.dart';
import '../screens/iptv_screen.dart';
import '../widgets/iptv_icon_placeholder.dart';
import '../widgets/iptv_mini_player.dart';
import '../widgets/video_player_widget.dart';
import 'iptv_tv.dart';

enum _TvChannelViewMode { grid, list }

/// A 10-foot IPTV experience for Android TV and Fire TV.
class IptvTvScreen extends ConsumerStatefulWidget {
  const IptvTvScreen({super.key});

  @override
  ConsumerState<IptvTvScreen> createState() => _IptvTvScreenState();
}

class _IptvTvScreenState extends ConsumerState<IptvTvScreen> {
  _TvChannelViewMode _viewMode = _TvChannelViewMode.grid;
  bool _recentOnly = false;

  @override
  void initState() {
    super.initState();
    ref.read(iptvStreamingServiceProvider).initialize();
  }

  void _playChannel(IPTVChannel channel) {
    ref.read(iptvStreamingServiceProvider).playChannel(channel);
    ref.read(addToRecentlyWatchedProvider(channel));
  }

  Future<void> _showSearchDialog() async {
    final controller = TextEditingController(
      text: ref.read(channelSearchQueryProvider),
    );

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Search channels'),
          content: SizedBox(
            width: 520,
            child: TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'Channel name or group',
                hintText: 'Music India, Hindi news, sports...',
              ),
              textInputAction: TextInputAction.search,
              onChanged: (value) =>
                  ref.read(channelSearchQueryProvider.notifier).state = value,
              onSubmitted: (_) => Navigator.of(context).pop(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                controller.clear();
                ref.read(channelSearchQueryProvider.notifier).state = '';
              },
              child: const Text('Clear'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );

    controller.dispose();
  }

  Future<void> _showPlaylistSheet() async {
    await showPlaylistSourceSheet(context, ref);
  }

  Future<void> _showPlaylistGuideDialog() async {
    await showDialog<void>(
      context: context,
      builder: (_) => const _TvPlaylistGuideDialog(),
    );
  }

  void _clearFilters() {
    setState(() => _recentOnly = false);
    ref.read(selectedCategoryProvider.notifier).state = ChannelCategory.all;
    ref.read(selectedFlavorProvider.notifier).state = null;
    ref.read(channelSearchQueryProvider.notifier).state = '';
  }

  @override
  Widget build(BuildContext context) {
    final channelsAsync = ref.watch(iptvChannelsProvider);
    final filteredChannels = ref.watch(filteredChannelsProvider);
    final streamingState = ref.watch(streamingStateProvider);
    final recentAsync = ref.watch(recentlyWatchedChannelsProvider);
    final hasActiveFilter = ref.watch(hasActiveFilterProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: channelsAsync.when(
          loading: () => const _TvLoadingState(),
          error: (error, _) => _TvErrorState(
            message: error.toString(),
            onRetry: () => ref.invalidate(iptvChannelsProvider),
          ),
          data: (allChannels) {
            final visibleChannels = _recentOnly
                ? recentAsync.valueOrNull ?? const <IPTVChannel>[]
                : filteredChannels;

            if (allChannels.isEmpty) {
              return _TvEmptyPlaylistState(
                onPlaylistSourceTap: _showPlaylistSheet,
                onPlaylistHelpTap: _showPlaylistGuideDialog,
              );
            }

            return _TvBrowseLayout(
              allChannels: allChannels,
              visibleChannels: visibleChannels,
              streamingState: streamingState,
              recentChannels: recentAsync.valueOrNull ?? const [],
              viewMode: _viewMode,
              recentOnly: _recentOnly,
              hasActiveFilter: hasActiveFilter || _recentOnly,
              onChannelSelect: _playChannel,
              onPlaylistSourceTap: _showPlaylistSheet,
              onPlaylistHelpTap: _showPlaylistGuideDialog,
              onSearchTap: _showSearchDialog,
              onRefresh: () {
                ref.invalidate(iptvChannelsProvider);
                ref.invalidate(recentlyWatchedChannelsProvider);
              },
              onClearFilters: _clearFilters,
              onRecentOnlyChanged: (value) {
                setState(() => _recentOnly = value);
              },
              onViewModeChanged: (mode) {
                setState(() => _viewMode = mode);
              },
            );
          },
        ),
      ),
    );
  }
}

class _TvBrowseLayout extends ConsumerWidget {
  const _TvBrowseLayout({
    required this.allChannels,
    required this.visibleChannels,
    required this.streamingState,
    required this.recentChannels,
    required this.viewMode,
    required this.recentOnly,
    required this.hasActiveFilter,
    required this.onChannelSelect,
    required this.onPlaylistSourceTap,
    required this.onPlaylistHelpTap,
    required this.onSearchTap,
    required this.onRefresh,
    required this.onClearFilters,
    required this.onRecentOnlyChanged,
    required this.onViewModeChanged,
  });

  final List<IPTVChannel> allChannels;
  final List<IPTVChannel> visibleChannels;
  final AsyncValue<StreamingState> streamingState;
  final List<IPTVChannel> recentChannels;
  final _TvChannelViewMode viewMode;
  final bool recentOnly;
  final bool hasActiveFilter;
  final ValueChanged<IPTVChannel> onChannelSelect;
  final VoidCallback onPlaylistSourceTap;
  final VoidCallback onPlaylistHelpTap;
  final VoidCallback onSearchTap;
  final VoidCallback onRefresh;
  final VoidCallback onClearFilters;
  final ValueChanged<bool> onRecentOnlyChanged;
  final ValueChanged<_TvChannelViewMode> onViewModeChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final searchQuery = ref.watch(channelSearchQueryProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final currentChannel = ref.watch(currentChannelProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
      child: Column(
        children: [
          _TvHeader(
            channelCount: allChannels.length,
            visibleCount: visibleChannels.length,
            searchQuery: searchQuery,
            onPlaylistSourceTap: onPlaylistSourceTap,
            onPlaylistHelpTap: onPlaylistHelpTap,
            onSearchTap: onSearchTap,
            onRefresh: onRefresh,
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 320,
                  child: _TvCategoryRail(
                    selectedCategory: selectedCategory,
                    onCategorySelected: (category) {
                      onRecentOnlyChanged(false);
                      ref.read(selectedCategoryProvider.notifier).state =
                          category;
                    },
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    children: [
                      _TvPlayerPanel(
                        streamingState: streamingState,
                        currentChannel: currentChannel,
                      ),
                      const SizedBox(height: 20),
                      _TvChannelToolbar(
                        viewMode: viewMode,
                        recentOnly: recentOnly,
                        hasRecentChannels: recentChannels.isNotEmpty,
                        hasActiveFilter: hasActiveFilter,
                        onRecentOnlyChanged: onRecentOnlyChanged,
                        onClearFilters: onClearFilters,
                        onViewModeChanged: onViewModeChanged,
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.24),
                            border: Border.all(
                              color: colorScheme.outlineVariant,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: visibleChannels.isEmpty
                              ? _TvNoChannelsState(
                                  recentOnly: recentOnly,
                                  onClearFilters: onClearFilters,
                                )
                              : viewMode == _TvChannelViewMode.grid
                              ? _TvChannelGridView(
                                  channels: visibleChannels,
                                  currentChannel: currentChannel,
                                  onChannelSelect: onChannelSelect,
                                )
                              : _TvChannelListView(
                                  channels: visibleChannels,
                                  currentChannel: currentChannel,
                                  onChannelSelect: onChannelSelect,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const IPTVMiniPlayer(forceVisible: true),
        ],
      ),
    );
  }
}

class _TvHeader extends StatelessWidget {
  const _TvHeader({
    required this.channelCount,
    required this.visibleCount,
    required this.searchQuery,
    required this.onPlaylistSourceTap,
    required this.onPlaylistHelpTap,
    required this.onSearchTap,
    required this.onRefresh,
  });

  final int channelCount;
  final int visibleCount;
  final String searchQuery;
  final VoidCallback onPlaylistSourceTap;
  final VoidCallback onPlaylistHelpTap;
  final VoidCallback onSearchTap;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final subtitle = searchQuery.isEmpty
        ? '$visibleCount of $channelCount live channels'
        : '$visibleCount results for "$searchQuery"';

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Live channels', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        _TvActionButton(
          icon: Icons.search,
          label: 'Search',
          onSelect: onSearchTap,
          autofocus: true,
        ),
        const SizedBox(width: 12),
        _TvActionButton(
          icon: Icons.link,
          label: 'Playlist',
          onSelect: onPlaylistSourceTap,
        ),
        const SizedBox(width: 12),
        _TvActionButton(
          icon: Icons.help_outline,
          label: 'Help',
          onSelect: onPlaylistHelpTap,
        ),
        const SizedBox(width: 12),
        _TvActionButton(
          icon: Icons.refresh,
          label: 'Refresh',
          onSelect: onRefresh,
        ),
      ],
    );
  }
}

class _TvCategoryRail extends ConsumerWidget {
  const _TvCategoryRail({
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  final ChannelCategory selectedCategory;
  final ValueChanged<ChannelCategory> onCategorySelected;

  static const _visibleCategories = [
    ChannelCategory.all,
    ChannelCategory.news,
    ChannelCategory.sports,
    ChannelCategory.entertainment,
    ChannelCategory.music,
    ChannelCategory.movies,
    ChannelCategory.kids,
    ChannelCategory.documentary,
    ChannelCategory.business,
    ChannelCategory.general,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(categoryCounts);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Browse', style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        Expanded(
          child: GridView.builder(
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.16,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemCount: _visibleCategories.length,
            itemBuilder: (context, index) {
              final category = _visibleCategories[index];
              return _TvCategoryTile(
                category: category,
                count: counts[category] ?? 0,
                selected: selectedCategory == category,
                onSelect: () => onCategorySelected(category),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TvCategoryTile extends StatelessWidget {
  const _TvCategoryTile({
    required this.category,
    required this.count,
    required this.selected,
    required this.onSelect,
  });

  final ChannelCategory category;
  final int count;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = selected
        ? colorScheme.onPrimaryContainer
        : colorScheme.primary;

    return TvFocusable(
      onSelect: onSelect,
      semanticLabel: '${category.label}, $count channels',
      semanticHint: 'Press OK to filter channels',
      semanticButton: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.36),
          border: Border.all(
            color: selected ? colorScheme.primary : colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_categoryIcon(category), color: foreground, size: 30),
              const Spacer(),
              Text(
                category.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: selected ? colorScheme.onPrimaryContainer : null,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$count',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: selected
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TvPlayerPanel extends StatelessWidget {
  const _TvPlayerPanel({
    required this.streamingState,
    required this.currentChannel,
  });

  final AsyncValue<StreamingState> streamingState;
  final IPTVChannel? currentChannel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 420,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: streamingState.when(
                  data: (state) => state.currentChannel == null
                      ? const _TvPlayerPlaceholder()
                      : const VideoPlayerWidget(showControls: true),
                  loading: () => const _TvPlayerPlaceholder(),
                  error: (_, _) => const _TvPlayerPlaceholder(),
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    currentChannel?.name ?? 'Choose a channel',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currentChannel == null
                        ? 'Use the category tiles and channel grid to start watching.'
                        : currentChannel!.group,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const _LivePill(),
                      if (currentChannel != null) ...[
                        const SizedBox(width: 12),
                        Icon(
                          currentChannel!.isAudioOnly
                              ? Icons.radio
                              : Icons.live_tv,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(currentChannel!.category.label),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TvChannelToolbar extends StatelessWidget {
  const _TvChannelToolbar({
    required this.viewMode,
    required this.recentOnly,
    required this.hasRecentChannels,
    required this.hasActiveFilter,
    required this.onRecentOnlyChanged,
    required this.onClearFilters,
    required this.onViewModeChanged,
  });

  final _TvChannelViewMode viewMode;
  final bool recentOnly;
  final bool hasRecentChannels;
  final bool hasActiveFilter;
  final ValueChanged<bool> onRecentOnlyChanged;
  final VoidCallback onClearFilters;
  final ValueChanged<_TvChannelViewMode> onViewModeChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _TvFilterChip(
          label: 'All',
          selected: !recentOnly,
          onSelect: () => onRecentOnlyChanged(false),
        ),
        const SizedBox(width: 10),
        _TvFilterChip(
          label: 'Recent',
          selected: recentOnly,
          enabled: hasRecentChannels,
          onSelect: () => onRecentOnlyChanged(true),
        ),
        const Spacer(),
        if (hasActiveFilter) ...[
          _TvActionButton(
            icon: Icons.filter_list_off,
            label: 'Clear',
            onSelect: onClearFilters,
          ),
          const SizedBox(width: 12),
        ],
        _TvIconToggle(
          icon: Icons.grid_view,
          label: 'Grid view',
          selected: viewMode == _TvChannelViewMode.grid,
          onSelect: () => onViewModeChanged(_TvChannelViewMode.grid),
        ),
        const SizedBox(width: 10),
        _TvIconToggle(
          icon: Icons.view_list,
          label: 'List view',
          selected: viewMode == _TvChannelViewMode.list,
          onSelect: () => onViewModeChanged(_TvChannelViewMode.list),
        ),
      ],
    );
  }
}

class _TvChannelGridView extends StatelessWidget {
  const _TvChannelGridView({
    required this.channels,
    required this.currentChannel,
    required this.onChannelSelect,
  });

  final List<IPTVChannel> channels;
  final IPTVChannel? currentChannel;
  final ValueChanged<IPTVChannel> onChannelSelect;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        childAspectRatio: 1.03,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
      ),
      itemCount: channels.length,
      itemBuilder: (context, index) {
        final channel = channels[index];
        return _TvChannelCard(
          channel: channel,
          isPlaying: currentChannel?.id == channel.id,
          autofocus: index == 0,
          onSelect: () => onChannelSelect(channel),
        );
      },
    );
  }
}

class _TvChannelListView extends StatelessWidget {
  const _TvChannelListView({
    required this.channels,
    required this.currentChannel,
    required this.onChannelSelect,
  });

  final List<IPTVChannel> channels;
  final IPTVChannel? currentChannel;
  final ValueChanged<IPTVChannel> onChannelSelect;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: channels.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final channel = channels[index];
        return _TvChannelRow(
          channel: channel,
          isPlaying: currentChannel?.id == channel.id,
          autofocus: index == 0,
          onSelect: () => onChannelSelect(channel),
        );
      },
    );
  }
}

class _TvChannelCard extends StatelessWidget {
  const _TvChannelCard({
    required this.channel,
    required this.isPlaying,
    required this.autofocus,
    required this.onSelect,
  });

  final IPTVChannel channel;
  final bool isPlaying;
  final bool autofocus;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return TvFocusable(
      autofocus: autofocus,
      onSelect: onSelect,
      semanticLabel: isPlaying
          ? '${channel.name}, currently playing'
          : channel.name,
      semanticHint: 'Press OK to play this channel',
      semanticButton: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isPlaying
              ? colorScheme.primaryContainer.withValues(alpha: 0.56)
              : colorScheme.surface.withValues(alpha: 0.6),
          border: Border.all(
            color: isPlaying ? colorScheme.primary : colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Center(child: _ChannelLogo(channel: channel)),
              ),
              const SizedBox(height: 10),
              Text(
                channel.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      channel.group,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (isPlaying)
                    Icon(Icons.equalizer, color: colorScheme.primary, size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TvChannelRow extends StatelessWidget {
  const _TvChannelRow({
    required this.channel,
    required this.isPlaying,
    required this.autofocus,
    required this.onSelect,
  });

  final IPTVChannel channel;
  final bool isPlaying;
  final bool autofocus;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return TvFocusable(
      autofocus: autofocus,
      onSelect: onSelect,
      semanticLabel: isPlaying
          ? '${channel.name}, currently playing'
          : channel.name,
      semanticHint: 'Press OK to play this channel',
      semanticButton: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isPlaying
              ? colorScheme.primaryContainer.withValues(alpha: 0.56)
              : colorScheme.surface.withValues(alpha: 0.6),
          border: Border.all(
            color: isPlaying ? colorScheme.primary : colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: _ChannelLogo(channel: channel),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      channel.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      channel.group,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              if (!channel.isAudioOnly) const _LivePill(),
              if (isPlaying) ...[
                const SizedBox(width: 12),
                Icon(Icons.equalizer, color: colorScheme.primary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ChannelLogo extends StatelessWidget {
  const _ChannelLogo({required this.channel});

  final IPTVChannel channel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: channel.hasLogo
            ? Image.network(
                channel.logoUrl!,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => IptvIconPlaceholder.channel(
                  isAudioOnly: channel.isAudioOnly,
                ),
              )
            : IptvIconPlaceholder.channel(isAudioOnly: channel.isAudioOnly),
      ),
    );
  }
}

class _TvActionButton extends StatelessWidget {
  const _TvActionButton({
    required this.icon,
    required this.label,
    required this.onSelect,
    this.autofocus = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onSelect;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return TvFocusable(
      autofocus: autofocus,
      onSelect: onSelect,
      semanticLabel: label,
      semanticHint: 'Press OK to activate',
      semanticButton: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.42),
          border: Border.all(color: colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22),
              const SizedBox(width: 8),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}

class _TvFilterChip extends StatelessWidget {
  const _TvFilterChip({
    required this.label,
    required this.selected,
    required this.onSelect,
    this.enabled = true,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: TvFocusable(
        enabled: enabled,
        onSelect: onSelect,
        semanticLabel: selected ? '$label, selected' : label,
        semanticHint: 'Press OK to filter channels',
        semanticButton: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected ? colorScheme.primary : Colors.transparent,
            border: Border.all(
              color: selected ? colorScheme.primary : colorScheme.outline,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? colorScheme.onPrimary : colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TvIconToggle extends StatelessWidget {
  const _TvIconToggle({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onSelect,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return TvFocusable(
      onSelect: onSelect,
      semanticLabel: selected ? '$label, selected' : label,
      semanticHint: 'Press OK to change channel layout',
      semanticButton: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.32),
          border: Border.all(
            color: selected ? colorScheme.primary : colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: selected ? colorScheme.primary : null),
        ),
      ),
    );
  }
}

class _LivePill extends StatelessWidget {
  const _LivePill();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.red.shade700,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, color: Colors.white, size: 7),
            SizedBox(width: 5),
            Text(
              'LIVE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TvPlayerPlaceholder extends StatelessWidget {
  const _TvPlayerPlaceholder();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Center(
        child: Icon(
          Icons.live_tv,
          color: colorScheme.primary.withValues(alpha: 0.78),
          size: 72,
        ),
      ),
    );
  }
}

class _TvNoChannelsState extends StatelessWidget {
  const _TvNoChannelsState({
    required this.recentOnly,
    required this.onClearFilters,
  });

  final bool recentOnly;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            recentOnly ? Icons.history : Icons.filter_list_off,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            recentOnly ? 'No recently watched channels' : 'No channels match',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          _TvActionButton(
            icon: Icons.filter_list_off,
            label: 'Clear filters',
            onSelect: onClearFilters,
          ),
        ],
      ),
    );
  }
}

class _TvEmptyPlaylistState extends StatelessWidget {
  const _TvEmptyPlaylistState({
    required this.onPlaylistSourceTap,
    required this.onPlaylistHelpTap,
  });

  final VoidCallback onPlaylistSourceTap;
  final VoidCallback onPlaylistHelpTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.live_tv, size: 88, color: colorScheme.primary),
            const SizedBox(height: 24),
            Text('Add your playlist', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 12),
            Text(
              'Airo TV is a media player. Add an M3U URL for media you own or are authorized to watch.',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                _TvActionButton(
                  icon: Icons.link,
                  label: 'Import playlist URL',
                  onSelect: onPlaylistSourceTap,
                  autofocus: true,
                ),
                _TvActionButton(
                  icon: Icons.help_outline,
                  label: 'How to add',
                  onSelect: onPlaylistHelpTap,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TvLoadingState extends StatelessWidget {
  const _TvLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _TvErrorState extends StatelessWidget {
  const _TvErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.error,
            size: 72,
          ),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 18),
          _TvActionButton(
            icon: Icons.refresh,
            label: 'Retry',
            onSelect: onRetry,
          ),
        ],
      ),
    );
  }
}

class _TvPlaylistGuideDialog extends StatelessWidget {
  const _TvPlaylistGuideDialog();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: const Text('How to add a playlist'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Airo TV plays playlist links you provide. Use an M3U or M3U8 URL from your TV provider, your own media server, or another source you are authorized to watch.',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              const _TvPlaylistGuideStep(
                index: 1,
                title: 'Find your playlist URL',
                body:
                    'Look for an M3U or M3U8 playlist link from your provider or authorized source.',
              ),
              const _TvPlaylistGuideStep(
                index: 2,
                title: 'Copy the complete link',
                body:
                    'The link usually starts with http:// or https:// and ends with .m3u or .m3u8.',
              ),
              const _TvPlaylistGuideStep(
                index: 3,
                title: 'Import it in Airo TV',
                body:
                    'Choose Playlist, paste the URL into M3U playlist URL, then Save.',
              ),
              const _TvPlaylistGuideStep(
                index: 4,
                title: 'Start watching',
                body:
                    'Pick a category, focus a channel, and press OK on your remote.',
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

class _TvPlaylistGuideStep extends StatelessWidget {
  const _TvPlaylistGuideStep({
    required this.index,
    required this.title,
    required this.body,
  });

  final int index;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            label: 'Step $index',
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: colorScheme.primary, width: 2),
                shape: BoxShape.circle,
              ),
              child: SizedBox.square(
                dimension: 36,
                child: Center(
                  child: Text(
                    '$index',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

IconData _categoryIcon(ChannelCategory category) {
  return switch (category) {
    ChannelCategory.all => Icons.live_tv,
    ChannelCategory.news => Icons.newspaper,
    ChannelCategory.entertainment => Icons.theater_comedy,
    ChannelCategory.sports => Icons.sports_soccer,
    ChannelCategory.music => Icons.music_note,
    ChannelCategory.movies => Icons.movie,
    ChannelCategory.kids => Icons.child_care,
    ChannelCategory.documentary => Icons.school,
    ChannelCategory.regional => Icons.public,
    ChannelCategory.international => Icons.language,
    ChannelCategory.lifestyle => Icons.spa,
    ChannelCategory.devotional => Icons.self_improvement,
    ChannelCategory.business => Icons.business_center,
    ChannelCategory.general => Icons.apps,
  };
}
