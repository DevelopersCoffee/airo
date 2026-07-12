import 'package:flutter/material.dart';

class IptvIconPlaceholder extends StatelessWidget {
  final IconData icon;

  const IptvIconPlaceholder._({required this.icon});

  factory IptvIconPlaceholder.channel({bool isAudioOnly = false}) {
    return IptvIconPlaceholder._(
      icon: isAudioOnly ? Icons.radio : Icons.live_tv,
    );
  }

  factory IptvIconPlaceholder.videoPlayer() {
    return const IptvIconPlaceholder._(icon: Icons.play_circle_outline);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: colorScheme.onSurfaceVariant, size: 32),
    );
  }
}
