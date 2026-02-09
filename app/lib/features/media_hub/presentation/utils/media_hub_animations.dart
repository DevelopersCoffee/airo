import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Animation constants for Media Hub following Material Design guidelines.
///
/// All durations and curves are standardized for consistent UX.
class MediaHubAnimations {
  MediaHubAnimations._();

  // Duration constants
  static const Duration playerCollapse = Duration(milliseconds: 300);
  static const Duration chipSelection = Duration(milliseconds: 200);
  static const Duration modeSwitch = Duration(milliseconds: 300);
  static const Duration controlsFade = Duration(milliseconds: 300);
  static const Duration thumbnailFade = Duration(milliseconds: 200);
  static const Duration shimmer = Duration(milliseconds: 1500);
  static const Duration pressScale = Duration(milliseconds: 100);

  // Curve constants
  static const Curve playerCollapseCurve = Curves.easeOutCubic;
  static const Curve chipSelectionCurve = Curves.easeOut;
  static const Curve modeSwitchCurve = Curves.easeInOut;
  static const Curve controlsFadeCurve = Curves.linear;
  static const Curve thumbnailFadeCurve = Curves.easeIn;
  static const Curve pressScaleCurve = Curves.easeInOut;

  /// Trigger light haptic feedback on mobile platforms
  static void lightHaptic() {
    if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
      HapticFeedback.lightImpact();
    }
  }

  /// Trigger medium haptic feedback on mobile platforms
  static void mediumHaptic() {
    if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
      HapticFeedback.mediumImpact();
    }
  }

  /// Trigger selection haptic feedback on mobile platforms
  static void selectionHaptic() {
    if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
      HapticFeedback.selectionClick();
    }
  }
}

/// A widget that provides press/hover feedback with scale animation.
///
/// Wraps any child widget and adds:
/// - Scale down on press (0.95)
/// - Haptic feedback on tap (mobile)
/// - Hover state for desktop/web
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scaleDown = 0.95,
    this.enableHaptic = true,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scaleDown;
  final bool enableHaptic;
  final bool enabled;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: MediaHubAnimations.pressScale,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.scaleDown).animate(
      CurvedAnimation(
        parent: _controller,
        curve: MediaHubAnimations.pressScaleCurve,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.enabled) {
      _controller.forward();
    }
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  void _onTap() {
    if (widget.enabled) {
      if (widget.enableHaptic) {
        MediaHubAnimations.lightHaptic();
      }
      widget.onTap?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.enabled && widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        onTap: widget.onTap != null ? _onTap : null,
        onLongPress: widget.onLongPress,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: AnimatedOpacity(
            duration: MediaHubAnimations.pressScale,
            opacity: widget.enabled ? (_isHovered ? 0.9 : 1.0) : 0.5,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Shimmer loading effect for content placeholders.
class ShimmerLoading extends StatefulWidget {
  const ShimmerLoading({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
  });

  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: MediaHubAnimations.shimmer,
      vsync: this,
    )..repeat();
    _animation = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor =
        widget.baseColor ?? theme.colorScheme.surfaceContainerHighest;
    final highlightColor = widget.highlightColor ?? theme.colorScheme.surface;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [baseColor, highlightColor, baseColor],
              stops: [
                (_animation.value - 0.3).clamp(0.0, 1.0),
                _animation.value.clamp(0.0, 1.0),
                (_animation.value + 0.3).clamp(0.0, 1.0),
              ],
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: widget.child,
        );
      },
    );
  }
}

/// Animated fade-in widget for thumbnails and images.
class FadeInWidget extends StatefulWidget {
  const FadeInWidget({
    super.key,
    required this.child,
    this.duration = MediaHubAnimations.thumbnailFade,
    this.curve = MediaHubAnimations.thumbnailFadeCurve,
  });

  final Widget child;
  final Duration duration;
  final Curve curve;

  @override
  State<FadeInWidget> createState() => _FadeInWidgetState();
}

class _FadeInWidgetState extends State<FadeInWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _animation = CurvedAnimation(parent: _controller, curve: widget.curve);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _animation, child: widget.child);
  }
}
