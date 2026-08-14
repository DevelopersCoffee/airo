import '../models/offline_model_info.dart';
import 'llm_cloud_consent.dart';
import 'llm_device_signals.dart';
import 'llm_device_tier.dart';
import 'llm_device_tier_policy.dart';
import 'llm_routing_decision.dart';
import 'llm_routing_log.dart';

/// Decides, per request, whether Mind should run locally or escalate to
/// cloud -- the "local/cloud routing" half of #1631.
///
/// This is a distinct axis from `AIRouter`/`AIRoutingStrategy`
/// (`router/ai_router.dart`): that router already knows *how* to fail over
/// between an on-device client and a cloud client once it has been told
/// which one to prefer. This class is what computes that preference for
/// Mind's local-LLM path specifically, from device tier, thermal pressure,
/// and consent -- inputs `AIRouterConfig.onDeviceMaxPromptLength` alone does
/// not capture. A caller wiring Mind's chat/summarization surfaces onto
/// `AIRouter` uses [route] to pick `AIRoutingStrategy.onDeviceOnly` /
/// `.cloudOnly` for that call, rather than duplicating fallback plumbing.
///
/// Every call records a [LlmRoutingDecision] to [log], which is how #1631's
/// "routing decision logged + inspectable" AC is satisfied without touching
/// `feature_mind`'s frozen `MindRuntime` ports (see `LlmRoutingLog`'s doc
/// comment for why that store is out of reach today).
class LlmLocalCloudRouter {
  LlmLocalCloudRouter({
    required LlmDeviceSignalsProbe signalsProbe,
    LlmDeviceTierPolicy tierPolicy = const LlmDeviceTierPolicy(),
    LlmCloudConsentGate? consentGate,
    LlmRoutingLog? log,
    this.complexQueryPromptThreshold = 4000,
  }) : _signalsProbe = signalsProbe,
       _tierPolicy = tierPolicy,
       _consentGate = consentGate ?? InMemoryLlmCloudConsentGate(),
       _log = log ?? LlmRoutingLog();

  final LlmDeviceSignalsProbe _signalsProbe;
  final LlmDeviceTierPolicy _tierPolicy;
  final LlmCloudConsentGate _consentGate;
  final LlmRoutingLog _log;

  /// Prompt length (characters) above which a request is treated as a
  /// "complex query" eligible for cloud escalation, absent an explicit
  /// [route] `isComplexQuery` override. Mirrors the shape of
  /// `AIRouterConfig.onDeviceMaxPromptLength` -- a caller with a better
  /// signal (declared long-context task, token count) should pass
  /// `isComplexQuery: true` directly instead of relying on this heuristic.
  final int complexQueryPromptThreshold;

  LlmRoutingLog get log => _log;

  /// Resolves one routing decision.
  ///
  /// [installedModels] is the caller's already-installed catalog models
  /// (typically `IntelligentModelManager.snapshot()`'s installed set) --
  /// this router does not itself know what is on disk. [isComplexQuery]
  /// marks a request as long-context/heavy reasoning; when true (or the
  /// prompt exceeds [complexQueryPromptThreshold]) and the device is below
  /// [LlmDeviceTier.large], the request is eligible to escalate to cloud --
  /// but only with consent. Without consent it stays local rather than
  /// failing, honoring "local handles quick tasks" as the floor every device
  /// tier that supports local inference at all can meet.
  Future<LlmRoutingDecision> route({
    required List<OfflineModelInfo> installedModels,
    String? taskId,
    int promptLength = 0,
    bool isComplexQuery = false,
    DateTime? now,
  }) async {
    final signals = await _signalsProbe.probe();
    final evaluation = _tierPolicy.evaluate(signals);
    final consentGranted = await _consentGate.hasConsented();
    final decidedAt = now ?? DateTime.now();

    final reasons = <LlmRoutingReasonCode>[];
    final LlmRoutingTarget target;

    if (!evaluation.tier.supportsLocalInference) {
      reasons.add(LlmRoutingReasonCode.deviceTierNone);
      if (consentGranted) {
        target = LlmRoutingTarget.cloud;
        reasons.add(LlmRoutingReasonCode.cloudConsentGranted);
      } else {
        target = LlmRoutingTarget.unavailable;
        reasons.add(LlmRoutingReasonCode.cloudConsentMissing);
      }
    } else {
      final maxParams = evaluation.tier.maxParameterCount;
      final hasLocalModel = installedModels.any(
        (model) => maxParams == null || (model.parameterCount ?? 0) <= maxParams,
      );
      final complex =
          isComplexQuery || promptLength > complexQueryPromptThreshold;
      final escalationEligible = complex && evaluation.tier != LlmDeviceTier.large;

      if (escalationEligible && consentGranted) {
        target = LlmRoutingTarget.cloud;
        reasons.add(LlmRoutingReasonCode.complexQueryEscalatedToCloud);
      } else if (hasLocalModel) {
        target = LlmRoutingTarget.local;
        reasons.add(LlmRoutingReasonCode.deviceTierSupportsLocal);
        if (escalationEligible) {
          reasons.add(LlmRoutingReasonCode.complexQueryKeptLocalNoConsent);
        }
      } else if (consentGranted) {
        target = LlmRoutingTarget.cloud;
        reasons.add(LlmRoutingReasonCode.noLocalModelInstalledForTier);
        reasons.add(LlmRoutingReasonCode.cloudConsentGranted);
      } else {
        target = LlmRoutingTarget.unavailable;
        reasons.add(LlmRoutingReasonCode.noLocalModelInstalledForTier);
        reasons.add(LlmRoutingReasonCode.cloudConsentMissing);
      }
    }

    final decision = LlmRoutingDecision(
      target: target,
      tier: evaluation.tier,
      reasons: reasons,
      decidedAt: decidedAt,
      taskId: taskId,
      promptLength: promptLength == 0 ? null : promptLength,
    );
    _log.record(decision);
    return decision;
  }
}
