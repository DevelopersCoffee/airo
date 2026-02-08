import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(8),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search channels...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              suffixIcon: searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () =>
                          ref.read(channelSearchQueryProvider.notifier).state =
                              '',
                    )
                  : null,
            ),
            onChanged: (value) =>
                ref.read(channelSearchQueryProvider.notifier).state = value,
          ),
        ),

        // Category tabs
        if (showCategories)
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: ChannelCategory.values.length,
              itemBuilder: (context, index) {
                final category = ChannelCategory.values[index];
                final isSelected = category == selectedCategory;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(category.label),
                    selected: isSelected,
                    onSelected: (_) =>
                        ref.read(selectedCategoryProvider.notifier).state =
                            category,
                  ),
                );
              },
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
                  errorBuilder: (_, __, ___) => _buildDefaultIcon(),
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
      subtitle: Text(
        channel.group,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (channel.isAudioOnly)
            const Icon(Icons.music_note, size: 16, color: Colors.orange),
          if (isPlaying)
            Icon(
              Icons.volume_up,
              size: 16,
              color: Theme.of(context).primaryColor,
            ),
        ],
      ),
      onTap: onTap,
    );
  }

  Widget _buildDefaultIcon() {
    return Icon(
      channel.isAudioOnly ? Icons.radio : Icons.live_tv,
      color: Colors.grey,
    );
  }
}
