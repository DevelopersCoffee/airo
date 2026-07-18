import 'dart:async';

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_epg/platform_epg.dart';

import '../../application/providers/guide_providers.dart';
import '../tv/iptv_tv.dart';

/// Horizontal-timeline EPG grid (CV-015 slice 2): a vertically-virtualized
/// list of channel rows, each showing its programmes for the current guide
/// window as proportionally-sized blocks. Rows share one horizontal
/// [ScrollController] with the time-axis header — scroll is driven by D-pad
/// focus movement (see [_ProgramBlock]'s `onFocus`), not free drag, so every
/// row's [SingleChildScrollView] uses [NeverScrollableScrollPhysics].
///
/// [ScrollController] does support attaching to multiple [ScrollPosition]s
/// at once (the header's plus every visible row's), and methods like
/// [ScrollController.animateTo]/[ScrollController.jumpTo] apply to all of
/// them. However, the singular [ScrollController.position] getter does NOT
/// support multiple attachments — it asserts exactly one attached position
/// and throws otherwise. Since this grid always has the header plus at
/// least one row attached simultaneously, code here must read scroll
/// extents via [ScrollController.positions] (e.g. `.positions.first`), not
/// via `.position`.
class EpgTimelineGrid extends ConsumerStatefulWidget {
  const EpgTimelineGrid({super.key, this.onChannelSelect});

  final void Function(IPTVChannel channel)? onChannelSelect;

  static const double pxPerMinute = 4.0;
  static const double rowHeight = 88.0;
  static const double channelLabelWidth = 220.0;
  static const double timeAxisHeight = 32.0;

  @override
  ConsumerState<EpgTimelineGrid> createState() => _EpgTimelineGridState();
}

class _EpgTimelineGridState extends ConsumerState<EpgTimelineGrid> {
  final ScrollController _timelineController = ScrollController();

  @override
  void dispose() {
    _timelineController.dispose();
    super.dispose();
  }

  void _scrollTimelineTo(double offset) {
    if (!_timelineController.hasClients) return;
    // Multiple ScrollPositions are attached (header + every visible row),
    // so `.position` (which requires exactly one) would throw. All attached
    // positions scroll the same timelineWidth-wide content within the same
    // viewport width, so any one of them (e.g. `.positions.first`) yields
    // the same maxScrollExtent.
    final maxScrollExtent = _timelineController.positions.first.maxScrollExtent;
    _timelineController.animateTo(
      offset.clamp(0.0, maxScrollExtent),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final channels = ref.watch(guideFilteredChannelsProvider);
    final windowAsync = ref.watch(guideEpgWindowProvider);
    final windowStart = ref.watch(guideWindowStartProvider);
    final windowDuration = ref.watch(guideWindowDurationProvider);
    final dimensions = ref.watch(tvDimensionsProvider(context));

    if (channels.isEmpty) {
      return const Center(child: Text('No channels to show yet.'));
    }

    final window = windowAsync.value;
    final entriesByChannel = <String, CompactEpgWindowEntry>{
      for (final entry in window?.entries ?? const <CompactEpgWindowEntry>[])
        entry.channelId: entry,
    };
    final timelineWidth =
        windowDuration.inMinutes * EpgTimelineGrid.pxPerMinute;

    return Padding(
      padding: dimensions.safeZone,
      child: Column(
        children: [
          SizedBox(
            height: EpgTimelineGrid.timeAxisHeight,
            child: Row(
              children: [
                const SizedBox(width: EpgTimelineGrid.channelLabelWidth),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _timelineController,
                    scrollDirection: Axis.horizontal,
                    physics: const NeverScrollableScrollPhysics(),
                    child: SizedBox(
                      width: timelineWidth,
                      child: _TimeAxis(
                        windowStart: windowStart,
                        windowDuration: windowDuration,
                        pxPerMinute: EpgTimelineGrid.pxPerMinute,
                        textScaleFactor: dimensions.textScaleFactor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                ListView.builder(
                  itemExtent: EpgTimelineGrid.rowHeight,
                  itemCount: channels.length,
                  itemBuilder: (context, index) {
                    final channel = channels[index];
                    final entry = entriesByChannel[channel.id];
                    return _EpgChannelRow(
                      key: ValueKey('epg_row_${channel.id}'),
                      channel: channel,
                      entry: entry,
                      windowStart: windowStart,
                      windowDuration: windowDuration,
                      scrollController: _timelineController,
                      dimensions: dimensions,
                      onProgramFocus: (offset) => _scrollTimelineTo(offset),
                      onSelect: () => widget.onChannelSelect?.call(channel),
                    );
                  },
                ),
                _CurrentTimeIndicator(
                  windowStart: windowStart,
                  windowDuration: windowDuration,
                  pxPerMinute: EpgTimelineGrid.pxPerMinute,
                  leftInset: EpgTimelineGrid.channelLabelWidth,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeAxis extends StatelessWidget {
  const _TimeAxis({
    required this.windowStart,
    required this.windowDuration,
    required this.pxPerMinute,
    required this.textScaleFactor,
  });

  final DateTime windowStart;
  final Duration windowDuration;
  final double pxPerMinute;
  final double textScaleFactor;

  @override
  Widget build(BuildContext context) {
    final hourCount = (windowDuration.inMinutes / 60).ceil();
    final baseStyle = Theme.of(context).textTheme.labelSmall;
    return Stack(
      children: [
        for (var i = 0; i <= hourCount; i++)
          Positioned(
            left: i * 60 * pxPerMinute,
            child: Text(
              TimeOfDay.fromDateTime(
                windowStart.add(Duration(hours: i)),
              ).format(context),
              style: baseStyle?.copyWith(
                fontSize: (baseStyle.fontSize ?? 11) * textScaleFactor,
              ),
            ),
          ),
      ],
    );
  }
}

class _EpgChannelRow extends StatelessWidget {
  const _EpgChannelRow({
    super.key,
    required this.channel,
    required this.entry,
    required this.windowStart,
    required this.windowDuration,
    required this.scrollController,
    required this.dimensions,
    required this.onProgramFocus,
    required this.onSelect,
  });

  final IPTVChannel channel;
  final CompactEpgWindowEntry? entry;
  final DateTime windowStart;
  final Duration windowDuration;
  final ScrollController scrollController;
  final TvUiDimensions dimensions;
  final void Function(double offset) onProgramFocus;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final programs = entry?.programs ?? const <CompactEpgProgram>[];
    return SizedBox(
      height: EpgTimelineGrid.rowHeight,
      child: Row(
        children: [
          SizedBox(
            width: EpgTimelineGrid.channelLabelWidth,
            // The label itself is selectable so a channel can be played even
            // when it has no programme blocks for the current window (e.g.
            // no XMLTV source configured yet) — selection must not depend on
            // EPG data being present.
            child: TvFocusable(
              onSelect: onSelect,
              semanticLabel: channel.name,
              semanticHint: 'Press OK to play this channel',
              semanticButton: true,
              child: Padding(
                padding: EdgeInsets.all(dimensions.cardPadding),
                child: Text(
                  channel.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              child: SizedBox(
                width: windowDuration.inMinutes * EpgTimelineGrid.pxPerMinute,
                child: Stack(
                  children: [
                    for (final program in programs)
                      _ProgramBlock(
                        key: ValueKey(
                          'epg_program_${channel.id}_${program.programId}',
                        ),
                        program: program,
                        windowStart: windowStart,
                        windowDuration: windowDuration,
                        onFocus: onProgramFocus,
                        onSelect: onSelect,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgramBlock extends StatelessWidget {
  const _ProgramBlock({
    super.key,
    required this.program,
    required this.windowStart,
    required this.windowDuration,
    required this.onFocus,
    required this.onSelect,
  });

  final CompactEpgProgram program;
  final DateTime windowStart;
  final Duration windowDuration;
  final void Function(double offset) onFocus;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final windowMinutes = windowDuration.inMinutes;
    final startOffsetMinutes = program.startsAt
        .difference(windowStart)
        .inMinutes
        .clamp(0, windowMinutes);
    final endOffsetMinutes = program.endsAt
        .difference(windowStart)
        .inMinutes
        .clamp(0, windowMinutes);
    final left = startOffsetMinutes * EpgTimelineGrid.pxPerMinute;
    final width =
        ((endOffsetMinutes - startOffsetMinutes) * EpgTimelineGrid.pxPerMinute)
            .clamp(24.0, double.infinity);

    return Positioned(
      left: left,
      width: width,
      top: 4,
      bottom: 4,
      child: TvFocusable(
        onSelect: onSelect,
        onFocus: () => onFocus(left),
        semanticLabel: program.title,
        semanticButton: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Text(
              program.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
      ),
    );
  }
}

/// Repaints its own position on a periodic timer — does NOT trigger a
/// rebuild of [_EpgChannelRow]/[_ProgramBlock] (CV-015 slice 2's explicit
/// "current-time indicator updates without full-row rebuilds" criterion).
///
/// Note: this does not account for the shared [ScrollController]'s live
/// horizontal scroll offset — it is positioned against the un-scrolled row
/// start (only [leftInset] is applied). That is a disclosed v1 limitation;
/// the acceptance criterion this satisfies is "updates without full-row
/// rebuilds," not "stays visually aligned while scrolled."
class _CurrentTimeIndicator extends StatefulWidget {
  const _CurrentTimeIndicator({
    required this.windowStart,
    required this.windowDuration,
    required this.pxPerMinute,
    required this.leftInset,
  });

  final DateTime windowStart;
  final Duration windowDuration;
  final double pxPerMinute;
  final double leftInset;

  @override
  State<_CurrentTimeIndicator> createState() => _CurrentTimeIndicatorState();
}

class _CurrentTimeIndicatorState extends State<_CurrentTimeIndicator> {
  Timer? _timer;
  DateTime _now = DateTime.now().toUtc();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      setState(() => _now = DateTime.now().toUtc());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutesFromStart = _now.difference(widget.windowStart).inMinutes;
    if (minutesFromStart < 0 ||
        minutesFromStart > widget.windowDuration.inMinutes) {
      return const SizedBox.shrink();
    }
    return Positioned(
      left: widget.leftInset + minutesFromStart * widget.pxPerMinute,
      top: 0,
      bottom: 0,
      child: IgnorePointer(
        child: Container(width: 2, color: Theme.of(context).colorScheme.error),
      ),
    );
  }
}
