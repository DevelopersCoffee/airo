import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

/// Wraps leanback Continue Watching content with a bottom long-press OK hint
/// when any tile in [hintVisible] is true.
class TvContinueWatchingScaffold extends StatelessWidget {
  const TvContinueWatchingScaffold({
    super.key,
    required this.showRemoveHint,
    required this.child,
  });

  final bool showRemoveHint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        child,
        if (showRemoveHint)
          Positioned(
            left: 0,
            right: 0,
            bottom: AiroSpacing.md,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: TvLongPressOkHint(
                message:
                    "Long press 'OK' to remove from continue watching",
              ),
            ),
          ),
      ],
    );
  }
}
