import 'package:core_ui/core_ui.dart';
import 'package:feature_iptv/application/multiview_split_ratio.dart';
import 'package:flutter/material.dart';

class MultiviewTwoPaneSplit extends StatefulWidget {
  const MultiviewTwoPaneSplit({
    super.key,
    required this.axis,
    required this.ratio,
    required this.first,
    required this.second,
    this.onSplitRatioChanged,
  });

  final Axis axis;
  final MultiviewSplitRatio ratio;
  final Widget first;
  final Widget second;
  final ValueChanged<MultiviewSplitRatio>? onSplitRatioChanged;

  @override
  State<MultiviewTwoPaneSplit> createState() => _MultiviewTwoPaneSplitState();
}

class _MultiviewTwoPaneSplitState extends State<MultiviewTwoPaneSplit> {
  double? _dragFraction;
  double? _layoutExtent;

  bool get _horizontal => widget.axis == Axis.horizontal;

  (int first, int second) _committedFlexes(
    MultiviewSplitRatio ratio,
    double extent,
  ) {
    final minFlex = (effectiveMultiviewSplitMin(extent) * 1000).round();
    final maxFlex = 1000 - minFlex;
    return switch (ratio) {
      MultiviewSplitRatio.five => (minFlex, maxFlex),
      MultiviewSplitRatio.fifty => (1, 1),
      MultiviewSplitRatio.ninetyFive => (maxFlex, minFlex),
    };
  }

  (int first, int second) _dragFlexes(double drag, double extent) {
    final minFlex = (effectiveMultiviewSplitMin(extent) * 1000).round();
    final maxFlex = 1000 - minFlex;
    final first = (drag * 1000).round().clamp(minFlex, maxFlex);
    return (first, 1000 - first);
  }

  int get _firstFlex {
    final extent = _layoutExtent ?? 0;
    final drag = _dragFraction;
    if (drag != null) return _dragFlexes(drag, extent).$1;
    return _committedFlexes(widget.ratio, extent).$1;
  }

  int get _secondFlex {
    final extent = _layoutExtent ?? 0;
    final drag = _dragFraction;
    if (drag != null) return _dragFlexes(drag, extent).$2;
    return _committedFlexes(widget.ratio, extent).$2;
  }

  void _onDragUpdate(DragUpdateDetails details, BoxConstraints constraints) {
    final extent = _horizontal ? constraints.maxWidth : constraints.maxHeight;
    if (extent <= 0) return;
    final delta = _horizontal ? details.delta.dx : details.delta.dy;
    final current = _dragFraction ?? widget.ratio.firstFraction;
    setState(() {
      _layoutExtent = extent;
      _dragFraction = clampMultiviewSplitFraction(
        current + delta / extent,
        extent: extent,
      );
    });
  }

  void _onDragEnd(DragEndDetails _) {
    final drag = _dragFraction;
    final extent = _layoutExtent;
    if (drag == null || extent == null) return;
    final snapped = snapMultiviewSplitFraction(drag, extent: extent);
    setState(() => _dragFraction = null);
    widget.onSplitRatioChanged?.call(snapped);
  }

  void _onDragCancel() {
    if (_dragFraction == null) return;
    setState(() => _dragFraction = null);
  }

  TvInputResult _onHandleInput(TvInputKey key) {
    final towardSecond = _horizontal
        ? key == TvInputKey.right
        : key == TvInputKey.down;
    final towardFirst = _horizontal
        ? key == TvInputKey.left
        : key == TvInputKey.up;
    if (!towardFirst && !towardSecond) return TvInputResult.notHandled;
    final next = stepMultiviewSplitRatio(
      widget.ratio,
      towardSecond: towardSecond,
    );
    if (next == null) return TvInputResult.notHandled;
    widget.onSplitRatioChanged?.call(next);
    return TvInputResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final extent = _horizontal ? constraints.maxWidth : constraints.maxHeight;
        if (extent > 0) {
          _layoutExtent = extent;
        }
        final children = [
          Expanded(flex: _firstFlex, child: widget.first),
          _SplitHandle(
            axis: widget.axis,
            onDragUpdate: (details) => _onDragUpdate(details, constraints),
            onDragEnd: _onDragEnd,
            onDragCancel: _onDragCancel,
            onInput: _onHandleInput,
          ),
          Expanded(flex: _secondFlex, child: widget.second),
        ];
        if (_horizontal) {
          return Row(children: children);
        }
        return Column(children: children);
      },
    );
  }
}

class _SplitHandle extends StatelessWidget {
  const _SplitHandle({
    required this.axis,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onDragCancel,
    required this.onInput,
  });

  final Axis axis;
  final GestureDragUpdateCallback onDragUpdate;
  final GestureDragEndCallback onDragEnd;
  final VoidCallback onDragCancel;
  final TvInputCallback onInput;

  @override
  Widget build(BuildContext context) {
    final horizontal = axis == Axis.horizontal;
    final gesture = horizontal
        ? GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: onDragUpdate,
            onHorizontalDragEnd: onDragEnd,
            onHorizontalDragCancel: onDragCancel,
            child: _seam(horizontal),
          )
        : GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragUpdate: onDragUpdate,
            onVerticalDragEnd: onDragEnd,
            onVerticalDragCancel: onDragCancel,
            child: _seam(horizontal),
          );
    return TvInputHandler(
      onInput: onInput,
      child: TvFocusable(
        key: const ValueKey('multiview-split-handle'),
        autofocus: false,
        semanticLabel: 'Resize split',
        semanticHint: horizontal
            ? 'Left or right to change size'
            : 'Up or down to change size',
        onSelect: () {},
        child: gesture,
      ),
    );
  }

  Widget _seam(bool horizontal) {
    return ColoredBox(
      color: Colors.white24,
      child: SizedBox(
        width: horizontal ? 24 : double.infinity,
        height: horizontal ? double.infinity : 24,
        child: Center(
          child: ColoredBox(
            color: Colors.white70,
            child: SizedBox(
              width: horizontal ? 4 : 32,
              height: horizontal ? 32 : 4,
            ),
          ),
        ),
      ),
    );
  }
}
