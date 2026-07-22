import 'package:core_ui/core_ui.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_channels/platform_channels.dart';

import '../../../application/providers/channel_filters_provider.dart';
import '../../../application/providers/hotbar_channels_provider.dart';

class Hotbar extends ConsumerWidget {
  const Hotbar({
    super.key,
    required this.channels,
    required this.onChannelSelected,
  });

  final List<IPTVChannel> channels;
  final ValueChanged<IPTVChannel> onChannelSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(hotbarChannelsProvider);
    if (entries.isEmpty) {
      return const SizedBox(height: 56);
    }

    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: entries.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final entry = entries[index];
          final channel = channels
              .where((item) => item.id == entry.channelId)
              .firstOrNull;
          if (channel == null) return const SizedBox.shrink();
          return TvFocusable(
            semanticLabel: channel.name,
            onSelect: () {
              ref.read(channelFiltersProvider.notifier).restore(entry.filters);
              onChannelSelected(channel);
            },
            child: ActionChip(
              label: Text(channel.name),
              onPressed: () {
                ref
                    .read(channelFiltersProvider.notifier)
                    .restore(entry.filters);
                onChannelSelected(channel);
              },
            ),
          );
        },
      ),
    );
  }
}
