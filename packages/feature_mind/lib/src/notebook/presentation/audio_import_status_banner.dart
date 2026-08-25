import 'package:flutter/material.dart';

import '../application/audio_import_progress.dart';

/// Bottom banner for podcast / YouTube import and queue transcription status.
class AudioImportStatusBanner extends StatelessWidget {
  const AudioImportStatusBanner({
    super.key,
    required this.progress,
    this.onDismiss,
  });

  final AudioImportProgress progress;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final failed = progress.stage == AudioImportStage.failed;
    final done = progress.stage == AudioImportStage.completed;
    final fraction = progress.fraction;

    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(12),
      color: failed
          ? colorScheme.errorContainer
          : colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (!progress.isTerminal)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (done)
                  Icon(Icons.check_circle, color: colorScheme.primary)
                else
                  Icon(Icons.error_outline, color: colorScheme.error),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    progress.title ?? progress.label,
                    style: theme.textTheme.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (progress.isTerminal && onDismiss != null)
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: onDismiss,
                    tooltip: 'Dismiss',
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              failed && progress.error != null
                  ? progress.error!
                  : progress.detail ?? progress.label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: failed
                    ? colorScheme.onErrorContainer
                    : colorScheme.onSurfaceVariant,
              ),
            ),
            if (!progress.isTerminal) ...[
              const SizedBox(height: 12),
              if (fraction != null)
                LinearProgressIndicator(value: fraction)
              else
                const LinearProgressIndicator(),
              if (progress.totalBytes > 0) ...[
                const SizedBox(height: 6),
                Text(
                  '${_formatBytes(progress.receivedBytes)} / ${_formatBytes(progress.totalBytes)}',
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
