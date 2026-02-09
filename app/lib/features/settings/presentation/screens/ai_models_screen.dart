import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core_ai/core_ai.dart';

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

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: models.length,
      itemBuilder: (context, index) {
        final model = models[index];
        return ModelCard(
          model: model,
          isActive: false, // TODO: Check against active model
          onTap: () => _openModelDetail(model),
          onDownload: model.isDownloaded ? null : () => _downloadModel(model),
          onDelete: model.isDownloaded ? () => _deleteModel(model) : null,
          onSetActive: model.isDownloaded ? () => _setActiveModel(model) : null,
        );
      },
    );
  }

  void _openModelDetail(OfflineModelInfo model) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => ModelDetailScreen(model: model)),
    );
  }

  Future<void> _downloadModel(OfflineModelInfo model) async {
    // TODO: Implement download with progress tracking
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Downloading ${model.name}...')));
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
      // TODO: Implement deletion
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${model.name} deleted')));
    }
  }

  Future<void> _setActiveModel(OfflineModelInfo model) async {
    // TODO: Set as active model
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${model.name} is now active')));
  }
}
