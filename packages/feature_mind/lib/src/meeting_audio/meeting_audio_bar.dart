import 'package:flutter/material.dart';

import 'meeting_audio_playback.dart';

/// Play / pause + scrubber for a meeting recording.
class MeetingAudioBar extends StatelessWidget {
  const MeetingAudioBar({
    required this.playback,
    required this.audioPath,
    super.key,
  });

  final MeetingAudioPlayback playback;
  final String audioPath;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: playback,
      builder: (context, _) {
        final durationMs = playback.duration.inMilliseconds;
        final positionMs = playback.position.inMilliseconds.clamp(
          0,
          durationMs == 0 ? 0 : durationMs,
        );
        return Card(
          key: const Key('meeting_audio_bar'),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
            child: Row(
              children: [
                IconButton(
                  key: const Key('meeting_audio_play_button'),
                  tooltip: playback.playing ? 'Pause' : 'Play recording',
                  onPressed: () => playback.toggle(audioPath),
                  icon: Icon(playback.playing ? Icons.pause : Icons.play_arrow),
                ),
                Text(
                  _clock(positionMs),
                  key: const Key('meeting_audio_position'),
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                Expanded(
                  child: Slider(
                    key: const Key('meeting_audio_scrubber'),
                    value: durationMs == 0 ? 0 : positionMs / durationMs,
                    onChanged: durationMs == 0
                        ? null
                        : (value) => playback.seekAndPlay(
                            audioPath,
                            (value * durationMs).round(),
                          ),
                  ),
                ),
                Text(
                  durationMs == 0 ? '--:--' : _clock(durationMs),
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _clock(int ms) {
    final totalSeconds = ms ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
}
