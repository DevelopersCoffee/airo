import 'package:flutter/material.dart';
import '../../domain/models/streaming_state.dart';

/// "Go Live" button widget (P0-5, P0-6)
///
/// Displays a button to return to live edge when user is behind live.
/// Touch-optimized with minimum 48dp touch target for accessibility.
///
/// Visibility logic (P0-5):
/// - Shows when: delay > 3 seconds OR stream is paused
/// - Hides when: at live edge (delay <= 3 seconds)
class GoLiveButton extends StatelessWidget {
  /// Callback when button is tapped (P0-6: seekToLiveEdge)
  final VoidCallback onGoLive;

  /// Current streaming state to determine visibility
  final StreamingState state;

  /// Optional custom label (default: "Go Live")
  final String? label;

  /// Whether to show compact version (icon only)
  final bool compact;

  /// Whether button is enabled
  final bool enabled;

  const GoLiveButton({
    super.key,
    required this.onGoLive,
    required this.state,
    this.label,
    this.compact = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    // P0-5: Visibility logic
    if (!state.shouldShowGoLive) {
      return const SizedBox.shrink();
    }

    return AnimatedOpacity(
      opacity: state.shouldShowGoLive ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: compact ? _buildCompactButton(context) : _buildFullButton(context),
    );
  }

  Widget _buildFullButton(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onGoLive : null,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _getBackgroundColor(),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Live indicator dot
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _getLiveIndicatorColor(),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              // Button text
              Text(
                label ?? 'Go Live',
                style: TextStyle(
                  color: enabled ? Colors.white : Colors.white54,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactButton(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onGoLive : null,
        borderRadius: BorderRadius.circular(20),
        // Minimum 48dp touch target for accessibility
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _getBackgroundColor(),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.skip_next_rounded,
                color: enabled ? Colors.white : Colors.white54,
                size: 24,
              ),
              // Live indicator dot
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _getLiveIndicatorColor(),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getBackgroundColor() {
    if (!enabled) return Colors.grey.shade800;
    // Red tint when behind live to indicate urgency
    if (state.isBehindLive) return Colors.red.shade700.withValues(alpha: 0.9);
    return Colors.black.withValues(alpha: 0.7);
  }

  Color _getLiveIndicatorColor() {
    if (!enabled) return Colors.grey;
    // Pulsing red for "live" concept
    return Colors.red;
  }
}

