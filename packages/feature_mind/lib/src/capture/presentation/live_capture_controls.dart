import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

/// Bottom capture controls — timer, listening state, pause/stop (`P0`).
class LiveCaptureControls extends StatelessWidget {
  const LiveCaptureControls({
    required this.elapsedLabel,
    required this.isPaused,
    required this.followLive,
    required this.onFollowLiveChanged,
    required this.onPause,
    required this.onResume,
    required this.onStop,
    super.key,
  });

  final String elapsedLabel;
  final bool isPaused;
  final bool followLive;
  final ValueChanged<bool> onFollowLiveChanged;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  isPaused ? Icons.pause_circle_outline : Icons.graphic_eq,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  isPaused ? 'Paused' : 'Listening',
                  style: theme.textTheme.labelLarge,
                ),
                const Spacer(),
                FilterChip(
                  key: const Key('meeting_capture_follow_live'),
                  label: Text(followLive ? 'Follow live ✓' : 'Follow live'),
                  selected: followLive,
                  onSelected: onFollowLiveChanged,
                ),
              ],
            ),
            const SizedBox(height: 8),
            _AudioActivityBar(isPaused: isPaused),
            const SizedBox(height: 12),
            Text(
              elapsedLabel,
              key: const Key('meeting_capture_elapsed'),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!isPaused)
                  OutlinedButton.icon(
                    key: const Key('meeting_capture_pause_button'),
                    onPressed: onPause,
                    icon: const Icon(Icons.pause),
                    label: const Text('Pause'),
                  )
                else
                  OutlinedButton.icon(
                    key: const Key('meeting_capture_resume_button'),
                    onPressed: onResume,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Resume'),
                  ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  key: const Key('meeting_capture_stop_button'),
                  onPressed: onStop,
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AudioActivityBar extends StatelessWidget {
  const _AudioActivityBar({required this.isPaused});

  final bool isPaused;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary.withValues(
      alpha: isPaused ? 0.25 : 0.7,
    );
    return SizedBox(
      height: 24,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(12, (index) {
          final height = isPaused ? 4.0 : 6.0 + (index % 4) * 4.0;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 4,
              height: height,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }
}
