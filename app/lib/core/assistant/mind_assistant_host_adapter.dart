import 'package:core_ai/core_ai.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/settings/application/ai_model_management.dart';
import 'app_assistant_host_adapter.dart';

/// Mind-shell host adapter: model management lives on `/models`, not Settings.
class MindAssistantHostAdapter extends AppAssistantHostAdapter {
  MindAssistantHostAdapter(this.ref) : super(ref);

  final Ref ref;

  @override
  void openModelManager(BuildContext context) => context.push('/models');

  @override
  void openHostSettings(BuildContext context) {
    // IPTV settings hub is not shipped in Mind; send people to model prefs.
    openModelManager(context);
  }

  @override
  Future<List<OfflineModelInfo>> loadAssistantDownloadedModels() async {
    final registry = ref.read(modelRegistryProvider);
    return registry
        .queryModels(downloaded: true)
        .where(
          (model) =>
              (model.filePath?.toLowerCase().endsWith('.gguf') ?? false) &&
              model.capabilities.contains(ModelCapability.chat),
        )
        .toList(growable: false);
  }
}
