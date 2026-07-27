import 'package:flutter/widgets.dart';

/// The AiroTV D-pad design's overscan-safe budget
/// (issues/05-device-scaling-overscan.md acceptance criterion 1): no
/// actionable content may cross 32 logical pixels horizontally or 24
/// vertically from the screen edge, since some TV panels/boxes (notably
/// older Fire TV hardware) crop or hide content in that band.
///
/// This is a single source of truth for the inset values -- consolidating
/// what one screen already inlined as a magic literal -- not a claim that
/// every TV screen has been measured against it on real hardware. That
/// qualification (physical Fire TV Stick Lite/4K, Google/Android TV
/// devices; screenshots, MediaQuery values, focus traces) is tracked
/// separately per the issue's own device-matrix requirement.
class TvOverscanConstants {
  TvOverscanConstants._();

  static const double horizontalInset = 32.0;
  static const double verticalInset = 24.0;

  static const EdgeInsets padding = EdgeInsets.symmetric(
    horizontal: horizontalInset,
    vertical: verticalInset,
  );
}

/// Applies [TvOverscanConstants.padding] around [child]. A thin,
/// intention-revealing wrapper so screens opt into the shared budget by
/// name instead of re-typing the literal `EdgeInsets.fromLTRB(32, 24, 32,
/// 24)` (or drifting from it) at each call site.
class TvOverscanSafeArea extends StatelessWidget {
  const TvOverscanSafeArea({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(padding: TvOverscanConstants.padding, child: child);
  }
}
