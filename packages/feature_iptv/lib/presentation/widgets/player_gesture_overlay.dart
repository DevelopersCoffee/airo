import 'dart:async';
import 'package:flutter/material.dart';

/// Converts a vertical drag delta into a fractional value change for
/// Netflix/YouTube-style brightness and volume gestures.
///
/// Dragging up (negative `dy`) increases the value; a drag spanning the full
/// viewport height maps to a 100% change.
double playerGestureValueDelta({
  required double dy,
  required double viewportHeight,
}) {
  if (viewportHeight <= 0) return 0;
  return -dy / viewportHeight;
}

/// Clamps a gesture-driven value into the valid `0.0`-`1.0` range.
double clampPlayerGestureValue(double value) => value.clamp(0.0, 1.0);

/// Which control a vertical drag adjusts, based on which half of the
/// viewport it starts in.
enum PlayerGestureZone {
  brightness,
  volume;

  /// The left half of the viewport controls brightness, the right half
  /// controls volume — the standard Netflix/YouTube split. The exact
  /// midpoint falls into the (right) volume zone.
  static PlayerGestureZone forDx({
    required double dx,
    required double viewportWidth,
  }) {
    return dx < viewportWidth / 2
        ? PlayerGestureZone.brightness
        : PlayerGestureZone.volume;
  }
}

/// Wraps the video surface with Netflix-style vertical drag gestures:
/// dragging on the left half adjusts screen brightness, the right half
/// adjusts playback volume. Shows an ephemeral icon + fill indicator while a
/// value is changing, matching the mute-button/slider it replaces.
///
/// Disabled entirely while [locked] is true, so the lock button is the only
/// way to affect playback state.
class PlayerGestureOverlay extends StatefulWidget {
  const PlayerGestureOverlay({
    super.key,
    required this.child,
    required this.locked,
    required this.brightness,
    required this.volume,
    required this.onBrightnessChanged,
    required this.onVolumeChanged,
    this.onTap,
  });

  final Widget child;
  final bool locked;

  /// Current values in the `0.0`-`1.0` range; the overlay reads these as the
  /// starting point of each new drag rather than owning the value itself.
  final double brightness;
  final double volume;

  final ValueChanged<double> onBrightnessChanged;
  final ValueChanged<double> onVolumeChanged;
  final VoidCallback? onTap;

  @override
  State<PlayerGestureOverlay> createState() => _PlayerGestureOverlayState();
}

class _PlayerGestureOverlayState extends State<PlayerGestureOverlay> {
  static const _indicatorLingerDuration = Duration(milliseconds: 700);

  PlayerGestureZone? _activeZone;
  double? _dragStartValue;
  double _liveValue = 0;
  Timer? _indicatorHideTimer;

  @override
  void dispose() {
    _indicatorHideTimer?.cancel();
    super.dispose();
  }

  void _onDragStart(DragStartDetails details, double viewportWidth) {
    if (widget.locked) return;
    _indicatorHideTimer?.cancel();
    final zone = PlayerGestureZone.forDx(
      dx: details.localPosition.dx,
      viewportWidth: viewportWidth,
    );
    setState(() {
      _activeZone = zone;
      _dragStartValue = zone == PlayerGestureZone.brightness
          ? widget.brightness
          : widget.volume;
      _liveValue = _dragStartValue!;
    });
  }

  void _onDragUpdate(DragUpdateDetails details, double viewportHeight) {
    final zone = _activeZone;
    final startValue = _dragStartValue;
    if (widget.locked || zone == null || startValue == null) return;

    final delta = playerGestureValueDelta(
      dy: details.primaryDelta ?? 0,
      viewportHeight: viewportHeight,
    );
    // Accumulate against the live value (not just the drag start) so each
    // incremental frame's delta compounds correctly across the gesture.
    final next = clampPlayerGestureValue(_liveValue + delta);
    setState(() => _liveValue = next);
    switch (zone) {
      case PlayerGestureZone.brightness:
        widget.onBrightnessChanged(next);
      case PlayerGestureZone.volume:
        widget.onVolumeChanged(next);
    }
  }

  void _onDragEnd(DragEndDetails details) {
    if (widget.locked) return;
    _indicatorHideTimer?.cancel();
    _indicatorHideTimer = Timer(_indicatorLingerDuration, () {
      if (!mounted) return;
      setState(() {
        _activeZone = null;
        _dragStartValue = null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        return Stack(
          fit: StackFit.expand,
          children: [
            widget.child,
            if (!widget.locked)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: widget.onTap,
                  onVerticalDragStart: (d) => _onDragStart(d, width),
                  onVerticalDragUpdate: (d) => _onDragUpdate(d, height),
                  onVerticalDragEnd: _onDragEnd,
                ),
              ),
            if (_activeZone != null)
              _GestureValueIndicator(
                key: ValueKey('player-gesture-indicator-${_activeZone!.name}'),
                zone: _activeZone!,
                value: _liveValue,
              ),
          ],
        );
      },
    );
  }
}

class _GestureValueIndicator extends StatelessWidget {
  const _GestureValueIndicator({
    super.key,
    required this.zone,
    required this.value,
  });

  final PlayerGestureZone zone;
  final double value;

  @override
  Widget build(BuildContext context) {
    final icon = switch (zone) {
      PlayerGestureZone.brightness =>
        value < 0.5 ? Icons.brightness_low : Icons.brightness_high,
      PlayerGestureZone.volume =>
        value == 0
            ? Icons.volume_off
            : value < 0.5
            ? Icons.volume_down
            : Icons.volume_up,
    };
    return Center(
      child: Container(
        width: 88,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(height: 8),
            SizedBox(
              height: 80,
              width: 4,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Container(color: Colors.white24),
                  FractionallySizedBox(
                    heightFactor: value,
                    child: Container(color: Colors.white),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(value * 100).round()}%',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
