import 'package:flutter/material.dart';

/// Live amplitude meter — recording energy only, not speaker identity (`P0`).
class AudioAmplitudeMeter extends StatelessWidget {
  const AudioAmplitudeMeter({
    required this.samples,
    required this.isPaused,
    super.key,
  });

  /// Recent normalized RMS samples (0–1), oldest first.
  final List<double> samples;
  final bool isPaused;

  static const _barCount = 12;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary.withValues(
      alpha: isPaused ? 0.25 : 0.75,
    );
    final levels = _normalizedLevels(samples);

    return SizedBox(
      key: const Key('meeting_capture_amplitude_meter'),
      height: 24,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_barCount, (index) {
          final level = isPaused ? 0.0 : levels[index];
          final height = 4.0 + level * 18.0;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
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

  List<double> _normalizedLevels(List<double> samples) {
    if (samples.isEmpty) {
      return List<double>.filled(_barCount, 0);
    }
    final padded = List<double>.filled(_barCount, 0);
    final start = _barCount - samples.length;
    for (var i = 0; i < samples.length; i++) {
      padded[start + i] = samples[i].clamp(0.0, 1.0);
    }
    return padded;
  }
}
