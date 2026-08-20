import 'package:core_ai/core_ai.dart';
import 'package:feature_mind/feature_mind.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/settings/application/ai_model_management.dart';
import '../../features/settings/presentation/screens/ai_models_screen.dart';
import '../../features/settings/presentation/screens/intelligent_model_manager_screen.dart';
import 'mind_model_catalog.dart';

/// Standalone Mind shell: task-first Intelligence control center.
class MindModelsScreen extends ConsumerWidget {
  const MindModelsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(modelRegistryEventsProvider);
    final registry = ref.watch(modelRegistryProvider);
    final service = ref.watch(mindScribeServiceProvider);

    return ProviderScope(
      overrides: [
        intelligenceCatalogProvider.overrideWithValue(registry.allModels),
      ],
      child: IntelligenceHomeScreen(
        modelsTab: const IntelligentModelManagerScreen(embedded: true),
        libraryTab: _IntelligenceLibraryTab(
          onOpenHuggingFace: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const AIModelsScreen()),
          ),
        ),
        diagnosticsTab: DeviceCapabilityReportLoaderScreen(
          models: registry.allModels,
          embedded: true,
        ),
        onOpenChat: () => context.go(AssistantRouteNames.chat),
        onOpenScribe: () => context.go('/'),
        onInstallModels: (models) => _installRecommended(ref, models, service),
      ),
    );
  }

  Future<void> _installRecommended(
    WidgetRef ref,
    List<OfflineModelInfo> models,
    MindService service,
  ) async {
    final downloads = ref.read(activeDownloadsProvider.notifier);
    final scribe = <OfflineModelInfo>[];
    for (final model in models) {
      if (model.tags.contains(mindScribeModelTag)) {
        scribe.add(model);
      } else {
        downloads.startDownload(model);
      }
    }
    if (scribe.isEmpty) return;
    final required = <RequiredModel>[];
    for (final model in scribe) {
      final pinned = await requiredModelForScribeCatalogId(model.id);
      if (pinned != null) required.add(pinned);
    }
    if (required.isEmpty) return;
    await for (final _ in service.acquireModelFiles(required)) {}
    await hydrateMindScribeModels(
      ref.read(modelRegistryProvider),
      requiredModels: mindScribeRequiredModels,
      modelsDirectory: service.modelsDirectory,
    );
  }
}

class _IntelligenceLibraryTab extends ConsumerWidget {
  const _IntelligenceLibraryTab({required this.onOpenHuggingFace});

  final VoidCallback onOpenHuggingFace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.travel_explore_outlined),
          title: const Text('Community catalog'),
          subtitle: const Text('Public GGUF and litert-community packages'),
          trailing: const Icon(Icons.chevron_right),
          onTap: onOpenHuggingFace,
        ),
        const Divider(height: 1),
        Expanded(
          child: ModelLibraryScreen(
            browseMode: true,
            onModelSelected: (candidate) {
              context.go(AssistantRouteNames.chat);
            },
            onOpenModelManager: () {},
          ),
        ),
      ],
    );
  }
}
