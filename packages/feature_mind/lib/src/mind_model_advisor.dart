import 'package:core_ai/core_ai.dart';
import 'package:flutter/foundation.dart';

import 'mind_indic_intelligence.dart';

/// Stable catalog ids for scribe weights shown in the model advisor.
abstract final class MindScribeModelIds {
  static const whisperMultilingual = 'mind-scribe-whisper-tiny-multilingual';
  static const whisperEnglish = 'mind-scribe-whisper-tiny-en';
  static const qwenGeneration = 'mind-scribe-qwen2.5-0.5b-instruct';
  static const sarvamGeneration = 'mind-scribe-sarvam-1-indic';
}

/// How strongly a stack or model fits the current device context.
enum MindModelRecommendationSeverity {
  safe,
  warning,
  critical,
  blocked;

  bool get canUse => this != blocked;
}

/// Primary call-to-action for a recommendation card.
enum MindModelRecommendationAction {
  tryNow,
  download,
  disabled,
}

/// Featured vs alternate row styling.
enum MindModelRecommendationBadge {
  bestOverall,
  alternate,
  blocked,
  comingSoon,
}

/// One scribe stack or single-model pick with runtime guidance.
@immutable
class MindModelRecommendation {
  const MindModelRecommendation({
    required this.id,
    required this.headline,
    required this.subheadline,
    required this.runtimeNote,
    required this.severity,
    required this.action,
    required this.badge,
    required this.speechModelId,
    required this.generationModelId,
    required this.sizeLabel,
    this.blockedReason,
    this.featured = false,
  });

  final String id;
  final String headline;
  final String subheadline;
  final String runtimeNote;
  final MindModelRecommendationSeverity severity;
  final MindModelRecommendationAction action;
  final MindModelRecommendationBadge badge;
  final String speechModelId;
  final String? generationModelId;
  final String sizeLabel;
  final String? blockedReason;
  final bool featured;

  String get badgeLabel => switch (badge) {
    MindModelRecommendationBadge.bestOverall => '★ Best overall',
    MindModelRecommendationBadge.alternate => 'Alternate',
    MindModelRecommendationBadge.blocked => 'Unavailable',
    MindModelRecommendationBadge.comingSoon => 'Coming soon',
  };

  String get actionLabel => switch (action) {
    MindModelRecommendationAction.tryNow => 'Try it',
    MindModelRecommendationAction.download => 'Download',
    MindModelRecommendationAction.disabled => 'Unavailable',
  };
}

/// Featured stack plus alternates for meeting scribe model picks.
@immutable
class MindScribeStackRecommendation {
  const MindScribeStackRecommendation({
    required this.featured,
    required this.alternates,
    this.speechStub,
  });

  final MindModelRecommendation featured;
  final List<MindModelRecommendation> alternates;

  /// Reserved Sarvam Edge ASR card — not publicly downloadable yet.
  final MindModelRecommendation? speechStub;
}

/// Context-based recommendations for meeting transcription + minutes stacks.
class MindModelAdvisor {
  const MindModelAdvisor();

  MindScribeStackRecommendation recommend({
    required MindIndicCapability capability,
    required MindIndicGenerationMode generationMode,
    required Map<String, OfflineModelInfo> scribeModelsById,
  }) {
    final whisperMl = scribeModelsById[MindScribeModelIds.whisperMultilingual];
    final whisperEn = scribeModelsById[MindScribeModelIds.whisperEnglish];
    final qwen = scribeModelsById[MindScribeModelIds.qwenGeneration];
    final sarvam = scribeModelsById[MindScribeModelIds.sarvamGeneration];

    final preferSarvam = capability.shouldPreferIndicGeneration(generationMode);
    final sarvamBlocked = _sarvamBlockedReason(capability, generationMode);
    final mobile = !capability.isDesktopHost;

    final featuredGenerationId = mobile || sarvamBlocked != null || !preferSarvam
        ? MindScribeModelIds.qwenGeneration
        : MindScribeModelIds.sarvamGeneration;

    final featured = _stackRecommendation(
      id: 'scribe-stack-featured',
      speechModel: whisperMl,
      generationModel: _modelForId(scribeModelsById, featuredGenerationId),
      speechFallbackName: 'Whisper Tiny (Multilingual)',
      generationFallbackName: featuredGenerationId == MindScribeModelIds.sarvamGeneration
          ? 'Sarvam-1 (Q4_K_M)'
          : 'Qwen2.5 0.5B Instruct (Q4_K_M)',
      badge: MindModelRecommendationBadge.bestOverall,
      featured: true,
      severity: _stackSeverity(
        speech: whisperMl,
        generation: _modelForId(scribeModelsById, featuredGenerationId),
        capability: capability,
        blockedReason: sarvamBlocked,
        usesSarvam: featuredGenerationId == MindScribeModelIds.sarvamGeneration,
      ),
      runtimeNote: mobile
          ? 'Meetings on phones and tablets stay on Whisper multilingual plus '
              'the compact Qwen minutes writer. Enhanced Indic generation is '
              'desktop-only.'
          : featuredGenerationId == MindScribeModelIds.sarvamGeneration
          ? 'Best Hindi/Marathi/Gujarati minutes on this device: Sarvam-1 after '
              'Whisper multilingual transcription with auto-detect.'
          : 'Reliable stack when RAM is tight or you chose Standard minutes: '
              'Whisper multilingual speech plus Qwen 0.5B generation.',
      blockedReason: featuredGenerationId == MindScribeModelIds.sarvamGeneration
          ? sarvamBlocked
          : null,
    );

    final alternates = <MindModelRecommendation>[];

    if (featuredGenerationId == MindScribeModelIds.sarvamGeneration) {
      alternates.add(
        _stackRecommendation(
          id: 'scribe-stack-qwen',
          speechModel: whisperMl,
          generationModel: qwen,
          speechFallbackName: 'Whisper Tiny (Multilingual)',
          generationFallbackName: 'Qwen2.5 0.5B Instruct (Q4_K_M)',
          badge: MindModelRecommendationBadge.alternate,
          severity: _stackSeverity(
            speech: whisperMl,
            generation: qwen,
            capability: capability,
            usesSarvam: false,
          ),
          runtimeNote:
              'Smaller minutes model — good fallback when you want English-heavy '
              'meetings or faster generation.',
        ),
      );
    } else if (capability.proEnabled && capability.isDesktopHost) {
      alternates.add(
        _stackRecommendation(
          id: 'scribe-stack-sarvam',
          speechModel: whisperMl,
          generationModel: sarvam,
          speechFallbackName: 'Whisper Tiny (Multilingual)',
          generationFallbackName: 'Sarvam-1 (Q4_K_M)',
          badge: sarvamBlocked != null
              ? MindModelRecommendationBadge.blocked
              : MindModelRecommendationBadge.alternate,
          severity: _stackSeverity(
            speech: whisperMl,
            generation: sarvam,
            capability: capability,
            blockedReason: sarvamBlocked,
            usesSarvam: true,
          ),
          runtimeNote: sarvamBlocked ?? capability.suggestionSummary(),
          blockedReason: sarvamBlocked,
        ),
      );
    }

    if (whisperEn != null || whisperMl != null) {
      alternates.add(
        _stackRecommendation(
          id: 'scribe-stack-whisper-en',
          speechModel: whisperEn ?? whisperMl,
          generationModel: qwen,
          speechFallbackName: 'Whisper Tiny (English)',
          generationFallbackName: 'Qwen2.5 0.5B Instruct (Q4_K_M)',
          badge: MindModelRecommendationBadge.alternate,
          severity: _stackSeverity(
            speech: whisperEn ?? whisperMl,
            generation: qwen,
            capability: capability,
            usesSarvam: false,
          ),
          runtimeNote:
              'English-only transcription — smaller speech weights when you do '
              'not need Hindi or Marathi auto-detect.',
        ),
      );
    }

    final speechStub = MindModelRecommendation(
      id: 'scribe-speech-sarvam-edge-stub',
      headline: 'Sarvam Edge ASR',
      subheadline: 'On-device Indic speech (not public yet)',
      runtimeNote:
          'Public Sarvam Edge weights are not on Hugging Face yet. Meeting '
          'capture stays on Whisper multilingual until they ship.',
      severity: MindModelRecommendationSeverity.blocked,
      action: MindModelRecommendationAction.disabled,
      badge: MindModelRecommendationBadge.comingSoon,
      speechModelId: MindScribeModelIds.whisperMultilingual,
      generationModelId: null,
      sizeLabel: 'Not downloadable',
      blockedReason: 'Waiting on public model artifacts.',
      featured: false,
    );

    return MindScribeStackRecommendation(
      featured: featured,
      alternates: alternates,
      speechStub: speechStub,
    );
  }

  String? _sarvamBlockedReason(
    MindIndicCapability capability,
    MindIndicGenerationMode mode,
  ) {
    if (!capability.proEnabled) {
      return 'Indic intelligence packs require Airo Mind Pro.';
    }
    if (!capability.isDesktopHost) {
      return 'Enhanced Indic generation is optimized for macOS, Windows, and Linux.';
    }
    if (mode == MindIndicGenerationMode.standard) {
      return 'You chose Standard minutes — switch to Auto or Enhanced Indic to '
          'use Sarvam-1.';
    }
    if (!capability.meetsRamGate) {
      return 'Needs about 8 GB total RAM and 4 GB free memory for Sarvam-1.';
    }
    return null;
  }

  OfflineModelInfo? _modelForId(
    Map<String, OfflineModelInfo> models,
    String id,
  ) => models[id];

  MindModelRecommendation _stackRecommendation({
    required String id,
    required OfflineModelInfo? speechModel,
    required OfflineModelInfo? generationModel,
    required String speechFallbackName,
    required String generationFallbackName,
    required MindModelRecommendationBadge badge,
    required MindModelRecommendationSeverity severity,
    required String runtimeNote,
    bool featured = false,
    String? blockedReason,
  }) {
    final speechName = speechModel?.name ?? speechFallbackName;
    final generationName = generationModel?.name ?? generationFallbackName;
    final speechId = speechModel?.id ?? MindScribeModelIds.whisperMultilingual;
    final generationId = generationModel?.id;

    final sizes = <int>[];
    if (speechModel != null) sizes.add(speechModel.fileSizeBytes);
    if (generationModel != null) sizes.add(generationModel.fileSizeBytes);
    final totalBytes = sizes.fold<int>(0, (sum, bytes) => sum + bytes);

    final speechReady = speechModel?.isDownloaded ?? false;
    final generationReady = generationModel?.isDownloaded ?? false;
    final blocked = blockedReason != null || severity == MindModelRecommendationSeverity.blocked;

    final action = blocked
        ? MindModelRecommendationAction.disabled
        : speechReady && generationReady
        ? MindModelRecommendationAction.tryNow
        : MindModelRecommendationAction.download;

    return MindModelRecommendation(
      id: id,
      headline: '$generationName + $speechName',
      subheadline: 'Meeting scribe stack',
      runtimeNote: runtimeNote,
      severity: severity,
      action: action,
      badge: badge,
      speechModelId: speechId,
      generationModelId: generationId,
      sizeLabel: totalBytes > 0 ? _formatSize(totalBytes) : 'Size unknown',
      blockedReason: blockedReason,
      featured: featured,
    );
  }

  MindModelRecommendationSeverity _stackSeverity({
    required OfflineModelInfo? speech,
    required OfflineModelInfo? generation,
    required MindIndicCapability capability,
    bool usesSarvam = false,
    String? blockedReason,
  }) {
    if (blockedReason != null) {
      return MindModelRecommendationSeverity.blocked;
    }
    if (usesSarvam && !capability.meetsRamGate && capability.memoryInfo?.isAvailable == true) {
      return MindModelRecommendationSeverity.warning;
    }
    final speechReady = speech?.isDownloaded ?? false;
    final generationReady = generation?.isDownloaded ?? false;
    if (speechReady && generationReady) {
      return MindModelRecommendationSeverity.safe;
    }
    if (speechReady || generationReady) {
      return MindModelRecommendationSeverity.warning;
    }
    return MindModelRecommendationSeverity.critical;
  }

  static String _formatSize(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    return '${(bytes / (1024 * 1024)).round()} MB';
  }
}
