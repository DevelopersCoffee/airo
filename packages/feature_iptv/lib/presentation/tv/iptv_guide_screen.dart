import 'dart:async';

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_epg/platform_epg.dart';

import '../../application/epg_reminder_scheduler.dart';
import '../../application/providers/epg_reminder_providers.dart';
import '../../application/providers/guide_providers.dart';
import '../../application/providers/iptv_providers.dart';
import '../widgets/epg_touch_timeline_grid.dart';
import '../widgets/epg_timeline_grid.dart';

/// TV Guide: a virtualized horizontal-timeline EPG grid (CV-015 slice 2),
/// sourced from [guidePagedWindowProvider]. Selecting a channel plays it and
/// invokes [onChannelSelected] so the caller (the app shell, which owns
/// routing) can navigate to the live/player screen.
class IptvGuideScreen extends ConsumerStatefulWidget {
  const IptvGuideScreen({
    required this.onChannelSelected,
    this.overrideFormFactor,
    super.key,
  });

  final VoidCallback onChannelSelected;

  /// Forces a specific form factor (e.g. [AiroFormFactor.tv] from the TV
  /// route). Leave null on mobile so the scaffold adapts to the actual
  /// device width instead of always rendering TV-sized chrome.
  final AiroFormFactor? overrideFormFactor;

  @override
  ConsumerState<IptvGuideScreen> createState() => _IptvGuideScreenState();
}

class _IptvGuideScreenState extends ConsumerState<IptvGuideScreen> {
  final Set<String> _reminderOperationsInFlight = {};
  final Map<String, int> _reminderOperationTokens = {};
  var _nextReminderOperationToken = 0;

  @override
  Widget build(BuildContext context) {
    final channelsAsync = ref.watch(iptvChannelsProvider);

    return AiroResponsiveScaffold(
      overrideFormFactor: widget.overrideFormFactor,
      padding: EdgeInsets.zero,
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: channelsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Text(
              'Could not load the guide: $error',
              textAlign: TextAlign.center,
            ),
          ),
          data: (channels) {
            if (channels.isEmpty) {
              return const Center(child: Text('No channels to show yet.'));
            }
            void selectChannel(IPTVChannel channel) {
              ref.read(iptvStreamingServiceProvider).playChannel(channel);
              ref.read(addToRecentlyWatchedProvider(channel));
              widget.onChannelSelected();
            }

            return Column(
              children: [
                const _GuideAvailabilityBanner(),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search the guide',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) =>
                        ref.read(guideSearchQueryProvider.notifier).state =
                            value,
                  ),
                ),
                Expanded(
                  child: widget.overrideFormFactor == AiroFormFactor.tv
                      ? EpgTimelineGrid(onChannelSelect: selectChannel)
                      : EpgTouchTimelineGrid(
                          onChannelSelect: selectChannel,
                          onReminderToggle: (channel, program) {
                            unawaited(_toggleReminder(channel, program));
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _toggleReminder(
    IPTVChannel channel,
    CompactEpgProgram program,
  ) async {
    final programId = program.programId;
    if (!_reminderOperationsInFlight.add(programId)) return;

    final scheduler = ref.read(epgReminderSchedulerProvider);
    try {
      if (await scheduler.isReminded(programId)) {
        _advanceReminderToken(programId);
        await scheduler.cancelReminder(programId);
        if (!mounted) return;
        ref.invalidate(epgRemindersProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reminder canceled for ${program.title}')),
        );
        return;
      }

      final token = _advanceReminderToken(programId);
      final outcome = await scheduler.scheduleReminder(
        channel: channel,
        program: program,
      );
      if (!mounted) return;
      ref.invalidate(epgRemindersProvider);

      switch (outcome) {
        case EpgReminderOutcome.scheduled:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Reminder set for ${program.title}'),
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () {
                  unawaited(_undoReminder(programId, token));
                },
              ),
            ),
          );
        case EpgReminderOutcome.scheduledInAppOnly:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Notifications are off — reminder will only show in-app.',
              ),
            ),
          );
        case EpgReminderOutcome.unavailable:
          break;
      }
    } finally {
      _reminderOperationsInFlight.remove(programId);
    }
  }

  int _advanceReminderToken(String programId) {
    final token = _nextReminderOperationToken++;
    _reminderOperationTokens[programId] = token;
    return token;
  }

  Future<void> _undoReminder(String programId, int token) async {
    if (!_reminderOperationIsCurrent(programId, token)) return;
    if (!_reminderOperationsInFlight.add(programId)) return;
    try {
      if (!_reminderOperationIsCurrent(programId, token) || !mounted) return;
      final scheduler = ref.read(epgReminderSchedulerProvider);
      await scheduler.cancelReminder(programId);
      if (!_reminderOperationIsCurrent(programId, token) || !mounted) return;
      ref.invalidate(epgRemindersProvider);
      _reminderOperationTokens.remove(programId);
    } finally {
      _reminderOperationsInFlight.remove(programId);
    }
  }

  bool _reminderOperationIsCurrent(String programId, int token) {
    return _reminderOperationTokens[programId] == token;
  }
}

class _GuideAvailabilityBanner extends ConsumerWidget {
  const _GuideAvailabilityBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final window = ref.watch(
      guidePagedWindowProvider.select((state) => state.window),
    );
    if (window == null) return const SizedBox.shrink();

    final availability = window.availabilityAt(DateTime.now().toUtc());
    if (availability == CompactEpgAvailability.available) {
      return const SizedBox.shrink();
    }

    final message = availability == CompactEpgAvailability.stale
        ? 'Guide data is out of date — refresh your XMLTV source in Settings.'
        : 'No guide data available yet — add an XMLTV source in Settings to see programme times.';

    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        message,
        style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
      ),
    );
  }
}
