import 'dart:async';

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_streams/platform_streams.dart';

import '../../../application/providers/channel_filters_provider.dart';

const _cardWidth = 172.0;
const _cardHeight = 169.0; // MediaCard.railHeightFor(MediaCardVariant.standard)
const _gridSpacing = 14.0;
const _preloadRowsBeforeViewport = 2;
const _preloadRowsAfterViewport = 6;

/// Card-grid channel browser — replaces the spreadsheet-style
/// [ChannelTable]. Matches the "LIBRARY" screen of the AiroTV D-pad design
/// (Claude Design project 02b0b312): tiles instead of rows, sort collapsed
/// to a compact chip row instead of clickable column headers.
class ChannelLibraryGrid extends StatefulWidget {
  const ChannelLibraryGrid({
    super.key,
    required this.channels,
    required this.metadataByChannelId,
    this.availabilityByChannelId = const {},
    this.sort = const ChannelSort(),
    this.onSort,
    this.onChannelSelected,
    this.focusPlayDelay,
    this.onVisibleChannelsChanged,
    this.multiviewChannelIds = const {},
    this.onMultiviewToggle,
  });

  final List<IPTVChannel> channels;
  final Map<String, ChannelBrowseMetadata> metadataByChannelId;
  final Map<String, StreamAvailability> availabilityByChannelId;
  final ChannelSort sort;
  final ValueChanged<ChannelSortColumn>? onSort;
  final ValueChanged<IPTVChannel>? onChannelSelected;
  final Duration? focusPlayDelay;
  final ValueChanged<List<IPTVChannel>>? onVisibleChannelsChanged;
  final Set<String> multiviewChannelIds;
  final ValueChanged<IPTVChannel>? onMultiviewToggle;

  @override
  State<ChannelLibraryGrid> createState() => _ChannelLibraryGridState();
}

class _ChannelLibraryGridState extends State<ChannelLibraryGrid> {
  late final ScrollController _scrollController;
  String _lastVisibleSignature = '';
  int _lastColumnCount = 1;

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
  void didUpdateWidget(covariant ChannelLibraryGrid oldWidget) {
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

  int _columnCountFor(double width) {
    final perColumn = _cardWidth + _gridSpacing;
    return ((width + _gridSpacing) / perColumn).floor().clamp(1, 100);
  }

  void _reportVisibleChannels({bool force = false}) {
    final callback = widget.onVisibleChannelsChanged;
    if (callback == null || !mounted || widget.channels.isEmpty) return;
    if (!_scrollController.hasClients) return;
    final columns = _lastColumnCount;
    final viewportHeight = _scrollController.position.viewportDimension;
    final offset = _scrollController.offset;
    final rowExtent = _cardHeight + _gridSpacing;
    final firstRow = (offset / rowExtent).floor().clamp(0, 1 << 30);
    final visibleRows = (viewportHeight / rowExtent).ceil() + 1;
    final firstIndex = ((firstRow - _preloadRowsBeforeViewport) * columns)
        .clamp(0, widget.channels.length)
        .toInt();
    final endIndex =
        ((firstRow + visibleRows + _preloadRowsAfterViewport) * columns)
            .clamp(0, widget.channels.length)
            .toInt();
    if (endIndex <= firstIndex) return;
    final visible = widget.channels.sublist(firstIndex, endIndex);
    final signature = visible.map((channel) => channel.id).join(',');
    if (!force && signature == _lastVisibleSignature) return;
    _lastVisibleSignature = signature;
    callback(visible);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _columnCountFor(constraints.maxWidth);
        if (columns != _lastColumnCount) {
          _lastColumnCount = columns;
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _reportVisibleChannels(force: true),
          );
        }
        return CustomScrollView(
          controller: _scrollController,
          key: const PageStorageKey<String>('airo-tv-channel-library-scroll'),
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _LibrarySortRow(sort: widget.sort, onSort: widget.onSort),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, _gridSpacing),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisExtent: _cardHeight,
                  crossAxisSpacing: _gridSpacing,
                  mainAxisSpacing: _gridSpacing,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final channel = widget.channels[index];
                    return RepaintBoundary(
                      key: ValueKey('channel-tile-${channel.id}'),
                      child: _ChannelTile(
                        channel: channel,
                        metadata: widget.metadataByChannelId[channel.id],
                        availability:
                            widget.availabilityByChannelId[channel.id],
                        onSelected: widget.onChannelSelected,
                        focusPlayDelay: widget.focusPlayDelay,
                        inMultiview: widget.multiviewChannelIds.contains(
                          channel.id,
                        ),
                        onMultiviewToggle: widget.onMultiviewToggle,
                      ),
                    );
                  },
                  childCount: widget.channels.length,
                  addAutomaticKeepAlives: false,
                  findChildIndexCallback: (key) {
                    if (key is! ValueKey<String>) return null;
                    final value = key.value;
                    if (!value.startsWith('channel-tile-')) return null;
                    final channelId = value.substring('channel-tile-'.length);
                    final index = widget.channels.indexWhere(
                      (channel) => channel.id == channelId,
                    );
                    return index < 0 ? null : index;
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LibrarySortRow extends StatelessWidget {
  const _LibrarySortRow({required this.sort, this.onSort});

  final ChannelSort sort;
  final ValueChanged<ChannelSortColumn>? onSort;

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, ChannelSortColumn column) {
      final active = sort.column == column;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: TvFocusable(
          key: ValueKey('channel-sort-${column.name}'),
          semanticLabel: 'Sort by $label',
          onSelect: onSort == null ? null : () => onSort!(column),
          borderRadius: 8,
          child: ChoiceChip(
            label: Text(label),
            selected: active,
            avatar: active
                ? Icon(
                    sort.ascending ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 14,
                  )
                : null,
            onSelected: onSort == null ? null : (_) => onSort!(column),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            chip('Name', ChannelSortColumn.name),
            chip('Category', ChannelSortColumn.category),
            chip('Language', ChannelSortColumn.language),
            chip('Country', ChannelSortColumn.country),
          ],
        ),
      ),
    );
  }
}

class _ChannelTile extends StatefulWidget {
  const _ChannelTile({
    required this.channel,
    required this.metadata,
    required this.availability,
    this.onSelected,
    this.focusPlayDelay,
    required this.inMultiview,
    this.onMultiviewToggle,
  });

  final IPTVChannel channel;
  final ChannelBrowseMetadata? metadata;
  final StreamAvailability? availability;
  final ValueChanged<IPTVChannel>? onSelected;
  final Duration? focusPlayDelay;
  final bool inMultiview;
  final ValueChanged<IPTVChannel>? onMultiviewToggle;

  @override
  State<_ChannelTile> createState() => _ChannelTileState();
}

class _ChannelTileState extends State<_ChannelTile> {
  Timer? _focusPlayTimer;

  @override
  void didUpdateWidget(covariant _ChannelTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.channel.id != widget.channel.id ||
        oldWidget.focusPlayDelay != widget.focusPlayDelay ||
        oldWidget.onSelected != widget.onSelected) {
      _cancelFocusPlay();
    }
  }

  @override
  void dispose() {
    _cancelFocusPlay();
    super.dispose();
  }

  void _scheduleFocusPlay() {
    _cancelFocusPlay();
    final delay = widget.focusPlayDelay;
    final onSelected = widget.onSelected;
    if (delay == null || onSelected == null) return;
    _focusPlayTimer = Timer(delay, () {
      _focusPlayTimer = null;
      if (!mounted) return;
      onSelected(widget.channel);
    });
  }

  void _cancelFocusPlay() {
    _focusPlayTimer?.cancel();
    _focusPlayTimer = null;
  }

  void _selectNow() {
    _cancelFocusPlay();
    widget.onSelected?.call(widget.channel);
  }

  @override
  Widget build(BuildContext context) {
    final country = effectiveChannelCountry(widget.channel, widget.metadata);
    final languages = effectiveChannelLanguages(
      widget.channel,
      widget.metadata,
    );
    final subtitle = _subtitleFor(country, languages);

    return Stack(
      children: [
        MediaCard(
          name: widget.channel.name,
          subtitle: subtitle,
          logoUrl: widget.channel.effectiveLogoUrl,
          initials: _initialsFor(widget.channel.name),
          onTap: widget.onSelected == null ? null : _selectNow,
          onLongPress: widget.onMultiviewToggle == null
              ? null
              : () => widget.onMultiviewToggle!(widget.channel),
          onFocus: _scheduleFocusPlay,
          onUnfocus: _cancelFocusPlay,
        ),
        Positioned(
          top: 7,
          left: 7,
          child: _AvailabilityDot(availability: widget.availability),
        ),
        if (widget.onMultiviewToggle != null)
          Positioned(
            top: 4,
            right: 4,
            child: ExcludeFocus(
              child: Material(
                key: ValueKey('channel-multiview-${widget.channel.id}'),
                color: Colors.black.withValues(alpha: 0.68),
                shape: const CircleBorder(),
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: widget.inMultiview
                      ? 'Remove from multiview'
                      : 'Add to multiview',
                  onPressed: () => widget.onMultiviewToggle!(widget.channel),
                  icon: Icon(
                    widget.inMultiview
                        ? Icons.remove_from_queue
                        : Icons.add_to_queue,
                    size: 18,
                    color: widget.inMultiview
                        ? Theme.of(context).colorScheme.primary
                        : Colors.white,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  String? _subtitleFor(String? country, List<String> languages) {
    final category =
        categoryDisplayLabel(widget.channel.group) ?? widget.channel.group;
    final flag = _countryFlagOnly(country);
    final languageSummary = _languageSummary(languages);
    final parts = [category, ?flag, ?languageSummary];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  String? _languageSummary(List<String> languages) {
    final labels = languages
        .map(languageDisplayLabel)
        .where((label) => label != 'Language')
        .toList(growable: false);
    if (labels.isEmpty) return null;
    return labels.join(', ');
  }

  String? _countryFlagOnly(String? country) {
    final label = countryDisplayLabel(country);
    if (label == 'Country') return null;
    final firstSpace = label.indexOf(' ');
    return firstSpace > 0 ? label.substring(0, firstSpace) : label;
  }

  String _initialsFor(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.substring(0, 1).toUpperCase();
  }
}

class _AvailabilityDot extends StatelessWidget {
  const _AvailabilityDot({required this.availability});

  final StreamAvailability? availability;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (color, label) = switch (availability) {
      StreamAvailability.available => (Colors.green, 'Channel reachable'),
      StreamAvailability.unavailable => (
        colorScheme.error,
        'Channel unavailable',
      ),
      StreamAvailability.restricted => (
        Colors.amber,
        'Channel may be restricted',
      ),
      StreamAvailability.cancelled => (Colors.amber, 'Channel check pending'),
      StreamAvailability.unverified ||
      null => (null, 'Channel not checked yet'),
    };
    if (color == null) return const SizedBox.shrink();
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black.withValues(alpha: 0.4)),
          ),
        ),
      ),
    );
  }
}
