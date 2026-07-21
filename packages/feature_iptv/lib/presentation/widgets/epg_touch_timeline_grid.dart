import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_epg/platform_epg.dart';

import '../../application/epg_reminder_store.dart';
import '../../application/providers/epg_reminder_providers.dart';
import '../../application/providers/guide_providers.dart';
import 'epg_program_progress.dart';

/// Phone interaction implementation of the Live Grid Navigation EPG.
///
/// Header and visible rows each own a separate horizontal [ScrollController].
/// Scroll offsets are synchronized with guarded `jumpTo` calls so drag-enabled
/// scrollables never share one controller or attach multiple positions to a
/// controller whose `.position` getter is used.
class EpgTouchTimelineGrid extends ConsumerStatefulWidget {
  const EpgTouchTimelineGrid({
    super.key,
    this.onChannelSelect,
    this.onReminderToggle,
  });

  final void Function(IPTVChannel channel)? onChannelSelect;
  final void Function(IPTVChannel channel, CompactEpgProgram program)?
  onReminderToggle;

  static const double pxPerMinute = 6.0;
  static const double rowHeight = 64.0;
  static const double channelLabelWidth = 120.0;
  static const double timeAxisHeight = 28.0;

  @override
  ConsumerState<EpgTouchTimelineGrid> createState() =>
      _EpgTouchTimelineGridState();
}

class _EpgTouchTimelineGridState extends ConsumerState<EpgTouchTimelineGrid> {
  final ScrollController _headerController = ScrollController();
  final Map<String, ScrollController> _rowControllers = {};
  bool _isSyncing = false;
  bool _didInitialJump = false;

  @override
  void initState() {
    super.initState();
    _headerController.addListener(() => _syncFrom(_headerController));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        ref
            .read(epgReminderSchedulerProvider)
            .pruneElapsed()
            .catchError(
              (Object error, StackTrace stackTrace) => debugPrint(
                '[EpgTouchTimelineGrid] pruneElapsed failed: $error',
              ),
            ),
      );
    });
  }

  @override
  void dispose() {
    _headerController.dispose();
    for (final controller in _rowControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  ScrollController _rowControllerFor(String channelId) {
    return _rowControllers.putIfAbsent(channelId, () {
      final controller = ScrollController();
      controller.addListener(() => _syncFrom(controller));
      return controller;
    });
  }

  void _syncFrom(ScrollController source) {
    if (_isSyncing || !source.hasClients) return;

    _isSyncing = true;
    final offset = source.offset;
    for (final controller in [_headerController, ..._rowControllers.values]) {
      if (identical(controller, source) || !controller.hasClients) continue;
      final target = offset.clamp(0.0, controller.position.maxScrollExtent);
      if ((controller.offset - target).abs() > 0.5) {
        controller.jumpTo(target);
      }
    }
    _isSyncing = false;

    _maybeExtendForward(source);
  }

  void _maybeExtendForward(ScrollController source) {
    if (!source.hasClients) return;
    if (source.position.maxScrollExtent - source.offset < 240) {
      ref.read(guidePagedWindowProvider.notifier).extendForward();
    }
  }

  double _nowOffsetPx(DateTime earliestStart, DateTime now) {
    return now.difference(earliestStart).inMinutes *
        EpgTouchTimelineGrid.pxPerMinute;
  }

  void _jumpToNow(GuidePagedWindowState paged, DateTime now) {
    final target = (_nowOffsetPx(paged.earliestStart, now) - 40).clamp(
      0.0,
      double.infinity,
    );
    for (final controller in [_headerController, ..._rowControllers.values]) {
      if (!controller.hasClients) continue;
      controller.jumpTo(target.clamp(0.0, controller.position.maxScrollExtent));
    }
  }

  @override
  Widget build(BuildContext context) {
    final channels = ref.watch(guideFilteredChannelsProvider);
    final paged = ref.watch(guidePagedWindowProvider);
    final now = ref.watch(nowTickerProvider).value ?? DateTime.now().toUtc();
    final reminders =
        ref.watch(epgRemindersProvider).value ?? const <EpgReminder>[];
    final remindedIds = {for (final reminder in reminders) reminder.programId};
    final remindersAvailable = ref
        .watch(epgReminderNotificationGatewayProvider)
        .isAvailable;

    if (channels.isEmpty) {
      return const Center(child: Text('No channels to show yet.'));
    }

    final window = paged.window;
    final entriesByChannel = <String, CompactEpgWindowEntry>{
      for (final entry in window?.entries ?? const <CompactEpgWindowEntry>[])
        entry.channelId: entry,
    };
    final timelineDuration = paged.loadedThrough.difference(
      paged.earliestStart,
    );
    final timelineWidth =
        timelineDuration.inMinutes * EpgTouchTimelineGrid.pxPerMinute;

    if (!_didInitialJump && window != null) {
      _didInitialJump = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _jumpToNow(paged, now);
      });
    }

    return Column(
      children: [
        SizedBox(
          height: EpgTouchTimelineGrid.timeAxisHeight,
          child: Row(
            children: [
              const SizedBox(width: EpgTouchTimelineGrid.channelLabelWidth),
              Expanded(
                child: SingleChildScrollView(
                  controller: _headerController,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: timelineWidth,
                    child: _TouchTimeAxis(
                      windowStart: paged.earliestStart,
                      windowDuration: timelineDuration,
                      pxPerMinute: EpgTouchTimelineGrid.pxPerMinute,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemExtent: EpgTouchTimelineGrid.rowHeight,
            itemCount: channels.length,
            itemBuilder: (context, index) {
              final channel = channels[index];
              return _TouchChannelRow(
                key: ValueKey('epg_touch_row_${channel.id}'),
                channel: channel,
                entry: entriesByChannel[channel.id],
                windowStart: paged.earliestStart,
                windowDuration: timelineDuration,
                scrollController: _rowControllerFor(channel.id),
                timelineWidth: timelineWidth,
                remindedIds: remindedIds,
                remindersAvailable: remindersAvailable,
                onChannelSelect: widget.onChannelSelect,
                onReminderToggle: widget.onReminderToggle,
              );
            },
          ),
        ),
        if (paged.forwardLoadFailed)
          Material(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      "Couldn't load more guide data.",
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                  TextButton(
                    key: const ValueKey('epg_touch_retry'),
                    onPressed: () => ref
                        .read(guidePagedWindowProvider.notifier)
                        .retryForward(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _TouchTimeAxis extends StatelessWidget {
  const _TouchTimeAxis({
    required this.windowStart,
    required this.windowDuration,
    required this.pxPerMinute,
  });

  final DateTime windowStart;
  final Duration windowDuration;
  final double pxPerMinute;

  @override
  Widget build(BuildContext context) {
    final hourCount = (windowDuration.inMinutes / 60).ceil();
    final baseStyle = Theme.of(context).textTheme.labelSmall;
    return Stack(
      children: [
        for (var i = 0; i <= hourCount; i++)
          Positioned(
            left: i * 60 * pxPerMinute,
            top: 5,
            child: Text(
              TimeOfDay.fromDateTime(
                windowStart.add(Duration(hours: i)).toLocal(),
              ).format(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: baseStyle,
            ),
          ),
      ],
    );
  }
}

class _TouchChannelRow extends StatefulWidget {
  const _TouchChannelRow({
    super.key,
    required this.channel,
    required this.entry,
    required this.windowStart,
    required this.windowDuration,
    required this.scrollController,
    required this.timelineWidth,
    required this.remindedIds,
    required this.remindersAvailable,
    required this.onChannelSelect,
    required this.onReminderToggle,
  });

  final IPTVChannel channel;
  final CompactEpgWindowEntry? entry;
  final DateTime windowStart;
  final Duration windowDuration;
  final ScrollController scrollController;
  final double timelineWidth;
  final Set<String> remindedIds;
  final bool remindersAvailable;
  final void Function(IPTVChannel channel)? onChannelSelect;
  final void Function(IPTVChannel channel, CompactEpgProgram program)?
  onReminderToggle;

  @override
  State<_TouchChannelRow> createState() => _TouchChannelRowState();
}

class _TouchChannelRowState extends State<_TouchChannelRow> {
  double _scrollOffset = 0;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_handleScroll);
  }

  @override
  void didUpdateWidget(_TouchChannelRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController == widget.scrollController) return;
    oldWidget.scrollController.removeListener(_handleScroll);
    widget.scrollController.addListener(_handleScroll);
    _scrollOffset = widget.scrollController.hasClients
        ? widget.scrollController.offset
        : 0;
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_handleScroll);
    super.dispose();
  }

  void _handleScroll() {
    if (!mounted || !widget.scrollController.hasClients) return;
    final next = widget.scrollController.offset;
    if ((next - _scrollOffset).abs() < 1) return;
    setState(() => _scrollOffset = next);
  }

  @override
  Widget build(BuildContext context) {
    final programs = widget.entry?.programs ?? const <CompactEpgProgram>[];
    return SizedBox(
      height: EpgTouchTimelineGrid.rowHeight,
      child: Row(
        children: [
          SizedBox(
            width: EpgTouchTimelineGrid.channelLabelWidth,
            child: InkWell(
              onTap: () => widget.onChannelSelect?.call(widget.channel),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.channel.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final viewportStart = _scrollOffset - 48;
                final viewportEnd = _scrollOffset + constraints.maxWidth + 48;
                return SingleChildScrollView(
                  controller: widget.scrollController,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: widget.timelineWidth,
                    child: Stack(
                      children: [
                        _TouchNowLine(
                          windowStart: widget.windowStart,
                          windowDuration: widget.windowDuration,
                        ),
                        for (final program in programs)
                          if (_programIntersectsViewport(
                            program,
                            viewportStart,
                            viewportEnd,
                          ))
                            _TouchProgramBlock(
                              key: ValueKey(
                                'epg_touch_program_'
                                '${widget.channel.id}_${program.programId}',
                              ),
                              program: program,
                              windowStart: widget.windowStart,
                              windowDuration: widget.windowDuration,
                              isReminded: widget.remindedIds.contains(
                                program.programId,
                              ),
                              remindersAvailable: widget.remindersAvailable,
                              onPlay: widget.onChannelSelect == null
                                  ? null
                                  : () =>
                                        widget.onChannelSelect!(widget.channel),
                              onRemind: widget.onReminderToggle == null
                                  ? null
                                  : () => widget.onReminderToggle!(
                                      widget.channel,
                                      program,
                                    ),
                            ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  bool _programIntersectsViewport(
    CompactEpgProgram program,
    double viewportStart,
    double viewportEnd,
  ) {
    final windowMinutes = widget.windowDuration.inMinutes;
    final startOffsetMinutes = program.startsAt
        .difference(widget.windowStart)
        .inMinutes
        .clamp(0, windowMinutes);
    final endOffsetMinutes = program.endsAt
        .difference(widget.windowStart)
        .inMinutes
        .clamp(0, windowMinutes);
    final left = startOffsetMinutes * EpgTouchTimelineGrid.pxPerMinute;
    final width =
        ((endOffsetMinutes - startOffsetMinutes) *
                EpgTouchTimelineGrid.pxPerMinute)
            .clamp(40.0, double.infinity);
    return left + width >= viewportStart && left <= viewportEnd;
  }
}

class _TouchNowLine extends ConsumerWidget {
  const _TouchNowLine({
    required this.windowStart,
    required this.windowDuration,
  });

  final DateTime windowStart;
  final Duration windowDuration;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(nowTickerProvider).value ?? DateTime.now().toUtc();
    final minutes = now.difference(windowStart).inMinutes;
    if (minutes < 0 || minutes > windowDuration.inMinutes) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: minutes * EpgTouchTimelineGrid.pxPerMinute,
      top: 0,
      bottom: 0,
      child: IgnorePointer(
        child: Container(width: 2, color: Theme.of(context).colorScheme.error),
      ),
    );
  }
}

class _TouchProgramBlock extends ConsumerWidget {
  const _TouchProgramBlock({
    super.key,
    required this.program,
    required this.windowStart,
    required this.windowDuration,
    required this.isReminded,
    required this.remindersAvailable,
    required this.onPlay,
    required this.onRemind,
  });

  final CompactEpgProgram program;
  final DateTime windowStart;
  final Duration windowDuration;
  final bool isReminded;
  final bool remindersAvailable;
  final VoidCallback? onPlay;
  final VoidCallback? onRemind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(nowTickerProvider).value ?? DateTime.now().toUtc();
    final windowMinutes = windowDuration.inMinutes;
    final startOffsetMinutes = program.startsAt
        .difference(windowStart)
        .inMinutes
        .clamp(0, windowMinutes);
    final endOffsetMinutes = program.endsAt
        .difference(windowStart)
        .inMinutes
        .clamp(0, windowMinutes);
    final left = startOffsetMinutes * EpgTouchTimelineGrid.pxPerMinute;
    final width =
        ((endOffsetMinutes - startOffsetMinutes) *
                EpgTouchTimelineGrid.pxPerMinute)
            .clamp(40.0, double.infinity);

    final isAiring = epgProgramIsAiring(
      startsAt: program.startsAt,
      endsAt: program.endsAt,
      now: now,
    );
    final isPast = !program.endsAt.isAfter(now);
    final tapHandler = isPast
        ? null
        : isAiring
        ? onPlay
        : remindersAvailable
        ? onRemind
        : null;
    final colorScheme = Theme.of(context).colorScheme;

    return Positioned(
      left: left,
      width: width,
      top: 4,
      bottom: 4,
      child: Semantics(
        button: tapHandler != null,
        enabled: tapHandler != null,
        label: _semanticLabel(isAiring: isAiring, isPast: isPast),
        child: Opacity(
          opacity: isPast ? 0.45 : 1.0,
          child: IgnorePointer(
            ignoring: tapHandler == null,
            child: InkWell(
              onTap: tapHandler,
              borderRadius: BorderRadius.circular(6),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: isReminded
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isAiring
                        ? colorScheme.primary
                        : colorScheme.outlineVariant,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                program.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                            if (isReminded)
                              Icon(
                                Icons.notifications_active,
                                size: 14,
                                color: colorScheme.onPrimaryContainer,
                              ),
                          ],
                        ),
                      ),
                      if (isAiring) ...[
                        Text(
                          '${epgProgramMinutesLeft(endsAt: program.endsAt, now: now)} min left',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        SizedBox(
                          height: 3,
                          child: LinearProgressIndicator(
                            value: epgProgramProgress(
                              startsAt: program.startsAt,
                              endsAt: program.endsAt,
                              now: now,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _semanticLabel({required bool isAiring, required bool isPast}) {
    if (isPast) return '${program.title}, elapsed';
    if (isAiring) return '${program.title}, airing now, tap to play';
    if (remindersAvailable) return '${program.title}, upcoming, tap to remind';
    return '${program.title}, upcoming';
  }
}
