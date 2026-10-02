import 'package:flutter/material.dart';

import '../theme/airo_spacing.dart';
import '../theme/airo_typography.dart';

/// Bottom-of-screen hint shown when a Continue Watching tile has D-pad focus
/// (SonyLIV-style leanback pattern).
class TvLongPressOkHint extends StatelessWidget {
  const TvLongPressOkHint({
    super.key,
    this.message = "Long press 'OK' to remove from continue watching",
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(AiroSpacing.radiusLg),
          border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.6)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AiroSpacing.lg,
            vertical: AiroSpacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _RemoteOkGlyph(),
              const SizedBox(width: AiroSpacing.md),
              Flexible(
                child: Text(
                  message,
                  style: AiroTypography.labelLarge.copyWith(
                    color: colors.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RemoteOkGlyph extends StatelessWidget {
  const _RemoteOkGlyph();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    return SizedBox(
      width: 36,
      height: 36,
      child: CustomPaint(painter: _RemoteOkPainter(color: color)),
    );
  }
}

class _RemoteOkPainter extends CustomPainter {
  _RemoteOkPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final fill = Paint()..color = color;

    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(center, size.width * 0.38, stroke);

    const dotRadius = 2.0;
    final arm = size.width * 0.22;
    for (final offset in [
      Offset(0, -arm),
      Offset(arm, 0),
      Offset(0, arm),
      Offset(-arm, 0),
    ]) {
      canvas.drawCircle(center + offset, dotRadius, fill);
    }
    canvas.drawCircle(center, 4.5, stroke);
    final ok = TextPainter(
      text: TextSpan(
        text: 'OK',
        style: TextStyle(
          color: color,
          fontSize: 6.5,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    ok.paint(canvas, center - Offset(ok.width / 2, ok.height / 2));
  }

  @override
  bool shouldRepaint(covariant _RemoteOkPainter oldDelegate) =>
      oldDelegate.color != color;
}
