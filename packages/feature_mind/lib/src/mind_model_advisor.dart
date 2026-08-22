import 'package:core_ai/core_ai.dart';
import 'package:flutter/foundation.dart';

import 'mind_indic_intelligence.dart';

/// Stable catalog ids for scribe weights shown in the model advisor.
abstract final class MindScribeModelIds {
  static const whisperMultilingual = 'mind-scribe-whisper-tiny-multilingual';
  static const whisperEnglish = 'mind-scribe-whisper-tiny-en';
  static const whisperSmallMultilingual =
      'mind-scribe-whisper-small-multilingual';
  static const whisperSmallEnglish = 'mind-scribe-whisper-small-en';
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
enum MindModelRecommendationAction { tryNow, download, disabled }

/// Named pipeline the Scribe UI can show without branching on model ids.
enum MindScribeStrategy {
  recommended,
  longMeetings,
  indianLanguages,
  englishOnly,
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
    this.strategy = MindScribeStrategy.recommended,
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
  final MindScribeStrategy strategy;
  final String? blockedReason;
  final bool featured;

  String get strategyTitle => switch (strategy) {
    MindScribeStrategy.recommended => 'Recommended',
    MindScribeStrategy.longMeetings => 'Long meetings',
    MindScribeStrategy.indianLanguages => 'Indian languages',
    MindScribeStrategy.englishOnly => 'English only',
  };

  String get strategySubtitle => switch (strategy) {
    MindScribeStrategy.recommended =>
      'Speech Automatic plus meeting intelligence',
    MindScribeStrategy.longMeetings =>
      'Higher-accuracy speech for longer recordings',
    MindScribeStrategy.indianLanguages =>
      'Speech Automatic with Indic meeting intelligence',
    MindScribeStrategy.englishOnly =>
      'English-only speech when you do not need auto-detect',
  };

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
    final whisperSmallMl =
        scribeModelsById[MindScribeModelIds.whisperSmallMultilingual];
    final whisperEn = scribeModelsById[MindScribeModelIds.whisperEnglish];
    final whisperSmallEn =
        scribeModelsById[MindScribeModelIds.whisperSmallEnglish];
    final qwen = scribeModelsById[MindScribeModelIds.qwenGeneration];
    final sarvam = scribeModelsById[MindScribeModelIds.sarvamGeneration];

    final preferSarvam = capability.shouldPreferIndicGeneration(generationMode);
    final sarvamBlocked = _sarvamBlockedReason(capability, generationMode);
    final mobile = !capability.isDesktopHost;
    final featuredSpeech = _featuredSpeechModel(
      capability: capability,
      whisperSmallMl: whisperSmallMl,
      whisperMl: whisperMl,
    );
    final featuredSpeechName =
        featuredSpeech?.name ??
        (featuredSpeech?.id == MindScribeModelIds.whisperSmallMultilingual
            ? 'Whisper Small (Multilingual)'
            : 'Whisper Tiny (Multilingual)');

    final featuredGenerationId =
        mobile || sarvamBlocked != null || !preferSarvam
        ? MindScribeModelIds.qwenGeneration
        : MindScribeModelIds.sarvamGeneration;

    final featured = _stackRecommendation(
      id: 'scribe-stack-featured',
      speechModel: featuredSpeech,
      generationModel: _modelForId(scribeModelsById, featuredGenerationId),
      speechFallbackName: featuredSpeechName,
      generationFallbackName:
          featuredGenerationId == MindScribeModelIds.sarvamGeneration
          ? 'Sarvam-1 (Q4_K_M)'
          : 'Qwen2.5 0.5B Instruct (Q4_K_M)',
      badge: MindModelRecommendationBadge.bestOverall,
      featured: true,
      severity: _stackSeverity(
        speech: featuredSpeech,
        generation: _modelForId(scribeModelsById, featuredGenerationId),
        capability: capability,
        blockedReason: sarvamBlocked,
        usesSarvam: featuredGenerationId == MindScribeModelIds.sarvamGeneration,
      ),
      runtimeNote: mobile
          ? 'Meetings on phones and tablets stay on Whisper multilingual plus '
                'the compact Qwen minutes writer. Enhanced Indic generation is '
                'desktop-only.'
          : featuredSpeech?.id == MindScribeModelIds.whisperSmallMultilingual
          ? 'Best long-meeting stack on this device: Whisper Small multilingual '
                'speech (fewer loops on 30+ min recordings) plus Qwen minutes.'
          : featuredGenerationId == MindScribeModelIds.sarvamGeneration
          ? 'Best Hindi/Marathi/Gujarati minutes on this device: Sarvam-1 after '
                'Whisper multilingual transcription with auto-detect.'
          : 'Reliable stack when RAM is tight or you chose Standard minutes: '
                'Whisper multilingual speech plus Qwen 0.5B generation.',
      blockedReason: featuredGenerationId == MindScribeModelIds.sarvamGeneration
          ? sarvamBlocked
          : null,
      strategy:
          featuredSpeech?.id == MindScribeModelIds.whisperSmallMultilingual
          ? MindScribeStrategy.longMeetings
          : featuredGenerationId == MindScribeModelIds.sarvamGeneration
          ? MindScribeStrategy.indianLanguages
          : MindScribeStrategy.recommended,
    );

    final alternates = <MindModelRecommendation>[];

    if (featuredGenerationId == MindScribeModelIds.sarvamGeneration) {
      alternates.add(
        _stackRecommendation(
          id: 'scribe-stack-qwen',
          speechModel: featuredSpeech ?? whisperMl,
          generationModel: qwen,
          speechFallbackName: featuredSpeechName,
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
          strategy: MindScribeStrategy.recommended,
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
          strategy: MindScribeStrategy.indianLanguages,
        ),
      );
    }

    if (whisperSmallMl != null &&
        featuredSpeech?.id != MindScribeModelIds.whisperSmallMultilingual) {
      alternates.add(
        _stackRecommendation(
          id: 'scribe-stack-whisper-small',
          speechModel: whisperSmallMl,
          generationModel: qwen,
          speechFallbackName: 'Whisper Small (Multilingual)',
          generationFallbackName: 'Qwen2.5 0.5B Instruct (Q4_K_M)',
          badge: MindModelRecommendationBadge.alternate,
          severity: _stackSeverity(
            speech: whisperSmallMl,
            generation: qwen,
            capability: capability,
            usesSarvam: false,
          ),
          runtimeNote:
              'Download for better accuracy on long meetings — fewer repetition '
              'loops than Whisper Tiny after ~30 minutes.',
          strategy: MindScribeStrategy.longMeetings,
        ),
      );
    }

    if (whisperEn != null || whisperMl != null) {
      alternates.add(
        _stackRecommendation(
          id: 'scribe-stack-whisper-en',
          speechModel: whisperSmallEn ?? whisperEn ?? whisperMl,
          generationModel: qwen,
          speechFallbackName: whisperSmallEn?.name ?? 'Whisper Tiny (English)',
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
          strategy: MindScribeStrategy.englishOnly,
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

  OfflineModelInfo? _featuredSpeechModel({
    required MindIndicCapability capability,
    required OfflineModelInfo? whisperSmallMl,
    required OfflineModelInfo? whisperMl,
  }) {
    if (capability.isDesktopHost &&
        whisperSmallMl?.isDownloaded == true &&
        _meetsSmallSpeechGate(capability)) {
      return whisperSmallMl;
    }
    return whisperMl;
  }

  bool _meetsSmallSpeechGate(MindIndicCapability capability) {
    final info = capability.memoryInfo;
    if (info == null || !info.isAvailable) {
      return capability.isDesktopHost;
    }
    const fourGb = 4 * 1024 * 1024 * 1024;
    return info.totalBytes >= fourGb;
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
    MindScribeStrategy strategy = MindScribeStrategy.recommended,
  }) {
    // Fallback names stay on the signature so callers can describe stacks
    // when catalog rows are missing; ranking never branches on those strings.
    final resolvedSpeechName = speechModel?.name ?? speechFallbackName;
    final resolvedGenerationName =
        generationModel?.name ?? generationFallbackName;
    assert(resolvedSpeechName.isNotEmpty || resolvedGenerationName.isNotEmpty);
    final speechId = speechModel?.id ?? MindScribeModelIds.whisperMultilingual;
    final generationId = generationModel?.id;

    final sizes = <int>[];
    if (speechModel != null) sizes.add(speechModel.fileSizeBytes);
    if (generationModel != null) sizes.add(generationModel.fileSizeBytes);
    final totalBytes = sizes.fold<int>(0, (sum, bytes) => sum + bytes);

    final speechReady = speechModel?.isDownloaded ?? false;
    final generationReady = generationModel?.isDownloaded ?? false;
    final blocked =
        blockedReason != null ||
        severity == MindModelRecommendationSeverity.blocked;

    final action = blocked
        ? MindModelRecommendationAction.disabled
        : speechReady && generationReady
        ? MindModelRecommendationAction.tryNow
        : MindModelRecommendationAction.download;

    final extraDescriptions = [
      if (generationModel?.description != null) generationModel!.description,
      if (speechModel?.description != null) speechModel!.description,
    ];
    final combinedRuntimeNote = extraDescriptions.isNotEmpty
        ? '${extraDescriptions.join(' ')} $runtimeNote'.trim()
        : runtimeNote;

    return MindModelRecommendation(
      id: id,
      headline: switch (strategy) {
        MindScribeStrategy.recommended => 'Recommended',
        MindScribeStrategy.longMeetings => 'Long meetings',
        MindScribeStrategy.indianLanguages => 'Indian languages',
        MindScribeStrategy.englishOnly => 'English only',
      },
      subheadline: switch (strategy) {
        MindScribeStrategy.recommended =>
          'Speech Automatic plus meeting intelligence',
        MindScribeStrategy.longMeetings =>
          'Higher-accuracy speech for longer recordings',
        MindScribeStrategy.indianLanguages =>
          'Speech Automatic with Indic meeting intelligence',
        MindScribeStrategy.englishOnly =>
          'English-only speech when you do not need auto-detect',
      },
      runtimeNote: combinedRuntimeNote,
      severity: severity,
      action: action,
      badge: badge,
      speechModelId: speechId,
      generationModelId: generationId,
      sizeLabel: totalBytes > 0 ? _formatSize(totalBytes) : 'Size unknown',
      strategy: strategy,
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
    if (usesSarvam &&
        !capability.meetsRamGate &&
        capability.memoryInfo?.isAvailable == true) {
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
