import 'package:flutter/widgets.dart';

/// Isolates a subtree that repaints often from the rest of the screen.
///
/// A 120 Hz panel drops any frame that takes longer than 8.33 ms. An
/// animating clock, progress ring, or canvas should not invalidate static
/// chrome on every tick. [RepaintBoundary] gives that subtree its own layer.
class AiroRepaintIsland extends StatelessWidget {
  const AiroRepaintIsland({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(child: child);
  }
}
