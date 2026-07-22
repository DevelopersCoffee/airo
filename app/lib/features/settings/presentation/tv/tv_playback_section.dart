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
    final extraSections = ref.watch(playbackSettingsExtraSectionsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      children: [
        for (var index = 0; index < AiroPlaybackViewFit.values.length; index++)
          Padding(
            padding: EdgeInsets.only(
              bottom: index == AiroPlaybackViewFit.values.length - 1 ? 0 : 8,
            ),
            child: _AspectRatioOption(
              fit: AiroPlaybackViewFit.values[index],
              isSelected: AiroPlaybackViewFit.values[index] == current,
              autofocus: index == 0,
              onSelect: () => ref
                  .read(videoAspectRatioProvider.notifier)
                  .setAspectRatio(AiroPlaybackViewFit.values[index]),
              labelFor: _labelFor,
              colorScheme: colorScheme,
            ),
          ),
        if (extraSections.isNotEmpty) const SizedBox(height: 24),
        ...extraSections,
      ],
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

class _AspectRatioOption extends StatelessWidget {
  const _AspectRatioOption({
    required this.fit,
    required this.isSelected,
    required this.autofocus,
    required this.onSelect,
    required this.labelFor,
    required this.colorScheme,
  });

  final AiroPlaybackViewFit fit;
  final bool isSelected;
  final bool autofocus;
  final VoidCallback onSelect;
  final String Function(AiroPlaybackViewFit fit) labelFor;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final label = labelFor(fit);

    return TvFocusable(
      autofocus: autofocus,
      onSelect: onSelect,
      semanticLabel: label,
      semanticButton: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(
                label,
                style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
              ),
              const Spacer(),
              if (isSelected) Icon(Icons.check, color: colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
