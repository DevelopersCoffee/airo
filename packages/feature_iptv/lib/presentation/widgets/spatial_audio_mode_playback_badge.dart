import 'package:feature_iptv/application/providers/spatial_audio_mode_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_player/platform_player.dart';

/// Compact always-visible audio-path hint during IPTV playback (#2081 / #2083).
class SpatialAudioModePlaybackBadge extends ConsumerWidget {
  const SpatialAudioModePlaybackBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(spatialAudioModeProvider);
    final isSpatial = mode == AiroSpatialAudioMode.spatial;
    final title = isSpatial
        ? 'Audio: Spatial (experimental)'
        : 'Audio: Original';
    final subtitle = isSpatial ? 'Post-decode PCM (passthrough)' : 'Direct decode';

    return Semantics(
      label: '$title. $subtitle',
      child: Material(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                key: const ValueKey('spatial-audio-mode-badge-title'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                subtitle,
                key: const ValueKey('spatial-audio-mode-badge-subtitle'),
                style: const TextStyle(color: Colors.white70, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
