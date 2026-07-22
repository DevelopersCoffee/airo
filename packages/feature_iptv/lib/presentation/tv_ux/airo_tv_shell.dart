import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_streams/platform_streams.dart';

import '../../application/providers/channel_filters_provider.dart';
import '../../application/channel_metadata_enrichment.dart';
import 'sections/channel_info_bar.dart';
import 'sections/channel_table.dart';
import 'sections/filter_row.dart';
import 'sections/hotbar.dart';

class AiroTvShell extends ConsumerStatefulWidget {
  const AiroTvShell({
    super.key,
    required this.channels,
    required this.videoStage,
    required this.onChannelSelected,
    this.currentChannel,
    this.metadataByChannelId = const {},
    this.availabilityByChannelId = const {},
    this.enrichMetadata = false,
  });

  final List<IPTVChannel> channels;
  final Widget videoStage;
  final ValueChanged<IPTVChannel> onChannelSelected;
  final IPTVChannel? currentChannel;
  final Map<String, ChannelBrowseMetadata> metadataByChannelId;
  final Map<String, StreamAvailability> availabilityByChannelId;
  final bool enrichMetadata;

  @override
  ConsumerState<AiroTvShell> createState() => _AiroTvShellState();
}

class _AiroTvShellState extends ConsumerState<AiroTvShell> {
  final _snapshotCache = ChannelBrowserSnapshotCache();

  @override
  void dispose() {
    _snapshotCache.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(channelFiltersProvider);
    final metadata = widget.enrichMetadata
        ? ref.watch(channelBrowseMetadataProvider).value ??
              widget.metadataByChannelId
        : widget.metadataByChannelId;
    final sort = ref.watch(channelSortProvider);
    final snapshot = _snapshotCache.resolve(
      channels: widget.channels,
      metadataByChannelId: metadata,
      filters: filters,
      sort: sort,
    );
    final table = ChannelTable(
      key: const ValueKey('airo-tv-channel-table'),
      channels: snapshot.visibleChannels,
      metadataByChannelId: metadata,
      availabilityByChannelId: widget.availabilityByChannelId,
      sort: sort,
      onSort: (column) =>
          ref.read(channelSortProvider.notifier).state = sort.toggle(column),
      onChannelSelected: widget.onChannelSelected,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final chrome = [
          ChannelInfoBar(channel: widget.currentChannel),
          Hotbar(
            channels: widget.channels,
            onChannelSelected: widget.onChannelSelected,
          ),
          FilterRow(dimensions: snapshot.dimensions),
        ];
        if (constraints.maxWidth < 600) {
          return Column(
            children: [
              Flexible(flex: 3, child: widget.videoStage),
              ...chrome,
              Expanded(flex: 4, child: table),
            ],
          );
        }
        final previewWidth = (constraints.maxWidth * 0.34)
            .clamp(320.0, 480.0)
            .toDouble();
        final previewHeight = previewWidth * 9 / 16;
        final panelWidth = (constraints.maxWidth * 0.88)
            .clamp(720.0, 1120.0)
            .toDouble();

        return Container(
          key: const ValueKey('airo-tv-explorer-wide-shell'),
          color: Colors.black,
          child: Column(
            children: [
              Flexible(
                flex: 3,
                child: Center(
                  child: ConstrainedBox(
                    key: const ValueKey('airo-tv-explorer-video-stage'),
                    constraints: BoxConstraints.tightFor(
                      width: previewWidth,
                      height: previewHeight,
                    ),
                    child: ClipRect(
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: SizedBox(
                          width: 640,
                          height: 360,
                          child: widget.videoStage,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 5,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    key: const ValueKey('airo-tv-explorer-panel'),
                    constraints: BoxConstraints(maxWidth: panelWidth),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFF020419),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        children: [
                          _ExplorerSection(
                            label: 'LIVE',
                            height: 64,
                            child: chrome[0],
                          ),
                          _ExplorerSection(
                            label: 'HOTBAR',
                            height: 56,
                            child: chrome[1],
                          ),
                          _ExplorerSection(
                            label: 'FILTER',
                            height: 56,
                            child: chrome[2],
                          ),
                          Expanded(child: table),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ExplorerSection extends StatelessWidget {
  const _ExplorerSection({
    required this.label,
    required this.height,
    required this.child,
  });

  final String label;
  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.white12)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 30,
              child: Center(
                child: RotatedBox(
                  quarterTurns: 3,
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white54,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ),
            const VerticalDivider(width: 1, color: Colors.white12),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
