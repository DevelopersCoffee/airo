import 'package:meta/meta.dart';

import 'llm_device_tier.dart';

/// Where a request was routed: on-device, cloud, or nowhere.
enum LlmRoutingTarget {
  local,
  cloud,

  /// Below-threshold device, no local model installed for the tier, and no
  /// cloud consent -- the request cannot be served rather than silently
  /// falling back to a path the person never agreed to.
  unavailable;

  String get stableId => name;
}

/// Why [LlmRoutingTarget] was chosen. Every value here is a fact the
/// decision log can print without a person needing to read this module's
/// source to understand it.
enum LlmRoutingReasonCode {
  deviceTierSupportsLocal,
  deviceTierNone,
  noLocalModelInstalledForTier,
  cloudConsentGranted,
  cloudConsentMissing,
  complexQueryEscalatedToCloud,
  complexQueryKeptLocalNoConsent;

  String get stableId => name;
}

/// One routing decision, inspectable after the fact.
///
/// This is #1631's "routing decision logged + inspectable" AC made concrete:
/// [reasons] is never empty, so "why local vs cloud" always has an answer
/// rather than a decision with no explanation attached.
@immutable
class LlmRoutingDecision {
  const LlmRoutingDecision({
    required this.target,
    required this.tier,
    required this.reasons,
    required this.decidedAt,
    this.taskId,
    this.promptLength,
    this.modelId,
  });

  final LlmRoutingTarget target;
  final LlmDeviceTier tier;
  final List<LlmRoutingReasonCode> reasons;
  final DateTime decidedAt;
  final String? taskId;
  final int? promptLength;
  final String? modelId;

  Map<String, Object?> toPublicMap() => {
    'target': target.stableId,
    'tier': tier.stableId,
    'reasons': reasons.map((reason) => reason.stableId).toList(growable: false),
    'decidedAt': decidedAt.toIso8601String(),
    if (taskId != null) 'taskId': taskId,
    if (promptLength != null) 'promptLength': promptLength,
    if (modelId != null) 'modelId': modelId,
  };

  @override
  String toString() => 'LlmRoutingDecision(${toPublicMap()})';
}
