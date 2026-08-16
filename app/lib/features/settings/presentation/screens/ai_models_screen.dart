import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:core_ai/core_ai.dart';
import 'package:core_ui/core_ui.dart';
import 'package:feature_mind/src/services/llama_gguf_service.dart';

import '../../application/ai_model_management.dart';
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
  ref.watch(modelRegistryEventsProvider);
  final filters = ref.watch(modelFiltersProvider);
  final matchingModels = registry.queryModels(
    family: filters.family,
    minCredibility: filters.credibility,
    downloaded: filters.downloaded,
    modality: filters.modality,
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
  ref.watch(modelRegistryEventsProvider);
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

final modelReadinessProvider =
    FutureProvider.family<ModelReadinessState, OfflineModelInfo>((
  ref,
  model,
) async {
  final liteRtAvailable = await LiteRtLmService().isAvailable();
  final ggufAvailable = await LlamaGgufService().isAvailable();
  return ModelReadinessService.evaluate(
    model,
    nativeGgufAvailable: ggufAvailable,
    liteRtNativeAvailable: liteRtAvailable,
    webMediaPipeAvailable: kIsWeb,
  );
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
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(_syncModalityFilterFromTab);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(modelFiltersProvider.notifier).state = ref
          .read(modelFiltersProvider)
          .copyWith(modality: ModelModality.text);
    });
  }

  void _syncModalityFilterFromTab() {
    if (!mounted || _tabController.indexIsChanging) return;
    final modality = switch (_tabController.index) {
      0 => ModelModality.text,
      1 => ModelModality.image,
      2 => ModelModality.audio,
      _ => null,
    };
    final current = ref.read(modelFiltersProvider);
    if (current.modality == modality) return;
    ref.read(modelFiltersProvider.notifier).state = current.copyWith(
      modality: modality,
      clearModality: modality == null,
    );
  }

  @override
  void dispose() {
    _tabController.removeListener(_syncModalityFilterFromTab);
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
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.chat_outlined), text: 'Text'),
            Tab(icon: Icon(Icons.image_outlined), text: 'Image'),
            Tab(icon: Icon(Icons.mic_none_outlined), text: 'Audio'),
            Tab(icon: Icon(Icons.apps_outlined), text: 'All'),
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
          _HuggingFaceCatalogStatusBanner(),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildModelsAsync(models),
                _buildModelsAsync(models),
                _buildModelsAsync(models),
                _buildModelsAsync(models),
                _buildModelsAsync(
                  downloadedModels,
                  emptyMessage:
                      'No downloaded models yet.\n'
                      'Browse the catalog tabs to download.',
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
        final isDownloading =
            downloadProgress?.isActive == true ||
            downloadProgress?.canRetry == true;
        final isActive = model.id == selectedModelId;
        final compatibility = ref.watch(modelCompatibilityProvider(model.id));
        final readiness = ref.watch(modelReadinessProvider(model));

        return compatibility.when(
          data: (result) => readiness.when(
            data: (readinessState) => ModelCard(
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
              readiness: readinessState,
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
              onPauseDownload: downloadProgress?.canPause == true
                  ? () => _pauseDownload(model.id)
                  : null,
              onResumeDownload: downloadProgress?.canResume == true
                  ? () => _resumeDownload(model.id)
                  : null,
              onRetryDownload: downloadProgress?.canRetry == true
                  ? () => _retryDownload(model.id)
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
              onPauseDownload: downloadProgress?.canPause == true
                  ? () => _pauseDownload(model.id)
                  : null,
              onResumeDownload: downloadProgress?.canResume == true
                  ? () => _resumeDownload(model.id)
                  : null,
              onRetryDownload: downloadProgress?.canRetry == true
                  ? () => _retryDownload(model.id)
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
              onPauseDownload: downloadProgress?.canPause == true
                  ? () => _pauseDownload(model.id)
                  : null,
              onResumeDownload: downloadProgress?.canResume == true
                  ? () => _resumeDownload(model.id)
                  : null,
              onRetryDownload: downloadProgress?.canRetry == true
                  ? () => _retryDownload(model.id)
                  : null,
              onLearnMore: model.learnMoreUri != null
                  ? () => launchModelLearnMore(context, model)
                  : null,
            ),
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
            onPauseDownload: downloadProgress?.canPause == true
                ? () => _pauseDownload(model.id)
                : null,
            onResumeDownload: downloadProgress?.canResume == true
                ? () => _resumeDownload(model.id)
                : null,
            onRetryDownload: downloadProgress?.canRetry == true
                ? () => _retryDownload(model.id)
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
            onPauseDownload: downloadProgress?.canPause == true
                ? () => _pauseDownload(model.id)
                : null,
            onResumeDownload: downloadProgress?.canResume == true
                ? () => _resumeDownload(model.id)
                : null,
            onRetryDownload: downloadProgress?.canRetry == true
                ? () => _retryDownload(model.id)
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

  void _pauseDownload(String modelId) {
    ref.read(activeDownloadsProvider.notifier).pauseDownload(modelId);
  }

  void _resumeDownload(String modelId) {
    ref.read(activeDownloadsProvider.notifier).resumeDownload(modelId);
  }

  void _retryDownload(String modelId) {
    ref.read(activeDownloadsProvider.notifier).retryDownload(modelId);
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
              content: Text(AiroVoice.errorGeneric.pickWith(detail: '$e')),
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

/// Clear empty/error vs offline-cached messaging for the HF catalog feed.
class _HuggingFaceCatalogStatusBanner extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final availability = ref.watch(huggingFaceCatalogAvailabilityProvider);
    final error = ref.watch(huggingFaceCatalogErrorProvider);
    final theme = Theme.of(context);

    final String? message = switch (availability) {
      HuggingFaceCatalogAvailability.online => null,
      HuggingFaceCatalogAvailability.offlineCached =>
        'Showing previously fetched Hugging Face catalog entries offline.',
      HuggingFaceCatalogAvailability.neverFetched =>
        error == null
            ? 'Hugging Face catalog not fetched yet. Connect once to discover '
                  'public GGUF and litert-community packages.'
            : 'Could not reach Hugging Face. No cached catalog entries yet.',
    };
    if (message == null) return const SizedBox.shrink();

    final isError = availability == HuggingFaceCatalogAvailability.neverFetched;
    return Material(
      color: isError
          ? theme.colorScheme.errorContainer
          : theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(
              isError ? Icons.cloud_off_outlined : Icons.offline_bolt_outlined,
              size: 18,
              color: isError
                  ? theme.colorScheme.onErrorContainer
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isError
                      ? theme.colorScheme.onErrorContainer
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
