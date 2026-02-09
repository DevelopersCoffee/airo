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
    this.isCompatible = true,
    this.onTap,
    this.onDownload,
    this.onDelete,
    this.onSetActive,
  });

  /// The model to display.
  final OfflineModelInfo model;

  /// Whether this model is currently active/loaded.
  final bool isActive;

  /// Whether the model is being downloaded.
  final bool isDownloading;

  /// Download progress from 0.0 to 1.0.
  final double? downloadProgress;

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDownloaded = model.isDownloaded;

    return Card(
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
                  if (model.supportsVision)
                    const _InfoChip(
                      icon: Icons.visibility_outlined,
                      label: 'Vision',
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
    );
  }

  Widget _buildStatusRow(BuildContext context, bool isDownloaded) {
    final theme = Theme.of(context);

    if (isDownloading && downloadProgress != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 8),
              Text(
                'Downloading... ${(downloadProgress! * 100).round()}%',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: downloadProgress,
              minHeight: 6,
            ),
          ),
        ],
      );
    }
    // ... more status handling to be continued
    return _buildActionButtons(context, isDownloaded);
  }

  Widget _buildActionButtons(BuildContext context, bool isDownloaded) {
    final theme = Theme.of(context);

    return Row(
      children: [
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
        else if (isDownloaded)
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
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
            ),
          ),
        const Spacer(),
        if (isDownloaded && onDelete != null)
          IconButton(
            onPressed: onDelete,
            icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
            visualDensity: VisualDensity.compact,
            tooltip: 'Delete model',
          ),
      ],
    );
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
