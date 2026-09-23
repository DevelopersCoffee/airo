import 'package:feature_iptv/feature_iptv.dart';
import 'package:feature_iptv/presentation/tv_ux/sections/channel_library_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_haptics/platform_haptics.dart';

/// Playback Settings Screen (CV-031): aspect ratio preference for video
/// playback. Picture-in-Picture is airo-pro scope and lives in its own
/// overlay, not this screen.
class PlaybackSettingsScreen extends ConsumerWidget {
  const PlaybackSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aspectRatio = ref.watch(videoAspectRatioProvider);
    final notifier = ref.read(videoAspectRatioProvider.notifier);
    final pipEnabled = ref.watch(pictureInPicturePreferenceProvider);
    final hapticStrength = ref.watch(aikaHapticStrengthProvider);
    final extraSections = ref.watch(playbackSettingsExtraSectionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Playback Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Aspect Ratio',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          RadioGroup<AiroPlaybackViewFit>(
            groupValue: aspectRatio,
            onChanged: (fit) {
              if (fit != null) notifier.setAspectRatio(fit);
            },
            child: Column(
              children: [
                for (final fit in AiroPlaybackViewFit.values)
                  RadioListTile<AiroPlaybackViewFit>(
                    key: ValueKey('playback-aspect-ratio-${fit.stableId}'),
                    value: fit,
                    title: Text(_labelFor(fit)),
                    subtitle: Text(_descriptionFor(fit)),
                  ),
              ],
            ),
          ),
          SwitchListTile(
            key: const ValueKey('playback-resume-last-channel-toggle'),
            secondary: const Icon(Icons.history),
            title: const Text('Resume last channel'),
            subtitle: const Text(
              'Open the last live channel when Aika Stream starts.',
            ),
            value: ref.watch(resumeLastChannelEnabledProvider),
            onChanged: (enabled) => ref
                .read(resumeLastChannelEnabledProvider.notifier)
                .setEnabled(enabled),
          ),
          SwitchListTile(
            key: const ValueKey('playback-picture-in-picture-toggle'),
            secondary: const Icon(Icons.picture_in_picture_alt_outlined),
            title: const Text('Picture-in-picture'),
            subtitle: const Text(
              'Automatically keep video playing in a small window when you leave the app.',
            ),
            value: pipEnabled,
            onChanged: (enabled) => ref
                .read(pictureInPicturePreferenceProvider.notifier)
                .setEnabled(enabled),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Text(
              'Haptic Feedback',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          AiroHapticStrengthPicker(
            value: hapticStrength,
            onChanged: (strength) => ref
                .read(aikaHapticStrengthProvider.notifier)
                .setStrength(strength),
          ),
          ...extraSections,
          const SizedBox(height: 24),
          const ChannelGridDensitySection(),
        ],
      ),
    );
  }

  String _labelFor(AiroPlaybackViewFit fit) {
    switch (fit) {
      case AiroPlaybackViewFit.contain:
        return 'Fit';
      case AiroPlaybackViewFit.cover:
        return 'Zoom to Fill';
      case AiroPlaybackViewFit.fill:
        return 'Fill Width';
      case AiroPlaybackViewFit.stretch:
        return 'Stretch';
    }
  }

  String _descriptionFor(AiroPlaybackViewFit fit) {
    switch (fit) {
      case AiroPlaybackViewFit.contain:
        return 'Show the whole video, may add bars';
      case AiroPlaybackViewFit.cover:
        return 'Fill the screen, cropping the edges';
      case AiroPlaybackViewFit.fill:
        return 'Fill the width, may add bars top and bottom';
      case AiroPlaybackViewFit.stretch:
        return 'Stretch to exactly fill the screen';
    }
  }
}
