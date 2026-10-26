import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A [ListView.builder] for long collections.
///
/// Only the visible window is built, so a long dataset does not spend the
/// 8.33 ms frame budget laying out off-screen rows. [ListView] already gives
/// each child its own [RepaintBoundary] when [isolateItems] is true, which
/// is the framework's per-row layer. Use [AiroRepaintIsland] for a widget
/// that repaints outside a lazy list, such as a spinner or a canvas.
class AiroLazyList extends StatelessWidget {
  const AiroLazyList({
    required this.itemCount,
    required this.itemBuilder,
    super.key,
    this.controller,
    this.padding,
    this.scrollDirection = Axis.vertical,
    this.isolateItems = true,
    this.cacheExtent,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;
  final Axis scrollDirection;
  final bool isolateItems;
  final double? cacheExtent;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: controller,
      padding: padding,
      scrollDirection: scrollDirection,
      itemCount: itemCount,
      scrollCacheExtent: cacheExtent == null
          ? null
          : ScrollCacheExtent.pixels(cacheExtent!),
      addRepaintBoundaries: isolateItems,
      itemBuilder: itemBuilder,
    );
  }
}
