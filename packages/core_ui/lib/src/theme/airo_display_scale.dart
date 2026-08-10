import 'package:flutter/material.dart';

import 'airo_motion.dart';
import 'airo_typography.dart';

/// Applies [AiroTypography]'s resolution-aware type scale to the active
/// theme's [TextTheme] while preserving everything else (colors, shapes,
/// extensions). Mirrors [AiroDomainTheme]'s pattern for the typography axis.
///
/// Place near the top of a flavor's widget tree, inside `MaterialApp.builder`
/// or immediately under it, so every descendant's `Theme.of(context)
/// .textTheme` already reflects the current [AiroDisplayProfile].
class AiroDisplayScale extends StatelessWidget {
  const AiroDisplayScale({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final scaledTextTheme = AiroTypography.of(context);

    return AnimatedTheme(
      data: base.copyWith(textTheme: scaledTextTheme),
      duration: AiroMotion.resolve(context, AiroMotion.standard),
      curve: AiroMotion.emphasis,
      child: child,
    );
  }
}
