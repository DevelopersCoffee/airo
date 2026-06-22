import 'package:core_ai/core_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/services/gemini_api_service.dart';
import '../../../../core/services/gemini_nano_service.dart';
import '../../../../core/services/litert_lm_service.dart';
import '../../domain/models/assistant_runtime_ids.dart';

const String _selectedAssistantModelKey = 'selected_assistant_model_id';

final selectedAssistantModelIdProvider =
    StateNotifierProvider<SelectedAssistantModelNotifier, String?>((ref) {
      return SelectedAssistantModelNotifier();
    });

class SelectedAssistantModelNotifier extends StateNotifier<String?> {
  SelectedAssistantModelNotifier() : super(null) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_selectedAssistantModelKey);
  }

  Future<void> select(String? modelId) async {
    state = modelId;
    final prefs = await SharedPreferences.getInstance();
    if (modelId == null) {
      await prefs.remove(_selectedAssistantModelKey);
    } else {
      await prefs.setString(_selectedAssistantModelKey, modelId);
    }
  }
}

final selectedAssistantTaskProvider = StateProvider<AssistantTask>((ref) {
  return AssistantTask.chat;
});

final assistantModelLibraryProvider =
    FutureProvider<AssistantModelLibraryState>((ref) async {
      final task = ref.watch(selectedAssistantTaskProvider);
      return AssistantModelLibraryState.load(task: task);
    });

enum AssistantTask {
  chat('Chat Project', Icons.chat_bubble_outline),
  reasoning('Thinking Project', Icons.psychology_outlined),
  documents('Document Project', Icons.description_outlined),
  image('Image Project', Icons.image_outlined),
  audio('Audio Project', Icons.mic_none),
  skills('Agent Skills Project', Icons.extension_outlined),
  actions('Action Project', Icons.touch_app_outlined);

  const AssistantTask(this.label, this.icon);

  final String label;
  final IconData icon;

  ModelCapability get defaultCapability => switch (this) {
    AssistantTask.chat => ModelCapability.chat,
    AssistantTask.reasoning => ModelCapability.reasoning,
    AssistantTask.documents => ModelCapability.documents,
    AssistantTask.image => ModelCapability.imageUnderstanding,
    AssistantTask.audio => ModelCapability.audioUnderstanding,
    AssistantTask.skills => ModelCapability.agentSkills,
    AssistantTask.actions => ModelCapability.mobileActions,
  };
}

class AssistantProjectTemplate {
  const AssistantProjectTemplate({
    required this.task,
    required this.title,
    required this.description,
    required this.primaryAction,
    required this.defaultPackage,
    required this.artifactLabel,
  });

  final AssistantTask task;
  final String title;
  final String description;
  final String primaryAction;
  final String defaultPackage;
  final String artifactLabel;

  static const values = [
    AssistantProjectTemplate(
      task: AssistantTask.chat,
      title: 'General Chat',
      description: 'Ask questions, draft text, and keep a lightweight thread.',
      primaryAction: 'Start chat',
      defaultPackage: 'Gemini Nano on Pixel, Gemma 4 E2B fallback',
      artifactLabel: 'Chat thread',
    ),
    AssistantProjectTemplate(
      task: AssistantTask.reasoning,
      title: 'Planning & Reasoning',
      description: 'Break down tasks, compare options, and plan next steps.',
      primaryAction: 'Start plan',
      defaultPackage: 'Gemma 4 E2B Instruct',
      artifactLabel: 'Plan notes',
    ),
    AssistantProjectTemplate(
      task: AssistantTask.documents,
      title: 'Docs & Notes',
      description: 'Summarize notes, reason over pasted text, and draft docs.',
      primaryAction: 'Start document project',
      defaultPackage: 'Gemma 4 E2B Instruct',
      artifactLabel: 'Project notes',
    ),
    AssistantProjectTemplate(
      task: AssistantTask.skills,
      title: 'Agent Skills',
      description:
          'Plan multi-step local skills before app connectors execute.',
      primaryAction: 'Start skill project',
      defaultPackage: 'Gemma 4 E2B Instruct',
      artifactLabel: 'Skill plan',
    ),
    AssistantProjectTemplate(
      task: AssistantTask.actions,
      title: 'Mobile Actions',
      description: 'Open Airo features and run approved local actions.',
      primaryAction: 'Start action chat',
      defaultPackage: 'Gemini Nano on Pixel, FunctionGemma fallback',
      artifactLabel: 'Action trace',
    ),
    AssistantProjectTemplate(
      task: AssistantTask.image,
      title: 'Image Help',
      description: 'Prepare image analysis workflows with clear privacy state.',
      primaryAction: 'Prepare image project',
      defaultPackage: 'Gemma 3n E2B Multimodal',
      artifactLabel: 'Image notes',
    ),
    AssistantProjectTemplate(
      task: AssistantTask.audio,
      title: 'Audio Notes',
      description: 'Prepare transcription and meeting intelligence workflows.',
      primaryAction: 'Prepare audio project',
      defaultPackage: 'Gemma 3n E2B Multimodal',
      artifactLabel: 'Transcript draft',
    ),
  ];

  static AssistantProjectTemplate forTask(AssistantTask task) {
    return values.firstWhere((template) => template.task == task);
  }
}

class AssistantModelLibraryState {
  const AssistantModelLibraryState({
    required this.task,
    required this.deviceLabel,
    required this.platformLabel,
    required this.candidates,
    required this.recommended,
    required this.defaultPackages,
  });

  final AssistantTask task;
  final String deviceLabel;
  final String platformLabel;
  final List<AssistantModelCandidate> candidates;
  final AssistantModelCandidate recommended;
  final Map<AssistantTask, OfflineModelInfo> defaultPackages;

  static Future<AssistantModelLibraryState> load({
    required AssistantTask task,
  }) async {
    final nanoService = GeminiNanoService();
    final nanoSupported = await nanoService.isSupported();
    final deviceInfo = await nanoService.getDeviceInfo();
    final liteRtAvailable = await LiteRtLmService().isAvailable();

    await geminiApiService.initialize();
    final cloudAvailable = geminiApiService.isAvailable;
    final defaultPackages = _defaultPackages();
    final balancedPackage = defaultPackages[AssistantTask.reasoning];

    final platformLabel = kIsWeb
        ? 'Web'
        : defaultTargetPlatform.name.toUpperCase();
    final manufacturer = (deviceInfo['manufacturer'] as String?)?.trim();
    final model = (deviceInfo['model'] as String?)?.trim();
    final deviceLabel = [
      if (manufacturer != null && manufacturer.isNotEmpty) manufacturer,
      if (model != null && model.isNotEmpty) model,
    ].join(' ').trim();

    final candidatesById = <String, AssistantModelCandidate>{};
    void addCandidate(AssistantModelCandidate candidate) {
      candidatesById[candidate.id] = candidate;
    }

    addCandidate(
      AssistantModelCandidate(
        id: geminiNanoAssistantModelId,
        name: 'Gemini Nano',
        runtime: 'AICore on-device',
        description:
            'Default for private chat and mobile actions on supported Pixel devices.',
        bestFor: const [
          AssistantTask.chat,
          AssistantTask.actions,
          AssistantTask.documents,
        ],
        tags: const ['Local', 'Private', 'Streaming'],
        privacyLabel: 'Prompt stays on device',
        sizeLabel: 'System managed',
        available: nanoSupported,
        actionLabel: nanoSupported ? 'Start' : 'Needs Pixel 9 AICore',
        unavailableReason: nanoSupported
            ? null
            : 'Gemini Nano is only runnable when the native AICore integration reports support.',
        local: true,
      ),
    );
    addCandidate(
      AssistantModelCandidate(
        id: litertGemmaAssistantModelId,
        name: 'Gemma mobile package',
        runtime: 'LiteRT-LM local model',
        description:
            'Default local package for planning, documents, and medium reasoning.',
        bestFor: const [
          AssistantTask.reasoning,
          AssistantTask.documents,
          AssistantTask.skills,
          AssistantTask.chat,
        ],
        tags: const ['Local', 'Downloadable', 'Gemma'],
        privacyLabel: 'Prompt stays on device',
        sizeLabel: balancedPackage?.fileSizeDisplay ?? '2 GB to 4 GB typical',
        available: liteRtAvailable,
        actionLabel: liteRtAvailable ? 'Start' : 'Download package',
        unavailableReason: liteRtAvailable
            ? null
            : 'Set LITERT_LM_MODEL_PATH or LITERT_LM_MODEL_URL, or install a compatible local model.',
        local: true,
        opensModelManager: !liteRtAvailable,
        package: balancedPackage,
      ),
    );
    addCandidate(
      AssistantModelCandidate(
        id: geminiCloudAssistantModelId,
        name: 'Gemini Cloud',
        runtime: 'Google Generative Language API',
        description:
            'Fallback for use cases that are not covered by the on-device packages yet.',
        bestFor: const [
          AssistantTask.image,
          AssistantTask.audio,
          AssistantTask.reasoning,
        ],
        tags: const ['Cloud', 'Vision', 'API key'],
        privacyLabel: 'Sends prompt to API',
        sizeLabel: 'No local download',
        available: cloudAvailable,
        actionLabel: cloudAvailable ? 'Start' : 'Needs API setup',
        unavailableReason: cloudAvailable
            ? null
            : 'Launch Flutter with --dart-define=GEMINI_API_KEY=... to enable this real API path.',
        local: false,
      ),
    );
    for (final model in ModelCatalog.mobileRecommended.take(3)) {
      addCandidate(AssistantModelCandidate.fromOfflineModel(model));
    }
    for (final task in [
      AssistantTask.image,
      AssistantTask.audio,
      AssistantTask.actions,
    ]) {
      final model = defaultPackages[task];
      if (model != null) {
        addCandidate(AssistantModelCandidate.fromOfflineModel(model));
      }
    }
    final candidates = candidatesById.values.toList();

    final recommended = _recommend(candidates, task, defaultPackages);
    return AssistantModelLibraryState(
      task: task,
      deviceLabel: deviceLabel.isEmpty ? 'Unknown device' : deviceLabel,
      platformLabel: platformLabel,
      candidates: candidates,
      recommended: recommended,
      defaultPackages: defaultPackages,
    );
  }

  static AssistantModelCandidate _recommend(
    List<AssistantModelCandidate> candidates,
    AssistantTask task,
    Map<AssistantTask, OfflineModelInfo> packages,
  ) {
    final package = packages[task];
    final preferredIds = switch (task) {
      AssistantTask.chat => [
        geminiNanoAssistantModelId,
        litertGemmaAssistantModelId,
        if (package != null) 'offline-${package.id}',
      ],
      AssistantTask.actions => [
        geminiNanoAssistantModelId,
        if (package != null) 'offline-${package.id}',
      ],
      AssistantTask.reasoning || AssistantTask.documents => [
        litertGemmaAssistantModelId,
        if (package != null) 'offline-${package.id}',
      ],
      AssistantTask.skills => [
        litertGemmaAssistantModelId,
        if (package != null) 'offline-${package.id}',
      ],
      AssistantTask.image || AssistantTask.audio => [
        if (package != null) 'offline-${package.id}',
        geminiCloudAssistantModelId,
      ],
    };

    final preferred = <AssistantModelCandidate>[];
    for (final id in preferredIds) {
      for (final candidate in candidates) {
        if (candidate.id == id) {
          preferred.add(candidate);
          break;
        }
      }
    }
    if (preferred.isNotEmpty) {
      final ready = preferred.where((candidate) => candidate.available);
      if (ready.isNotEmpty) return ready.first;

      final setup = preferred.where((candidate) => candidate.opensModelManager);
      if (setup.isNotEmpty) return setup.first;

      return preferred.first;
    }

    final ranked = [...candidates]
      ..sort((a, b) {
        final aScore = a.scoreFor(task);
        final bScore = b.scoreFor(task);
        return bScore.compareTo(aScore);
      });
    return ranked.first;
  }

  AssistantModelCandidate? candidateById(String? id) {
    if (id == null) return null;
    for (final candidate in candidates) {
      if (candidate.id == id) return candidate;
    }
    return null;
  }

  AssistantModelCandidate recommendedFor(AssistantTask task) {
    return _recommend(candidates, task, defaultPackages);
  }

  OfflineModelInfo? packageFor(AssistantTask task) {
    return defaultPackages[task];
  }

  static Map<AssistantTask, OfflineModelInfo> _defaultPackages() {
    OfflineModelInfo byId(String id) {
      return ModelCatalog.bundledModels.firstWhere((model) => model.id == id);
    }

    final gemma4E2b = byId('gemma-4-e2b-it-litertlm');
    final gemma3n = byId('gemma-3n-e2b-it-litertlm');
    final functionGemma = byId('mobile-actions-270m-litertlm');

    return {
      AssistantTask.chat: gemma4E2b,
      AssistantTask.reasoning: gemma4E2b,
      AssistantTask.documents: gemma4E2b,
      AssistantTask.image: gemma3n,
      AssistantTask.audio: gemma3n,
      AssistantTask.skills: gemma4E2b,
      AssistantTask.actions: functionGemma,
    };
  }
}

class AssistantModelCandidate {
  const AssistantModelCandidate({
    required this.id,
    required this.name,
    required this.runtime,
    required this.description,
    required this.bestFor,
    required this.tags,
    required this.privacyLabel,
    required this.sizeLabel,
    required this.available,
    required this.actionLabel,
    required this.local,
    this.unavailableReason,
    this.opensModelManager = false,
    this.package,
  });

  factory AssistantModelCandidate.fromOfflineModel(OfflineModelInfo model) {
    return AssistantModelCandidate(
      id: 'offline-${model.id}',
      name: model.name,
      runtime: '${model.family.displayName} ${model.provider.displayName}',
      description:
          model.description ??
          'Offline model from the bundled local model catalog.',
      bestFor: _tasksFor(model),
      tags: [
        'Local',
        model.backendPreference.displayName,
        model.licenseState.displayName,
      ],
      privacyLabel: 'Prompt stays on device after install',
      sizeLabel: model.fileSizeDisplay,
      available: model.isDownloaded,
      actionLabel: model.isDownloaded ? 'Start' : 'Download package',
      unavailableReason: model.isDownloaded
          ? null
          : 'Download this package from Profile settings before using it in chat.',
      local: true,
      opensModelManager: !model.isDownloaded,
      package: model,
    );
  }

  final String id;
  final String name;
  final String runtime;
  final String description;
  final List<AssistantTask> bestFor;
  final List<String> tags;
  final String privacyLabel;
  final String sizeLabel;
  final bool available;
  final String actionLabel;
  final bool local;
  final String? unavailableReason;
  final bool opensModelManager;
  final OfflineModelInfo? package;

  int scoreFor(AssistantTask task) {
    var score = 0;
    if (available) score += 100;
    if (bestFor.contains(task)) score += 50;
    if (local && task != AssistantTask.image && task != AssistantTask.audio) {
      score += 10;
    }
    if (!available && opensModelManager) score -= 10;
    return score;
  }

  static List<AssistantTask> _tasksFor(OfflineModelInfo model) {
    return [
      for (final task in AssistantTask.values)
        if (model.capabilities.contains(task.defaultCapability)) task,
    ];
  }
}

class ModelLibraryScreen extends ConsumerWidget {
  const ModelLibraryScreen({
    super.key,
    required this.onModelSelected,
    required this.onOpenModelManager,
  });

  final ValueChanged<AssistantModelCandidate> onModelSelected;
  final VoidCallback onOpenModelManager;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(assistantModelLibraryProvider);

    return Scaffold(
      body: SafeArea(
        child: library.when(
          data: (state) => _ModelLibraryContent(
            state: state,
            onModelSelected: onModelSelected,
            onOpenModelManager: onOpenModelManager,
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _ModelLibraryError(
            message: error.toString(),
            onRetry: () => ref.invalidate(assistantModelLibraryProvider),
          ),
        ),
      ),
    );
  }
}

class _ModelLibraryContent extends ConsumerWidget {
  const _ModelLibraryContent({
    required this.state,
    required this.onModelSelected,
    required this.onOpenModelManager,
  });

  final AssistantModelLibraryState state;
  final ValueChanged<AssistantModelCandidate> onModelSelected;
  final VoidCallback onOpenModelManager;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final selectedModelId = ref.watch(selectedAssistantModelIdProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Row(
          children: [
            Icon(
              Icons.account_tree_outlined,
              color: theme.colorScheme.primary,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Start a Project',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Airo picks the right local package for each use case.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Refresh models',
              onPressed: () => ref.invalidate(assistantModelLibraryProvider),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _ProjectHierarchyBanner(state: state),
        const SizedBox(height: 16),
        Text('Choose category', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        for (final template in AssistantProjectTemplate.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ProjectTemplateCard(
              template: template,
              candidate: state.recommendedFor(template.task),
              package: state.packageFor(template.task),
              selected:
                  selectedModelId == state.recommendedFor(template.task).id,
              onStart: () => _handleStartProject(context, ref, template),
            ),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onOpenModelManager,
          icon: const Icon(Icons.tune, size: 18),
          label: const Text('Advanced model settings in Profile'),
        ),
      ],
    );
  }

  Future<void> _handleStartProject(
    BuildContext context,
    WidgetRef ref,
    AssistantProjectTemplate template,
  ) async {
    final candidate = state.recommendedFor(template.task);
    ref.read(selectedAssistantTaskProvider.notifier).state = template.task;

    if (candidate.opensModelManager) {
      final confirmed = await _confirmPackageSetup(
        context,
        template: template,
        candidate: candidate,
        package: state.packageFor(template.task),
      );
      if (confirmed == true && context.mounted) {
        onOpenModelManager();
      }
      return;
    }
    if (!candidate.available) {
      await _showUnavailablePackage(
        context,
        template: template,
        candidate: candidate,
      );
      return;
    }
    await ref
        .read(selectedAssistantModelIdProvider.notifier)
        .select(candidate.id);
    onModelSelected(candidate);
  }

  Future<bool?> _confirmPackageSetup(
    BuildContext context, {
    required AssistantProjectTemplate template,
    required AssistantModelCandidate candidate,
    required OfflineModelInfo? package,
  }) {
    final theme = Theme.of(context);
    final selectedPackage = package ?? candidate.package;
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.download_outlined),
        title: Text('Download ${template.title} package?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              selectedPackage == null
                  ? 'Airo recommends ${candidate.name} for this category.'
                  : 'Airo recommends ${selectedPackage.name} for this category.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            _DialogDetail(
              label: 'Package',
              value: selectedPackage?.name ?? template.defaultPackage,
            ),
            _DialogDetail(
              label: 'Size',
              value: selectedPackage?.fileSizeDisplay ?? candidate.sizeLabel,
            ),
            if (selectedPackage != null) ...[
              _DialogDetail(
                label: 'Backend',
                value: selectedPackage.backendPreference.displayName,
              ),
              _DialogDetail(
                label: 'Input',
                value: selectedPackage.modalities
                    .map((modality) => modality.displayName)
                    .join(', '),
              ),
              _DialogDetail(
                label: 'License',
                value: selectedPackage.licenseState.displayName,
              ),
            ],
            _DialogDetail(label: 'Privacy', value: candidate.privacyLabel),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Download package'),
          ),
        ],
      ),
    );
  }

  Future<void> _showUnavailablePackage(
    BuildContext context, {
    required AssistantProjectTemplate template,
    required AssistantModelCandidate candidate,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.info_outline),
        title: Text('${template.title} setup needed'),
        content: Text(
          candidate.unavailableReason ??
              'The default package for this category is not available on this device yet.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onOpenModelManager();
            },
            child: const Text('Open Profile settings'),
          ),
        ],
      ),
    );
  }
}

class _ProjectHierarchyBanner extends StatelessWidget {
  const _ProjectHierarchyBanner({required this.state});

  final AssistantModelLibraryState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.folder_open, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Project > Chat > Local package',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              state.platformLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectTemplateCard extends StatelessWidget {
  const _ProjectTemplateCard({
    required this.template,
    required this.candidate,
    required this.package,
    required this.selected,
    required this.onStart,
  });

  final AssistantProjectTemplate template;
  final AssistantModelCandidate candidate;
  final OfflineModelInfo? package;
  final bool selected;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outline = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.outlineVariant;
    final statusColor = candidate.available
        ? Colors.green.shade700
        : theme.colorScheme.onSurfaceVariant;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: outline),
        borderRadius: BorderRadius.circular(8),
        color: selected
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.28)
            : theme.colorScheme.surface,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: candidate.local
                        ? Colors.teal.withValues(alpha: 0.12)
                        : Colors.indigo.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    template.task.icon,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              template.title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          _StatusPill(
                            label: candidate.available ? 'Ready' : 'Setup',
                            color: statusColor,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        template.artifactLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(template.description, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatusPill(
                  label: candidate.name,
                  color: theme.colorScheme.primary,
                ),
                if (package != null && package!.name != candidate.name)
                  _StatusPill(
                    label: package!.name,
                    color: Colors.deepPurple.shade600,
                  ),
                _StatusPill(label: candidate.sizeLabel, color: Colors.blueGrey),
                if (package != null)
                  _StatusPill(
                    label: package!.backendPreference.displayName,
                    color: Colors.brown.shade600,
                  ),
                _StatusPill(
                  label: candidate.privacyLabel,
                  color: candidate.local ? Colors.teal : Colors.indigo,
                ),
                for (final tag in candidate.tags)
                  _StatusPill(label: tag, color: Colors.grey.shade700),
              ],
            ),
            if (candidate.unavailableReason != null) ...[
              const SizedBox(height: 10),
              Text(
                candidate.unavailableReason!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: onStart,
                icon: Icon(
                  candidate.opensModelManager
                      ? Icons.settings_outlined
                      : Icons.play_arrow,
                ),
                label: Text(
                  candidate.opensModelManager
                      ? 'Download package'
                      : template.primaryAction,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogDetail extends StatelessWidget {
  const _DialogDetail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ModelLibraryError extends StatelessWidget {
  const _ModelLibraryError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 44,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              'Model library failed to load',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
