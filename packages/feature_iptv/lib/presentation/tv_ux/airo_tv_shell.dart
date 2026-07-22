import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_streams/platform_streams.dart';

import '../../application/providers/channel_filters_provider.dart';
import 'sections/channel_info_bar.dart';
import 'sections/channel_table.dart';
import 'sections/filter_row.dart';
import 'sections/hotbar.dart';

class AiroTvShell extends ConsumerWidget {
  const AiroTvShell({
    super.key,
    required this.channels,
    required this.videoStage,
    required this.onChannelSelected,
    this.currentChannel,
    this.metadataByChannelId = const {},
    this.availabilityByChannelId = const {},
  });

  final List<IPTVChannel> channels;
  final Widget videoStage;
  final ValueChanged<IPTVChannel> onChannelSelected;
  final IPTVChannel? currentChannel;
  final Map<String, ChannelBrowseMetadata> metadataByChannelId;
  final Map<String, StreamAvailability> availabilityByChannelId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(channelFiltersProvider);
    final sort = ref.watch(channelSortProvider);
    final dimensions = channelFilterDimensions(
      channels: channels,
      metadataByChannelId: metadataByChannelId,
    );
    final visible = sortChannels(
      channels: applyChannelFilters(
        channels: channels,
        filters: filters,
        metadataByChannelId: metadataByChannelId,
      ),
      metadataByChannelId: metadataByChannelId,
      sort: sort,
    );
    final table = ChannelTable(
      key: const ValueKey('airo-tv-channel-table'),
      channels: visible,
      metadataByChannelId: metadataByChannelId,
      availabilityByChannelId: availabilityByChannelId,
      sort: sort,
      onSort: (column) =>
          ref.read(channelSortProvider.notifier).state = sort.toggle(column),
      onChannelSelected: onChannelSelected,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final chrome = [
          ChannelInfoBar(channel: currentChannel),
          Hotbar(channels: channels, onChannelSelected: onChannelSelected),
          FilterRow(dimensions: dimensions),
        ];
        if (constraints.maxWidth < 600) {
          return Column(
            children: [
              Flexible(flex: 3, child: videoStage),
              ...chrome,
              Expanded(flex: 4, child: table),
            ],
          );
        }
        return Column(
          children: [
            Flexible(flex: 3, child: videoStage),
            ...chrome,
            Expanded(flex: 4, child: table),
          ],
        );
      },
    );
  }
}
