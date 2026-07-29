import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core_ai/core_ai.dart';
import 'package:core_ui/core_ui.dart';

import '../../application/ai_model_management.dart';
import '../intelligent_model_manager_provider.dart';
import '../../../agent_chat/presentation/screens/model_health_center_screen.dart';

/// Screen for displaying and managing AI models using glassmorphic UI elements,
/// gradient backgrounds, and animations.
class IntelligentModelManagerScreen extends ConsumerWidget {
  const IntelligentModelManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshotAsync = ref.watch(intelligentModelManagerSnapshotProvider);
    final activeDownloads = ref.watch(activeDownloadsProvider);
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
              Theme.of(
                context,
              ).colorScheme.primaryContainer.withValues(alpha: 0.2),
              Theme.of(context).colorScheme.surface,
              Theme.of(
                context,
              ).colorScheme.secondaryContainer.withValues(alpha: 0.1),
            ],
          ),
        ),
        child: snapshotAsync.when(
          data: (snapshot) {
            final models = snapshot.models;
            final visibleQueue = activeDownloads.isEmpty
                ? snapshot.downloadQueue
                : (activeDownloads.values.toList()..sort(
                    (left, right) => (left.queuePosition ?? 0x7fffffff)
                        .compareTo(right.queuePosition ?? 0x7fffffff),
                  ));
            if (models.isEmpty) {
              return const EmptyStateWidget(
                icon: Icons.smart_toy_outlined,
                message: 'No models found in the catalog.',
              );
            }

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              children: [
                _buildManagerSummary(context, snapshot),
                if (visibleQueue.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildQueueSummary(context, visibleQueue),
                ],
                const SizedBox(height: 20),
                for (final model in models) ...[
                  Builder(
                    builder: (context) {
                      final modelInfo = registry.getModel(model.id);
                      if (modelInfo == null) return const SizedBox.shrink();

                      final downloadProgress = activeDownloads[model.id];
                      final isDownloading =
                          downloadProgress?.isActive == true ||
                          downloadProgress?.isFailed == true;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildGlassModelCard(
                          context,
                          ref,
                          model: model,
                          modelInfo: modelInfo,
                          isActive: model.isActive,
                          isDownloading: isDownloading,
                          downloadProgress: downloadProgress,
                        ),
                      );
                    },
                  ),
                ],
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(
            child: ErrorView(
              message: AiroVoice.errorGeneric.pickWith(detail: '$err'),
              onRetry: () =>
                  ref.refresh(intelligentModelManagerSnapshotProvider),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildManagerSummary(
    BuildContext context,
    ModelManagerSnapshot snapshot,
  ) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 24,
          runSpacing: 12,
          children: [
            _buildSummaryMetric(
              context,
              Icons.inventory_2_outlined,
              'Installed',
              '${snapshot.installedModels.length}',
            ),
            _buildSummaryMetric(
              context,
              Icons.storage_outlined,
              'Model storage',
              _formatBytes(snapshot.storageUsedBytes),
            ),
            _buildSummaryMetric(
              context,
              Icons.recommend_outlined,
              'Recommended',
              '${snapshot.recommendedModels.length}',
            ),
            Text(
              'Downloads continue in the background and restore after restart.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryMetric(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Text('$label: $value'),
      ],
    );
  }

  Widget _buildQueueSummary(
    BuildContext context,
    List<ModelDownloadProgress> queue,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Download queue',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            for (final item in queue)
              Text(
                '${item.queuePosition == null ? '•' : '#${item.queuePosition! + 1}'} '
                '${item.modelId} — ${item.statusDisplay}',
              ),
          ],
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
        ? Colors.black.withValues(alpha: 0.25)
        : Colors.white.withValues(alpha: 0.45);
    final borderColor = theme.brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);

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
                  ? theme.colorScheme.primary.withValues(alpha: 0.5)
                  : borderColor,
              width: isActive ? 2.0 : 1.0,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.15),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
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
                              Expanded(
                                child: Text(
                                  model.name,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildVersionBadge(context, model.version),
                            ],
                          ),
                          if (model.isRecommended ||
                              model.updateState !=
                                  ModelUpdateState.notInstalled) ...[
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              children: [
                                if (model.isRecommended)
                                  const Chip(
                                    label: Text('Recommended'),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                if (model.hasUpdate)
                                  const Chip(
                                    label: Text('Update available'),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                if (model.isResident)
                                  const Chip(
                                    avatar: Icon(Icons.memory, size: 16),
                                    label: Text('Warm'),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                if (model.updateState ==
                                    ModelUpdateState.unknown)
                                  const Tooltip(
                                    message:
                                        'Installed before version receipts were available',
                                    child: Chip(
                                      label: Text('Version unknown'),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            modelInfo.author != null
                                ? 'By ${modelInfo.author}'
                                : 'Local Model',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (model.isDownloaded)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isActive) ...[
                            _buildActiveBadge(context),
                            const SizedBox(width: 4),
                          ],
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            color: theme.colorScheme.error,
                            tooltip: 'Delete Model',
                            onPressed: () => _showDeleteConfirmation(
                              context,
                              ref,
                              model,
                              modelInfo,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  model.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 16),
                _buildModelMetrics(context, modelInfo),
                const SizedBox(height: 16),
                if (isDownloading && downloadProgress != null)
                  _buildDownloadProgress(
                    context,
                    ref,
                    modelInfo,
                    downloadProgress,
                  )
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
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
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
        color: theme.colorScheme.onSurface.withValues(alpha: 0.03),
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
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
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
              '${progress.speedDisplay} • ETA: '
              '${progress.etaDisplay ?? 'calculating'}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            Wrap(
              spacing: 4,
              children: [
                if (progress.canPause)
                  IconButton(
                    tooltip: 'Pause',
                    onPressed: () => ref
                        .read(activeDownloadsProvider.notifier)
                        .pauseDownload(model.id),
                    icon: const Icon(Icons.pause),
                  ),
                if (progress.canResume)
                  IconButton(
                    tooltip: 'Resume',
                    onPressed: () => ref
                        .read(activeDownloadsProvider.notifier)
                        .resumeDownload(model.id),
                    icon: const Icon(Icons.play_arrow),
                  ),
                if (progress.canRetry)
                  IconButton(
                    tooltip: 'Retry',
                    onPressed: () => ref
                        .read(activeDownloadsProvider.notifier)
                        .retryDownload(model.id),
                    icon: const Icon(Icons.refresh),
                  ),
                if (progress.canCancel)
                  IconButton(
                    tooltip: 'Cancel',
                    color: theme.colorScheme.error,
                    onPressed: () => ref
                        .read(activeDownloadsProvider.notifier)
                        .cancelDownload(model.id),
                    icon: const Icon(Icons.cancel_outlined),
                  ),
              ],
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
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!isActive)
                FilledButton.icon(
                  onPressed: () async {
                    await ref
                        .read(intelligentModelManagerProvider)
                        .activateModel(model.id);
                    ref.invalidate(intelligentModelManagerSnapshotProvider);
                  },
                  icon: const Icon(Icons.bolt),
                  label: const Text('Activate'),
                ),
              OutlinedButton.icon(
                onPressed: () => _warmModel(context, ref, model.id),
                icon: const Icon(Icons.memory),
                label: const Text('Warm now'),
              ),
              OutlinedButton.icon(
                onPressed: () => _benchmarkModel(context, ref, model.id),
                icon: const Icon(Icons.speed_outlined),
                label: const Text('Benchmark'),
              ),
              OutlinedButton.icon(
                onPressed: () => _openHealthCenter(context, modelInfo),
                icon: const Icon(Icons.help_outline),
                label: const Text('Why?'),
              ),
              if (model.hasUpdate)
                OutlinedButton.icon(
                  onPressed: () => ref
                      .read(activeDownloadsProvider.notifier)
                      .startDownload(modelInfo),
                  icon: const Icon(Icons.system_update_alt),
                  label: const Text('Update'),
                ),
            ],
          ),
          Material(
            color: Colors.transparent,
            child: SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Preload when frequently used'),
              subtitle: const Text(
                'Loads at the next runtime warm-up when memory permits.',
              ),
              value: model.preloadFrequentlyUsed,
              onChanged: (enabled) async {
                await ref
                    .read(intelligentModelManagerProvider)
                    .setPreloadFrequentlyUsed(model.id, enabled);
                ref.invalidate(intelligentModelManagerSnapshotProvider);
              },
            ),
          ),
        ],
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

  Future<void> _warmModel(
    BuildContext context,
    WidgetRef ref,
    String modelId,
  ) async {
    final result = await ref
        .read(intelligentModelManagerProvider)
        .warmModel(modelId);
    if (!context.mounted) return;
    final message = switch (result.status) {
      ModelWarmupStatus.warmed => 'Model warmed and ready.',
      ModelWarmupStatus.alreadyResident => 'Model is already warm.',
      ModelWarmupStatus.unavailable =>
        'Model could not be warmed: ${result.detail ?? 'runtime unavailable'}.',
      ModelWarmupStatus.failed =>
        'Model warm-up failed: ${result.detail ?? 'unknown error'}.',
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _benchmarkModel(
    BuildContext context,
    WidgetRef ref,
    String modelId,
  ) async {
    final stopwatch = Stopwatch()..start();
    final result = await ref
        .read(intelligentModelManagerProvider)
        .warmModel(modelId);
    stopwatch.stop();
    if (!context.mounted) return;

    final elapsed =
        '${(stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(2)}s';
    final message = switch (result.status) {
      ModelWarmupStatus.warmed =>
        'Warm-up benchmark: $elapsed. Model is ready for inference.',
      ModelWarmupStatus.alreadyResident =>
        'Warm-up benchmark: $elapsed. Model was already resident.',
      ModelWarmupStatus.unavailable =>
        'Benchmark unavailable: ${result.detail ?? 'runtime unavailable'}.',
      ModelWarmupStatus.failed =>
        'Benchmark failed after $elapsed: ${result.detail ?? 'unknown error'}.',
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _openHealthCenter(BuildContext context, OfflineModelInfo model) {
    final report = ModelHealthReport.fromFacts(model: model);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ModelHealthCenterScreen(
          report: report,
          onAction: (action) {
            Navigator.of(context).pop();
            final message = switch (action) {
              ModelHealthAction.retry =>
                'Retry the model warm-up from Model Management.',
              ModelHealthAction.resumeDownload =>
                'Resume the download from Model Management.',
              ModelHealthAction.repair =>
                'Repair or re-download this model from Model Management.',
              ModelHealthAction.reduceContext =>
                'Reduce context in AI preferences, then warm the model again.',
              ModelHealthAction.chooseAlternative =>
                'Choose another installed model from Model Management.',
            };
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(message)));
          },
        ),
      ),
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
              await ref
                  .read(intelligentModelManagerProvider)
                  .deleteModel(model.id);
              // Refresh model list
              ref.invalidate(intelligentModelManagerSnapshotProvider);
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
