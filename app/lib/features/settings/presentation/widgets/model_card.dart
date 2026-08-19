import 'package:flutter/material.dart';
import 'package:core_ai/core_ai.dart';

import 'credibility_badge.dart';

/// A card widget displaying information about an offline AI model.
///
/// Shows model name, family, size, credibility, and download/active status.
/// Inspired by ModelCard.tsx from the reference implementation.
class ModelCard extends StatelessWidget {
  const ModelCard({
    super.key,
    required this.model,
    this.isActive = false,
    this.isDownloading = false,
    this.downloadProgress,
    this.downloadStatus,
    this.downloadSpeed,
    this.downloadEta,
    this.isCompatible = true,
    this.onTap,
    this.onDownload,
    this.onDelete,
    this.onSetActive,
    this.onCancelDownload,
    this.onPauseDownload,
    this.onResumeDownload,
    this.onRetryDownload,
    this.onLearnMore,
    this.readiness,
  });

  /// The model to display.
  final OfflineModelInfo model;

  /// Whether this model is currently active/loaded.
  final bool isActive;

  /// Whether the model is being downloaded.
  final bool isDownloading;

  /// Download progress from 0.0 to 1.0.
  final double? downloadProgress;

  /// Current stage display (e.g. "Downloading" or "Verifying").
  final String? downloadStatus;

  /// Download speed display (e.g., "2.5 MB/s").
  final String? downloadSpeed;

  /// Estimated time remaining display (e.g., "5m 30s remaining").
  final String? downloadEta;

  /// Whether the model is compatible with this device.
  final bool isCompatible;

  /// Callback when the card is tapped.
  final VoidCallback? onTap;

  /// Callback to initiate download.
  final VoidCallback? onDownload;

  /// Callback to delete the model.
  final VoidCallback? onDelete;

  /// Callback to set this model as active.
  final VoidCallback? onSetActive;

  /// Callback to cancel an in-progress download.
  final VoidCallback? onCancelDownload;

  /// Pause, resume, or retry callbacks for the persistent download manager.
  final VoidCallback? onPauseDownload;
  final VoidCallback? onResumeDownload;
  final VoidCallback? onRetryDownload;

  /// Callback to open the model source page.
  final VoidCallback? onLearnMore;

  /// Download vs runtime readiness for installed packages.
  final ModelReadinessState? readiness;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDownloaded = model.isDownloaded;
    final semanticsLabel =
        'Model: ${model.name}. '
        'Family: ${model.family.displayName}. '
        'Size: ${model.fileSizeDisplay}. '
        '${isActive ? "Active." : ""} '
        '${isDownloading ? "Downloading." : ""} '
        '${isDownloaded && !isActive ? "Downloaded." : "Not downloaded."}';

    return Semantics(
      container: true,
      label: semanticsLabel,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row: Name + badges
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            model.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (model.author != null)
                            Text(
                              model.author!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    CredibilityBadge(
                      credibility: model.credibility,
                      size: CredibilityBadgeSize.small,
                    ),
                    if (onLearnMore != null)
                      IconButton(
                        onPressed: onLearnMore,
                        icon: const Icon(Icons.open_in_new, size: 18),
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Learn more',
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Info row: Family, Size, Quantization
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _InfoChip(
                      icon: Icons.category_outlined,
                      label: model.family.displayName,
                    ),
                    _InfoChip(
                      icon: Icons.storage_outlined,
                      label: model.fileSizeDisplay,
                    ),
                    _InfoChip(
                      icon: Icons.memory_outlined,
                      label: model.quantization.displayName,
                    ),
                    for (final modality in model.modalities)
                      if (modality != ModelModality.toolCall)
                        _InfoChip(
                          icon: switch (modality) {
                            ModelModality.text => Icons.chat_bubble_outline,
                            ModelModality.image => Icons.image_outlined,
                            ModelModality.audio => Icons.mic_none_outlined,
                            ModelModality.toolCall => Icons.build_outlined,
                          },
                          label: modality.displayName,
                        ),
                    if (model.contextLength > 2048)
                      _InfoChip(
                        icon: Icons.format_list_numbered,
                        label: '${(model.contextLength / 1024).round()}K ctx',
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Status row: Downloaded/Downloading/Download button
                _buildStatusRow(context, isDownloaded),

                if (readiness != null && isDownloaded && readiness!.isRunnable)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            readiness!.headline,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                if (readiness != null && isDownloaded && !readiness!.isRunnable)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: theme.colorScheme.tertiary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            readiness!.detail.isNotEmpty
                                ? readiness!.detail
                                : readiness!.headline,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Compatibility warning
                if (!isCompatible)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 16,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'May exceed device memory',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusRow(BuildContext context, bool isDownloaded) {
    final theme = Theme.of(context);

    if (isDownloading && downloadProgress != null) {
      final percentage = (downloadProgress! * 100).round();
      return Semantics(
        liveRegion: true,
        label:
            'Download progress: ${downloadStatus ?? "Downloading"} $percentage percent. ${downloadEta ?? ""}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress info row
            Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text(
                  downloadStatus ?? 'Downloading',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Text('$percentage%', style: theme.textTheme.bodySmall),
                if (downloadSpeed != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '• $downloadSpeed',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
                const Spacer(),
                if (onResumeDownload != null)
                  IconButton(
                    onPressed: onResumeDownload,
                    icon: const Icon(Icons.play_arrow, size: 18),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Resume download',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  )
                else if (onRetryDownload != null)
                  IconButton(
                    onPressed: onRetryDownload,
                    icon: const Icon(Icons.refresh, size: 18),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Retry download',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  )
                else if (onPauseDownload != null)
                  IconButton(
                    onPressed: onPauseDownload,
                    icon: const Icon(Icons.pause, size: 18),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Pause download',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                if (onCancelDownload != null)
                  IconButton(
                    onPressed: onCancelDownload,
                    icon: const Icon(Icons.close, size: 18),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Cancel download',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            // ETA display
            if (downloadEta != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  downloadEta!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: downloadProgress,
                minHeight: 6,
              ),
            ),
          ],
        ),
      );
    }
    return _buildActionButtons(context, isDownloaded);
  }

  Widget _buildActionButtons(BuildContext context, bool isDownloaded) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final isTextLarge = mediaQuery.textScaler.scale(10) > 12.5;
    final canSetActive =
        onSetActive != null && (readiness == null || readiness!.isRunnable);

    final children = [
      if (isDownloaded && isActive)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle,
                size: 14,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 4),
              Text(
                'Active',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        )
      else if (isDownloaded && canSetActive)
        TextButton.icon(
          onPressed: onSetActive,
          icon: const Icon(Icons.play_arrow, size: 18),
          label: const Text('Set Active'),
          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
        )
      else if (onDownload != null)
        OutlinedButton.icon(
          onPressed: onDownload,
          icon: const Icon(Icons.download, size: 18),
          label: const Text('Download'),
          style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
        ),
      if (isDownloaded && onDelete != null) ...[
        if (!isTextLarge) const Spacer(),
        IconButton(
          onPressed: onDelete,
          icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
          visualDensity: VisualDensity.compact,
          tooltip: 'Delete model ${model.name}',
        ),
      ],
    ];

    if (isTextLarge) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: children,
      );
    }

    return Row(children: children);
  }
}

/// Small info chip showing an icon and label.
class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
