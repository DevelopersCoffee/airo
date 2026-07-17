import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core_ai/core_ai.dart';
import 'package:core_ui/core_ui.dart';

import '../../application/ai_model_management.dart';
import '../intelligent_model_manager_provider.dart';

/// Screen for displaying and managing AI models using glassmorphic UI elements,
/// gradient backgrounds, and animations.
class IntelligentModelManagerScreen extends ConsumerWidget {
  const IntelligentModelManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modelsAsync = ref.watch(intelligentModelsListProvider);
    final activeDownloads = ref.watch(activeDownloadsProvider);
    final selectedModelId = ref.watch(selectedModelIdProvider);
    final registry = ref.watch(modelRegistryProvider);

    return AiroResponsiveScaffold(
      padding: EdgeInsets.zero,
      appBar: AppBar(
        title: const Text('Intelligent Model Manager'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2),
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.1),
            ],
          ),
        ),
        child: modelsAsync.when(
          data: (models) {
            if (models.isEmpty) {
              return const EmptyStateWidget(
                icon: Icons.smart_toy_outlined,
                message: 'No models found in the catalog.',
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: models.length,
              itemBuilder: (context, index) {
                final model = models[index];
                final modelInfo = registry.getModel(model.id);
                if (modelInfo == null) return const SizedBox.shrink();

                final downloadProgress = activeDownloads[model.id];
                final isDownloading = downloadProgress?.isActive ?? false;
                final isActive = model.id == selectedModelId;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildGlassModelCard(
                    context,
                    ref,
                    model: model,
                    modelInfo: modelInfo,
                    isActive: isActive,
                    isDownloading: isDownloading,
                    downloadProgress: downloadProgress,
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(
            child: ErrorView(
              message: 'Failed to load models: $err',
              onRetry: () => ref.refresh(intelligentModelsListProvider),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassModelCard(
    BuildContext context,
    WidgetRef ref, {
    required ModelEntry model,
    required OfflineModelInfo modelInfo,
    required bool isActive,
    required bool isDownloading,
    required ModelDownloadProgress? downloadProgress,
  }) {
    final theme = Theme.of(context);
    final cardColor = theme.brightness == Brightness.dark
        ? Colors.black.withOpacity(0.25)
        : Colors.white.withOpacity(0.45);
    final borderColor = theme.brightness == Brightness.dark
        ? Colors.white.withOpacity(0.08)
        : Colors.black.withOpacity(0.08);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive
                  ? theme.colorScheme.primary.withOpacity(0.5)
                  : borderColor,
              width: isActive ? 2.0 : 1.0,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: theme.colorScheme.primary.withOpacity(0.15),
                      blurRadius: 16,
                      spreadRadius: 2,
                    )
                  ]
                : [],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                model.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildVersionBadge(context, model.version),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            modelInfo.author != null
                                ? 'By ${modelInfo.author}'
                                : 'Local Model',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isActive)
                      _buildActiveBadge(context)
                    else if (model.isDownloaded)
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        color: theme.colorScheme.error,
                        tooltip: 'Delete Model',
                        onPressed: () => _showDeleteConfirmation(context, ref, model, modelInfo),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  model.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.85),
                  ),
                ),
                const SizedBox(height: 16),
                _buildModelMetrics(context, modelInfo),
                const SizedBox(height: 16),
                if (isDownloading && downloadProgress != null)
                  _buildDownloadProgress(context, ref, modelInfo, downloadProgress)
                else
                  _buildActionRow(context, ref, model, modelInfo, isActive),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVersionBadge(BuildContext context, String version) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        version,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildActiveBadge(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text(
            'ACTIVE',
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelMetrics(BuildContext context, OfflineModelInfo modelInfo) {
    final theme = Theme.of(context);
    final sizeStr = _formatBytes(modelInfo.fileSizeBytes);
    final paramStr = modelInfo.parameterCount != null
        ? _formatParams(modelInfo.parameterCount!)
        : 'Unknown';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildMetricItem(context, Icons.sd_card_outlined, 'Size', sizeStr),
          const SizedBox(
            height: 24,
            child: VerticalDivider(width: 24, thickness: 1),
          ),
          _buildMetricItem(context, Icons.memory_outlined, 'Params', paramStr),
          const SizedBox(
            height: 24,
            child: VerticalDivider(width: 24, thickness: 1),
          ),
          _buildMetricItem(
            context,
            Icons.speed_outlined,
            'Context',
            '${modelInfo.contextLength} tokens',
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: theme.colorScheme.primary),
              const SizedBox(width: 4),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadProgress(
    BuildContext context,
    WidgetRef ref,
    OfflineModelInfo model,
    ModelDownloadProgress progress,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                progress.statusDisplay,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              '${(progress.progress * 100).toStringAsFixed(1)}%',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress.progress,
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${progress.speedDisplay} • ETA: ${progress.etaDisplay}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            TextButton.icon(
              onPressed: () {
                ref.read(activeDownloadsProvider.notifier).cancelDownload(model.id);
              },
              icon: const Icon(Icons.cancel_outlined, size: 16),
              label: const Text('Cancel'),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
                padding: EdgeInsets.zero,
                minimumSize: const Size(50, 30),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionRow(
    BuildContext context,
    WidgetRef ref,
    ModelEntry model,
    OfflineModelInfo modelInfo,
    bool isActive,
  ) {
    if (model.isDownloaded) {
      if (isActive) {
        return const SizedBox.shrink();
      }

      return AppButton(
        label: 'Activate Model',
        icon: Icons.bolt,
        isExpanded: true,
        onPressed: () async {
          await activateOfflineModel(ref, modelInfo);
        },
      );
    }

    return AppButton(
      label: 'Download Model (${_formatBytes(model.sizeBytes)})',
      icon: Icons.download_outlined,
      isExpanded: true,
      onPressed: () {
        ref.read(activeDownloadsProvider.notifier).startDownload(modelInfo);
      },
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
    ModelEntry model,
    OfflineModelInfo modelInfo,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${model.name}?'),
        content: Text(
          'This will delete the model files from your local storage and free up approximately '
          '${_formatBytes(model.sizeBytes)}. You can download it again later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              Navigator.of(context).pop();
              // Delete model
              await ref.read(intelligentModelManagerProvider).deleteModel(model.id);
              // Clear selections if deleted model was active
              await clearOfflineModelSelections(ref, modelInfo);
              // Refresh model list
              ref.invalidate(intelligentModelsListProvider);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    var doubleBytes = bytes / (1024 * 1024 * 1024);
    if (doubleBytes >= 0.1) {
      return '${doubleBytes.toStringAsFixed(1)} GB';
    }
    doubleBytes = bytes / (1024 * 1024);
    return '${doubleBytes.toStringAsFixed(0)} MB';
  }

  String _formatParams(int params) {
    if (params >= 1000000000) {
      return '${(params / 1000000000).toStringAsFixed(1)}B';
    }
    if (params >= 1000000) {
      return '${(params / 1000000).toStringAsFixed(1)}M';
    }
    return params.toString();
  }
}
