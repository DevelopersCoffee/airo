import 'package:core_ui/core_ui.dart';
import 'package:feature_iptv/application/multiview_split_ratio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class MultiviewTwoPaneSplit extends StatefulWidget {
  const MultiviewTwoPaneSplit({
    super.key,
    required this.axis,
    required this.ratio,
    required this.first,
    required this.second,
    this.onSplitRatioChanged,
    this.onSplitMixPreview,
  });

  final Axis axis;
  final MultiviewSplitRatio ratio;
  final Widget first;
  final Widget second;
  final ValueChanged<MultiviewSplitRatio>? onSplitRatioChanged;
  final void Function(double fraction, double extent)? onSplitMixPreview;

  @override
  State<MultiviewTwoPaneSplit> createState() => _MultiviewTwoPaneSplitState();
}

class _MultiviewTwoPaneSplitState extends State<MultiviewTwoPaneSplit> {
  double? _dragFraction;
  double? _layoutExtent;
  int? _mixPreviewFrameId;
  double? _pendingMixFraction;
  double? _pendingMixExtent;

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

  @override
  void dispose() {
    _cancelMixPreview();
    super.dispose();
  }

  void _cancelMixPreview() {
    final frameId = _mixPreviewFrameId;
    if (frameId != null) {
      SchedulerBinding.instance.cancelFrameCallbackWithId(frameId);
      _mixPreviewFrameId = null;
    }
    _pendingMixFraction = null;
    _pendingMixExtent = null;
  }

  void _scheduleMixPreview(double fraction, double extent) {
    if (widget.onSplitMixPreview == null) return;
    _pendingMixFraction = fraction;
    _pendingMixExtent = extent;
    if (_mixPreviewFrameId != null) return;
    _mixPreviewFrameId = SchedulerBinding.instance.scheduleFrameCallback((_) {
      _mixPreviewFrameId = null;
      final pendingFraction = _pendingMixFraction;
      final pendingExtent = _pendingMixExtent;
      _pendingMixFraction = null;
      _pendingMixExtent = null;
      if (!mounted || pendingFraction == null || pendingExtent == null) return;
      widget.onSplitMixPreview?.call(pendingFraction, pendingExtent);
    });
  }

  void _onDragUpdate(DragUpdateDetails details, BoxConstraints constraints) {
    final extent = _horizontal ? constraints.maxWidth : constraints.maxHeight;
    if (extent <= 0) return;
    final delta = _horizontal ? details.delta.dx : details.delta.dy;
    final current = _dragFraction ?? widget.ratio.firstFraction;
    final next = clampMultiviewSplitFraction(
      current + delta / extent,
      extent: extent,
    );
    setState(() {
      _layoutExtent = extent;
      _dragFraction = next;
    });
    _scheduleMixPreview(next, extent);
  }

  void _onDragEnd(DragEndDetails _) {
    _cancelMixPreview();
    final drag = _dragFraction;
    final extent = _layoutExtent;
    if (drag == null || extent == null) return;
    final snapped = snapMultiviewSplitFraction(drag, extent: extent);
    setState(() => _dragFraction = null);
    widget.onSplitRatioChanged?.call(snapped);
  }

  void _onDragCancel() {
    _cancelMixPreview();
    if (_dragFraction == null) return;
    final extent = _layoutExtent;
    setState(() => _dragFraction = null);
    if (extent != null && extent > 0) {
      widget.onSplitMixPreview?.call(widget.ratio.firstFraction, extent);
    }
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
        final extent = _horizontal
            ? constraints.maxWidth
            : constraints.maxHeight;
        if (extent > 0) {
          _layoutExtent = extent;
        }
        final compact =
            constraints.maxWidth < 600 || constraints.maxHeight < 600;
        final children = [
          Expanded(flex: _firstFlex, child: widget.first),
          _SplitHandle(
            axis: widget.axis,
            hitCrossAxis: compact ? 48 : 24,
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

class _SplitHandle extends StatefulWidget {
  const _SplitHandle({
    required this.axis,
    required this.hitCrossAxis,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onDragCancel,
    required this.onInput,
  });

  final Axis axis;
  final double hitCrossAxis;
  final GestureDragUpdateCallback onDragUpdate;
  final GestureDragEndCallback onDragEnd;
  final VoidCallback onDragCancel;
  final TvInputCallback onInput;

  @override
  State<_SplitHandle> createState() => _SplitHandleState();
}

class _SplitHandleState extends State<_SplitHandle> {
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final horizontal = widget.axis == Axis.horizontal;
    return TvInputHandler(
      onInput: widget.onInput,
      child: TvFocusable(
        key: const ValueKey('multiview-split-handle'),
        focusNode: _focusNode,
        autofocus: false,
        showScaleEffect: false,
        showBorderEffect: false,
        showGlowEffect: false,
        semanticLabel: 'Resize split',
        semanticHint: horizontal
            ? 'Left or right to change size'
            : 'Up or down to change size',
        onSelect: () {},
        child: ListenableBuilder(
          listenable: _focusNode,
          builder: (context, _) {
            final seam = _seam(
              horizontal: horizontal,
              focused: _focusNode.hasFocus,
            );
            if (horizontal) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: widget.onDragUpdate,
                onHorizontalDragEnd: widget.onDragEnd,
                onHorizontalDragCancel: widget.onDragCancel,
                child: seam,
              );
            }
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragUpdate: widget.onDragUpdate,
              onVerticalDragEnd: widget.onDragEnd,
              onVerticalDragCancel: widget.onDragCancel,
              child: seam,
            );
          },
        ),
      ),
    );
  }

  Widget _seam({required bool horizontal, required bool focused}) {
    const hairline = 2.0;
    const gripCross = 8.0;
    const gripAlong = 28.0;
    final hit = widget.hitCrossAxis;
    return SizedBox(
      width: horizontal ? hit : double.infinity,
      height: horizontal ? double.infinity : hit,
      child: Align(
        child: FractionallySizedBox(
          widthFactor: horizontal ? null : 1 / 3,
          heightFactor: horizontal ? 1 / 3 : null,
          child: Stack(
            alignment: Alignment.center,
            children: [
              ColoredBox(
                color: Colors.white.withValues(alpha: 0.28),
                child: SizedBox(
                  width: horizontal ? hairline : double.infinity,
                  height: horizontal ? double.infinity : hairline,
                ),
              ),
              Transform.scale(
                scale: focused ? 1.05 : 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(
                      alpha: focused ? 0.80 : 0.55,
                    ),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: focused
                        ? const [
                            BoxShadow(color: Colors.white70, blurRadius: 8),
                          ]
                        : null,
                  ),
                  child: SizedBox(
                    width: horizontal ? gripCross : gripAlong,
                    height: horizontal ? gripAlong : gripCross,
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
