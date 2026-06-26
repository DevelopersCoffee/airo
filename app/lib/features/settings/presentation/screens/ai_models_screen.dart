import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core_ai/core_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/ai/model_learn_more_launcher.dart';
import '../../../../features/iptv/application/providers/iptv_providers.dart'
    show sharedPreferencesProvider;
import '../widgets/model_card.dart';
import '../widgets/model_filter_bar.dart';
import 'model_detail_screen.dart';

/// Provider for the model registry singleton.
final modelRegistryProvider = Provider<ModelRegistry>((ref) {
  final registry = ModelRegistry();
  // Register bundled models from catalog
  registry.registerModels(ModelCatalog.bundledModels);
  return registry;
});

/// Key for storing selected model ID in SharedPreferences.
const String _selectedModelKey = 'selected_offline_model_id';

/// Provider for the currently selected offline model ID.
final selectedModelIdProvider =
    StateNotifierProvider<SelectedModelNotifier, String?>((ref) {
      return SelectedModelNotifier(ref);
    });

/// Notifier for managing selected model persistence.
class SelectedModelNotifier extends StateNotifier<String?> {
  SelectedModelNotifier(this._ref) : super(null) {
    _loadFromStorage();
  }

  final Ref _ref;

  Future<void> _loadFromStorage() async {
    try {
      final prefs = _ref.read(sharedPreferencesProvider);
      state = prefs.getString(_selectedModelKey);
    } catch (e) {
      // SharedPreferences might not be initialized yet
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getString(_selectedModelKey);
    }
  }

  Future<void> setSelectedModel(String? modelId) async {
    state = modelId;
    try {
      final prefs = _ref.read(sharedPreferencesProvider);
      if (modelId != null) {
        await prefs.setString(_selectedModelKey, modelId);
      } else {
        await prefs.remove(_selectedModelKey);
      }
    } catch (e) {
      final prefs = await SharedPreferences.getInstance();
      if (modelId != null) {
        await prefs.setString(_selectedModelKey, modelId);
      } else {
        await prefs.remove(_selectedModelKey);
      }
    }
  }
}

/// Provider for the currently selected model info.
final selectedModelProvider = Provider<OfflineModelInfo?>((ref) {
  final selectedId = ref.watch(selectedModelIdProvider);
  if (selectedId == null) return null;

  final registry = ref.watch(modelRegistryProvider);
  final models = registry.downloadedModels;
  return models.where((m) => m.id == selectedId).firstOrNull;
});

/// Provider for the model download service.
final modelDownloadServiceProvider = Provider<ModelDownloadService>((ref) {
  final service = ModelDownloadService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider for active downloads progress.
final activeDownloadsProvider =
    StateNotifierProvider<
      ActiveDownloadsNotifier,
      Map<String, ModelDownloadProgress>
    >((ref) => ActiveDownloadsNotifier(ref));

/// Notifier for managing active downloads.
class ActiveDownloadsNotifier
    extends StateNotifier<Map<String, ModelDownloadProgress>> {
  ActiveDownloadsNotifier(this._ref) : super({});

  final Ref _ref;
  final Map<String, StreamSubscription<ModelDownloadProgress>> _subscriptions =
      {};

  /// Starts downloading a model.
  void startDownload(OfflineModelInfo model) {
    final service = _ref.read(modelDownloadServiceProvider);
    final stream = service.downloadModel(model);

    _subscriptions[model.id]?.cancel();
    _subscriptions[model.id] = stream.listen((progress) {
      state = {...state, model.id: progress};

      // Clean up when complete or failed
      if (progress.isComplete ||
          progress.isFailed ||
          progress.status == ModelDownloadStatus.cancelled) {
        _subscriptions[model.id]?.cancel();
        _subscriptions.remove(model.id);

        // Remove from state after a delay
        Future.delayed(const Duration(seconds: 2), () {
          state = Map.from(state)..remove(model.id);
        });
      }
    });
  }

  /// Cancels a download in progress.
  void cancelDownload(String modelId) {
    final service = _ref.read(modelDownloadServiceProvider);
    service.cancelDownload(modelId);
  }

  @override
  void dispose() {
    for (final sub in _subscriptions.values) {
      sub.cancel();
    }
    _subscriptions.clear();
    super.dispose();
  }
}

/// Provider for current filters state.
final modelFiltersProvider = StateProvider<ModelFilters>((ref) {
  return const ModelFilters();
});

/// Provider for filtered models list.
final filteredModelsProvider = Provider<List<OfflineModelInfo>>((ref) {
  final registry = ref.watch(modelRegistryProvider);
  final filters = ref.watch(modelFiltersProvider);

  return registry.queryModels(
    family: filters.family,
    minCredibility: filters.credibility,
    downloaded: filters.downloaded,
    searchQuery: filters.searchQuery,
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
    final registry = ref.watch(modelRegistryProvider);

    return Scaffold(
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
                _buildModelsList(models, registry),

                // Downloaded models tab
                _buildModelsList(
                  registry.downloadedModels,
                  registry,
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

  Widget _buildModelsList(
    List<OfflineModelInfo> models,
    ModelRegistry registry, {
    String? emptyMessage,
  }) {
    final activeDownloads = ref.watch(activeDownloadsProvider);

    if (models.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage ?? 'No models found.\nTry adjusting your filters.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
      );
    }

    final selectedModelId = ref.watch(selectedModelIdProvider);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: models.length,
      itemBuilder: (context, index) {
        final model = models[index];
        final downloadProgress = activeDownloads[model.id];
        final isDownloading = downloadProgress?.isInProgress ?? false;
        final isActive = model.id == selectedModelId;

        return ModelCard(
          model: model,
          isActive: isActive,
          isDownloading: isDownloading,
          downloadProgress: downloadProgress?.progress,
          downloadSpeed: isDownloading ? downloadProgress?.speedDisplay : null,
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
    await ref.read(selectedModelIdProvider.notifier).setSelectedModel(model.id);
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
