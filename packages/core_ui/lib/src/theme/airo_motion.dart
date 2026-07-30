import 'package:flutter/material.dart';

/// Shared motion grammar for the Airo Living Console.
abstract final class AiroMotion {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration standard = Duration(milliseconds: 200);
  static const Duration spatial = Duration(milliseconds: 300);

  static const Curve emphasis = Cubic(0.2, 0.8, 0.2, 1);
  static const Curve exit = Cubic(0.4, 0, 1, 1);

  static bool isReduced(BuildContext context) {
    return MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  }

  static Duration resolve(BuildContext context, Duration duration) {
    return isReduced(context) ? Duration.zero : duration;
  }
}

/// A restrained fade-and-shift transition used for Material routes.
///
/// Reduced-motion preferences keep the route change immediate.
class AiroPageTransitionsBuilder extends PageTransitionsBuilder {
  const AiroPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (AiroMotion.isReduced(context)) return child;

    final curved = animation.drive(CurveTween(curve: AiroMotion.emphasis));
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: curved.drive(
          Tween<Offset>(begin: const Offset(0.018, 0), end: Offset.zero),
        ),
        child: child,
      ),
    );
  }
}
