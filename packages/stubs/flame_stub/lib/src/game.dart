/// Stub FlameGame class for TV builds
import 'dart:ui';
import 'package:flutter/widgets.dart';
import 'package:flutter/rendering.dart';

/// Stub FlameGame - provides base game functionality
abstract class FlameGame extends ChangeNotifier {
  /// Game size
  Vector2 get size => Vector2(800, 600);

  /// Called when game is loaded
  Future<void> onLoad() async {}

  /// Called to render the game
  void render(Canvas canvas) {}

  /// Called to update game state
  void update(double dt) {}

  /// Attach to game widget
  void attach(PipelineOwner owner) {}

  /// Detach from game widget
  void detach() {}

  /// Called when game is removed
  void onRemove() {}

  /// Called when game size changes
  void onGameResize(Vector2 size) {}
}

/// Simple 2D vector
class Vector2 {
  final double x;
  final double y;

  const Vector2(this.x, this.y);

  static Vector2 zero() => const Vector2(0, 0);
}
