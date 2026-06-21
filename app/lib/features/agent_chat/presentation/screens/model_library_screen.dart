import 'package:core_ai/core_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/services/gemini_api_service.dart';
import '../../../../core/services/gemini_nano_service.dart';
import '../../../../core/services/litert_lm_service.dart';

const String geminiNanoAssistantModelId = 'gemini-nano';
const String litertGemmaAssistantModelId = 'litert-gemma-mobile';
const String geminiCloudAssistantModelId = 'gemini-cloud';

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
  chat('Chat', Icons.chat_bubble_outline),
  reasoning('Reasoning', Icons.psychology_outlined),
  documents('Docs', Icons.description_outlined),
  image('Image', Icons.image_outlined),
  audio('Audio', Icons.mic_none),
  actions('Actions', Icons.touch_app_outlined);

  const AssistantTask(this.label, this.icon);

  final String label;
  final IconData icon;
}

class AssistantModelLibraryState {
  const AssistantModelLibraryState({
    required this.task,
    required this.deviceLabel,
    required this.platformLabel,
    required this.candidates,
    required this.recommended,
  });

  final AssistantTask task;
  final String deviceLabel;
  final String platformLabel;
  final List<AssistantModelCandidate> candidates;
  final AssistantModelCandidate recommended;

  static Future<AssistantModelLibraryState> load({
    required AssistantTask task,
  }) async {
    final nanoService = GeminiNanoService();
    final nanoSupported = await nanoService.isSupported();
    final deviceInfo = await nanoService.getDeviceInfo();
    final liteRtAvailable = await LiteRtLmService().isAvailable();

    await geminiApiService.initialize();
    final cloudAvailable = geminiApiService.isAvailable;

    final platformLabel = kIsWeb
        ? 'Web'
        : defaultTargetPlatform.name.toUpperCase();
    final manufacturer = (deviceInfo['manufacturer'] as String?)?.trim();
    final model = (deviceInfo['model'] as String?)?.trim();
    final deviceLabel = [
      if (manufacturer != null && manufacturer.isNotEmpty) manufacturer,
      if (model != null && model.isNotEmpty) model,
    ].join(' ').trim();

    final candidates = <AssistantModelCandidate>[
      AssistantModelCandidate(
        id: geminiNanoAssistantModelId,
        name: 'Gemini Nano',
        runtime: 'AICore on-device',
        description:
            'Best first choice for Pixel 9 chat and private assistant commands.',
        bestFor: const [
          AssistantTask.chat,
          AssistantTask.actions,
          AssistantTask.documents,
        ],
        tags: const ['Local', 'Private', 'Streaming'],
        privacyLabel: 'Prompt stays on device',
        sizeLabel: 'System managed',
        available: nanoSupported,
        actionLabel: nanoSupported ? 'Use model' : 'Requires Pixel 9 AICore',
        unavailableReason: nanoSupported
            ? null
            : 'Gemini Nano is only runnable when the native AICore integration reports support.',
        local: true,
      ),
      AssistantModelCandidate(
        id: litertGemmaAssistantModelId,
        name: 'Gemma mobile via LiteRT-LM',
        runtime: 'LiteRT-LM local model',
        description:
            'Good for offline drafts, routines, planning, and medium reasoning after a model is installed.',
        bestFor: const [
          AssistantTask.reasoning,
          AssistantTask.documents,
          AssistantTask.chat,
        ],
        tags: const ['Local', 'Downloadable', 'Gemma'],
        privacyLabel: 'Prompt stays on device',
        sizeLabel: '1 GB to 3 GB typical',
        available: liteRtAvailable,
        actionLabel: liteRtAvailable ? 'Use model' : 'Install/configure model',
        unavailableReason: liteRtAvailable
            ? null
            : 'Set LITERT_LM_MODEL_PATH or LITERT_LM_MODEL_URL, or install a compatible local model.',
        local: true,
        opensModelManager: !liteRtAvailable,
      ),
      AssistantModelCandidate(
        id: geminiCloudAssistantModelId,
        name: 'Gemini Cloud',
        runtime: 'Google Generative Language API',
        description:
            'Use when device models are unavailable or the task needs vision, long context, or broader knowledge.',
        bestFor: const [
          AssistantTask.image,
          AssistantTask.audio,
          AssistantTask.reasoning,
        ],
        tags: const ['Cloud', 'Vision', 'API key'],
        privacyLabel: 'Sends prompt to API',
        sizeLabel: 'No local download',
        available: cloudAvailable,
        actionLabel: cloudAvailable ? 'Use model' : 'Needs GEMINI_API_KEY',
        unavailableReason: cloudAvailable
            ? null
            : 'Launch Flutter with --dart-define=GEMINI_API_KEY=... to enable this real API path.',
        local: false,
      ),
      ...ModelCatalog.mobileRecommended
          .take(3)
          .map((model) => AssistantModelCandidate.fromOfflineModel(model)),
    ];

    final recommended = _recommend(candidates, task);
    return AssistantModelLibraryState(
      task: task,
      deviceLabel: deviceLabel.isEmpty ? 'Unknown device' : deviceLabel,
      platformLabel: platformLabel,
      candidates: candidates,
      recommended: recommended,
    );
  }

  static AssistantModelCandidate _recommend(
    List<AssistantModelCandidate> candidates,
    AssistantTask task,
  ) {
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
  });

  factory AssistantModelCandidate.fromOfflineModel(OfflineModelInfo model) {
    return AssistantModelCandidate(
      id: 'offline-${model.id}',
      name: model.name,
      runtime: '${model.family.displayName} GGUF',
      description:
          model.description ??
          'Offline model from the bundled local model catalog.',
      bestFor: model.tags.contains('reasoning')
          ? const [AssistantTask.reasoning, AssistantTask.chat]
          : const [AssistantTask.chat, AssistantTask.documents],
      tags: ['Local', model.fileSizeDisplay, model.quantization.displayName],
      privacyLabel: 'Prompt stays on device after install',
      sizeLabel: model.fileSizeDisplay,
      available: model.isDownloaded,
      actionLabel: model.isDownloaded ? 'Use model' : 'Download in AI Models',
      unavailableReason: model.isDownloaded
          ? null
          : 'Download this model from AI Models before using it in chat.',
      local: true,
      opensModelManager: !model.isDownloaded,
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
              Icons.model_training,
              color: theme.colorScheme.primary,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Model Library',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${state.platformLabel} - ${state.deviceLabel}',
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
        Text('Task', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        _TaskSelector(),
        const SizedBox(height: 16),
        Text('Recommended', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        _ModelCandidateCard(
          candidate: state.recommended,
          selected: selectedModelId == state.recommended.id,
          recommended: true,
          onUse: () => _handleUse(context, ref, state.recommended),
        ),
        const SizedBox(height: 18),
        Text('All Models', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        for (final candidate in state.candidates)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ModelCandidateCard(
              candidate: candidate,
              selected: selectedModelId == candidate.id,
              recommended: candidate.id == state.recommended.id,
              onUse: () => _handleUse(context, ref, candidate),
            ),
          ),
      ],
    );
  }

  Future<void> _handleUse(
    BuildContext context,
    WidgetRef ref,
    AssistantModelCandidate candidate,
  ) async {
    if (candidate.opensModelManager) {
      onOpenModelManager();
      return;
    }
    if (!candidate.available) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(candidate.unavailableReason ?? 'Model is unavailable'),
        ),
      );
      return;
    }
    await ref
        .read(selectedAssistantModelIdProvider.notifier)
        .select(candidate.id);
    onModelSelected(candidate);
  }
}

class _TaskSelector extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedAssistantTaskProvider);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final task in AssistantTask.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                avatar: Icon(task.icon, size: 18),
                label: Text(task.label),
                selected: selected == task,
                onSelected: (_) {
                  ref.read(selectedAssistantTaskProvider.notifier).state = task;
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _ModelCandidateCard extends StatelessWidget {
  const _ModelCandidateCard({
    required this.candidate,
    required this.selected,
    required this.recommended,
    required this.onUse,
  });

  final AssistantModelCandidate candidate;
  final bool selected;
  final bool recommended;
  final VoidCallback onUse;

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
                    candidate.local
                        ? Icons.memory_outlined
                        : Icons.cloud_outlined,
                    color: candidate.local ? Colors.teal : Colors.indigo,
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
                              candidate.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (recommended)
                            _StatusPill(
                              label: 'Recommended',
                              color: theme.colorScheme.primary,
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        candidate.runtime,
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
            Text(candidate.description, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatusPill(
                  label: candidate.available ? 'Runnable' : 'Setup needed',
                  color: statusColor,
                ),
                _StatusPill(label: candidate.sizeLabel, color: Colors.blueGrey),
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
                onPressed: onUse,
                icon: Icon(
                  candidate.opensModelManager
                      ? Icons.settings_outlined
                      : Icons.play_arrow,
                ),
                label: Text(candidate.actionLabel),
              ),
            ),
          ],
        ),
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
