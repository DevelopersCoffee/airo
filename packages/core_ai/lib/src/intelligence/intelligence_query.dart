import 'package:meta/meta.dart';

import '../device/memory_severity.dart';
import '../models/model_contract.dart';
import '../models/model_credibility.dart';
import '../models/model_readiness_service.dart';
import '../models/offline_model_info.dart';
import 'why_selected.dart';

/// How ranking should trade size versus quality when memory allows both.
enum IntelligenceSizeBias {
  /// Prefer smaller artifacts (short recordings, tight RAM).
  compact,

  /// Prefer a balance of size and parameters.
  balanced,

  /// Prefer larger / higher-parameter models when they fit.
  quality,
}

/// Constraints the query may use. All fields are optional so callers can
/// ask "what can this catalog do?" without device probes.
@immutable
class IntelligenceConstraints {
  const IntelligenceConstraints({
    this.memory,
    this.languages = const <String>[],
    this.modality,
    this.sizeBias = IntelligenceSizeBias.balanced,
    this.preferInstalled = true,
    this.requireCurrentPlatform = true,
  });

  final MemoryInfo? memory;
  final List<String> languages;
  final ModelModality? modality;
  final IntelligenceSizeBias sizeBias;
  final bool preferInstalled;
  final bool requireCurrentPlatform;
}

/// A scored candidate. [score] is only meaningful relative to siblings of
/// the same query.
@immutable
class IntelligenceCandidate {
  const IntelligenceCandidate({
    required this.model,
    required this.score,
    required this.installable,
    required this.fitsMemory,
  });

  final OfflineModelInfo model;
  final int score;
  final bool installable;
  final bool fitsMemory;
}

/// Ranked answer for one capability.
@immutable
class IntelligenceSelection {
  const IntelligenceSelection({
    required this.capability,
    required this.candidates,
    this.model,
    this.why,
  });

  final ModelCapability capability;
  final OfflineModelInfo? model;
  final WhySelected? why;
  final List<IntelligenceCandidate> candidates;

  bool get ready => model != null && model!.isDownloaded;

  bool get canInstall =>
      !ready && candidates.any((candidate) => candidate.installable);
}

/// Product-neutral query over [OfflineModelInfo] metadata.
///
/// UI and application profiles must call this instead of branching on model
/// ids. Speech is resolved from [ModelTask.speechToText] / audio modality /
/// [ModelCapability.audioUnderstanding], never from `AiTask.speechToText`.
class IntelligenceQuery {
  const IntelligenceQuery();

  /// Capabilities that have at least one installable or downloaded model
  /// on this device. Empty-capability companions (tokenizers) never appear.
  List<ModelCapability> capabilitiesPresent(
    List<OfflineModelInfo> catalog, {
    IntelligenceConstraints constraints = const IntelligenceConstraints(),
  }) {
    final present = <ModelCapability>{};
    for (final model in catalog) {
      if (!_isVisible(model, constraints)) continue;
      for (final capability in model.capabilities) {
        if (_isUserFacing(capability) && servesCapability(model, capability)) {
          present.add(capability);
        }
      }
      if (servesCapability(model, ModelCapability.audioUnderstanding)) {
        present.add(ModelCapability.audioUnderstanding);
      }
    }
    final ordered = List<ModelCapability>.from(_userFacingOrder)
      ..retainWhere(present.contains);
    for (final extra in present) {
      if (!ordered.contains(extra)) ordered.add(extra);
    }
    return ordered;
  }

  /// Whether [model] can serve [capability] from declared metadata.
  bool servesCapability(OfflineModelInfo model, ModelCapability capability) {
    if (model.capabilities.contains(capability)) return true;
    if (capability == ModelCapability.audioUnderstanding) {
      return model.effectiveTask == ModelTask.speechToText ||
          (model.modalities.contains(ModelModality.audio) &&
              model.effectiveRuntime == InferenceRuntime.whisper);
    }
    if (capability == ModelCapability.imageUnderstanding) {
      return model.supportsVision || model.effectiveTask == ModelTask.vision;
    }
    return false;
  }

  /// Short badges for a card: modality then capability, never family names.
  List<String> badgesFor(OfflineModelInfo model) {
    final badges = <String>[];
    for (final modality in model.modalities) {
      final label = _modalityBadge(modality);
      if (label != null && !badges.contains(label)) badges.add(label);
    }
    for (final capability in model.capabilities) {
      final label = _capabilityBadge(capability);
      if (label != null && !badges.contains(label)) badges.add(label);
    }
    if (servesCapability(model, ModelCapability.audioUnderstanding) &&
        !badges.contains('TRANSCRIPTION')) {
      badges.add('TRANSCRIPTION');
    }
    return badges;
  }

  /// Ranked pick for [capability]. [overrideModelId] wins when that model is
  /// in [catalog] and still serves the capability.
  IntelligenceSelection select({
    required ModelCapability capability,
    required List<OfflineModelInfo> catalog,
    IntelligenceConstraints constraints = const IntelligenceConstraints(),
    String? overrideModelId,
  }) {
    final matching = <IntelligenceCandidate>[];
    for (final model in catalog) {
      if (!servesCapability(model, capability)) continue;
      if (constraints.modality != null &&
          !model.modalities.contains(constraints.modality)) {
        continue;
      }
      if (constraints.requireCurrentPlatform &&
          !model.isDownloaded &&
          !model.isRunnableOnCurrentPlatform) {
        continue;
      }
      if (!_isInstallable(model) && !model.isDownloaded) continue;
      matching.add(
        IntelligenceCandidate(
          model: model,
          score: _score(model, constraints),
          installable: _isInstallable(model),
          fitsMemory: _fitsMemory(model, constraints.memory),
        ),
      );
    }
    matching.sort((left, right) {
      final byScore = right.score.compareTo(left.score);
      if (byScore != 0) return byScore;
      return left.model.fileSizeBytes.compareTo(right.model.fileSizeBytes);
    });

    if (overrideModelId != null) {
      final override = matching
          .where((candidate) => candidate.model.id == overrideModelId)
          .firstOrNull;
      if (override != null) {
        return IntelligenceSelection(
          capability: capability,
          model: override.model,
          why: _explain(
            override.model,
            capability: capability,
            constraints: constraints,
            automatic: false,
            override: true,
          ),
          candidates: matching,
        );
      }
    }

    final winner = matching.isEmpty ? null : matching.first.model;
    return IntelligenceSelection(
      capability: capability,
      model: winner,
      why: winner == null
          ? null
          : _explain(
              winner,
              capability: capability,
              constraints: constraints,
              automatic: true,
              override: false,
            ),
      candidates: matching,
    );
  }

  /// Group catalog rows by the user-facing capabilities they serve.
  Map<ModelCapability, List<OfflineModelInfo>> groupByCapability(
    List<OfflineModelInfo> catalog, {
    IntelligenceConstraints constraints = const IntelligenceConstraints(),
  }) {
    final groups = <ModelCapability, List<OfflineModelInfo>>{};
    for (final capability in capabilitiesPresent(
      catalog,
      constraints: constraints,
    )) {
      groups[capability] = catalog
          .where(
            (model) =>
                _isVisible(model, constraints) &&
                servesCapability(model, capability),
          )
          .toList(growable: false);
    }
    return groups;
  }

  bool _isVisible(OfflineModelInfo model, IntelligenceConstraints constraints) {
    if (model.capabilities.isEmpty && model.modalities.isEmpty) return false;
    if (!_isInstallable(model) && !model.isDownloaded) return false;
    if (constraints.requireCurrentPlatform &&
        !model.isDownloaded &&
        !model.isRunnableOnCurrentPlatform) {
      return false;
    }
    return true;
  }

  bool _isInstallable(OfflineModelInfo model) {
    final url = model.downloadUrl?.trim();
    return model.isDownloaded || (url != null && url.isNotEmpty);
  }

  bool _fitsMemory(OfflineModelInfo model, MemoryInfo? memory) {
    if (memory == null || !memory.isAvailable) return true;
    return model.estimatedMinMemoryBytes <= memory.availableBytes;
  }

  int _score(OfflineModelInfo model, IntelligenceConstraints constraints) {
    var score = 0;
    if (constraints.preferInstalled && model.isDownloaded) score += 1000;
    if (_isInstallable(model)) score += 40;
    if (model.credibility == ModelCredibility.official) score += 80;

    if (constraints.languages.isNotEmpty) {
      final wanted = constraints.languages.map((code) => code.toLowerCase());
      final offered = model.languages.map((code) => code.toLowerCase());
      if (wanted.any(offered.contains)) {
        score += 120;
      } else if (offered.length > 3 || offered.contains('multilingual')) {
        score += 50;
      }
    }

    final fits = _fitsMemory(model, constraints.memory);
    if (fits) {
      score += 200;
    } else {
      score -= 400;
    }

    switch (constraints.sizeBias) {
      case IntelligenceSizeBias.compact:
        score += _compactBonus(model.fileSizeBytes);
      case IntelligenceSizeBias.quality:
        score += (model.parameterCount ?? 0) ~/ 50_000_000;
        score += model.fileSizeBytes ~/ 20_000_000;
      case IntelligenceSizeBias.balanced:
        score += model.contextLength ~/ 512;
        if (constraints.memory != null &&
            constraints.memory!.isAvailable &&
            model.estimatedMinMemoryBytes * 2 >
                constraints.memory!.availableBytes) {
          score += _compactBonus(model.fileSizeBytes);
        } else {
          score += (model.parameterCount ?? 0) ~/ 100_000_000;
        }
    }
    return score;
  }

  int _compactBonus(int fileSizeBytes) {
    const cap = 2_000_000_000;
    final clamped = fileSizeBytes.clamp(0, cap);
    return ((cap - clamped) ~/ 10_000_000);
  }

  WhySelected _explain(
    OfflineModelInfo model, {
    required ModelCapability capability,
    required IntelligenceConstraints constraints,
    required bool automatic,
    required bool override,
  }) {
    final reasons = <WhySelectedReason>[];
    if (override) {
      reasons.add(
        const WhySelectedReason(
          code: WhySelectedCode.override,
          message: 'You chose this model for the task.',
        ),
      );
    } else if (automatic) {
      reasons.add(
        const WhySelectedReason(
          code: WhySelectedCode.automatic,
          message: 'Airo selected this automatically.',
        ),
      );
    }
    if (model.isDownloaded) {
      reasons.add(
        const WhySelectedReason(
          code: WhySelectedCode.installed,
          message: 'Already installed on this device.',
        ),
      );
    }
    if (_fitsMemory(model, constraints.memory)) {
      reasons.add(
        const WhySelectedReason(
          code: WhySelectedCode.fitsMemory,
          message: 'Fits available memory.',
        ),
      );
    }
    if (constraints.languages.isNotEmpty &&
        constraints.languages.any(
          (code) => model.languages
              .map((offered) => offered.toLowerCase())
              .contains(code.toLowerCase()),
        )) {
      reasons.add(
        const WhySelectedReason(
          code: WhySelectedCode.language,
          message: 'Supports the required language.',
        ),
      );
    }
    if (model.contextLength >= 4096) {
      reasons.add(
        WhySelectedReason(
          code: WhySelectedCode.context,
          message: 'Supports ${model.contextLength} tokens of context.',
        ),
      );
    }
    reasons.add(
      WhySelectedReason(
        code: WhySelectedCode.taskFit,
        message: 'Declared capability: ${capability.displayName}.',
      ),
    );
    if (constraints.sizeBias == IntelligenceSizeBias.compact) {
      reasons.add(
        const WhySelectedReason(
          code: WhySelectedCode.compact,
          message: 'Chosen for a smaller, faster footprint.',
        ),
      );
    }
    if (model.credibility == ModelCredibility.official) {
      reasons.add(
        const WhySelectedReason(
          code: WhySelectedCode.official,
          message: 'From an official catalog source.',
        ),
      );
    }
    return WhySelected(
      modelId: model.id,
      automatic: automatic && !override,
      reasons: reasons,
    );
  }

  static const List<ModelCapability> _userFacingOrder = [
    ModelCapability.chat,
    ModelCapability.audioUnderstanding,
    ModelCapability.translation,
    ModelCapability.meetingSummarization,
    ModelCapability.documents,
    ModelCapability.imageUnderstanding,
    ModelCapability.ocr,
    ModelCapability.embeddings,
  ];

  static bool _isUserFacing(ModelCapability capability) {
    return capability != ModelCapability.benchmark &&
        capability != ModelCapability.promptLab;
  }

  static String? _modalityBadge(ModelModality modality) {
    return switch (modality) {
      ModelModality.text => 'TEXT',
      ModelModality.audio => 'AUDIO',
      ModelModality.image => 'IMAGE',
      ModelModality.toolCall => null,
    };
  }

  static String? _capabilityBadge(ModelCapability capability) {
    return switch (capability) {
      ModelCapability.chat => 'CHAT',
      ModelCapability.reasoning => 'REASONING',
      ModelCapability.documents => 'DOCUMENTS',
      ModelCapability.meetingSummarization => 'SUMMARY',
      ModelCapability.translation => 'TRANSLATION',
      ModelCapability.audioUnderstanding => 'TRANSCRIPTION',
      ModelCapability.imageUnderstanding => 'VISION',
      ModelCapability.ocr => 'OCR',
      ModelCapability.embeddings => 'SEARCH',
      ModelCapability.agentSkills => 'SKILLS',
      ModelCapability.mobileActions => 'ACTIONS',
      ModelCapability.promptLab => null,
      ModelCapability.benchmark => null,
    };
  }
}
