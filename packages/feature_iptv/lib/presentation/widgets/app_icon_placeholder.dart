import 'package:flutter/material.dart';

class AppIconPlaceholder extends StatelessWidget {
  final double? size;
  final EdgeInsetsGeometry padding;
  final Widget? fallbackIcon;

  const AppIconPlaceholder({
    super.key,
    this.size,
    this.padding = EdgeInsets.zero,
    this.fallbackIcon,
    bool forceFallback = false,
  });

  factory AppIconPlaceholder.channel({Key? key, bool isAudioOnly = false}) {
    return AppIconPlaceholder(
      key: key,
      fallbackIcon: _ChannelIconFallback(isAudioOnly: isAudioOnly),
    );
  }

  factory AppIconPlaceholder.videoPlayer({Key? key}) {
    return AppIconPlaceholder(
      key: key,
      size: 120,
      padding: const EdgeInsets.all(16),
      fallbackIcon: const Icon(Icons.live_tv, color: Colors.white54, size: 64),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child:
          fallbackIcon ??
          Icon(Icons.image, color: Theme.of(context).disabledColor, size: size),
    );
  }
}

class _ChannelIconFallback extends StatelessWidget {
  const _ChannelIconFallback({required this.isAudioOnly});

  final bool isAudioOnly;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colorScheme.surface.withValues(alpha: 0.52),
      child: Center(
        child: Icon(
          isAudioOnly ? Icons.radio : Icons.live_tv,
          color: colorScheme.primary.withValues(alpha: 0.72),
          size: 24,
        ),
      ),
    );
  }
}
