import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_epg/platform_epg.dart';

import '../../application/providers/guide_providers.dart';
import '../../application/providers/iptv_providers.dart';
import '../widgets/epg_timeline_grid.dart';

/// TV Guide: a virtualized horizontal-timeline EPG grid (CV-015 slice 2),
/// sourced from [guideEpgWindowProvider]. Selecting a channel plays it and
/// invokes [onChannelSelected] so the caller (the app shell, which owns
/// routing) can navigate to the live/player screen.
class IptvGuideScreen extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final channelsAsync = ref.watch(iptvChannelsProvider);

    return AiroResponsiveScaffold(
      overrideFormFactor: overrideFormFactor,
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
                  child: EpgTimelineGrid(
                    onChannelSelect: (channel) {
                      ref
                          .read(iptvStreamingServiceProvider)
                          .playChannel(channel);
                      onChannelSelected();
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
}

class _GuideAvailabilityBanner extends ConsumerWidget {
  const _GuideAvailabilityBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final windowAsync = ref.watch(guideEpgWindowProvider);
    final window = windowAsync.value;
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
