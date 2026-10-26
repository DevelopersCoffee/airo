import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../theme/airo_domain.dart';
import '../theme/airo_motion.dart';
import '../widgets/airo_repaint_island.dart';

/// A thin animated edge for a video or audio surface.
///
/// Aika Stream plays a picture, not an audio-reactive canvas. A full-screen
/// wave drawn once per horizontal pixel would cover the program and spend
/// the frame budget on paint. This glow is a short two-stroke ribbon the
/// caller places along an edge, outside the video-capture
/// [RepaintBoundary], so a shared frame stays clean and D-pad or touch
/// targets above it still receive hits.
///
/// [level] is optional energy in the range 0 to 1. Playback does not expose
/// frequency data today, so 0 is a calm idle drift. A later audio meter can
/// pass a louder level without changing the widget.
///
/// Reduced-motion preferences paint one still ribbon and do not tick.
class AiroStreamGlow extends StatefulWidget {
  const AiroStreamGlow({super.key, this.active = true, this.level = 0});

  /// When false, the ticker stops and nothing is painted.
  final bool active;

  /// Extra lift for the ribbon, clamped to 0..1.
  final double level;

  @override
  State<AiroStreamGlow> createState() => _AiroStreamGlowState();
}

class _AiroStreamGlowState extends State<AiroStreamGlow>
    with SingleTickerProviderStateMixin {
  static const _cycle = Duration(milliseconds: 6400);

  late final AnimationController _motion;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(vsync: this, duration: _cycle);
  }

  @override
  void didUpdateWidget(AiroStreamGlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTicker();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTicker();
  }

  void _syncTicker() {
    final reduced = AiroMotion.isReduced(context);
    final shouldTick = widget.active && !reduced;
    if (shouldTick && !_motion.isAnimating) {
      _motion.repeat();
    } else if (!shouldTick && _motion.isAnimating) {
      _motion.stop();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return const SizedBox.shrink();

    final domain = AiroDomainTokens.of(context);
    final reduced = AiroMotion.isReduced(context);
    final level = widget.level.clamp(0.0, 1.0).toDouble();
    final painter = _StreamRibbonPainter(
      progress: reduced ? 0 : _motion.value,
      level: level,
      primary: domain.accent,
      secondary: domain.accentSecondary,
    );

    return IgnorePointer(
      child: AiroRepaintIsland(
        child: CustomPaint(
          key: const ValueKey('airo-stream-glow'),
          painter: painter,
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _StreamRibbonPainter extends CustomPainter {
  const _StreamRibbonPainter({
    required this.progress,
    required this.level,
    required this.primary,
    required this.secondary,
  });

  final double progress;
  final double level;
  final Color primary;
  final Color secondary;

  static const _samples = 24;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final phase = progress * math.pi * 2;
    final amplitude = size.height * (0.12 + 0.18 * level);
    _stroke(
      canvas,
      size,
      phase: phase,
      amplitude: amplitude,
      verticalShift: 0,
      color: primary.withValues(alpha: 0.55),
      width: 1.6,
    );
    _stroke(
      canvas,
      size,
      phase: phase + 0.8,
      amplitude: amplitude * 0.65,
      verticalShift: 4,
      color: secondary.withValues(alpha: 0.35),
      width: 3.2,
    );
  }

  void _stroke(
    Canvas canvas,
    Size size, {
    required double phase,
    required double amplitude,
    required double verticalShift,
    required Color color,
    required double width,
  }) {
    final path = Path();
    final midY = size.height * 0.55 + verticalShift;
    for (var sample = 0; sample <= _samples; sample++) {
      final t = sample / _samples;
      final x = size.width * t;
      final y =
          midY +
          math.sin((t * math.pi * 2) + phase) * amplitude +
          math.sin((t * math.pi * 4) + phase * 1.5) * amplitude * 0.35;
      if (sample == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(covariant _StreamRibbonPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.level != level ||
        oldDelegate.primary != primary ||
        oldDelegate.secondary != secondary;
  }
}
