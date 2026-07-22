import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_streams/platform_streams.dart';

import '../../../application/providers/channel_filters_provider.dart';
import '../../widgets/channel_logo.dart';

const _channelRowHeight = 56.0;
const _tableHeaderHeight = 52.0;
const _availabilityStripWidth = 4.0;

class ChannelTable extends StatefulWidget {
  const ChannelTable({
    super.key,
    required this.channels,
    required this.metadataByChannelId,
    this.availabilityByChannelId = const {},
    this.sort = const ChannelSort(),
    this.onSort,
    this.onChannelSelected,
    this.onVisibleChannelsChanged,
  });

  final List<IPTVChannel> channels;
  final Map<String, ChannelBrowseMetadata> metadataByChannelId;
  final Map<String, StreamAvailability> availabilityByChannelId;
  final ChannelSort sort;
  final ValueChanged<ChannelSortColumn>? onSort;
  final ValueChanged<IPTVChannel>? onChannelSelected;
  final ValueChanged<List<IPTVChannel>>? onVisibleChannelsChanged;

  @override
  State<ChannelTable> createState() => _ChannelTableState();
}

class _ChannelTableState extends State<ChannelTable> {
  late final ScrollController _scrollController;
  String _lastVisibleSignature = '';

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_reportVisibleChannels);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _reportVisibleChannels(),
    );
  }

  @override
  void didUpdateWidget(covariant ChannelTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.channels, widget.channels)) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _reportVisibleChannels(force: true),
      );
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_reportVisibleChannels)
      ..dispose();
    super.dispose();
  }

  void _reportVisibleChannels({bool force = false}) {
    final callback = widget.onVisibleChannelsChanged;
    if (callback == null || !mounted || widget.channels.isEmpty) return;
    if (!_scrollController.hasClients) return;
    final viewportHeight = _scrollController.position.viewportDimension;
    final offset = _scrollController.offset;
    final first = ((offset - _tableHeaderHeight) / _channelRowHeight)
        .floor()
        .clamp(0, widget.channels.length - 1)
        .toInt();
    final visibleCount =
        ((viewportHeight - _tableHeaderHeight) / _channelRowHeight).ceil() + 4;
    final end = (first + visibleCount).clamp(0, widget.channels.length).toInt();
    final visible = widget.channels.sublist(first, end);
    final signature = visible.map((channel) => channel.id).join(',');
    if (!force && signature == _lastVisibleSignature) return;
    _lastVisibleSignature = signature;
    callback(visible);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 600;
        return Scrollbar(
          controller: _scrollController,
          child: CustomScrollView(
            controller: _scrollController,
            key: const PageStorageKey<String>('airo-tv-channel-table-scroll'),
            physics: const AlwaysScrollableScrollPhysics(),
            cacheExtent: _channelRowHeight * 8,
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: _TableHeaderDelegate(
                  wide: wide,
                  sort: widget.sort,
                  onSort: widget.onSort,
                ),
              ),
              SliverFixedExtentList(
                itemExtent: _channelRowHeight,
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final channel = widget.channels[index];
                    return RepaintBoundary(
                      key: ValueKey('channel-row-${channel.id}'),
                      child: _ChannelRow(
                        channel: channel,
                        metadata: widget.metadataByChannelId[channel.id],
                        availability:
                            widget.availabilityByChannelId[channel.id],
                        wide: wide,
                        onSelected: widget.onChannelSelected,
                      ),
                    );
                  },
                  childCount: widget.channels.length,
                  addAutomaticKeepAlives: false,
                  findChildIndexCallback: (key) {
                    if (key is! ValueKey<String>) return null;
                    final value = key.value;
                    if (!value.startsWith('channel-row-')) return null;
                    final channelId = value.substring('channel-row-'.length);
                    final index = widget.channels.indexWhere(
                      (channel) => channel.id == channelId,
                    );
                    return index < 0 ? null : index;
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TableHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _TableHeaderDelegate({
    required this.wide,
    required this.sort,
    this.onSort,
  });

  final bool wide;
  final ChannelSort sort;
  final ValueChanged<ChannelSortColumn>? onSort;

  @override
  double get minExtent => _tableHeaderHeight;

  @override
  double get maxExtent => _tableHeaderHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      elevation: overlapsContent ? 2 : 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: _TableHeader(wide: wide, sort: sort, onSort: onSort),
    );
  }

  @override
  bool shouldRebuild(covariant _TableHeaderDelegate oldDelegate) {
    return oldDelegate.wide != wide ||
        oldDelegate.sort != sort ||
        oldDelegate.onSort != onSort;
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
          style: TextButton.styleFrom(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            minimumSize: const Size(0, 40),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: sort.column == column
              ? Icon(
                  sort.ascending ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 16,
                )
              : const SizedBox.shrink(),
          label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      );
    }

    return SizedBox(
      height: _tableHeaderHeight,
      child: Padding(
        padding: const EdgeInsets.only(left: _availabilityStripWidth),
        child: Row(
          children: [
            SizedBox(width: wide ? 50 : 42),
            header('Name', ChannelSortColumn.name, flex: wide ? 4 : 5),
            header(
              wide ? 'Category' : 'Cat.',
              ChannelSortColumn.category,
              flex: wide ? 3 : 4,
            ),
            header(
              wide ? 'Language' : 'Lang.',
              ChannelSortColumn.language,
              flex: 2,
            ),
            header(wide ? 'Status' : 'Stat.', ChannelSortColumn.type),
            header('Flag', ChannelSortColumn.country),
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
    final country = effectiveChannelCountry(channel, metadata);
    final languages = effectiveChannelLanguages(channel, metadata);
    final language = languages.isEmpty ? null : languages.first;
    final languageSummary = _languageSummary(languages);
    final textTheme = Theme.of(context).textTheme;
    final logoSize = wide ? 30.0 : 26.0;
    return TvFocusable(
      semanticLabel: channel.name,
      onSelect: onSelected == null ? null : () => onSelected!(channel),
      child: InkWell(
        onTap: onSelected == null ? null : () => onSelected!(channel),
        child: Row(
          children: [
            Container(
              width: _availabilityStripWidth,
              height: _channelRowHeight,
              color: _availabilityColor(availability),
            ),
            const SizedBox(width: 7),
            ChannelLogo(
              logoUrl: channel.effectiveLogoUrl,
              channelName: channel.name,
              size: logoSize,
              fit: BoxFit.contain,
              borderRadius: 4,
              isAudioOnly: channel.isAudioOnly,
            ),
            const SizedBox(width: 7),
            Expanded(
              flex: wide ? 4 : 5,
              child: Text(
                channel.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              flex: wide ? 3 : 4,
              child: _MetadataCell(
                icon: _categoryIcon(channel),
                label: categoryDisplayLabel(channel.group) ?? channel.group,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                languageSummary ?? languageDisplayLabel(language),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              child: _AvailabilityStatusIcon(availability: availability),
            ),
            Expanded(
              child: Tooltip(
                message: countryDisplayLabel(country),
                child: Text(
                  _countryFlagOnly(country),
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  textAlign: TextAlign.center,
                  style: textTheme.titleMedium,
                ),
              ),
            ),
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

  IconData _categoryIcon(IPTVChannel channel) {
    final group = channel.group.toLowerCase();
    if (group.contains('news')) return Icons.newspaper;
    if (group.contains('movie') || group.contains('film')) {
      return Icons.movie_outlined;
    }
    if (group.contains('music')) return Icons.music_note;
    if (group.contains('sport')) return Icons.sports_soccer;
    if (group.contains('kids')) return Icons.child_care;
    if (group.contains('relig')) return Icons.self_improvement;
    return Icons.public;
  }

  String? _languageSummary(List<String> languages) {
    final labels = languages
        .map(languageDisplayLabel)
        .where((label) => label != 'Language')
        .toList(growable: false);
    if (labels.isEmpty) return null;
    return labels.join(', ');
  }

  String _countryFlagOnly(String? country) {
    final label = countryDisplayLabel(country);
    if (label == 'Country') return '🏳️';
    final firstSpace = label.indexOf(' ');
    return firstSpace > 0 ? label.substring(0, firstSpace) : label;
  }
}

class _AvailabilityStatusIcon extends StatelessWidget {
  const _AvailabilityStatusIcon({required this.availability});

  final StreamAvailability? availability;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (icon, color, label) = switch (availability) {
      StreamAvailability.available => (
        Icons.check_circle,
        Colors.green,
        'Channel reachable',
      ),
      StreamAvailability.unavailable => (
        Icons.error,
        colorScheme.error,
        'Channel unavailable',
      ),
      StreamAvailability.restricted => (
        Icons.warning_amber_rounded,
        Colors.amber,
        'Channel may be restricted',
      ),
      StreamAvailability.cancelled => (
        Icons.schedule,
        Colors.amber,
        'Channel check pending',
      ),
      StreamAvailability.unverified || null => (
        Icons.help_outline,
        colorScheme.onSurfaceVariant,
        'Channel not checked yet',
      ),
    };
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}

class _MetadataCell extends StatelessWidget {
  const _MetadataCell({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    final icon = this.icon;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}
