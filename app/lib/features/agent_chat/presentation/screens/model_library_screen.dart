import 'dart:async';

import 'package:core_ai/core_ai.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../application/assistant_model_preferences.dart';
import '../../../settings/application/ai_preferences_settings.dart';
import '../../data/services/assistant_runtime_service.dart';
import '../../../../core/ai/model_learn_more_launcher.dart';
import '../../../../core/services/gemini_api_service.dart';
import '../../../../core/services/gemini_nano_service.dart';
import '../../../../core/services/litert_lm_service.dart';
import '../../domain/models/assistant_runtime_ids.dart';
import 'model_health_center_screen.dart';

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
  actions('Action Project', Icons.touch_app_outlined),
  promptLab('Prompt Lab Project', Icons.tune),
  tinyGarden('Tiny Garden Project', Icons.local_florist_outlined);

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
    AssistantTask.promptLab => ModelCapability.promptLab,
    AssistantTask.tinyGarden => ModelCapability.mobileActions,
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
    AssistantProjectTemplate(
      task: AssistantTask.promptLab,
      title: 'Prompt Lab',
      description: 'Compare prompts with controlled generation settings.',
      primaryAction: 'Open prompt lab',
      defaultPackage: 'Gemma 4 E2B Instruct',
      artifactLabel: 'Prompt experiment',
    ),
    AssistantProjectTemplate(
      task: AssistantTask.tinyGarden,
      title: 'Tiny Garden',
      description:
          'Try a playful offline world controlled with natural language.',
      primaryAction: 'Open Tiny Garden',
      defaultPackage: 'FunctionGemma 270M',
      artifactLabel: 'Garden state',
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

  /// A native LiteRT channel is not proof that a model can be loaded. The
  /// runtime must either have an installed package or an explicit local model
  /// path configured. A URL alone is only a download source, not a runnable
  /// model.
  static bool isLiteRtReady({
    required bool runtimeAvailable,
    required bool hasDownloadedPackage,
    required bool hasConfiguredModelPath,
  }) {
    return hasDownloadedPackage || (runtimeAvailable && hasConfiguredModelPath);
  }

  /// A downloaded file is not automatically an executable local runtime.
  /// `.litertlm`/`.task` artifacts (or an explicit LiteRT catalog tag) are
  /// handled by the LiteRT adapter; plain `.gguf` files require the native
  /// llama.cpp backend, which is not bundled in the public app yet.
  static bool isLiteRtPackage(OfflineModelInfo model) {
    final source =
        '${model.id} ${model.filePath ?? ''} ${model.downloadUrl ?? ''}'
            .toLowerCase();
    return source.contains('.litertlm') ||
        source.contains('litertlm') ||
        source.contains('.task') ||
        model.tags.any((tag) => tag.toLowerCase().contains('litert'));
  }

  static Future<AssistantModelLibraryState> load({
    required AssistantTask task,
  }) async {
    final nanoService = GeminiNanoService();
    final nanoSupported = await nanoService.isSupported();
    final deviceInfo = await nanoService.getDeviceInfo();
    final liteRtService = LiteRtLmService();
    final liteRtAvailable = await liteRtService.isAvailable();

    await geminiApiService.initialize();
    final cloudAvailable = geminiApiService.isAvailable;
    final defaultPackages = await _defaultPackages(liteRtService);
    final balancedPackage = defaultPackages[AssistantTask.reasoning];
    final hasDownloadedBalancedPackage = balancedPackage?.isDownloaded ?? false;
    final liteRtReady = isLiteRtReady(
      runtimeAvailable: liteRtAvailable,
      hasDownloadedPackage: hasDownloadedBalancedPackage,
      hasConfiguredModelPath: liteRtService.hasConfiguredModelPath,
    );
    final compatibilityByModelId = await _loadCompatibilityByModelId(
      liteRtService,
      defaultPackages,
    );

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
    // A catalog entry is not an installed runtime. Do not put a LiteRT card
    // in the Mind chooser when the device has neither an executable artifact
    // nor a configured model path. Model Management remains the explicit
    // place to download/install a package.
    if (liteRtReady) {
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
          available: true,
          actionLabel: 'Start',
          local: true,
          package: balancedPackage,
          compatibility: balancedPackage == null
              ? null
              : compatibilityByModelId[balancedPackage.id],
        ),
      );
    }
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
      final hydrated = await liteRtService.hydrateDownloadedModel(model);
      if (hydrated.isDownloaded) {
        addCandidate(
          AssistantModelCandidate.fromOfflineModel(
            hydrated,
            compatibilityByModelId: compatibilityByModelId,
          ),
        );
      }
    }
    for (final task in [
      AssistantTask.image,
      AssistantTask.audio,
      AssistantTask.actions,
      AssistantTask.promptLab,
      AssistantTask.tinyGarden,
    ]) {
      final model = defaultPackages[task];
      if (model != null && model.isDownloaded) {
        addCandidate(
          AssistantModelCandidate.fromOfflineModel(
            model,
            compatibilityByModelId: compatibilityByModelId,
          ),
        );
      }
    }
    final candidates = candidatesById.values.toList();

    final recommended = recommend(candidates, task, defaultPackages);
    return AssistantModelLibraryState(
      task: task,
      deviceLabel: deviceLabel.isEmpty ? 'Unknown device' : deviceLabel,
      platformLabel: platformLabel,
      candidates: candidates,
      recommended: recommended,
      defaultPackages: defaultPackages,
    );
  }

  static AssistantModelCandidate recommend(
    List<AssistantModelCandidate> candidates,
    AssistantTask task,
    Map<AssistantTask, OfflineModelInfo> packages,
  ) {
    final package = packages[task];
    final preferredIds = switch (task) {
      AssistantTask.chat => [
        litertGemmaAssistantModelId,
        geminiNanoAssistantModelId,
        if (package != null) assistantModelIdForOfflineModel(package.id),
      ],
      AssistantTask.actions => [
        geminiNanoAssistantModelId,
        if (package != null) assistantModelIdForOfflineModel(package.id),
      ],
      AssistantTask.reasoning || AssistantTask.documents => [
        litertGemmaAssistantModelId,
        if (package != null) assistantModelIdForOfflineModel(package.id),
      ],
      AssistantTask.skills => [
        litertGemmaAssistantModelId,
        if (package != null) assistantModelIdForOfflineModel(package.id),
      ],
      AssistantTask.image || AssistantTask.audio => [
        if (package != null) assistantModelIdForOfflineModel(package.id),
        geminiCloudAssistantModelId,
      ],
      AssistantTask.promptLab => [
        litertGemmaAssistantModelId,
        if (package != null) assistantModelIdForOfflineModel(package.id),
      ],
      AssistantTask.tinyGarden => [
        geminiNanoAssistantModelId,
        if (package != null) assistantModelIdForOfflineModel(package.id),
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
    return recommend(candidates, task, defaultPackages);
  }

  OfflineModelInfo? packageFor(AssistantTask task) {
    return defaultPackages[task];
  }

  static Future<Map<AssistantTask, OfflineModelInfo>> _defaultPackages(
    LiteRtLmService liteRtService,
  ) async {
    OfflineModelInfo byId(String id) {
      return ModelCatalog.bundledModels.firstWhere((model) => model.id == id);
    }

    final gemma4E2b = await liteRtService.hydrateDownloadedModel(
      byId('gemma-4-e2b-it-litertlm'),
    );
    final gemma3n = await liteRtService.hydrateDownloadedModel(
      byId('gemma-3n-e2b-it-litertlm'),
    );
    final functionGemma = await liteRtService.hydrateDownloadedModel(
      byId('mobile-actions-270m-litertlm'),
    );

    return {
      AssistantTask.chat: gemma4E2b,
      AssistantTask.reasoning: gemma4E2b,
      AssistantTask.documents: gemma4E2b,
      AssistantTask.image: gemma3n,
      AssistantTask.audio: gemma3n,
      AssistantTask.skills: gemma4E2b,
      AssistantTask.actions: functionGemma,
      AssistantTask.promptLab: gemma4E2b,
      AssistantTask.tinyGarden: functionGemma,
    };
  }

  static Future<Map<String, ModelCompatibilityResult>>
  _loadCompatibilityByModelId(
    LiteRtLmService liteRtService,
    Map<AssistantTask, OfflineModelInfo> defaultPackages,
  ) async {
    final registry = ModelRegistry();
    final modelsById = <String, OfflineModelInfo>{};

    void addModel(OfflineModelInfo model) {
      modelsById[model.id] = model;
    }

    for (final model in defaultPackages.values) {
      addModel(model);
    }
    for (final model in ModelCatalog.mobileRecommended.take(3)) {
      addModel(await liteRtService.hydrateDownloadedModel(model));
    }

    final compatibilityByModelId = <String, ModelCompatibilityResult>{};
    for (final entry in modelsById.entries) {
      compatibilityByModelId[entry.key] = await registry.checkCompatibility(
        entry.value,
      );
    }
    return compatibilityByModelId;
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
    this.compatibility,
  });

  factory AssistantModelCandidate.fromOfflineModel(
    OfflineModelInfo model, {
    Map<String, ModelCompatibilityResult> compatibilityByModelId = const {},
  }) {
    final isLiteRt = AssistantModelLibraryState.isLiteRtPackage(model);
    final isRunnable = model.isDownloaded && isLiteRt;
    return AssistantModelCandidate(
      id: assistantModelIdForOfflineModel(model.id),
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
      available: isRunnable,
      actionLabel: isRunnable
          ? 'Start'
          : model.isDownloaded
          ? 'Native backend unavailable'
          : 'Download package',
      unavailableReason: model.isDownloaded && !isLiteRt
          ? 'This GGUF package is downloaded, but local llama.cpp execution is not bundled. Configure an OpenAI-compatible remote server or choose a LiteRT package.'
          : model.isDownloaded
          ? null
          : 'Download this package from Profile settings before using it in chat.',
      local: true,
      opensModelManager: !model.isDownloaded,
      package: model,
      compatibility: compatibilityByModelId[model.id],
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
  final ModelCompatibilityResult? compatibility;

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
    this.runtimeService,
  });

  final ValueChanged<AssistantModelCandidate> onModelSelected;
  final VoidCallback onOpenModelManager;
  final AssistantRuntimeService? runtimeService;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(assistantModelLibraryProvider);

    return AiroResponsiveScaffold(
      isLoading: library.isLoading,
      errorMessage: library.hasError ? library.error.toString() : null,
      onRetry: () => ref.invalidate(assistantModelLibraryProvider),
      body: library.maybeWhen(
        data: (state) => _ModelLibraryContent(
          state: state,
          onModelSelected: onModelSelected,
          onOpenModelManager: onOpenModelManager,
          runtimeService: runtimeService ?? AssistantRuntimeService(),
        ),
        orElse: () => const SizedBox.shrink(),
      ),
    );
  }
}

class _ModelLibraryContent extends ConsumerWidget {
  const _ModelLibraryContent({
    required this.state,
    required this.onModelSelected,
    required this.onOpenModelManager,
    required this.runtimeService,
  });

  final AssistantModelLibraryState state;
  final ValueChanged<AssistantModelCandidate> onModelSelected;
  final VoidCallback onOpenModelManager;
  final AssistantRuntimeService runtimeService;

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
        _RuntimeHealthButton(
          candidate: state.recommended,
          onOpenModelManager: onOpenModelManager,
        ),
        const SizedBox(height: 16),
        Text('Choose category', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        for (final template in AssistantProjectTemplate.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ProjectTemplateCard(
              template: template,
              candidate: state.recommendedFor(template.task),
              // Keep the catalog package available to setup callbacks, but do
              // not render an uninstalled LiteRT artifact as if it were part
              // of the active project. The card should describe executable
              // state, not a download recommendation.
              package: state.packageFor(template.task)?.isDownloaded == true
                  ? state.packageFor(template.task)
                  : null,
              selected:
                  selectedModelId == state.recommendedFor(template.task).id,
              onStart: () => _handleStartProject(context, ref, template),
              onLearnMore: () {
                final model =
                    state.packageFor(template.task) ??
                    state.recommendedFor(template.task).package;
                if (model != null) {
                  launchModelLearnMore(context, model);
                }
              },
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
    final hasDownloadedPackage = candidate.package?.isDownloaded ?? false;
    ref.read(selectedAssistantTaskProvider.notifier).state = template.task;
    // Read the notifier up front: the library provider can reload while a
    // local runtime prepares, which unmounts this element and makes `ref`
    // unusable by the time preparation finishes.
    final selection = ref.read(selectedAssistantModelIdProvider.notifier);

    if (candidate.opensModelManager && !hasDownloadedPackage) {
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
    if (!candidate.available && !hasDownloadedPackage) {
      await _showUnavailablePackage(
        context,
        template: template,
        candidate: candidate,
      );
      return;
    }
    if (candidate.local) {
      final result = await _prepareLocalRuntime(
        context,
        candidate: candidate,
        template: template,
      );
      if (!result.isReady) {
        return;
      }
    }
    await selection.select(candidate.id);
    onModelSelected(candidate);
  }

  Future<AssistantRuntimePreparationResult> _prepareLocalRuntime(
    BuildContext context, {
    required AssistantModelCandidate candidate,
    required AssistantProjectTemplate template,
  }) async {
    final progress = ValueNotifier(
      const AssistantRuntimePreparationProgress(
        phase: AssistantRuntimePreparationPhase.validate,
        progress: 0,
        label: 'Prepare runtime',
        detail: 'Starting compatibility checks.',
      ),
    );
    var cancelRequested = false;

    // Preparation outlives this element: a library reload swaps the content
    // subtree out while a runtime warms up. Hold the navigator and messenger
    // captured here rather than reaching through `context` after the await,
    // or the progress dialog is never dismissed and the prepared runtime is
    // silently dropped instead of opening chat.
    final navigator = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);
    var dialogVisible = true;

    void closeSetupDialog() {
      if (!dialogVisible) return;
      dialogVisible = false;
      navigator.pop();
    }

    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return ValueListenableBuilder<AssistantRuntimePreparationProgress>(
            valueListenable: progress,
            builder: (context, value, _) {
              return AlertDialog(
                title: Text('${template.title} setup'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value.label),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: value.progress),
                    const SizedBox(height: 12),
                    Text(value.detail),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      // Close on the spot. The runtime notices the flag and
                      // returns `cancelled`; waiting for that to dismiss the
                      // dialog leaves no way out once preparation has already
                      // finished.
                      cancelRequested = true;
                      closeSetupDialog();
                    },
                    child: const Text('Cancel'),
                  ),
                ],
              );
            },
          );
        },
        // Covers the Android back button, which pops the dialog without going
        // through closeSetupDialog().
      ).then((_) => dialogVisible = false),
    );

    final result = await runtimeService.prepareRuntime(
      candidate: candidate,
      onProgress: (value) => progress.value = value,
      isCancelled: () => cancelRequested,
    );

    progress.dispose();
    closeSetupDialog();

    if (result.status == AssistantRuntimePreparationStatus.cancelled) {
      messenger.showSnackBar(
        SnackBar(content: Text('${candidate.name} setup cancelled.')),
      );
      return result;
    }
    if (result.diagnostic != null) {
      await _showPreparationFailure(
        navigator.context,
        diagnostic: result.diagnostic!,
        candidate: candidate,
      );
    }
    return result;
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
          if (selectedPackage?.learnMoreUri != null)
            TextButton(
              onPressed: () => launchModelLearnMore(context, selectedPackage!),
              child: const Text('Learn more'),
            ),
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

  Future<void> _showPreparationFailure(
    BuildContext context, {
    required AssistantRuntimeDiagnosticEnvelope diagnostic,
    required AssistantModelCandidate candidate,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(diagnostic.summary),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(diagnostic.detail),
              const SizedBox(height: 12),
              Text(
                'Device: ${diagnostic.deviceLabel}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                'Platform: ${diagnostic.platformLabel}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (diagnostic.repairActions.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Repair actions',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                for (final action in diagnostic.repairActions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('• $action'),
                  ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: diagnostic.toMarkdown()),
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Diagnostics copied')),
                );
              }
            },
            child: const Text('Copy diagnostics'),
          ),
          if (candidate.opensModelManager)
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                onOpenModelManager();
              },
              child: const Text('Open model settings'),
            )
          else
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
        ],
      ),
    );
  }
}

class _RuntimeHealthButton extends ConsumerWidget {
  const _RuntimeHealthButton({
    required this.candidate,
    required this.onOpenModelManager,
  });

  final AssistantModelCandidate candidate;
  final VoidCallback onOpenModelManager;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.health_and_safety_outlined),
        title: const Text('Runtime Health Center'),
        subtitle: const Text(
          'See why this model is ready, blocked, or still preparing.',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          final model = candidate.package;
          if (model == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Health details will appear after a local model is selected.',
                ),
              ),
            );
            return;
          }
          final report = ModelHealthReport.fromFacts(
            model: model,
            compatibility: candidate.compatibility,
          );
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ModelHealthCenterScreen(
                report: report,
                onAction: (action) {
                  var reducedContext = 1024;
                  if (action == ModelHealthAction.reduceContext) {
                    final settings = ref.read(aiPreferencesSettingsProvider);
                    reducedContext = settings.contextLength <= 1024
                        ? 512
                        : 1024;
                    unawaited(
                      ref
                          .read(aiPreferencesSettingsProvider.notifier)
                          .update(
                            settings.copyWith(contextLength: reducedContext),
                          ),
                    );
                  }
                  final message = switch (action) {
                    ModelHealthAction.retry =>
                      'Retrying is available from Model Management after checking the runtime status.',
                    ModelHealthAction.reduceContext =>
                      'Context profile reduced to $reducedContext tokens. Retry the model now.',
                    ModelHealthAction.resumeDownload =>
                      'Resume the model download from Model Management.',
                    ModelHealthAction.repair =>
                      'Repair or re-download the model from Model Management.',
                    ModelHealthAction.chooseAlternative =>
                      'Choose another installed model from Model Management.',
                  };
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(message)));
                  onOpenModelManager();
                },
              ),
            ),
          );
        },
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
    required this.onLearnMore,
  });

  final AssistantProjectTemplate template;
  final AssistantModelCandidate candidate;
  final OfflineModelInfo? package;
  final bool selected;
  final VoidCallback onStart;
  final VoidCallback onLearnMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outline = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.outlineVariant;
    final statusColor = candidate.available
        ? Colors.green.shade700
        : theme.colorScheme.onSurfaceVariant;

    final semanticsLabel =
        'Project: ${template.title}. '
        'Artifact: ${template.artifactLabel}. '
        'Description: ${template.description}. '
        'Model: ${candidate.name}. '
        'Status: ${candidate.available ? "Ready" : "Requires setup"}. '
        'Privacy: ${candidate.privacyLabel}.';

    return Semantics(
      container: true,
      label: semanticsLabel,
      child: DecoratedBox(
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
                  _StatusPill(
                    label: candidate.sizeLabel,
                    color: Colors.blueGrey,
                  ),
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
              if (candidate.local && candidate.compatibility != null) ...[
                const SizedBox(height: 12),
                _CompatibilityPanel(compatibility: candidate.compatibility!),
              ],
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
                child: OverflowBar(
                  alignment: MainAxisAlignment.end,
                  spacing: 8,
                  overflowAlignment: OverflowBarAlignment.end,
                  children: [
                    if ((package ?? candidate.package)?.learnMoreUri != null)
                      TextButton(
                        onPressed: onLearnMore,
                        child: const Text('Learn more'),
                      ),
                    FilledButton.icon(
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
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompatibilityPanel extends StatelessWidget {
  const _CompatibilityPanel({required this.compatibility});

  final ModelCompatibilityResult compatibility;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final severity = compatibility.memorySeverity;
    final color = switch (severity) {
      MemorySeverity.safe => Colors.green.shade700,
      MemorySeverity.warning => Colors.orange.shade700,
      MemorySeverity.critical => Colors.deepOrange.shade700,
      MemorySeverity.blocked => theme.colorScheme.error,
    };
    final detail = compatibility.reason ?? severity.description;
    final memoryLine =
        compatibility.availableMemoryMB > 0 &&
            compatibility.requiredMemoryMB > 0
        ? 'Needs ${compatibility.requiredMemoryMB.toStringAsFixed(0)} MB, '
              'device has ${compatibility.availableMemoryMB.toStringAsFixed(0)} MB free.'
        : 'Device memory estimate unavailable. Runtime checks will verify before launch.';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_iconFor(severity), color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Device fit: ${severity.title}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(detail, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text(
                    memoryLine,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(MemorySeverity severity) {
    return switch (severity) {
      MemorySeverity.safe => Icons.verified_outlined,
      MemorySeverity.warning => Icons.warning_amber_rounded,
      MemorySeverity.critical => Icons.report_problem_outlined,
      MemorySeverity.blocked => Icons.block_outlined,
    };
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
