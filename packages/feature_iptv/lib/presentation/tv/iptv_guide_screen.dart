import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_epg/platform_epg.dart';

import '../../application/providers/iptv_providers.dart';
import '../widgets/iptv_icon_placeholder.dart';

/// TV Guide: a scrollable list of all channels with their current/next
/// program, sourced from [compactEpgSliceForChannelsProvider]. Selecting a
/// channel plays it and invokes [onChannelSelected] so the caller (the app
/// shell, which owns routing) can navigate to the live/player screen.
class IptvGuideScreen extends ConsumerWidget {
  const IptvGuideScreen({required this.onChannelSelected, super.key});

  final VoidCallback onChannelSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channelsAsync = ref.watch(iptvChannelsProvider);

    return channelsAsync.when(
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
        return _GuideList(
          channels: channels,
          onChannelSelected: onChannelSelected,
        );
      },
    );
  }
}

class _GuideList extends ConsumerWidget {
  const _GuideList({required this.channels, required this.onChannelSelected});

  final List<IPTVChannel> channels;
  final VoidCallback onChannelSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(compactEpgReferenceTimeProvider);
    final sliceAsync = ref.watch(
      compactEpgSliceForChannelsProvider(
        CompactEpgChannelQuery(
          channelIds: channels.map((c) => c.id).toList(growable: false),
          now: now,
        ),
      ),
    );
    final currentChannel = ref.watch(currentChannelProvider);

    final entriesByChannel = <String, CompactEpgEntry>{
      for (final entry in sliceAsync.value?.entries ?? const [])
        entry.channelId: entry,
    };

    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: channels.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final channel = channels[index];
        return _GuideChannelRow(
          channel: channel,
          epgEntry: entriesByChannel[channel.id],
          isPlaying: currentChannel?.id == channel.id,
          autofocus: index == 0,
          onSelect: () {
            ref.read(iptvStreamingServiceProvider).playChannel(channel);
            ref.read(addToRecentlyWatchedProvider(channel));
            onChannelSelected();
          },
        );
      },
    );
  }
}

class _GuideChannelRow extends StatelessWidget {
  const _GuideChannelRow({
    required this.channel,
    required this.epgEntry,
    required this.isPlaying,
    required this.autofocus,
    required this.onSelect,
  });

  final IPTVChannel channel;
  final CompactEpgEntry? epgEntry;
  final bool isPlaying;
  final bool autofocus;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return TvFocusable(
      autofocus: autofocus,
      onSelect: onSelect,
      semanticLabel: isPlaying
          ? '${channel.name}, currently playing'
          : channel.name,
      semanticHint: 'Press OK to play this channel',
      semanticButton: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isPlaying
              ? colorScheme.primaryContainer.withValues(alpha: 0.56)
              : colorScheme.surface.withValues(alpha: 0.6),
          border: Border.all(
            color: isPlaying ? colorScheme.primary : colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.42,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: channel.hasLogo
                        ? AiroNetworkImage(
                            url: channel.logoUrl!,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                IptvIconPlaceholder.channel(
                                  isAudioOnly: channel.isAudioOnly,
                                ),
                          )
                        : IptvIconPlaceholder.channel(
                            isAudioOnly: channel.isAudioOnly,
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      channel.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      channel.group,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (epgEntry?.hasPrograms ?? false) ...[
                      const SizedBox(height: 6),
                      _GuideEpgLine(entry: epgEntry!),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 16),
              if (!channel.isAudioOnly) const AiroBadge.live(),
              if (isPlaying) ...[
                const SizedBox(width: 12),
                Icon(Icons.equalizer, color: colorScheme.primary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _GuideEpgLine extends StatelessWidget {
  const _GuideEpgLine({required this.entry});

  final CompactEpgEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final program = entry.current ?? entry.next;
    if (program == null) {
      return const SizedBox.shrink();
    }

    final prefix = entry.current != null ? 'Now' : 'Next';
    return Row(
      children: [
        Icon(Icons.schedule, size: 14, color: colorScheme.primary),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            '$prefix: ${program.title}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
