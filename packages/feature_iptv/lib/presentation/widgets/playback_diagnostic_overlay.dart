import 'package:flutter/material.dart';
import 'package:platform_player/platform_player.dart';

/// TV-safe playback failure/recovery overlay (CV-001 AUTO-003).
///
/// Renders the diagnostic's user-safe copy, reconnect progress for retryable
/// failures, and — only when [showDetail] is set — the redacted technical
/// detail line for the debug overlay.
class PlaybackDiagnosticOverlay extends StatelessWidget {
  const PlaybackDiagnosticOverlay({
    super.key,
    required this.diagnostic,
    this.retryAttempt,
    this.maxRetryAttempts,
    this.showDetail = false,
  });

  final AiroPlaybackDiagnostic diagnostic;

  /// 1-based attempt currently in flight, when a retry is scheduled.
  final int? retryAttempt;

  final int? maxRetryAttempts;

  final bool showDetail;

  bool get _isReconnecting => diagnostic.retryEligible && retryAttempt != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detail = diagnostic.technicalDetail;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isReconnecting)
                const SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(strokeWidth: 3),
                )
              else
                Icon(
                  diagnostic.severity == AiroPlaybackDiagnosticSeverity.fatal
                      ? Icons.error_outline_rounded
                      : Icons.wifi_tethering_error_rounded,
                  size: 44,
                  color: theme.colorScheme.error,
                ),
              const SizedBox(height: 16),
              Text(
                diagnostic.userMessage,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                ),
              ),
              if (_isReconnecting && maxRetryAttempts != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Attempt $retryAttempt of $maxRetryAttempts',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ],
              if (showDetail && detail != null) ...[
                const SizedBox(height: 12),
                Text(
                  detail,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white54,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
