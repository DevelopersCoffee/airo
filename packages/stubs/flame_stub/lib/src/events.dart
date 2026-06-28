/// Stub events for TV builds

/// Tap callbacks mixin
mixin TapCallbacks {
  void onTapDown(TapDownEvent event) {}
  void onTapUp(TapUpEvent event) {}
  void onTapCancel(TapCancelEvent event) {}
}

/// Tap down event stub
class TapDownEvent {
  TapDownEvent({this.x = 0, this.y = 0});
  final double x;
  final double y;

  /// Position of the tap
  ({double x, double y}) get localPosition => (x: x, y: y);
  ({double x, double y}) get canvasPosition => (x: x, y: y);
}

/// Tap up event stub
class TapUpEvent {
  TapUpEvent({this.x = 0, this.y = 0});
  final double x;
  final double y;
}

/// Tap cancel event stub
class TapCancelEvent {}
