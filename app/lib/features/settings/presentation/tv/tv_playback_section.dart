import 'package:core_ui/core_ui.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Playback preferences for the TV settings screen (CV-022): the default
/// video aspect-ratio fit. Reuses [videoAspectRatioProvider] — the same
/// provider the in-player aspect-ratio cycle button already drives.
class TvPlaybackSection extends ConsumerWidget {
  const TvPlaybackSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(videoAspectRatioProvider);

    return ListView.separated(
      itemCount: AiroPlaybackViewFit.values.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final fit = AiroPlaybackViewFit.values[index];
        final label = _labelFor(fit);
        final isSelected = fit == current;
        return TvFocusable(
          autofocus: index == 0,
          onSelect: () =>
              ref.read(videoAspectRatioProvider.notifier).setAspectRatio(fit),
          semanticLabel: label,
          semanticButton: true,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Colors.white10,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    label,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const Spacer(),
                  if (isSelected) const Icon(Icons.check, color: Colors.white),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Matches the meaning documented on
  /// `_VideoPlayerWidgetState._boxFitFor` in video_player_widget.dart.
  String _labelFor(AiroPlaybackViewFit fit) {
    return switch (fit) {
      AiroPlaybackViewFit.contain => 'Fit (letterboxed)',
      AiroPlaybackViewFit.cover => 'Fill screen (cropped)',
      AiroPlaybackViewFit.fill => 'Fill width',
      AiroPlaybackViewFit.stretch => 'Stretch to fill',
    };
  }
}
