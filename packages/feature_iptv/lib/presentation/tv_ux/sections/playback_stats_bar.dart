import 'package:flutter/material.dart';
import 'package:platform_player/platform_player.dart';

class PlaybackStatsBar extends StatelessWidget {
  const PlaybackStatsBar({super.key, required this.stats});

  final AiroPlaybackStats stats;

  @override
  Widget build(BuildContext context) {
    final facts = <Widget>[
      if (stats.codec case final codec?)
        _PlaybackFact(label: 'Codec', value: codec.toUpperCase()),
      if (stats.resolution case final resolution?)
        _PlaybackFact(label: 'Resolution', value: resolution),
      if (stats.bitrateKbps case final bitrate?)
        _PlaybackFact(label: 'Bitrate', value: '$bitrate kbps'),
    ];

    return Semantics(
      label: 'Live playback statistics',
      child: ListView.separated(
        key: const ValueKey('airo-tv-playback-stats'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: facts.length,
        separatorBuilder: (_, _) => const VerticalDivider(width: 24),
        itemBuilder: (_, index) => facts[index],
      ),
    );
  }
}

class _PlaybackFact extends StatelessWidget {
  const _PlaybackFact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: Colors.white54),
        ),
        Text(value, style: Theme.of(context).textTheme.labelLarge),
      ],
    );
  }
}
