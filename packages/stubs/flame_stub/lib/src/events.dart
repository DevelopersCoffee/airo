/// Stub events for TV builds

/// Tap callbacks mixin
mixin TapCallbacks {
  void onTapDown(TapDownEvent event) {}
  void onTapUp(TapUpEvent event) {}
  void onTapCancel(TapCancelEvent event) {}
}

/// Tap down event stub
class TapDownEvent {
  final double x;
  final double y;
  
  TapDownEvent({this.x = 0, this.y = 0});
  
  /// Position of the tap
  ({double x, double y}) get localPosition => (x: x, y: y);
  ({double x, double y}) get canvasPosition => (x: x, y: y);
}

/// Tap up event stub
class TapUpEvent {
  final double x;
  final double y;
  
  TapUpEvent({this.x = 0, this.y = 0});
}

/// Tap cancel event stub
class TapCancelEvent {}

