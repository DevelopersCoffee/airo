import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Live mic meter for an in-progress recording.
///
/// Bars dance from a mix of the real [amplitude] and a looping idle wave so
/// the strip still moves in a quiet room — the "something is happening"
/// feedback a flat timer does not give.
class MeetingRecordingVisualizer extends StatefulWidget {
  const MeetingRecordingVisualizer({
    required this.recording,
    required this.amplitude,
    super.key,
  });

  final bool recording;
  final double amplitude;

  @override
  State<MeetingRecordingVisualizer> createState() =>
      _MeetingRecordingVisualizerState();
}

class _MeetingRecordingVisualizerState extends State<MeetingRecordingVisualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    if (widget.recording) _pulse.repeat();
  }

  @override
  void didUpdateWidget(covariant MeetingRecordingVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.recording && !_pulse.isAnimating) {
      _pulse.repeat();
    } else if (!widget.recording && _pulse.isAnimating) {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      key: const Key('meeting_capture_visualizer'),
      height: 88,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          return CustomPaint(
            painter: _WavePainter(
              t: _pulse.value,
              amplitude: widget.amplitude.clamp(0.0, 1.0),
              recording: widget.recording,
              color: scheme.error,
              glow: scheme.error.withValues(alpha: 0.35),
            ),
          );
        },
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  const _WavePainter({
    required this.t,
    required this.amplitude,
    required this.recording,
    required this.color,
    required this.glow,
  });

  final double t;
  final double amplitude;
  final bool recording;
  final Color color;
  final Color glow;

  static const _barCount = 36;

  @override
  void paint(Canvas canvas, Size size) {
    final midY = size.height / 2;
    final gap = size.width / _barCount;
    final barWidth = math.max(2.5, gap * 0.42);
    final time = t * math.pi * 2;

    if (recording) {
      final glowPaint = Paint()
        ..color = glow
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(size.width / 2, midY),
            width: size.width * (0.45 + 0.25 * amplitude),
            height: size.height * (0.35 + 0.45 * amplitude),
          ),
          const Radius.circular(24),
        ),
        glowPaint,
      );
    }

    final paint = Paint()
      ..color = color.withValues(alpha: recording ? 1 : 0.28);

    for (var i = 0; i < _barCount; i++) {
      final centerBias =
          1.0 - ((i - (_barCount - 1) / 2).abs() / (_barCount / 2));
      final phase = i * 0.42;
      final idle = 0.5 + 0.5 * math.sin(time * (1.4 + i * 0.07) + phase);
      final energy = recording
          ? (0.16 + amplitude * 0.84) *
                (0.45 + 0.55 * idle) *
                (0.55 + 0.45 * centerBias)
          : 0.08 + 0.04 * idle;
      final height = (energy.clamp(0.06, 1.0)) * size.height * 0.92;
      final x = (i + 0.5) * gap;
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x, midY),
          width: barWidth,
          height: height,
        ),
        Radius.circular(barWidth),
      );
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) {
    return oldDelegate.t != t ||
        oldDelegate.amplitude != amplitude ||
        oldDelegate.recording != recording ||
        oldDelegate.color != color;
  }
}
