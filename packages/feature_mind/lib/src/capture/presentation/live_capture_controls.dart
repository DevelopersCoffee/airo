import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../domain/speaker_activity_span.dart';
import 'audio_amplitude_meter.dart';
import 'speaker_activity_timeline.dart';

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
    required this.amplitudeSamples,
    this.speakerActivitySpans = const [],
    this.speakerTimelineEndMs = 0,
    this.activeSpeakerIndex,
    super.key,
  });

  final String elapsedLabel;
  final bool isPaused;
  final bool followLive;
  final ValueChanged<bool> onFollowLiveChanged;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;
  final List<double> amplitudeSamples;
  final List<SpeakerActivitySpan> speakerActivitySpans;
  final int speakerTimelineEndMs;
  final int? activeSpeakerIndex;

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
                Flexible(
                  child: FilterChip(
                    key: const Key('meeting_capture_follow_live'),
                    label: Text(followLive ? 'Follow live ✓' : 'Follow live'),
                    selected: followLive,
                    onSelected: onFollowLiveChanged,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            AudioAmplitudeMeter(
              samples: amplitudeSamples,
              isPaused: isPaused,
            ),
            if (speakerActivitySpans.isNotEmpty) ...[
              const SizedBox(height: 10),
              SpeakerActivityTimeline(
                spans: speakerActivitySpans,
                timelineEndMs: speakerTimelineEndMs,
                activeSpeakerIndex: activeSpeakerIndex,
              ),
            ],
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
