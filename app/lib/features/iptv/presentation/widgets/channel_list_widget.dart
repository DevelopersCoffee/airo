import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/widgets/app_icon_placeholder.dart';
import '../../application/providers/iptv_providers.dart';
import '../../domain/models/iptv_channel.dart';

/// Channel list widget with category tabs and search
class ChannelListWidget extends ConsumerWidget {
  final Function(IPTVChannel) onChannelTap;
  final bool showCategories;

  const ChannelListWidget({
    super.key,
    required this.onChannelTap,
    this.showCategories = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channels = ref.watch(filteredChannelsProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final searchQuery = ref.watch(channelSearchQueryProvider);
    final counts = ref.watch(categoryCounts);
    final hasActiveFilter = ref.watch(hasActiveFilterProvider);

    return Column(
      children: [
        // Search bar - compact to prevent overflow
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: SizedBox(
            height: 44,
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search channels...',
                prefixIcon: const Icon(Icons.search, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
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

        // Channel list
        Expanded(
          child: channels.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  itemCount: channels.length,
                  itemBuilder: (context, index) {
                    final channel = channels[index];
                    return _ChannelListTile(
                      channel: channel,
                      onTap: () => onChannelTap(channel),
                    );
                  },
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

class _ChannelListTile extends ConsumerWidget {
  final IPTVChannel channel;
  final VoidCallback onTap;

  const _ChannelListTile({required this.channel, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentChannel = ref.watch(currentChannelProvider);
    final isPlaying = currentChannel?.id == channel.id;

    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 48,
          height: 48,
          color: Colors.grey[200],
          child: channel.logoUrl != null
              ? Image.network(
                  channel.logoUrl!,
                  fit: BoxFit.cover,
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
    );
  }

  Widget _buildDefaultIcon() {
    // Use shared AppIconPlaceholder for brand consistency and optimized caching
    return AppIconPlaceholder.channel(isAudioOnly: channel.isAudioOnly);
  }
}
