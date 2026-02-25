/// Stub GameWidget for TV builds
import 'package:flutter/material.dart';
import 'game.dart';

/// Stub GameWidget - renders a placeholder for TV builds
class GameWidget<T extends FlameGame> extends StatelessWidget {
  final T game;
  final Widget? loadingBuilder;
  final Widget? errorBuilder;
  final Widget? backgroundBuilder;
  final Widget? overlayBuilderMap;
  
  const GameWidget({
    super.key,
    required this.game,
    this.loadingBuilder,
    this.errorBuilder,
    this.backgroundBuilder,
    this.overlayBuilderMap,
  });
  
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Games not available on TV',
        style: TextStyle(color: Colors.white54),
      ),
    );
  }
}

