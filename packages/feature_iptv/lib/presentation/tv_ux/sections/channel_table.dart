import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_streams/platform_streams.dart';

import '../../../application/providers/channel_filters_provider.dart';

class ChannelTable extends StatelessWidget {
  const ChannelTable({
    super.key,
    required this.channels,
    required this.metadataByChannelId,
    this.availabilityByChannelId = const {},
    this.sort = const ChannelSort(),
    this.onSort,
    this.onChannelSelected,
  });

  final List<IPTVChannel> channels;
  final Map<String, ChannelBrowseMetadata> metadataByChannelId;
  final Map<String, StreamAvailability> availabilityByChannelId;
  final ChannelSort sort;
  final ValueChanged<ChannelSortColumn>? onSort;
  final ValueChanged<IPTVChannel>? onChannelSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 600;
        return ListView(
          children: [
            _TableHeader(wide: wide, sort: sort, onSort: onSort),
            for (final channel in channels)
              _ChannelRow(
                key: ValueKey('channel-row-${channel.id}'),
                channel: channel,
                metadata: metadataByChannelId[channel.id],
                availability: availabilityByChannelId[channel.id],
                wide: wide,
                onSelected: onChannelSelected,
              ),
          ],
        );
      },
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader({required this.wide, required this.sort, this.onSort});

  final bool wide;
  final ChannelSort sort;
  final ValueChanged<ChannelSortColumn>? onSort;

  @override
  Widget build(BuildContext context) {
    Widget header(String label, ChannelSortColumn column, {int flex = 1}) {
      return Expanded(
        flex: flex,
        child: TextButton.icon(
          onPressed: onSort == null ? null : () => onSort!(column),
          icon: sort.column == column
              ? Icon(
                  sort.ascending ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 16,
                )
              : const SizedBox.shrink(),
          label: Text(label),
        ),
      );
    }

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.only(left: 5),
        child: Row(
          children: [
            header('Name', ChannelSortColumn.name, flex: 3),
            header('Category', ChannelSortColumn.category, flex: 2),
            if (wide) ...[
              header('Country', ChannelSortColumn.country),
              header('Language', ChannelSortColumn.language),
              header('Type', ChannelSortColumn.type),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChannelRow extends StatelessWidget {
  const _ChannelRow({
    super.key,
    required this.channel,
    required this.metadata,
    required this.availability,
    required this.wide,
    this.onSelected,
  });

  final IPTVChannel channel;
  final ChannelBrowseMetadata? metadata;
  final StreamAvailability? availability;
  final bool wide;
  final ValueChanged<IPTVChannel>? onSelected;

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      semanticLabel: channel.name,
      onSelect: onSelected == null ? null : () => onSelected!(channel),
      child: InkWell(
        onTap: onSelected == null ? null : () => onSelected!(channel),
        child: Row(
          children: [
            Container(
              width: 5,
              height: 54,
              color: _availabilityColor(availability),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: Text(channel.name, overflow: TextOverflow.ellipsis),
            ),
            Expanded(
              flex: 2,
              child: Text(channel.group, overflow: TextOverflow.ellipsis),
            ),
            if (wide) ...[
              Expanded(child: Text(metadata?.country ?? '—')),
              Expanded(child: Text(metadata?.language ?? '—')),
              Expanded(
                child: Icon(
                  channel.isAudioOnly ? Icons.radio : Icons.live_tv,
                  size: 18,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _availabilityColor(StreamAvailability? value) {
    return switch (value) {
      StreamAvailability.available => Colors.green,
      StreamAvailability.unavailable ||
      StreamAvailability.restricted => Colors.red,
      _ => Colors.grey,
    };
  }
}
