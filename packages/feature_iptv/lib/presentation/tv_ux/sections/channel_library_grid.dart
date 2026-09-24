import 'dart:async';

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_streams/platform_streams.dart';

import '../../../application/providers/browse_grid_tv_peek_provider.dart';
import '../../../application/providers/channel_filters_provider.dart';
import '../../../application/providers/guide_providers.dart';
import '../../../application/providers/iptv_cast_providers.dart';
import '../../../application/providers/tv_font_mode_provider.dart';
import '../../widgets/tv_mini_guide_overlay.dart';
import '../browse_grid_tv_peek_controller.dart';

const _cardWidth = 155.0;
// _ChannelTile builds MediaCard without a `variant`, so it always renders at
// MediaCardVariant.standard's fixed 104px thumbnail regardless of this grid's
// own card-width constant (a grid cell's width is flexible — the Sliver
// divides available width evenly across columns — but its height is a hard,
// non-scrollable constraint). MediaCard.railHeightFor(MediaCardVariant.standard)
// is 169 at text scale 1. TV `rowExtent` grows the 65px name/subtitle block
// with `tvFontModeProvider` so Extra large does not overflow the sliver cell.
// Phone 5-up already drops subtitle via `compactGridShowSubtitle`.
const _cardHeight = 169.0; // MediaCard.railHeightFor(MediaCardVariant.standard)
const _mediaCardThumbHeight = 104.0;
const _mediaCardTextBlockHeight = _cardHeight - _mediaCardThumbHeight;

double _tvRowExtent(double textScale) {
  return _mediaCardThumbHeight + _mediaCardTextBlockHeight * textScale;
}

const _gridSpacing = 14.0;
const _phoneGridSpacing = 8.0;
const _phoneGridPadding = 8.0;

double _phoneGridRowExtent(int columns) {
  return switch (columns.clamp(2, 5)) {
    2 => 168.0,
    3 => 128.0,
    4 => 108.0,
    _ => 92.0,
  };
}

const _preloadRowsBeforeViewport = 2;
const _preloadRowsAfterViewport = 6;

/// Below this width the multi-column tile grid (built for D-pad/TV browsing)
/// gives way to a single-column horizontal card list — the premium
/// editorial layout touch users expect from an OTT app, and the same
/// breakpoint [AiroTvShell] already uses to switch into phone chrome.
const _phoneBreakpoint = 600.0;
const _horizontalCardHeight = 88.0;
const _horizontalRowSpacing = 10.0;

/// Best-effort quality badge for browse rows: playlist `qualityUrls` first,
/// then tokens in the channel name (HD / 1080p / 4K / SD).
String? channelBrowseQualityLabel(IPTVChannel channel) {
  final urls = channel.qualityUrls;
  if (urls != null && urls.isNotEmpty) {
    const rank = [
      '4K',
      '2160P',
      '2160',
      '1080P',
      '1080',
      '720P',
      '720',
      'HD',
      '480P',
      '360P',
      'SD',
    ];
    var bestIndex = rank.length;
    String? best;
    for (final key in urls.keys) {
      final upper = key.toUpperCase();
      for (var i = 0; i < rank.length; i++) {
        if (!upper.contains(rank[i]) || i >= bestIndex) continue;
        bestIndex = i;
        best = switch (rank[i]) {
          '2160P' || '2160' => '4K',
          '1080' => '1080p',
          '720' => '720p',
          '1080P' => '1080p',
          '720P' => '720p',
          _ =>
            rank[i] == 'HD'
                ? 'HD'
                : rank[i] == '4K'
                ? '4K'
                : rank[i] == 'SD'
                ? 'SD'
                : key,
        };
      }
    }
    return best ?? urls.keys.first;
  }
  final upper = channel.name.toUpperCase();
  if (upper.contains('4K') || upper.contains('UHD')) return '4K';
  if (upper.contains('1080') || upper.contains('FHD')) return '1080p';
  if (RegExp(r'(^|[\s\-])HD([\s\-]|$)').hasMatch(upper)) return 'HD';
  if (upper.contains('720')) return '720p';
  if (RegExp(r'(^|[\s\-])SD([\s\-]|$)').hasMatch(upper)) return 'SD';
  return null;
}

Widget _channelArtwork({
  required String? logoUrl,
  required Widget fallback,
  double? width,
  double? height,
}) {
  if (logoUrl == null || logoUrl.isEmpty) return fallback;
  return AiroNetworkImage(
    url: logoUrl,
    width: width,
    height: height,
    fit: BoxFit.cover,
    errorBuilder: (_, _, _) => fallback,
  );
}

/// Card-grid channel browser — replaces the spreadsheet-style
/// [ChannelTable]. Matches the "LIBRARY" screen of the AiroTV D-pad design
/// (Claude Design project 02b0b312): tiles instead of rows, sort collapsed
/// to a compact chip row instead of clickable column headers.
class ChannelLibraryGrid extends ConsumerStatefulWidget {
  static const browseAdSlotKey = ValueKey<String>('browse-ad-slot');

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
    this.browseAdCard,
    this.showSortRow = true,
    this.phoneGridColumns = 3,
    this.floatingNavScrollClearance = 0,
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

  /// Optional in-app native ad tile. Inserted at index 4 (or at the end
  /// when the library is shorter). Null keeps the grid channel-only.
  final Widget? browseAdCard;

  /// Phone compact chrome moves sort + list/grid onto [FilterRow]. False
  /// hides this grid's own sort row so those controls are not duplicated.
  final bool showSortRow;

  /// Phone-width tile grid column count (2–5). Ignored in list mode and
  /// above [_phoneBreakpoint].
  final int phoneGridColumns;

  /// Extra trailing scroll space so the last row can sit above an overlay
  /// nav. Zero when the host has no floating bar.
  final double floatingNavScrollClearance;

  @override
  ConsumerState<ChannelLibraryGrid> createState() => _ChannelLibraryGridState();
}

class _ChannelLibraryGridState extends ConsumerState<ChannelLibraryGrid> {
  late final ScrollController _scrollController;
  late final BrowseGridTvPeekController _peekController;
  String _lastVisibleSignature = '';
  String _lastChannelSignature = '';
  int _lastColumnCount = 1;
  double _lastRowExtent = _cardHeight;
  double _lastRowSpacing = _gridSpacing;
  bool _visibleReportQueued = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_reportVisibleChannels);
    _peekController = BrowseGridTvPeekController(
      previewFactory: () => ref.read(tvMiniGuidePreviewFactoryProvider)(),
    );
    _lastChannelSignature = _channelSignature;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _reportVisibleChannels(),
    );
  }

  @override
  void didUpdateWidget(covariant ChannelLibraryGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    final signature = _channelSignature;
    if (signature != _lastChannelSignature) {
      _lastChannelSignature = signature;
      _peekController.onLibrarySignatureChanged();
    }
    if (!identical(oldWidget.channels, widget.channels)) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _reportVisibleChannels(force: true),
      );
    }
  }

  @override
  void dispose() {
    _peekController.dispose();
    _scrollController
      ..removeListener(_reportVisibleChannels)
      ..dispose();
    super.dispose();
  }

  String get _channelSignature =>
      widget.channels.map((channel) => channel.id).join('|');

  void _handleTilePeekFocus(IPTVChannel channel, LayerLink anchorLink) {
    if (channel.isAudioOnly || channel.streamUrl.isEmpty) return;
    _peekController.onTileFocused(channel, anchorLink);
    if (mounted) setState(() {});
  }

  void _handleTilePeekUnfocus() {
    _peekController.onTileUnfocused();
    if (mounted) setState(() {});
  }

  Future<void> _selectChannelWithPeekRelease(IPTVChannel channel) async {
    await _peekController.releaseBeforePlay();
    widget.onChannelSelected?.call(channel);
  }

  static const _browseAdIndex = 4;

  int get _adIndex {
    if (widget.browseAdCard == null || widget.channels.isEmpty) {
      return -1;
    }
    return widget.channels.length < _browseAdIndex
        ? widget.channels.length
        : _browseAdIndex;
  }

  SliverGrid _channelsSliver({
    required List<IPTVChannel> channels,
    required int columns,
    required double rowExtent,
    required double rowSpacing,
    required bool usePhoneList,
    required bool usePhoneGrid,
    required bool tvPeekEnabled,
  }) {
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisExtent: rowExtent,
        crossAxisSpacing: rowSpacing,
        mainAxisSpacing: rowSpacing,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final channel = channels[index];
          return RepaintBoundary(
            key: ValueKey('channel-tile-${channel.id}'),
            child: _ChannelTile(
              channel: channel,
              metadata: widget.metadataByChannelId[channel.id],
              availability: widget.availabilityByChannelId[channel.id],
              onSelected: tvPeekEnabled ? null : widget.onChannelSelected,
              onSelectWithPeekRelease: tvPeekEnabled
                  ? _selectChannelWithPeekRelease
                  : null,
              focusPlayDelay: tvPeekEnabled ? null : widget.focusPlayDelay,
              onPeekFocus: tvPeekEnabled ? _handleTilePeekFocus : null,
              onPeekUnfocus: tvPeekEnabled ? _handleTilePeekUnfocus : null,
              inMultiview: widget.multiviewChannelIds.contains(channel.id),
              onMultiviewToggle: widget.onMultiviewToggle,
              isFavorite: widget.favoriteChannelIds.contains(channel.id),
              onFavoriteToggle: widget.onFavoriteToggle,
              isNotForMe: widget.notForMeChannelIds.contains(channel.id),
              onNotForMeToggle: widget.onNotForMeToggle,
              horizontal: usePhoneList,
              compactGrid: usePhoneGrid,
              compactGridShowSubtitle: columns < 5,
            ),
          );
        },
        childCount: channels.length,
        addAutomaticKeepAlives: false,
        findChildIndexCallback: (key) {
          if (key is! ValueKey<String>) return null;
          final value = key.value;
          if (!value.startsWith('channel-tile-')) return null;
          final channelId = value.substring('channel-tile-'.length);
          final channelIndex = channels.indexWhere(
            (channel) => channel.id == channelId,
          );
          return channelIndex < 0 ? null : channelIndex;
        },
      ),
    );
  }

  int _columnCountFor(double width) {
    final perColumn = _cardWidth + _gridSpacing;
    return ((width + _gridSpacing) / perColumn).floor().clamp(1, 100);
  }

  void _reportVisibleChannels({bool force = false}) {
    if (force) {
      _visibleReportQueued = false;
      _flushVisibleChannels(force: true);
      return;
    }
    if (_visibleReportQueued) return;
    _visibleReportQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _visibleReportQueued = false;
      if (!mounted) return;
      _flushVisibleChannels();
    });
  }

  void _flushVisibleChannels({bool force = false}) {
    final callback = widget.onVisibleChannelsChanged;
    if (callback == null || !mounted || widget.channels.isEmpty) return;
    if (!_scrollController.hasClients) return;
    final columns = _lastColumnCount;
    final viewportHeight = _scrollController.position.viewportDimension;
    final offset = _scrollController.offset;
    final rowExtent = _lastRowExtent + _lastRowSpacing;
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
    final fontMode = ref.watch(tvFontModeProvider);
    final mediaQuery = MediaQuery.of(context);
    final baseScale = mediaQuery.textScaler.scale(1.0);
    return MediaQuery(
      data: mediaQuery.copyWith(
        textScaler: TextScaler.linear(baseScale * fontMode.scale),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isPhone = constraints.maxWidth < _phoneBreakpoint;
          // Phone width defaults to the single-column editorial list; the user
          // can opt into the same dynamic tile grid tablet/TV always uses.
          // Above the breakpoint there's no cramped single column to choose an
          // alternative to, so the toggle (and this widget's viewMode) has no
          // effect there.
          final usePhoneList =
              isPhone && widget.viewMode == ChannelViewMode.list;
          final usePhoneGrid = isPhone && !usePhoneList;
          final columns = usePhoneList
              ? 1
              : usePhoneGrid
              ? widget.phoneGridColumns.clamp(2, 5)
              : _columnCountFor(constraints.maxWidth);
          final rowExtent = usePhoneList
              ? _horizontalCardHeight
              : usePhoneGrid
              ? _phoneGridRowExtent(columns)
              : _tvRowExtent(fontMode.scale);
          final rowSpacing = usePhoneList
              ? _horizontalRowSpacing
              : usePhoneGrid
              ? _phoneGridSpacing
              : _gridSpacing;
          final gridHPad = usePhoneGrid ? _phoneGridPadding : 12.0;
          if (columns != _lastColumnCount ||
              rowExtent != _lastRowExtent ||
              rowSpacing != _lastRowSpacing) {
            _lastColumnCount = columns;
            _lastRowExtent = rowExtent;
            _lastRowSpacing = rowSpacing;
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _reportVisibleChannels(force: true),
            );
          }
          final peekFlag = ref.watch(browseGridTvPeekEnabledProvider);
          final isCasting = ref.watch(
            iptvCastProvider.select((state) => state.isCasting),
          );
          final tvPeekEnabled =
              peekFlag &&
              browseGridTvPeekAllowedOnPlatform(isPhoneWidth: isPhone) &&
              !isCasting &&
              !usePhoneList &&
              !usePhoneGrid;
          final scrollView = CustomScrollView(
            controller: _scrollController,
            key: const PageStorageKey<String>('airo-tv-channel-library-scroll'),
            physics: const AlwaysScrollableScrollPhysics(),
            scrollCacheExtent: const ScrollCacheExtent.pixels(640),
            slivers: [
              if (widget.showSortRow)
                SliverToBoxAdapter(
                  child: _LibrarySortRow(
                    sort: widget.sort,
                    onSort: widget.onSort,
                    viewMode: widget.viewMode,
                    onViewModeChanged: isPhone
                        ? widget.onViewModeChanged
                        : null,
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
              else ...[
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    gridHPad,
                    4,
                    gridHPad,
                    rowSpacing,
                  ),
                  sliver: _channelsSliver(
                    channels: _adIndex < 0
                        ? widget.channels
                        : widget.channels.sublist(0, _adIndex),
                    columns: columns,
                    rowExtent: rowExtent,
                    rowSpacing: rowSpacing,
                    usePhoneList: usePhoneList,
                    usePhoneGrid: usePhoneGrid,
                    tvPeekEnabled: tvPeekEnabled,
                  ),
                ),
                if (_adIndex >= 0)
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      gridHPad,
                      0,
                      gridHPad,
                      rowSpacing,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: RepaintBoundary(
                        child: KeyedSubtree(
                          key: ChannelLibraryGrid.browseAdSlotKey,
                          child: widget.browseAdCard!,
                        ),
                      ),
                    ),
                  ),
                if (_adIndex >= 0 && _adIndex < widget.channels.length)
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      gridHPad,
                      0,
                      gridHPad,
                      rowSpacing,
                    ),
                    sliver: _channelsSliver(
                      channels: widget.channels.sublist(_adIndex),
                      columns: columns,
                      rowExtent: rowExtent,
                      rowSpacing: rowSpacing,
                      usePhoneList: usePhoneList,
                      usePhoneGrid: usePhoneGrid,
                      tvPeekEnabled: tvPeekEnabled,
                    ),
                  ),
                if (widget.floatingNavScrollClearance > 0)
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height:
                          widget.floatingNavScrollClearance +
                          MediaQuery.paddingOf(context).bottom,
                    ),
                  ),
              ],
            ],
          );
          if (!tvPeekEnabled || _peekController.anchorLink == null) {
            return scrollView;
          }
          return Stack(
            clipBehavior: Clip.none,
            children: [
              scrollView,
              Positioned.fill(
                child: IgnorePointer(
                  child: CompositedTransformFollower(
                    link: _peekController.anchorLink!,
                    showWhenUnlinked: false,
                    targetAnchor: Alignment.topCenter,
                    followerAnchor: Alignment.topCenter,
                    child: SizedBox(
                      height: 104,
                      width: _cardWidth,
                      child: _peekController.previewView != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: _peekController.previewView,
                            )
                          : _peekController.isStartingPreview
                          ? const Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: ChannelLibrarySortChip(sort: sort, onSort: onSort),
            ),
          ),
          if (onViewModeChanged != null) ...[
            const SizedBox(width: 8),
            ChannelViewModeToggle(
              mode: viewMode,
              onChanged: onViewModeChanged!,
            ),
          ],
        ],
      ),
    );
  }
}

/// Sort chip shared by the library grid and the compact [FilterRow].
class ChannelLibrarySortChip extends StatelessWidget {
  const ChannelLibrarySortChip({
    super.key,
    required this.sort,
    this.onSort,
    this.height,
  });

  final ChannelSort sort;
  final ValueChanged<ChannelSortColumn>? onSort;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final label = _sortColumnLabels[sort.column] ?? 'Name';
    return TvFocusable(
      key: const ValueKey('channel-sort-trigger'),
      semanticLabel:
          'Sort by $label, ${sort.ascending ? 'ascending' : 'descending'}',
      onSelect: onSort == null ? null : () => _showChannelSortSheet(context),
      borderRadius: 8,
      child: Material(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onSort == null ? null : () => _showChannelSortSheet(context),
          child: SizedBox(
            height: height,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: height == null ? 8 : 0,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
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
    );
  }

  void _showChannelSortSheet(BuildContext context) {
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

/// Phone-only list/grid switch, styled to match [ChannelLibrarySortChip].
class ChannelViewModeToggle extends StatelessWidget {
  const ChannelViewModeToggle({
    super.key,
    required this.mode,
    required this.onChanged,
  });

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

class ChannelGridDensityButton extends StatelessWidget {
  const ChannelGridDensityButton({
    super.key,
    required this.density,
    required this.onChanged,
  });

  final ChannelGridDensity density;
  final ValueChanged<ChannelGridDensity> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ChannelGridDensity>(
      key: const ValueKey('channel-grid-density'),
      tooltip: 'Grid size',
      initialValue: density,
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final option in ChannelGridDensity.values)
          PopupMenuItem(value: option, child: Text(option.settingsLabel)),
      ],
      child: Material(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.grid_on, size: 18),
              const SizedBox(width: 6),
              Text('${density.columns}×'),
            ],
          ),
        ),
      ),
    );
  }
}

/// Settings radios for [channelGridDensityProvider]. Phone grid only.
class ChannelGridDensitySection extends ConsumerWidget {
  const ChannelGridDensitySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final density = ref.watch(channelGridDensityProvider);
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Channel grid',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Text(
          'How many channel tiles fit on one row in grid view.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        RadioGroup<ChannelGridDensity>(
          groupValue: density,
          onChanged: (value) {
            if (value != null) {
              ref.read(channelGridDensityProvider.notifier).setDensity(value);
            }
          },
          child: Column(
            children: [
              for (final option in ChannelGridDensity.values)
                RadioListTile<ChannelGridDensity>(
                  key: ValueKey('channel-grid-density-${option.name}'),
                  value: option,
                  title: Text(option.settingsLabel),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChannelTile extends StatefulWidget {
  const _ChannelTile({
    required this.channel,
    required this.metadata,
    required this.availability,
    this.onSelected,
    this.onSelectWithPeekRelease,
    this.focusPlayDelay,
    this.onPeekFocus,
    this.onPeekUnfocus,
    required this.inMultiview,
    this.onMultiviewToggle,
    required this.isFavorite,
    this.onFavoriteToggle,
    required this.isNotForMe,
    this.onNotForMeToggle,
    this.horizontal = false,
    this.compactGrid = false,
    this.compactGridShowSubtitle = true,
  });

  final IPTVChannel channel;
  final ChannelBrowseMetadata? metadata;
  final StreamAvailability? availability;
  final ValueChanged<IPTVChannel>? onSelected;
  final Future<void> Function(IPTVChannel channel)? onSelectWithPeekRelease;
  final Duration? focusPlayDelay;
  final void Function(IPTVChannel channel, LayerLink anchorLink)? onPeekFocus;
  final VoidCallback? onPeekUnfocus;
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

  /// Phone-width tile grid: fill the cell so 3-up does not leave empty
  /// gutters around a fixed 172px rail card.
  final bool compactGrid;

  /// Dense 5-up tiles drop the subtitle so the name still fits.
  final bool compactGridShowSubtitle;

  @override
  State<_ChannelTile> createState() => _ChannelTileState();
}

class _ChannelTileState extends State<_ChannelTile> {
  Timer? _focusPlayTimer;
  final LayerLink _peekAnchorLink = LayerLink();

  @override
  void didUpdateWidget(covariant _ChannelTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.channel.id != widget.channel.id ||
        oldWidget.focusPlayDelay != widget.focusPlayDelay ||
        oldWidget.onSelected != widget.onSelected ||
        oldWidget.onSelectWithPeekRelease != widget.onSelectWithPeekRelease) {
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

  void _handleFocus() {
    _scheduleFocusPlay();
    widget.onPeekFocus?.call(widget.channel, _peekAnchorLink);
  }

  void _handleUnfocus() {
    _cancelFocusPlay();
    widget.onPeekUnfocus?.call();
  }

  void _selectNow() {
    _cancelFocusPlay();
    if (widget.onSelectWithPeekRelease != null) {
      unawaited(widget.onSelectWithPeekRelease!(widget.channel));
      return;
    }
    widget.onSelected?.call(widget.channel);
  }

  bool get _hasActions =>
      widget.onSelected != null ||
      widget.onSelectWithPeekRelease != null ||
      widget.onMultiviewToggle != null ||
      widget.onFavoriteToggle != null ||
      widget.onNotForMeToggle != null;

  Future<void> _showActionsMenu(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => _ChannelActionsSheet(
        channel: widget.channel,
        onPlay:
            widget.onSelected == null && widget.onSelectWithPeekRelease == null
            ? null
            : _selectNow,
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
    return Consumer(
      builder: (context, ref, _) {
        final nowTitle = ref.watch(
          browseNowPlayingByChannelIdProvider.select(
            (map) => map[widget.channel.id],
          ),
        );
        final country = effectiveChannelCountry(
          widget.channel,
          widget.metadata,
        );
        final languages = effectiveChannelLanguages(
          widget.channel,
          widget.metadata,
        );
        final fallback = _subtitleFor(country, languages);
        final subtitle = nowTitle ?? fallback;
        final semanticLabel = nowTitle == null
            ? widget.channel.name
            : '${widget.channel.name}, $nowTitle';

        final Widget card;
        if (widget.horizontal) {
          card = _HorizontalMediaCard(
            name: widget.channel.name,
            subtitle: subtitle,
            semanticLabel: widget.channel.isAudioOnly
                ? semanticLabel
                : nowTitle == null
                ? '$semanticLabel, live'
                : semanticLabel,
            logoUrl: widget.channel.effectiveLogoUrl,
            initials: _initialsFor(widget.channel.name),
            isLive: !widget.channel.isAudioOnly,
            isAudio: widget.channel.isAudioOnly,
            isFavorite: widget.isFavorite,
            qualityLabel: channelBrowseQualityLabel(widget.channel),
            onFavoriteToggle: widget.onFavoriteToggle == null
                ? null
                : () => widget.onFavoriteToggle!(widget.channel),
            favoriteKey: ValueKey('channel-favorite-${widget.channel.id}'),
            onTap:
                widget.onSelected == null &&
                    widget.onSelectWithPeekRelease == null
                ? null
                : _selectNow,
            onLongPress: _hasActions ? () => _showActionsMenu(context) : null,
            onFocus: _handleFocus,
            onUnfocus: _handleUnfocus,
          );
        } else if (widget.compactGrid) {
          card = _CompactGridMediaCard(
            name: widget.channel.name,
            subtitle: widget.compactGridShowSubtitle ? subtitle : null,
            semanticLabel: semanticLabel,
            logoUrl: widget.channel.effectiveLogoUrl,
            initials: _initialsFor(widget.channel.name),
            onTap:
                widget.onSelected == null &&
                    widget.onSelectWithPeekRelease == null
                ? null
                : _selectNow,
            onLongPress: _hasActions ? () => _showActionsMenu(context) : null,
            onFocus: _handleFocus,
            onUnfocus: _handleUnfocus,
          );
        } else {
          final mediaCard = MediaCard(
            name: widget.channel.name,
            subtitle: subtitle,
            logoUrl: widget.channel.effectiveLogoUrl,
            initials: _initialsFor(widget.channel.name),
            onTap:
                widget.onSelected == null &&
                    widget.onSelectWithPeekRelease == null
                ? null
                : _selectNow,
            onLongPress: _hasActions ? () => _showActionsMenu(context) : null,
            onFocus: _handleFocus,
            onUnfocus: _handleUnfocus,
          );
          card = nowTitle == null
              ? mediaCard
              : Semantics(label: semanticLabel, child: mediaCard);
        }

        final cardWithPeekAnchor = widget.onPeekFocus == null
            ? card
            : CompositedTransformTarget(link: _peekAnchorLink, child: card);

        return Stack(
          children: [
            cardWithPeekAnchor,
            Positioned(
              top: 7,
              left: 7,
              child: _AvailabilityDot(availability: widget.availability),
            ),
          ],
        );
      },
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

/// Fills the grid cell (no fixed 172px rail width) so a 3-column phone
/// layout does not leave empty gutters around a small logo.
class _CompactGridMediaCard extends StatelessWidget {
  const _CompactGridMediaCard({
    required this.name,
    required this.initials,
    this.subtitle,
    this.semanticLabel,
    this.logoUrl,
    this.onTap,
    this.onLongPress,
    this.onFocus,
    this.onUnfocus,
  });

  final String name;
  final String initials;
  final String? subtitle;
  final String? semanticLabel;
  final String? logoUrl;
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
      borderRadius: 10,
      semanticLabel: semanticLabel ?? name,
      semanticHint: 'Press OK to play channel',
      semanticButton: true,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ColoredBox(
                  color: colorScheme.surfaceContainerHighest,
                  child: _channelArtwork(
                    logoUrl: logoUrl,
                    fallback: _initialsFill(colorScheme),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 5, 6, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          height: 1.2,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _initialsFill(ColorScheme colorScheme) {
    return Center(
      child: Text(
        initials,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
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
    this.semanticLabel,
    this.logoUrl,
    this.isLive = false,
    this.isAudio = false,
    this.isFavorite = false,
    this.qualityLabel,
    this.onFavoriteToggle,
    this.favoriteKey,
    this.onTap,
    this.onLongPress,
    this.onFocus,
    this.onUnfocus,
  });

  final String name;
  final String initials;
  final String? subtitle;
  final String? semanticLabel;
  final String? logoUrl;
  final bool isLive;
  final bool isAudio;
  final bool isFavorite;
  final String? qualityLabel;
  final VoidCallback? onFavoriteToggle;
  final Key? favoriteKey;
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
      semanticLabel: semanticLabel ?? (isLive ? '$name, live' : name),
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
                    child: _channelArtwork(
                      logoUrl: logoUrl,
                      width: 56,
                      height: 56,
                      fallback: _initialsBox(colorScheme),
                    ),
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
              if (isFavorite ||
                  onFavoriteToggle != null ||
                  qualityLabel != null ||
                  isLive ||
                  isAudio) ...[
                const SizedBox(width: 8),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: onFavoriteToggle,
                          child: Icon(
                            key: favoriteKey,
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            size: 18,
                            color: isFavorite
                                ? colorScheme.error
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (qualityLabel != null) ...[
                          const SizedBox(width: 6),
                          AiroBadge(
                            label: qualityLabel!,
                            variant: AiroBadgeVariant.neutral,
                            size: AiroBadgeSize.sm,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (isAudio)
                      AiroBadge(
                        label: 'Audio',
                        variant: AiroBadgeVariant.warning,
                        size: AiroBadgeSize.sm,
                      )
                    else if (isLive)
                      const AiroBadge.live(
                        pulse: false,
                        borderRadius: AiroSpacing.radiusSm,
                      ),
                  ],
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
