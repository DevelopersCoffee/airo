import 'dart:async';

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter/services.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_epg/platform_epg.dart';
import 'package:platform_player/platform_player.dart';
import 'package:product_capabilities/product_capabilities.dart';

import '../../application/providers/iptv_providers.dart';
import '../../application/services/airo_macos_update_service.dart';
import '../screens/iptv_screen.dart';
import '../widgets/iptv_icon_placeholder.dart';
import '../widgets/iptv_mini_player.dart';
import '../widgets/video_player_widget.dart';

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

  Future<void> _showMacosUpdateDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) => const _MacosUpdateDialog(),
    );
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
    final productProfile = ref.watch(airoTvProductProfileProvider);

    return AiroResponsiveScaffold(
      overrideFormFactor: AiroFormFactor.tv,
      padding: EdgeInsets.zero,
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
                ? recentAsync.value ?? const <IPTVChannel>[]
                : filteredChannels;

            if (allChannels.isEmpty) {
              return _TvEmptyPlaylistLayout(
                productProfile: productProfile,
                child: _TvEmptyPlaylistState(
                  onPlaylistSourceTap: _showPlaylistSheet,
                  onPlaylistHelpTap: _showPlaylistGuideDialog,
                ),
              );
            }

            return _TvBrowseLayout(
              productProfile: productProfile,
              allChannels: allChannels,
              visibleChannels: visibleChannels,
              streamingState: streamingState,
              recentChannels: recentAsync.value ?? const [],
              viewMode: _viewMode,
              recentOnly: _recentOnly,
              hasActiveFilter: hasActiveFilter || _recentOnly,
              onChannelSelect: _playChannel,
              onPlaylistSourceTap: _showPlaylistSheet,
              onPlaylistHelpTap: _showPlaylistGuideDialog,
              onSearchTap: _showSearchDialog,
              onUpdateTap: _showMacosUpdateDialog,
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
    required this.productProfile,
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
    required this.onUpdateTap,
    required this.onRefresh,
    required this.onClearFilters,
    required this.onRecentOnlyChanged,
    required this.onViewModeChanged,
  });

  final ProductProfileManifest productProfile;
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
  final VoidCallback onUpdateTap;
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
    final favoriteChannelIds =
        ref.watch(favoriteChannelIdsProvider).value ?? const <String>{};
    void toggleFavorite(IPTVChannel channel) {
      ref.read(toggleChannelFavoriteProvider(channel.id));
    }
    final viewport = MediaQuery.sizeOf(context);
    final compactTv = viewport.height < 760 || viewport.width < 1200;
    final denseTv = viewport.height < 650;
    final compactEpg = ref.watch(
      compactEpgSliceForChannelsProvider(
        CompactEpgChannelQuery(
          channelIds: visibleChannels
              .map((channel) => channel.id)
              .toList(growable: false),
          now: ref.watch(compactEpgReferenceTimeProvider),
        ),
      ),
    );
    final compactEpgEntries = _compactEpgEntriesByChannel(
      compactEpg.value,
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        compactTv ? 20 : 32,
        compactTv ? 16 : 24,
        compactTv ? 20 : 32,
        compactTv ? 16 : 24,
      ),
      child: Column(
        children: [
          _TvLiteReceiverShellHeader(productProfile: productProfile),
          SizedBox(height: compactTv ? 12 : 18),
          _TvHeader(
            channelCount: allChannels.length,
            visibleCount: visibleChannels.length,
            searchQuery: searchQuery,
            onPlaylistSourceTap: onPlaylistSourceTap,
            onPlaylistHelpTap: onPlaylistHelpTap,
            onSearchTap: onSearchTap,
            showUpdateAction: AiroMacosUpdateService.isSupportedPlatform,
            onUpdateTap: onUpdateTap,
            onRefresh: onRefresh,
            compactTv: compactTv,
          ),
          SizedBox(height: compactTv ? 16 : 24),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: compactTv ? 280 : 320,
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
                      if (!denseTv) ...[
                        if (currentChannel == null &&
                            !hasActiveFilter &&
                            !recentOnly &&
                            visibleChannels.isNotEmpty)
                          _TvHeroRailsPanel(
                            heroChannel: visibleChannels.first,
                            allChannels: allChannels,
                            favoriteChannelIds: favoriteChannelIds,
                            onChannelSelect: onChannelSelect,
                            onToggleFavorite: toggleFavorite,
                          )
                        else
                          _TvPlayerPanel(
                            streamingState: streamingState,
                            currentChannel: currentChannel,
                            compact: compactTv,
                          ),
                        SizedBox(height: compactTv ? 12 : 20),
                      ],
                      _TvChannelToolbar(
                        viewMode: viewMode,
                        recentOnly: recentOnly,
                        hasRecentChannels: recentChannels.isNotEmpty,
                        hasActiveFilter: hasActiveFilter,
                        onRecentOnlyChanged: onRecentOnlyChanged,
                        onClearFilters: onClearFilters,
                        onViewModeChanged: onViewModeChanged,
                      ),
                      SizedBox(height: compactTv ? 10 : 16),
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
                                  compact: denseTv,
                                  compactEpgEntries: compactEpgEntries,
                                  onChannelSelect: onChannelSelect,
                                  favoriteChannelIds: favoriteChannelIds,
                                  onToggleFavorite: toggleFavorite,
                                )
                              : _TvChannelListView(
                                  channels: visibleChannels,
                                  currentChannel: currentChannel,
                                  compactEpgEntries: compactEpgEntries,
                                  onChannelSelect: onChannelSelect,
                                  favoriteChannelIds: favoriteChannelIds,
                                  onToggleFavorite: toggleFavorite,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: compactTv ? 8 : 12),
          const IPTVMiniPlayer(forceVisible: true),
        ],
      ),
    );
  }
}

Map<String, CompactEpgEntry> _compactEpgEntriesByChannel(
  CompactEpgSlice? slice,
) {
  if (slice == null || slice.entries.isEmpty) {
    return const {};
  }
  return {for (final entry in slice.entries) entry.channelId: entry};
}

/// Occupies the inline player panel's slot when nothing is currently
/// selected/playing: a featured hero channel plus a Netflix-style channel
/// rail, matching the design handoff's default browse state. Once a
/// channel is selected (or a filter/search is active) this gives way back
/// to the normal [_TvPlayerPanel].
class _TvHeroRailsPanel extends StatelessWidget {
  const _TvHeroRailsPanel({
    required this.heroChannel,
    required this.allChannels,
    required this.favoriteChannelIds,
    required this.onChannelSelect,
    required this.onToggleFavorite,
  });

  final IPTVChannel heroChannel;
  final List<IPTVChannel> allChannels;
  final Set<String> favoriteChannelIds;
  final ValueChanged<IPTVChannel> onChannelSelect;
  final ValueChanged<IPTVChannel> onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TvHeroBanner(
          channel: heroChannel,
          isFavorite: favoriteChannelIds.contains(heroChannel.id),
          onWatch: onChannelSelect,
          onToggleFavorite: onToggleFavorite,
        ),
        const SizedBox(height: 8),
        _TvChannelRailsSection(
          allChannels: allChannels,
          favoriteChannels: allChannels
              .where((c) => favoriteChannelIds.contains(c.id))
              .toList(),
          favoriteChannelIds: favoriteChannelIds,
          onChannelSelect: onChannelSelect,
          onToggleFavorite: onToggleFavorite,
        ),
      ],
    );
  }
}

/// Large featured banner above the browse rails — matches the design
/// handoff's hero: channel art, LIVE + category tags, Watch Now / Favorite.
class _TvHeroBanner extends StatelessWidget {
  const _TvHeroBanner({
    required this.channel,
    required this.isFavorite,
    required this.onWatch,
    required this.onToggleFavorite,
  });

  final IPTVChannel channel;
  final bool isFavorite;
  final ValueChanged<IPTVChannel> onWatch;
  final ValueChanged<IPTVChannel> onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 148,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: channel.logoUrl != null && channel.logoUrl!.isNotEmpty
                  ? Image.network(
                      channel.logoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    )
                  : const SizedBox.shrink(),
            ),
            // Left-to-right dark scrim so the title/actions stay readable
            // over whatever the channel art looks like.
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0xB3000000),
                      Colors.transparent,
                    ],
                    stops: [0.0, 0.7],
                  ),
                ),
              ),
            ),
            // Bottom fade so the text block reads clearly regardless of
            // what's directly behind it.
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0x99000000)],
                    stops: [0.4, 1.0],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const _LivePill(),
                      const SizedBox(width: 8),
                      Text(
                        channel.category.label.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    channel.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 32,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FilledButton.icon(
                          onPressed: () => onWatch(channel),
                          icon: const Icon(Icons.play_arrow, size: 16),
                          label: const Text('Watch Now'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            textStyle: const TextStyle(fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => onToggleFavorite(channel),
                          icon: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            size: 14,
                          ),
                          label: Text(isFavorite ? 'Favorited' : 'Favorite'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            textStyle: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
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

/// Horizontal, Netflix-style channel rails grouped by category — the
/// design handoff's signature browse pattern ("Top 50 India", "Live
/// Sports", etc). Sits above the filterable category-rail/grid layout so
/// existing filtering, search, and view-mode toggling stay untouched.
class _TvChannelRailsSection extends StatelessWidget {
  const _TvChannelRailsSection({
    required this.allChannels,
    required this.favoriteChannels,
    required this.favoriteChannelIds,
    required this.onChannelSelect,
    required this.onToggleFavorite,
  });

  final List<IPTVChannel> allChannels;
  final List<IPTVChannel> favoriteChannels;
  final Set<String> favoriteChannelIds;
  final ValueChanged<IPTVChannel> onChannelSelect;
  final ValueChanged<IPTVChannel> onToggleFavorite;

  static const _maxPerRail = 14;

  @override
  Widget build(BuildContext context) {
    // Prefer a "Favorites" rail; otherwise the single largest category —
    // kept to one rail so the fixed-height band above the filterable
    // category/grid layout never crowds it out on smaller TV viewports.
    final List<IPTVChannel> rail;
    final String title;
    if (favoriteChannels.isNotEmpty) {
      rail = favoriteChannels.take(_maxPerRail).toList();
      title = 'Favorites';
    } else {
      final byCategory = <ChannelCategory, List<IPTVChannel>>{};
      for (final channel in allChannels) {
        byCategory.putIfAbsent(channel.category, () => []).add(channel);
      }
      if (byCategory.isEmpty) return const SizedBox.shrink();
      final topCategory = byCategory.entries.reduce(
        (a, b) => b.value.length > a.value.length ? b : a,
      );
      rail = topCategory.value.take(_maxPerRail).toList();
      title = topCategory.key.label;
    }

    return AiroRail(
      title: title,
      padding: EdgeInsets.zero,
      railHeight: 140,
      children: [
        for (final channel in rail)
          AiroRailCard(
            name: channel.name,
            subtitle: channel.category.label,
            logoUrl: channel.logoUrl,
            // Not isLive: AiroRailCard's LIVE badge runs an infinite pulse
            // animation, which would hang every pumpAndSettle() in this
            // screen's existing widget tests.
            isLive: false,
            width: 140,
            thumbnailHeight: 78,
            onTap: () => onChannelSelect(channel),
            onLongPress: () => onToggleFavorite(channel),
          ),
      ],
    );
  }
}

class _TvLiteReceiverShellHeader extends StatelessWidget {
  const _TvLiteReceiverShellHeader({required this.productProfile});

  final ProductProfileManifest productProfile;

  static const _heavyCapabilities = {
    ProductCapability.localAi,
    ProductCapability.recording,
    ProductCapability.downloads,
    ProductCapability.multiview,
    ProductCapability.fullEpg,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final unavailable = _heavyCapabilities
        .where((capability) => !productProfile.supportsCapability(capability))
        .map((capability) => capability.tvLabel)
        .toList(growable: false);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.28),
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(Icons.tv, color: colorScheme.primary, size: 32),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        productProfile.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${productProfile.supportLevel.tvLabel} profile',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: Text(
                    unavailable.isEmpty
                        ? 'All profile capabilities available'
                        : 'Profile-limited: ${unavailable.join(', ')}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(height: 1, color: colorScheme.outlineVariant),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: productProfile.navigation
                  .map((entry) => _ProfileSectionChip(entry: entry))
                  .toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileSectionChip extends StatelessWidget {
  const _ProfileSectionChip({required this.entry});

  final ProductNavigationEntry entry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      label: '${entry.tvLabel} section',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: 0.7),
          border: Border.all(color: colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            entry.tvLabel,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
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
    required this.showUpdateAction,
    required this.onUpdateTap,
    required this.onRefresh,
    required this.compactTv,
  });

  final int channelCount;
  final int visibleCount;
  final String searchQuery;
  final VoidCallback onPlaylistSourceTap;
  final VoidCallback onPlaylistHelpTap;
  final VoidCallback onSearchTap;
  final bool showUpdateAction;
  final VoidCallback onUpdateTap;
  final VoidCallback onRefresh;
  final bool compactTv;

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
              SizedBox(height: compactTv ? 6 : 12),
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
        SizedBox(width: compactTv ? 12 : 16),
        _TvActionButton(
          icon: Icons.link,
          label: 'Playlist',
          onSelect: onPlaylistSourceTap,
        ),
        SizedBox(width: compactTv ? 12 : 16),
        _TvActionButton(
          icon: Icons.help_outline,
          label: 'Help',
          onSelect: onPlaylistHelpTap,
        ),
        if (showUpdateAction) ...[
          SizedBox(width: compactTv ? 12 : 16),
          _TvActionButton(
            icon: Icons.system_update_alt,
            label: 'Update',
            onSelect: onUpdateTap,
          ),
        ],
        SizedBox(width: compactTv ? 12 : 16),
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
    final visibleCategories = _visibleCategories
        .where(
          (category) =>
              category == ChannelCategory.all ||
              category == selectedCategory ||
              (counts[category] ?? 0) > 0,
        )
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Browse', style: theme.textTheme.titleLarge),
        const SizedBox(height: 20),
        Expanded(
          child: GridView.builder(
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.16,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemCount: visibleCategories.length,
            itemBuilder: (context, index) {
              final category = visibleCategories[index];
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
    final categoryColor = _categoryColor(context, category);

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
            color: selected ? categoryColor : colorScheme.outlineVariant,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_categoryIcon(category), color: categoryColor, size: 30),
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
    required this.compact,
  });

  final AsyncValue<StreamingState> streamingState;
  final IPTVChannel? currentChannel;
  final bool compact;

  void _openFullscreenPlayer(BuildContext context) {
    // Must use the root navigator: this screen sits inside TvShell's
    // ShellRoute, whose nested navigator only covers the content area next
    // to the sidebar. Pushing there leaves the sidebar visible; pushing on
    // root escapes the shell entirely and covers the whole window.
    Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => const _TvFullscreenPlayerPage(),
      ),
    );
  }

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
        padding: EdgeInsets.all(compact ? 12 : 16),
        child: Row(
          children: [
            SizedBox(
              width: compact ? 300 : 420,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: streamingState.when(
                  data: (state) => state.currentChannel == null
                      ? const _TvPlayerPlaceholder()
                      : VideoPlayerWidget(
                          showControls: true,
                          onFullscreenToggle: () =>
                              _openFullscreenPlayer(context),
                        ),
                  loading: () => const _TvPlayerPlaceholder(),
                  error: (_, _) => const _TvPlayerPlaceholder(),
                ),
              ),
            ),
            SizedBox(width: compact ? 16 : 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    currentChannel?.name ?? 'Choose a channel',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: compact
                        ? theme.textTheme.titleLarge
                        : theme.textTheme.headlineSmall,
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

class _TvFullscreenPlayerPage extends StatefulWidget {
  const _TvFullscreenPlayerPage();

  @override
  State<_TvFullscreenPlayerPage> createState() =>
      _TvFullscreenPlayerPageState();
}

class _TvFullscreenPlayerPageState extends State<_TvFullscreenPlayerPage> {
  late final FocusNode _focusNode;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'Airo TV fullscreen player');
    AiroNativeFullscreen.setMacosFullscreenExitHandler(
      _handleNativeFullscreenExit,
    );
    // Entering this page only maximizes the video within the current
    // window bounds; it never asked the OS to actually go fullscreen.
    // dispose() below already pairs with an exit call, so request the
    // matching enter here.
    unawaited(AiroNativeFullscreen.setMacosFullscreen(true));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    AiroNativeFullscreen.setMacosFullscreenExitHandler(null);
    _focusNode.dispose();
    unawaited(AiroNativeFullscreen.exitMacosFullscreen());
    super.dispose();
  }

  void _handleNativeFullscreenExit() {
    _close(exitNativeFullscreen: false);
  }

  void _close({bool exitNativeFullscreen = true}) {
    if (_isClosing || !mounted) {
      return;
    }
    _isClosing = true;
    if (exitNativeFullscreen) {
      unawaited(AiroNativeFullscreen.exitMacosFullscreen());
    }
    // Must match the navigator used to push this page in
    // _openFullscreenPlayer (root — see the comment there for why).
    Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          _close();
        }
      },
      child: Scaffold(
        key: const ValueKey('airo-tv-fullscreen-player'),
        backgroundColor: Colors.black,
        body: SizedBox.expand(
          child: VideoPlayerWidget(
            key: const ValueKey('airo-tv-fullscreen-video-player'),
            showControls: true,
            enableSwipeChannelChange: true,
            initiallyFullscreen: true,
            onFullscreenToggle: _close,
          ),
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

class _TvChannelGridView extends StatefulWidget {
  const _TvChannelGridView({
    required this.channels,
    required this.currentChannel,
    required this.compact,
    required this.compactEpgEntries,
    required this.onChannelSelect,
    required this.favoriteChannelIds,
    required this.onToggleFavorite,
  });

  final List<IPTVChannel> channels;
  final IPTVChannel? currentChannel;
  final bool compact;
  final Map<String, CompactEpgEntry> compactEpgEntries;
  final ValueChanged<IPTVChannel> onChannelSelect;
  final Set<String> favoriteChannelIds;
  final ValueChanged<IPTVChannel> onToggleFavorite;

  @override
  State<_TvChannelGridView> createState() => _TvChannelGridViewState();
}

class _TvChannelGridViewState extends State<_TvChannelGridView> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: widget.compact ? 180 : 220,
          childAspectRatio: widget.compact ? 1.2 : 1.03,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
        ),
        itemCount: widget.channels.length,
        itemBuilder: (context, index) {
          final channel = widget.channels[index];
          return _TvChannelCard(
            channel: channel,
            isPlaying: widget.currentChannel?.id == channel.id,
            isFavorite: widget.favoriteChannelIds.contains(channel.id),
            epgEntry: widget.compactEpgEntries[channel.id],
            autofocus: index == 0,
            onSelect: () => widget.onChannelSelect(channel),
            onToggleFavorite: () => widget.onToggleFavorite(channel),
          );
        },
      ),
    );
  }
}

class _TvChannelListView extends StatefulWidget {
  const _TvChannelListView({
    required this.channels,
    required this.currentChannel,
    required this.compactEpgEntries,
    required this.onChannelSelect,
    required this.favoriteChannelIds,
    required this.onToggleFavorite,
  });

  final List<IPTVChannel> channels;
  final IPTVChannel? currentChannel;
  final Map<String, CompactEpgEntry> compactEpgEntries;
  final ValueChanged<IPTVChannel> onChannelSelect;
  final Set<String> favoriteChannelIds;
  final ValueChanged<IPTVChannel> onToggleFavorite;

  @override
  State<_TvChannelListView> createState() => _TvChannelListViewState();
}

class _TvChannelListViewState extends State<_TvChannelListView> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: widget.channels.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final channel = widget.channels[index];
          return _TvChannelRow(
            channel: channel,
            isPlaying: widget.currentChannel?.id == channel.id,
            isFavorite: widget.favoriteChannelIds.contains(channel.id),
            epgEntry: widget.compactEpgEntries[channel.id],
            autofocus: index == 0,
            onSelect: () => widget.onChannelSelect(channel),
            onToggleFavorite: () => widget.onToggleFavorite(channel),
          );
        },
      ),
    );
  }
}

class _TvChannelCard extends StatelessWidget {
  const _TvChannelCard({
    required this.channel,
    required this.isPlaying,
    required this.isFavorite,
    required this.epgEntry,
    required this.autofocus,
    required this.onSelect,
    required this.onToggleFavorite,
  });

  final IPTVChannel channel;
  final bool isPlaying;
  final bool isFavorite;
  final CompactEpgEntry? epgEntry;
  final bool autofocus;
  final VoidCallback onSelect;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return TvFocusable(
      autofocus: autofocus,
      onSelect: onSelect,
      onSecondaryAction: onToggleFavorite,
      semanticLabel: isPlaying
          ? '${channel.name}, currently playing'
          : channel.name,
      semanticHint: isFavorite
          ? 'Press OK to play this channel. Press menu to remove from favorites.'
          : 'Press OK to play this channel. Press menu to add to favorites.',
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
        child: Stack(
          children: [
            Padding(
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
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          channel.group,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (isPlaying)
                        Icon(
                          Icons.equalizer,
                          color: colorScheme.primary,
                          size: 20,
                        ),
                    ],
                  ),
                  if (epgEntry?.hasPrograms ?? false) ...[
                    const SizedBox(height: 6),
                    _CompactEpgLine(entry: epgEntry!),
                  ],
                ],
              ),
            ),
            if (isFavorite)
              Positioned(
                top: 6,
                right: 6,
                child: Icon(
                  Icons.star,
                  color: colorScheme.primary,
                  size: 18,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TvChannelRow extends StatelessWidget {
  const _TvChannelRow({
    required this.channel,
    required this.isPlaying,
    required this.isFavorite,
    required this.epgEntry,
    required this.autofocus,
    required this.onSelect,
    required this.onToggleFavorite,
  });

  final IPTVChannel channel;
  final bool isPlaying;
  final bool isFavorite;
  final CompactEpgEntry? epgEntry;
  final bool autofocus;
  final VoidCallback onSelect;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return TvFocusable(
      autofocus: autofocus,
      onSelect: onSelect,
      onSecondaryAction: onToggleFavorite,
      semanticLabel: isPlaying
          ? '${channel.name}, currently playing'
          : channel.name,
      semanticHint: isFavorite
          ? 'Press OK to play this channel. Press menu to remove from favorites.'
          : 'Press OK to play this channel. Press menu to add to favorites.',
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
                    if (epgEntry?.hasPrograms ?? false) ...[
                      const SizedBox(height: 6),
                      _CompactEpgLine(entry: epgEntry!),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 16),
              if (isFavorite)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    Icons.star,
                    color: colorScheme.primary,
                    size: 18,
                  ),
                ),
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

class _CompactEpgLine extends StatelessWidget {
  const _CompactEpgLine({required this.entry});

  final CompactEpgEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final program = entry.current ?? entry.next;
    if (program == null) {
      return const SizedBox.shrink();
    }

    final prefix = entry.current != null ? 'Now' : 'Next';
    return Row(
      children: [
        Icon(Icons.schedule, size: 14, color: colorScheme.primary),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            '$prefix: ${program.title}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
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
            ? AiroNetworkImage(
                url: channel.logoUrl!,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    IptvIconPlaceholder.channel(
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

class _TvEmptyPlaylistLayout extends StatelessWidget {
  const _TvEmptyPlaylistLayout({
    required this.productProfile,
    required this.child,
  });

  final ProductProfileManifest productProfile;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
      child: Column(
        children: [
          _TvLiteReceiverShellHeader(productProfile: productProfile),
          const SizedBox(height: 18),
          Expanded(child: child),
        ],
      ),
    );
  }
}

extension on ProductSupportLevel {
  String get tvLabel {
    return switch (this) {
      ProductSupportLevel.certified => 'Certified',
      ProductSupportLevel.compatible => 'Compatible',
      ProductSupportLevel.experimental => 'Experimental',
      ProductSupportLevel.unsupported => 'Unsupported',
    };
  }
}

extension on ProductNavigationEntry {
  String get tvLabel {
    return switch (this) {
      ProductNavigationEntry.home => 'Home',
      ProductNavigationEntry.live => 'Live',
      ProductNavigationEntry.guide => 'Guide',
      ProductNavigationEntry.favorites => 'Favorites',
      ProductNavigationEntry.recent => 'Recent',
      ProductNavigationEntry.search => 'Search',
      ProductNavigationEntry.settings => 'Settings',
      ProductNavigationEntry.diagnostics => 'Diagnostics',
      ProductNavigationEntry.profiles => 'Profiles',
    };
  }
}

extension on ProductCapability {
  String get tvLabel {
    return switch (this) {
      ProductCapability.directPlayback => 'direct playback',
      ProductCapability.dpadNavigation => 'D-pad navigation',
      ProductCapability.companionRemote => 'companion remote',
      ProductCapability.compactEpg => 'compact guide',
      ProductCapability.fullEpg => 'full guide',
      ProductCapability.basicSearch => 'basic search',
      ProductCapability.diagnostics => 'diagnostics',
      ProductCapability.analytics => 'analytics',
      ProductCapability.localAi => 'local AI',
      ProductCapability.recording => 'recording',
      ProductCapability.downloads => 'downloads',
      ProductCapability.multiview => 'multiview',
    };
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
            Text('Airo TV', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 12),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                children: [
                  const TextSpan(
                    text: 'Import any M3U playlist and get a clean, ',
                  ),
                  TextSpan(
                    text: 'smart TV experience',
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const TextSpan(text: ' — instantly.'),
                ],
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
                  label: 'Add Playlist URL',
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
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 20,
              runSpacing: 8,
              children: const [
                _EmptyStateChecklistItem(label: 'No account required'),
                _EmptyStateChecklistItem(label: 'Dead links removed'),
                _EmptyStateChecklistItem(label: 'Duplicates merged'),
                _EmptyStateChecklistItem(label: 'Smart rails built'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyStateChecklistItem extends StatelessWidget {
  const _EmptyStateChecklistItem({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.check, size: 14, color: colorScheme.primary),
        const SizedBox(width: 5),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
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

class _MacosUpdateDialog extends ConsumerStatefulWidget {
  const _MacosUpdateDialog();

  @override
  ConsumerState<_MacosUpdateDialog> createState() => _MacosUpdateDialogState();
}

class _MacosUpdateDialogState extends ConsumerState<_MacosUpdateDialog> {
  late Future<AiroMacosUpdateResult> _updateFuture;

  @override
  void initState() {
    super.initState();
    _updateFuture = _checkForUpdate();
  }

  Future<AiroMacosUpdateResult> _checkForUpdate() {
    return AiroMacosUpdateService(ref.read(dioProvider)).checkLatest();
  }

  void _retry() {
    setState(() {
      _updateFuture = _checkForUpdate();
    });
  }

  Future<void> _openRelease(Uri releaseUrl) async {
    await AiroMacosUpdateService(ref.read(dioProvider)).openRelease(releaseUrl);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Airo TV updates'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: FutureBuilder<AiroMacosUpdateResult>(
          future: _updateFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _MacosUpdateDialogBody(
                icon: CircularProgressIndicator(),
                title: 'Checking for updates',
                message: 'Looking for a macOS release on GitHub.',
              );
            }

            final result = snapshot.data;
            if (snapshot.hasError || result == null) {
              return _MacosUpdateDialogBody(
                icon: Icon(
                  Icons.error_outline,
                  color: Theme.of(context).colorScheme.error,
                  size: 40,
                ),
                title: 'Could not check updates',
                message:
                    snapshot.error?.toString() ??
                    'The update check did not return a result.',
              );
            }

            return _MacosUpdateResultBody(result: result);
          },
        ),
      ),
      actions: [
        TextButton(onPressed: _retry, child: const Text('Check again')),
        FutureBuilder<AiroMacosUpdateResult>(
          future: _updateFuture,
          builder: (context, snapshot) {
            final result = snapshot.data;
            if (result == null || !result.hasUpdate) {
              return const SizedBox.shrink();
            }
            return FilledButton.icon(
              onPressed: () => _openRelease(result.releaseUrl),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open release'),
            );
          },
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _MacosUpdateResultBody extends StatelessWidget {
  const _MacosUpdateResultBody({required this.result});

  final AiroMacosUpdateResult result;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return switch (result.availability) {
      AiroMacosUpdateAvailability.available => _MacosUpdateDialogBody(
        icon: Icon(
          Icons.system_update_alt,
          color: colorScheme.primary,
          size: 40,
        ),
        title: 'Update available',
        message:
            'Airo TV ${result.latestVersion} is available for macOS. Current version: ${result.currentVersion}.',
      ),
      AiroMacosUpdateAvailability.upToDate => _MacosUpdateDialogBody(
        icon: Icon(Icons.check_circle, color: colorScheme.primary, size: 40),
        title: 'Airo TV is up to date',
        message:
            'Current version: ${result.currentVersion}. Latest macOS release: ${result.latestVersion}.',
      ),
      AiroMacosUpdateAvailability.unavailable => _MacosUpdateDialogBody(
        icon: Icon(
          Icons.info_outline,
          color: colorScheme.onSurfaceVariant,
          size: 40,
        ),
        title: 'No macOS update available',
        message:
            result.detail ??
            'The latest GitHub release does not include a newer macOS app.',
      ),
    };
  }
}

class _MacosUpdateDialogBody extends StatelessWidget {
  const _MacosUpdateDialogBody({
    required this.icon,
    required this.title,
    required this.message,
  });

  final Widget icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 44, height: 44, child: Center(child: icon)),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                message,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
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
        FilledButton(
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

/// Per-category accent (icon color only, never a full fill) so category
/// identity doesn't rely on shading the brand green differently everywhere.
/// "All" intentionally uses the primary accent since it represents the
/// whole (unfiltered) catalog rather than one category.
Color _categoryColor(BuildContext context, ChannelCategory category) {
  final primary = Theme.of(context).colorScheme.primary;
  return switch (category) {
    ChannelCategory.all => primary,
    ChannelCategory.news => AppColors.airoTvCategoryNews,
    ChannelCategory.sports => AppColors.airoTvCategorySports,
    ChannelCategory.movies => AppColors.airoTvCategoryMovies,
    ChannelCategory.music => AppColors.airoTvCategoryMusic,
    ChannelCategory.kids => AppColors.airoTvCategoryKids,
    ChannelCategory.documentary => AppColors.airoTvCategoryDocumentary,
    ChannelCategory.entertainment => AppColors.airoTvCategoryEntertainment,
    _ => AppColors.airoTvCategoryDefault,
  };
}
