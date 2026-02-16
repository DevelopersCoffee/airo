import 'package:flutter/material.dart';
import '../../domain/models/streaming_state.dart';

/// Live badge indicator (P0-7)
///
/// Displays "🔴 LIVE" badge when at live edge.
/// Animates between states for smooth transitions.
class LiveBadge extends StatelessWidget {
  final StreamingState state;
  
  /// Whether to show the badge even when not live (grayed out)
  final bool showWhenNotLive;

  const LiveBadge({
    super.key,
    required this.state,
    this.showWhenNotLive = false,
  });

  @override
  Widget build(BuildContext context) {
    // Only show for live streams
    if (!state.isLiveStream) {
      return const SizedBox.shrink();
    }

    final isAtLive = state.isAtLiveEdge;
    
    // Hide if not at live and showWhenNotLive is false
    if (!isAtLive && !showWhenNotLive) {
      return const SizedBox.shrink();
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isAtLive 
            ? Colors.red.shade700 
            : Colors.grey.shade700,
        borderRadius: BorderRadius.circular(4),
        boxShadow: isAtLive
            ? [
                BoxShadow(
                  color: Colors.red.withValues(alpha: 0.4),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated live dot
          _LiveDot(isActive: isAtLive),
          const SizedBox(width: 4),
          Text(
            'LIVE',
            style: TextStyle(
              color: isAtLive ? Colors.white : Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated pulsing dot for live indicator
class _LiveDot extends StatefulWidget {
  final bool isActive;

  const _LiveDot({required this.isActive});

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    if (widget.isActive) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_LiveDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isActive && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: widget.isActive 
                ? Colors.white.withValues(alpha: _animation.value)
                : Colors.white54,
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}

/// Delay indicator widget (P0-8)
///
/// Shows "45s behind" or "2m 30s behind" when user is behind live.
class DelayIndicator extends StatelessWidget {
  final StreamingState state;
  
  /// Text style override
  final TextStyle? style;

  const DelayIndicator({
    super.key,
    required this.state,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    // Only show when behind live
    if (!state.isBehindLive || state.formattedDelay.isEmpty) {
      return const SizedBox.shrink();
    }

    return AnimatedOpacity(
      opacity: state.isBehindLive ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          state.formattedDelay,
          style: style ?? const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

