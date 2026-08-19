import 'dart:async';

import 'package:core_ai/core_ai.dart';
import 'package:core_entitlements/core_entitlements.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mind_indic_intelligence.dart';
import 'mind_model_advisor.dart';
import 'mind_service.dart';
import 'models/model_descriptor_adapter.dart';
import 'models/model_provider.dart';
import 'settings/indic_intelligence_preferences.dart';

/// Shell override supplies the live scribe [MindService] (optional downloads,
/// Try it navigation). Mind shell overrides this at composition root.
final mindScribeServiceProvider = Provider<MindService>((ref) {
  throw StateError(
    'mindScribeServiceProvider must be overridden in the Mind shell.',
  );
});

/// Meeting scribe recommendations: featured ★ stack, alternates, Indic mode.
class MindScribeModelsPanel extends ConsumerStatefulWidget {
  const MindScribeModelsPanel({
    super.key,
    required this.scribeModelsById,
    required this.entitlements,
    this.memoryInfo,
    this.onTryStack,
    this.onAcquireComplete,
  });

  final Map<String, OfflineModelInfo> scribeModelsById;
  final Entitlements entitlements;
  final MemoryInfo? memoryInfo;
  final VoidCallback? onTryStack;
  final Future<void> Function()? onAcquireComplete;

  @override
  ConsumerState<MindScribeModelsPanel> createState() =>
      _MindScribeModelsPanelState();
}

class _MindScribeModelsPanelState extends ConsumerState<MindScribeModelsPanel> {
  String? _downloadingStackId;
  ModelAcquisitionProgress? _downloadProgress;
  String? _downloadError;
  List<String> _downloadFailed = const [];

  MindScribeStackRecommendation _recommendation(MindIndicGenerationMode mode) {
    final capability = MindIndicCapability(
      entitlements: widget.entitlements,
      memoryInfo: widget.memoryInfo,
    );
    return const MindModelAdvisor().recommend(
      capability: capability,
      generationMode: mode,
      scribeModelsById: widget.scribeModelsById,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_refreshInstalledState());
    });
  }

  Future<void> _refreshInstalledState() async {
    await widget.onAcquireComplete?.call();
    if (mounted) setState(() {});
  }

  Future<void> _downloadStack(MindModelRecommendation recommendation) async {
    final service = ref.read(mindScribeServiceProvider);
    final models = await _missingRequiredForStack(recommendation, service);
    if (models.isEmpty) {
      await _refreshInstalledState();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'These models are already on disk. Tap Try it to start scribe.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _downloadingStackId = recommendation.id;
      _downloadProgress = null;
      _downloadError = null;
      _downloadFailed = const [];
    });

    try {
      await for (final event in service.acquireModelFiles(models)) {
        if (!mounted) return;
        switch (event) {
          case ModelAcquisitionProgress():
            setState(() => _downloadProgress = event);
          case ModelAcquisitionDone(:final failedFileNames):
            setState(() => _downloadFailed = failedFileNames);
        }
      }
    } on Object catch (error) {
      if (mounted) setState(() => _downloadError = '$error');
    }

    if (!mounted) return;
    setState(() {
      _downloadingStackId = null;
      _downloadProgress = null;
    });
    if (_downloadFailed.isEmpty && _downloadError == null) {
      await _refreshInstalledState();
    }
  }

  Future<List<RequiredModel>> _missingRequiredForStack(
    MindModelRecommendation recommendation,
    MindService service,
  ) async {
    final dir = await service.modelsDirectory();
    final catalogIds = <String>[
      recommendation.speechModelId,
      if (recommendation.generationModelId != null)
        recommendation.generationModelId!,
    ];
    final missing = <RequiredModel>[];
    for (final id in catalogIds) {
      final required = await requiredModelForScribeCatalogId(id);
      if (required == null) continue;
      if (!PinnedModelFiles.isPresent(dir, required)) {
        missing.add(required);
      }
    }
    return missing;
  }

  @override
  Widget build(BuildContext context) {
    final generationMode = ref.watch(indicGenerationModeProvider);
    final recommendation = _recommendation(generationMode);
    final capability = MindIndicCapability(
      entitlements: widget.entitlements,
      memoryInfo: widget.memoryInfo,
    );
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Meeting scribe picks',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Airo recommends a speech + minutes stack for your device. '
          'Nothing runs until the weights are on disk.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (capability.proEnabled && capability.isDesktopHost) ...[
          const SizedBox(height: 12),
          _GenerationModeSelector(
            value: generationMode,
            onChanged: (mode) =>
                ref.read(indicGenerationModeProvider.notifier).select(mode),
          ),
        ],
        const SizedBox(height: 16),
        _RecommendationCard(
          recommendation: recommendation.featured,
          downloading: _downloadingStackId == recommendation.featured.id,
          progress: _downloadingStackId == recommendation.featured.id
              ? _downloadProgress
              : null,
          onPrimary: () => _handlePrimary(recommendation.featured),
        ),
        if (_downloadError != null && _downloadFailed.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            _downloadError!,
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ],
        if (recommendation.alternates.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Alternates', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          for (final alternate in recommendation.alternates)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _RecommendationCard(
                recommendation: alternate,
                downloading: _downloadingStackId == alternate.id,
                progress: _downloadingStackId == alternate.id
                    ? _downloadProgress
                    : null,
                onPrimary: () => _handlePrimary(alternate),
              ),
            ),
        ],
        if (recommendation.speechStub != null) ...[
          const SizedBox(height: 8),
          _RecommendationCard(
            recommendation: recommendation.speechStub!,
            onPrimary: null,
          ),
        ],
      ],
    );
  }

  void _handlePrimary(MindModelRecommendation recommendation) {
    switch (recommendation.action) {
      case MindModelRecommendationAction.tryNow:
        widget.onTryStack?.call();
      case MindModelRecommendationAction.download:
        unawaited(_downloadStack(recommendation));
      case MindModelRecommendationAction.disabled:
        break;
    }
  }
}

class _GenerationModeSelector extends StatelessWidget {
  const _GenerationModeSelector({
    required this.value,
    required this.onChanged,
  });

  final MindIndicGenerationMode value;
  final ValueChanged<MindIndicGenerationMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final mode in MindIndicGenerationMode.values)
          ChoiceChip(
            label: Text(_label(mode)),
            selected: value == mode,
            onSelected: (_) => onChanged(mode),
          ),
      ],
    );
  }

  static String _label(MindIndicGenerationMode mode) => switch (mode) {
    MindIndicGenerationMode.auto => 'Auto',
    MindIndicGenerationMode.standard => 'Standard (Qwen)',
    MindIndicGenerationMode.enhancedIndic => 'Enhanced Indic (Sarvam)',
  };
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({
    required this.recommendation,
    required this.onPrimary,
    this.downloading = false,
    this.progress,
  });

  final MindModelRecommendation recommendation;
  final VoidCallback? onPrimary;
  final bool downloading;
  final ModelAcquisitionProgress? progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outline = recommendation.featured
        ? theme.colorScheme.primary
        : theme.colorScheme.outlineVariant;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: outline, width: recommendation.featured ? 2 : 1),
        borderRadius: BorderRadius.circular(12),
        color: recommendation.featured
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.22)
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recommendation.badgeLabel,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        recommendation.headline,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        recommendation.subheadline,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  recommendation.sizeLabel,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(recommendation.runtimeNote, style: theme.textTheme.bodyMedium),
            if (recommendation.blockedReason != null) ...[
              const SizedBox(height: 8),
              Text(
                recommendation.blockedReason!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (downloading && progress != null) ...[
              LinearProgressIndicator(
                value: progress!.total > 0
                    ? progress!.fetched / progress!.total
                    : null,
              ),
              const SizedBox(height: 6),
              Text(
                'Downloading ${progress!.fileName}…',
                style: theme.textTheme.bodySmall,
              ),
            ] else if (onPrimary != null &&
                recommendation.action != MindModelRecommendationAction.disabled)
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  onPressed: downloading ? null : onPrimary,
                  child: Text(recommendation.actionLabel),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Maps scribe catalog ids to pinned [RequiredModel] entries.
Future<RequiredModel?> requiredModelForScribeCatalogId(String catalogId) async {
  final fileName = scribeCatalogIdToFileName[catalogId];
  if (fileName == null) return null;

  final pinned = await pinnedRequiredModels();
  for (final model in pinned) {
    if (model.fileName == fileName) return model;
  }
  for (final model in mindSpeechOptionalModels()) {
    if (model.fileName == fileName) return model;
  }
  for (final model in mindIndicOptionalModels()) {
    if (model.fileName == fileName) return model;
  }
  for (final model in mindDiarizeOptionalModels()) {
    if (model.fileName == fileName) return model;
  }
  if (pinnedMultilingualSpeechModel.fileName == fileName) {
    return pinnedMultilingualSpeechModel;
  }
  return null;
}

const Map<String, String> scribeCatalogIdToFileName = {
  MindScribeModelIds.whisperMultilingual: 'ggml-tiny.bin',
  MindScribeModelIds.whisperEnglish: 'ggml-tiny.en.bin',
  MindScribeModelIds.whisperSmallMultilingual: 'ggml-small.bin',
  MindScribeModelIds.whisperSmallEnglish: 'ggml-small.en.bin',
  MindScribeModelIds.qwenGeneration: 'qwen2.5-0.5b-instruct-q4_k_m.gguf',
  MindScribeModelIds.sarvamGeneration: 'sarvam-1-Q4_K_M.gguf',
  'mind-scribe-ecapa-diarize': 'ecapa_tdnn_tiny_int8.onnx',
};
