import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/providers/iptv_providers.dart';
import "package:platform_channels/platform_channels.dart";
import 'app_icon_placeholder.dart';

/// Channel list widget with category tabs and search
class ChannelListWidget extends ConsumerWidget {
  final Function(IPTVChannel) onChannelTap;
  final bool showCategories;
  final bool showSearchBar;

  const ChannelListWidget({
    super.key,
    required this.onChannelTap,
    this.showCategories = true,
    this.showSearchBar = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channels = ref.watch(filteredChannelsProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final searchQuery = ref.watch(channelSearchQueryProvider);
    final counts = ref.watch(categoryCounts);
    final hasActiveFilter = ref.watch(hasActiveFilterProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Search bar - compact to prevent overflow
        if (showSearchBar)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: SizedBox(
              height: 44,
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search channels...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(0),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  isDense: true,
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () =>
                              ref
                                      .read(channelSearchQueryProvider.notifier)
                                      .state =
                                  '',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        )
                      : null,
                ),
                onChanged: (value) =>
                    ref.read(channelSearchQueryProvider.notifier).state = value,
              ),
            ),
          ),

        // Category tabs with counts - compact height
        if (showCategories)
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: ChannelCategory.values.length,
              itemBuilder: (context, index) {
                final category = ChannelCategory.values[index];
                final isSelected = category == selectedCategory;
                final count = counts[category] ?? 0;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    // Show count in label for better UX feedback
                    label: Text('${category.label} ($count)'),
                    selected: isSelected,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                      side: BorderSide(color: colorScheme.outlineVariant),
                    ),
                    onSelected: (_) =>
                        ref.read(selectedCategoryProvider.notifier).state =
                            category,
                  ),
                );
              },
            ),
          ),

        // Clear filters button - show when filters are active
        if (hasActiveFilter)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                Text(
                  '${channels.length} channels',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    ref.read(selectedCategoryProvider.notifier).state =
                        ChannelCategory.all;
                    ref.read(channelSearchQueryProvider.notifier).state = '';
                  },
                  icon: const Icon(Icons.clear_all, size: 16),
                  label: const Text('Clear filters'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ),

        // Channel list with recently watched section
        Expanded(
          child: channels.isEmpty
              ? _buildEmptyState()
              : _ChannelListWithRecent(
                  channels: channels,
                  onChannelTap: onChannelTap,
                  showRecentlyWatched: !hasActiveFilter,
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.live_tv, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('No channels found', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

/// Channel list with recently watched section at top
class _ChannelListWithRecent extends ConsumerWidget {
  final List<IPTVChannel> channels;
  final Function(IPTVChannel) onChannelTap;
  final bool showRecentlyWatched;

  const _ChannelListWithRecent({
    required this.channels,
    required this.onChannelTap,
    this.showRecentlyWatched = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentAsync = ref.watch(recentlyWatchedChannelsProvider);

    return ListView.builder(
      itemCount: channels.length + (showRecentlyWatched ? 1 : 0),
      itemBuilder: (context, index) {
        // Recently watched section at top
        if (showRecentlyWatched && index == 0) {
          return recentAsync.when(
            data: (recentChannels) {
              if (recentChannels.isEmpty) {
                return const SizedBox.shrink();
              }
              return _RecentlyWatchedSection(
                channels: recentChannels,
                onChannelTap: onChannelTap,
                onClearRecent: () {
                  ref.read(clearRecentlyWatchedProvider(null));
                },
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          );
        }

        // Regular channel list
        final channelIndex = showRecentlyWatched ? index - 1 : index;
        final channel = channels[channelIndex];
        return _ChannelListTile(
          channel: channel,
          onTap: () => onChannelTap(channel),
        );
      },
    );
  }
}

/// Recently watched channels horizontal section
class _RecentlyWatchedSection extends StatelessWidget {
  final List<IPTVChannel> channels;
  final Function(IPTVChannel) onChannelTap;
  final VoidCallback onClearRecent;

  const _RecentlyWatchedSection({
    required this.channels,
    required this.onChannelTap,
    required this.onClearRecent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header with clear button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
          child: Row(
            children: [
              Icon(Icons.history, size: 18, color: theme.primaryColor),
              const SizedBox(width: 8),
              Text(
                'Recently Watched',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: onClearRecent,
                icon: const Icon(Icons.clear_all, size: 16),
                label: const Text('Clear'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  visualDensity: VisualDensity.compact,
                  foregroundColor: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        // Horizontal scrollable list
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: channels.length,
            itemBuilder: (context, index) {
              final channel = channels[index];
              return _RecentChannelCard(
                channel: channel,
                onTap: () => onChannelTap(channel),
              );
            },
          ),
        ),
        const Divider(height: 16),
      ],
    );
  }
}

/// Compact card for recently watched channel
class _RecentChannelCard extends StatelessWidget {
  final IPTVChannel channel;
  final VoidCallback onTap;

  const _RecentChannelCard({required this.channel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 80,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Channel logo
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 56,
                height: 56,
                color: Colors.grey[200],
                child: channel.hasLogo
                    ? Image.network(
                        channel.logoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _buildDefaultIcon(),
                      )
                    : _buildDefaultIcon(),
              ),
            ),
            const SizedBox(height: 4),
            // Channel name
            Text(
              channel.name,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultIcon() {
    return Center(
      child: Icon(
        channel.isAudioOnly ? Icons.radio : Icons.live_tv,
        color: Colors.grey,
        size: 28,
      ),
    );
  }
}

class _ChannelListTile extends ConsumerWidget {
  final IPTVChannel channel;
  final VoidCallback onTap;

  const _ChannelListTile({required this.channel, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentChannel = ref.watch(currentChannelProvider);
    final isPlaying = currentChannel?.id == channel.id;

    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: 48,
            height: 48,
            color: Theme.of(
              context,
            ).colorScheme.surface.withValues(alpha: 0.42),
            child: channel.hasLogo
                ? Image.network(
                    channel.logoUrl!,
                    fit: BoxFit.cover,
                    loadingBuilder: (_, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      );
                    },
                    errorBuilder: (_, _, _) => _buildDefaultIcon(),
                  )
                : _buildDefaultIcon(),
          ),
        ),
        title: Text(
          channel.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
            color: isPlaying ? Theme.of(context).primaryColor : null,
          ),
        ),
        subtitle: Row(
          children: [
            // Audio-only label for clarity (UX improvement)
            if (channel.isAudioOnly)
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Audio',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.orange,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            Expanded(
              child: Text(
                channel.group,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!channel.isAudioOnly) const _LiveStatusPill(),
            if (!channel.isAudioOnly) const SizedBox(width: 8),
            // Playing indicator with animation
            if (isPlaying)
              Icon(
                Icons.equalizer,
                size: 18,
                color: Theme.of(context).primaryColor,
              ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildDefaultIcon() {
    // Use shared AppIconPlaceholder for brand consistency and optimized caching
    return AppIconPlaceholder.channel(isAudioOnly: channel.isAudioOnly);
  }
}

class _LiveStatusPill extends StatelessWidget {
  const _LiveStatusPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.red.shade700,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 6, color: Colors.white),
          SizedBox(width: 4),
          Text(
            'LIVE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
