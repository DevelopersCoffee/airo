import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core_ai/core_ai.dart';
import 'package:core_ui/core_ui.dart';

import '../../application/ai_model_management.dart';
import '../../../../core/ai/model_learn_more_launcher.dart';
import '../widgets/model_card.dart';
import '../widgets/model_filter_bar.dart';
import 'model_detail_screen.dart';

final modelFiltersProvider = StateProvider<ModelFilters>((ref) {
  return const ModelFilters();
});

final filteredModelsProvider = FutureProvider<List<OfflineModelInfo>>((
  ref,
) async {
  final registry = ref.watch(modelRegistryProvider);
  final filters = ref.watch(modelFiltersProvider);
  final matchingModels = registry.queryModels(
    family: filters.family,
    minCredibility: filters.credibility,
    downloaded: filters.downloaded,
    searchQuery: filters.searchQuery,
  );

  if (!filters.showCompatibleOnly) {
    return matchingModels;
  }

  final compatibleModels = <OfflineModelInfo>[];
  for (final model in matchingModels) {
    final compatibility = await registry.checkCompatibility(model);
    if (compatibility.isCompatible) {
      compatibleModels.add(model);
    }
  }

  return compatibleModels;
});

final downloadedModelsProvider = FutureProvider<List<OfflineModelInfo>>((
  ref,
) async {
  final registry = ref.watch(modelRegistryProvider);
  final filters = ref.watch(modelFiltersProvider);
  final matchingModels = registry.queryModels(
    family: filters.family,
    minCredibility: filters.credibility,
    downloaded: true,
    searchQuery: filters.searchQuery,
  );

  if (!filters.showCompatibleOnly) {
    return matchingModels;
  }

  final compatibleModels = <OfflineModelInfo>[];
  for (final model in matchingModels) {
    final compatibility = await registry.checkCompatibility(model);
    if (compatibility.isCompatible) {
      compatibleModels.add(model);
    }
  }

  return compatibleModels;
});

final modelCompatibilityProvider =
    FutureProvider.family<ModelCompatibilityResult, String>((
      ref,
      modelId,
    ) async {
      final registry = ref.watch(modelRegistryProvider);
      final model = registry.getModel(modelId);
      if (model == null) {
        return ModelCompatibilityResult.compatible(MemorySeverity.warning);
      }
      return registry.checkCompatibility(model);
    });

/// AI Models browser screen.
///
/// Displays a searchable, filterable list of available offline AI models.
/// Allows users to view model details, download models, and manage storage.
class AIModelsScreen extends ConsumerStatefulWidget {
  const AIModelsScreen({super.key});

  @override
  ConsumerState<AIModelsScreen> createState() => _AIModelsScreenState();
}

class _AIModelsScreenState extends ConsumerState<AIModelsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(modelFiltersProvider);
    final models = ref.watch(filteredModelsProvider);
    final downloadedModels = ref.watch(downloadedModelsProvider);

    return AiroResponsiveScaffold(
      padding: EdgeInsets.zero,
      appBar: AppBar(
        title: const Text('AI Models'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.chat_outlined), text: 'Text Models'),
            Tab(icon: Icon(Icons.download_done_outlined), text: 'Downloaded'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Filter bar
          ModelFilterBar(
            filters: filters,
            onFiltersChanged: (newFilters) {
              ref.read(modelFiltersProvider.notifier).state = newFilters;
            },
          ),
          const Divider(height: 1),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // All models tab
                _buildModelsAsync(models),

                // Downloaded models tab
                _buildModelsAsync(
                  downloadedModels,
                  emptyMessage:
                      'No downloaded models yet.\n'
                      'Browse the Text Models tab to download.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelsAsync(
    AsyncValue<List<OfflineModelInfo>> models, {
    String? emptyMessage,
  }) {
    return models.when(
      data: (resolvedModels) =>
          _buildModelsList(resolvedModels, emptyMessage: emptyMessage),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Could not load AI models.\n$error',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildModelsList(
    List<OfflineModelInfo> models, {
    String? emptyMessage,
  }) {
    final activeDownloads = ref.watch(activeDownloadsProvider);

    if (models.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.search_off,
        message:
            emptyMessage ?? 'No models found.\nTry adjusting your filters.',
      );
    }

    final selectedModelId = ref.watch(selectedModelIdProvider);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: models.length,
      itemBuilder: (context, index) {
        final model = models[index];
        final downloadProgress = activeDownloads[model.id];
        final isDownloading = downloadProgress?.isActive ?? false;
        final isActive = model.id == selectedModelId;
        final compatibility = ref.watch(modelCompatibilityProvider(model.id));

        return compatibility.when(
          data: (result) => ModelCard(
            model: model,
            isActive: isActive,
            isDownloading: isDownloading,
            downloadProgress: downloadProgress?.progress,
            downloadStatus: isDownloading
                ? downloadProgress?.statusDisplay
                : null,
            downloadSpeed: isDownloading
                ? downloadProgress?.speedDisplay
                : null,
            downloadEta: isDownloading ? downloadProgress?.etaDisplay : null,
            isCompatible: result.isCompatible,
            onTap: () => _openModelDetail(model),
            onDownload: model.isDownloaded || isDownloading
                ? null
                : () => _downloadModel(model),
            onDelete: model.isDownloaded ? () => _deleteModel(model) : null,
            onSetActive: model.isDownloaded && !isActive
                ? () => _setActiveModel(model)
                : null,
            onCancelDownload: isDownloading
                ? () => _cancelDownload(model.id)
                : null,
            onLearnMore: model.learnMoreUri != null
                ? () => launchModelLearnMore(context, model)
                : null,
          ),
          loading: () => ModelCard(
            model: model,
            isActive: isActive,
            isDownloading: isDownloading,
            downloadProgress: downloadProgress?.progress,
            downloadStatus: isDownloading
                ? downloadProgress?.statusDisplay
                : null,
            downloadSpeed: isDownloading
                ? downloadProgress?.speedDisplay
                : null,
            downloadEta: isDownloading ? downloadProgress?.etaDisplay : null,
            onTap: () => _openModelDetail(model),
            onDownload: model.isDownloaded || isDownloading
                ? null
                : () => _downloadModel(model),
            onDelete: model.isDownloaded ? () => _deleteModel(model) : null,
            onSetActive: model.isDownloaded && !isActive
                ? () => _setActiveModel(model)
                : null,
            onCancelDownload: isDownloading
                ? () => _cancelDownload(model.id)
                : null,
            onLearnMore: model.learnMoreUri != null
                ? () => launchModelLearnMore(context, model)
                : null,
          ),
          error: (_, _) => ModelCard(
            model: model,
            isActive: isActive,
            isDownloading: isDownloading,
            downloadProgress: downloadProgress?.progress,
            downloadStatus: isDownloading
                ? downloadProgress?.statusDisplay
                : null,
            downloadSpeed: isDownloading
                ? downloadProgress?.speedDisplay
                : null,
            downloadEta: isDownloading ? downloadProgress?.etaDisplay : null,
            isCompatible: false,
            onTap: () => _openModelDetail(model),
            onDownload: model.isDownloaded || isDownloading
                ? null
                : () => _downloadModel(model),
            onDelete: model.isDownloaded ? () => _deleteModel(model) : null,
            onSetActive: model.isDownloaded && !isActive
                ? () => _setActiveModel(model)
                : null,
            onCancelDownload: isDownloading
                ? () => _cancelDownload(model.id)
                : null,
            onLearnMore: model.learnMoreUri != null
                ? () => launchModelLearnMore(context, model)
                : null,
          ),
        );
      },
    );
  }

  void _openModelDetail(OfflineModelInfo model) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => ModelDetailScreen(model: model)),
    );
  }

  void _downloadModel(OfflineModelInfo model) {
    ref.read(activeDownloadsProvider.notifier).startDownload(model);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Starting download: ${model.name}')));
  }

  void _cancelDownload(String modelId) {
    ref.read(activeDownloadsProvider.notifier).cancelDownload(modelId);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Download cancelled')));
  }

  Future<void> _deleteModel(OfflineModelInfo model) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Model'),
        content: Text(
          'Delete ${model.name}? This will free up ${model.fileSizeDisplay}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        // Delete the model file
        final downloadService = ref.read(modelDownloadServiceProvider);
        final deleted = await downloadService.deleteModel(model.id);

        if (deleted) {
          // Update the registry to mark as removed
          final registry = ref.read(modelRegistryProvider);
          registry.markAsRemoved(model.id);
          await clearOfflineModelSelections(ref, model);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${model.name} deleted successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${model.name} file not found'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _setActiveModel(OfflineModelInfo model) async {
    await activateOfflineModel(ref, model);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${model.name} is now active'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}
