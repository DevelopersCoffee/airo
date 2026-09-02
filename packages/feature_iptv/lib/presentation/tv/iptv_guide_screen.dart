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
import '../widgets/epg_match_override_sheet.dart';
import '../widgets/richer_context_prototype.dart';
import '../widgets/channel_load_error_view.dart';

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
          error: (error, _) => ChannelLoadErrorView(
            message: 'Could not load the guide: $error',
            onRetry: () => invalidateChannelLibraries(ref),
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
                      labelText: 'Search guide',
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
                      ? EpgTimelineGrid(
                          onChannelSelect: selectChannel,
                          onProgramSelect: (channel, program) {
                            unawaited(
                              _showProgrammeDetails(
                                channel,
                                program,
                                onWatchNow: () => selectChannel(channel),
                              ),
                            );
                          },
                          onMatchEpg: (channel) => unawaited(
                            showEpgMatchOverrideSheet(context, channel),
                          ),
                        )
                      : EpgTouchTimelineGrid(
                          onChannelSelect: selectChannel,
                          onReminderToggle: (channel, program) {
                            unawaited(_toggleReminder(channel, program));
                          },
                          onMatchEpg: (channel) => unawaited(
                            showEpgMatchOverrideSheet(context, channel),
                          ),
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
          // Unreachable while the button is gated on the gateway above, but
          // a reminder that cannot be set must never fail silently.
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Reminders are not available on this device.'),
            ),
          );
      }
    } finally {
      _reminderOperationsInFlight.remove(programId);
    }
  }

  Future<void> _showProgrammeDetails(
    IPTVChannel channel,
    CompactEpgProgram program, {
    required VoidCallback onWatchNow,
  }) async {
    final scheduler = ref.read(epgReminderSchedulerProvider);
    // Without a notification gateway `scheduleReminder` can only answer
    // `unavailable`, so the button would be a control that silently does
    // nothing. That is the permanent state on TV: `main_tv.dart` never
    // overrides `epgReminderNotificationGatewayProvider` (only the phone
    // entrypoint does), and the TV flavor stubs `flutter_local_notifications`
    // anyway, so there is nothing to wire it to.
    final canScheduleReminders = ref
        .read(epgReminderNotificationGatewayProvider)
        .isAvailable;
    final isReminded = await scheduler.isReminded(program.programId);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => ProgrammeDetailsDialog(
        channel: channel,
        program: program,
        isReminded: isReminded,
        onWatchNow: () {
          Navigator.of(dialogContext).pop();
          onWatchNow();
        },
        onToggleReminder:
            canScheduleReminders &&
                program.startsAt.isAfter(DateTime.now().toUtc())
            ? () {
                Navigator.of(dialogContext).pop();
                unawaited(_toggleReminder(channel, program));
              }
            : null,
      ),
    );
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

class ProgrammeDetailsDialog extends StatelessWidget {
  const ProgrammeDetailsDialog({
    required this.channel,
    required this.program,
    required this.isReminded,
    required this.onWatchNow,
    required this.onToggleReminder,
    super.key,
  });

  final IPTVChannel channel;
  final CompactEpgProgram program;
  final bool isReminded;
  final VoidCallback onWatchNow;
  final VoidCallback? onToggleReminder;

  @override
  Widget build(BuildContext context) {
    final localStart = program.startsAt.toLocal();
    final localEnd = program.endsAt.toLocal();
    final time =
        '${TimeOfDay.fromDateTime(localStart).format(context)} – '
        '${TimeOfDay.fromDateTime(localEnd).format(context)}';
    final badges = [
      if (program.isNew) 'NEW',
      if (program.isPremiere) 'PREMIERE',
      if (program.previouslyShown) 'REPEAT',
    ];
    return AlertDialog(
      semanticLabel: 'Programme details for ${program.title}',
      title: Text(program.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${channel.name} · $time'),
            if (program.subtitle != null) Text(program.subtitle!),
            if (program.episodeNumber != null)
              Text('Episode ${program.episodeNumber}'),
            if (program.description != null) Text(program.description!),
            if (program.categories.isNotEmpty)
              Text('Categories: ${program.categories.join(', ')}'),
            if (program.rating != null) Text('Rating: ${program.rating}'),
            if (badges.isNotEmpty) Text(badges.join(' · ')),
            ProgrammeEnrichmentPrototypeCard(
              request: ProgrammeMetadataRequest(
                title: program.title,
                startsAt: program.startsAt,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: onWatchNow, child: const Text('Watch now')),
        if (onToggleReminder != null)
          TextButton(
            onPressed: onToggleReminder,
            child: Text(isReminded ? 'Cancel reminder' : 'Set reminder'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
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
