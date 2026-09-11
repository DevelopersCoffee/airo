import 'dart:async';

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_streams/platform_streams.dart';

import '../../../application/providers/channel_filters_provider.dart';

const _cardWidth = 155.0;
// _ChannelTile builds MediaCard without a `variant`, so it always renders at
// MediaCardVariant.standard's fixed 104px thumbnail regardless of this grid's
// own card-width constant (a grid cell's width is flexible — the Sliver
// divides available width evenly across columns — but its height is a hard,
// non-scrollable constraint). MediaCard.railHeightFor(MediaCardVariant.standard)
// is 169; shrinking this below that overflows the card's name/subtitle
// column by a few pixels every frame (verified: widget tests below fail with
// a real `RenderFlex overflowed` exception at 155). Left at 169 so only
// _cardWidth (which drives _columnCountFor, and is layout-flexible) does the
// column-gaining work; revisit together with a smaller MediaCardVariant if
// the tile needs to shrink vertically too.
const _cardHeight = 169.0; // MediaCard.railHeightFor(MediaCardVariant.standard)
const _gridSpacing = 14.0;
const _preloadRowsBeforeViewport = 2;
const _preloadRowsAfterViewport = 6;

/// Below this width the multi-column tile grid (built for D-pad/TV browsing)
/// gives way to a single-column horizontal card list — the premium
/// editorial layout touch users expect from an OTT app, and the same
/// breakpoint [AiroTvShell] already uses to switch into phone chrome.
const _phoneBreakpoint = 600.0;
const _horizontalCardHeight = 84.0;
const _horizontalRowSpacing = 10.0;

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
    this.favoriteChannelIds = const {},
    this.onFavoriteToggle,
    this.notForMeChannelIds = const {},
    this.onNotForMeToggle,
    this.onClearFilters,
    this.viewMode = ChannelViewMode.list,
    this.onViewModeChanged,
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
  final Set<String> favoriteChannelIds;
  final ValueChanged<IPTVChannel>? onFavoriteToggle;
  final Set<String> notForMeChannelIds;
  final ValueChanged<IPTVChannel>? onNotForMeToggle;

  /// Phone-width layout choice. Ignored above [_phoneBreakpoint], which
  /// always gets the dynamic tile grid. Null [onViewModeChanged] hides the
  /// toggle entirely (tablet/TV hosts that never reach phone width).
  final ChannelViewMode viewMode;
  final ValueChanged<ChannelViewMode>? onViewModeChanged;

  /// Resets every filter from the "no matches" state. Null hides that
  /// action, leaving the explanation without a shortcut.
  final VoidCallback? onClearFilters;

  @override
  State<ChannelLibraryGrid> createState() => _ChannelLibraryGridState();
}

class _ChannelLibraryGridState extends State<ChannelLibraryGrid> {
  late final ScrollController _scrollController;
  String _lastVisibleSignature = '';
  int _lastColumnCount = 1;
  double _lastRowExtent = _cardHeight;

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
    final rowExtent = _lastRowExtent + _gridSpacing;
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
        final isPhone = constraints.maxWidth < _phoneBreakpoint;
        // Phone width defaults to the single-column editorial list; the user
        // can opt into the same dynamic tile grid tablet/TV always uses.
        // Above the breakpoint there's no cramped single column to choose an
        // alternative to, so the toggle (and this widget's viewMode) has no
        // effect there.
        final usePhoneList = isPhone && widget.viewMode == ChannelViewMode.list;
        final columns = usePhoneList
            ? 1
            : _columnCountFor(constraints.maxWidth);
        final rowExtent = usePhoneList ? _horizontalCardHeight : _cardHeight;
        final rowSpacing = usePhoneList ? _horizontalRowSpacing : _gridSpacing;
        if (columns != _lastColumnCount || rowExtent != _lastRowExtent) {
          _lastColumnCount = columns;
          _lastRowExtent = rowExtent;
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
              child: _LibrarySortRow(
                sort: widget.sort,
                onSort: widget.onSort,
                viewMode: widget.viewMode,
                onViewModeChanged: isPhone ? widget.onViewModeChanged : null,
              ),
            ),
            // The shell only builds this grid once the unfiltered library is
            // non-empty (an empty library gets the onboarding view instead),
            // so zero channels here always means the filters excluded them
            // all. Without this the panel just rendered blank below the sort
            // row, which the first-run country prompt makes easy to hit: it
            // sets a country filter that a playlist may have nothing for.
            if (widget.channels.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _NoMatchesView(onClearFilters: widget.onClearFilters),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(12, 4, 12, rowSpacing),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisExtent: rowExtent,
                    crossAxisSpacing: _gridSpacing,
                    mainAxisSpacing: rowSpacing,
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
                          isFavorite: widget.favoriteChannelIds.contains(
                            channel.id,
                          ),
                          onFavoriteToggle: widget.onFavoriteToggle,
                          isNotForMe: widget.notForMeChannelIds.contains(
                            channel.id,
                          ),
                          onNotForMeToggle: widget.onNotForMeToggle,
                          horizontal: usePhoneList,
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

/// Shown when the active filters exclude every channel. On TV the filter
/// chips are a D-pad journey away, so this offers a focusable way back to
/// the full library rather than only naming the problem.
class _NoMatchesView extends StatelessWidget {
  const _NoMatchesView({required this.onClearFilters});

  final VoidCallback? onClearFilters;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.filter_alt_off, size: 48, color: colors.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(
            'No channels match your filters',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'This playlist has channels, but none of them match every filter '
            'you have applied.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
          if (onClearFilters != null) ...[
            const SizedBox(height: 20),
            TvFocusable(
              autofocus: true,
              onSelect: onClearFilters!,
              semanticLabel: 'Clear all filters',
              semanticButton: true,
              borderRadius: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Clear filters',
                  style: TextStyle(
                    color: colors.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

const Map<ChannelSortColumn, String> _sortColumnLabels = {
  ChannelSortColumn.name: 'Name',
  ChannelSortColumn.category: 'Category',
  ChannelSortColumn.language: 'Language',
  ChannelSortColumn.country: 'Country',
  ChannelSortColumn.type: 'Type',
};

/// One compact trigger instead of four always-visible chips — same four
/// sort columns, tucked behind a single control that opens on demand
/// (#compact-tv-chrome) rather than permanently occupying a full row.
class _LibrarySortRow extends StatelessWidget {
  const _LibrarySortRow({
    required this.sort,
    this.onSort,
    this.viewMode = ChannelViewMode.list,
    this.onViewModeChanged,
  });

  final ChannelSort sort;
  final ValueChanged<ChannelSortColumn>? onSort;
  final ChannelViewMode viewMode;
  final ValueChanged<ChannelViewMode>? onViewModeChanged;

  @override
  Widget build(BuildContext context) {
    final label = _sortColumnLabels[sort.column] ?? 'Name';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: TvFocusable(
                key: const ValueKey('channel-sort-trigger'),
                semanticLabel:
                    'Sort by $label, ${sort.ascending ? 'ascending' : 'descending'}',
                onSelect: onSort == null ? null : () => _showSortSheet(context),
                borderRadius: 8,
                child: Material(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: onSort == null
                        ? null
                        : () => _showSortSheet(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            sort.ascending
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text('Sort: $label'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (onViewModeChanged != null) ...[
            const SizedBox(width: 8),
            _ViewModeToggle(mode: viewMode, onChanged: onViewModeChanged!),
          ],
        ],
      ),
    );
  }

  void _showSortSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final column in ChannelSortColumn.values)
              ListTile(
                key: ValueKey('channel-sort-${column.name}'),
                leading: sort.column == column
                    ? Icon(
                        sort.ascending
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                      )
                    : const SizedBox(width: 24),
                title: Text(_sortColumnLabels[column] ?? column.name),
                selected: sort.column == column,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onSort?.call(column);
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// Phone-only list/grid switch, styled to match [_LibrarySortRow]'s chip.
class _ViewModeToggle extends StatelessWidget {
  const _ViewModeToggle({required this.mode, required this.onChanged});

  final ChannelViewMode mode;
  final ValueChanged<ChannelViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final isGrid = mode == ChannelViewMode.grid;
    return TvFocusable(
      key: const ValueKey('channel-view-mode-toggle'),
      semanticLabel: isGrid ? 'Switch to list view' : 'Switch to grid view',
      onSelect: () =>
          onChanged(isGrid ? ChannelViewMode.list : ChannelViewMode.grid),
      borderRadius: 8,
      child: Material(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () =>
              onChanged(isGrid ? ChannelViewMode.list : ChannelViewMode.grid),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(isGrid ? Icons.view_list : Icons.grid_view, size: 20),
          ),
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
    required this.isFavorite,
    this.onFavoriteToggle,
    required this.isNotForMe,
    this.onNotForMeToggle,
    this.horizontal = false,
  });

  final IPTVChannel channel;
  final ChannelBrowseMetadata? metadata;
  final StreamAvailability? availability;
  final ValueChanged<IPTVChannel>? onSelected;
  final Duration? focusPlayDelay;
  final bool inMultiview;
  final ValueChanged<IPTVChannel>? onMultiviewToggle;
  final bool isFavorite;
  final ValueChanged<IPTVChannel>? onFavoriteToggle;
  final bool isNotForMe;
  final ValueChanged<IPTVChannel>? onNotForMeToggle;

  /// Renders the premium horizontal media card (logo left, name/metadata
  /// right, LIVE trailing) used below the phone breakpoint, instead of the
  /// vertical poster tile the D-pad/TV grid uses.
  final bool horizontal;

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

  bool get _hasActions =>
      widget.onSelected != null ||
      widget.onMultiviewToggle != null ||
      widget.onFavoriteToggle != null ||
      widget.onNotForMeToggle != null;

  Future<void> _showActionsMenu(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => _ChannelActionsSheet(
        channel: widget.channel,
        onPlay: widget.onSelected == null ? null : _selectNow,
        inMultiview: widget.inMultiview,
        onMultiviewToggle: widget.onMultiviewToggle == null
            ? null
            : () => widget.onMultiviewToggle!(widget.channel),
        isFavorite: widget.isFavorite,
        onFavoriteToggle: widget.onFavoriteToggle == null
            ? null
            : () => widget.onFavoriteToggle!(widget.channel),
        isNotForMe: widget.isNotForMe,
        onNotForMeToggle: widget.onNotForMeToggle == null
            ? null
            : () => widget.onNotForMeToggle!(widget.channel),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final country = effectiveChannelCountry(widget.channel, widget.metadata);
    final languages = effectiveChannelLanguages(
      widget.channel,
      widget.metadata,
    );
    final subtitle = _subtitleFor(country, languages);

    final card = widget.horizontal
        ? _HorizontalMediaCard(
            name: widget.channel.name,
            subtitle: subtitle,
            logoUrl: widget.channel.effectiveLogoUrl,
            initials: _initialsFor(widget.channel.name),
            isLive: !widget.channel.isAudioOnly,
            onTap: widget.onSelected == null ? null : _selectNow,
            onLongPress: _hasActions ? () => _showActionsMenu(context) : null,
            onFocus: _scheduleFocusPlay,
            onUnfocus: _cancelFocusPlay,
          )
        : MediaCard(
            name: widget.channel.name,
            subtitle: subtitle,
            logoUrl: widget.channel.effectiveLogoUrl,
            initials: _initialsFor(widget.channel.name),
            onTap: widget.onSelected == null ? null : _selectNow,
            onLongPress: _hasActions ? () => _showActionsMenu(context) : null,
            onFocus: _scheduleFocusPlay,
            onUnfocus: _cancelFocusPlay,
          );

    return Stack(
      children: [
        card,
        Positioned(
          top: 7,
          left: 7,
          child: _AvailabilityDot(availability: widget.availability),
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

/// Full-width editorial card for the phone channel list: a square logo,
/// name + metadata, and a trailing LIVE badge — replacing the vertical
/// poster tile below the phone breakpoint (design feedback: the grid tile
/// read as "a lot of unused dark space" around a small centered logo).
class _HorizontalMediaCard extends StatelessWidget {
  const _HorizontalMediaCard({
    required this.name,
    required this.initials,
    this.subtitle,
    this.logoUrl,
    this.isLive = false,
    this.onTap,
    this.onLongPress,
    this.onFocus,
    this.onUnfocus,
  });

  final String name;
  final String initials;
  final String? subtitle;
  final String? logoUrl;
  final bool isLive;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onFocus;
  final VoidCallback? onUnfocus;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return TvFocusable(
      onSelect: onTap,
      onSecondaryAction: onLongPress,
      onFocus: onFocus,
      onUnfocus: onUnfocus,
      borderRadius: 16,
      semanticLabel: isLive ? '$name, live' : name,
      semanticHint: 'Press OK to play channel',
      semanticButton: true,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: Container(
                    color: colorScheme.surfaceContainerHighest,
                    child: logoUrl != null && logoUrl!.isNotEmpty
                        ? Image.network(
                            logoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                _initialsBox(colorScheme),
                          )
                        : _initialsBox(colorScheme),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isLive) ...[
                const SizedBox(width: 8),
                const AiroBadge.live(
                  pulse: false,
                  borderRadius: AiroSpacing.radiusSm,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _initialsBox(ColorScheme colorScheme) {
    return Center(
      child: Text(
        initials,
        style: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w800,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Long-press menu for a channel tile — the touch equivalent of the grid's
/// always-visible per-tile split-view toggle, plus favoriting, in one
/// discoverable place instead of separate small icon targets.
class _ChannelActionsSheet extends StatelessWidget {
  const _ChannelActionsSheet({
    required this.channel,
    required this.onPlay,
    required this.inMultiview,
    required this.onMultiviewToggle,
    required this.isFavorite,
    required this.onFavoriteToggle,
    required this.isNotForMe,
    required this.onNotForMeToggle,
  });

  final IPTVChannel channel;
  final VoidCallback? onPlay;
  final bool inMultiview;
  final VoidCallback? onMultiviewToggle;
  final bool isFavorite;
  final VoidCallback? onFavoriteToggle;
  final bool isNotForMe;
  final VoidCallback? onNotForMeToggle;

  @override
  Widget build(BuildContext context) {
    void act(VoidCallback? action) {
      // Call the action before popping: onMultiviewToggle's closure chain
      // reaches back into AiroTvShellState's own `ref` (via _toggleMultiview),
      // and popping first can leave that ref "unmounted" by the time the
      // callback's first ref.read() runs, throwing
      // "Using 'ref' when a widget is about to or has been unmounted" even
      // though AiroTvShell itself is still on screen.
      action?.call();
      Navigator.of(context).pop();
    }

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    channel.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
          ),
          if (onPlay != null)
            ListTile(
              key: const ValueKey('channel-actions-play'),
              leading: const Icon(Icons.play_arrow),
              title: const Text('Play'),
              onTap: () => act(onPlay),
            ),
          if (onMultiviewToggle != null)
            ListTile(
              key: const ValueKey('channel-actions-multiview'),
              leading: Icon(
                inMultiview ? Icons.remove_from_queue : Icons.add_to_queue,
              ),
              title: Text(
                inMultiview ? 'Remove from split view' : 'Add to split view',
              ),
              onTap: () => act(onMultiviewToggle),
            ),
          if (onFavoriteToggle != null)
            ListTile(
              key: const ValueKey('channel-actions-favorite'),
              leading: Icon(
                isFavorite ? Icons.favorite : Icons.favorite_border,
              ),
              title: Text(
                isFavorite ? 'Remove from favorites' : 'Add to favorites',
              ),
              onTap: () => act(onFavoriteToggle),
            ),
          if (onNotForMeToggle != null)
            ListTile(
              key: const ValueKey('channel-actions-not-for-me'),
              leading: Icon(
                isNotForMe
                    ? Icons.visibility_off
                    : Icons.visibility_off_outlined,
              ),
              title: Text(isNotForMe ? 'Remove "not for me"' : 'Not for me'),
              onTap: () => act(onNotForMeToggle),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
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
