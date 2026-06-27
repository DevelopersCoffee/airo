import 'package:meta/meta.dart';

import 'skill_schema.dart';

/// Tool/action domains used by the skill permission engine.
enum SkillActionDomain {
  calendar,
  reminders,
  finance,
  fileSystem,
  contacts,
  memory,
  network,
  notifications,
  unknown,
}

/// High-level operation categories used for trust-tier decisions.
enum SkillActionOperation {
  read,
  create,
  update,
  delete,
  transfer,
  notify,
  execute,
}

/// Provenance/source of the action request.
enum SkillActionSource { builtIn, community, localDraft, organization }

/// Scoped automation grant that can narrow auto-approval to a specific routine.
@immutable
class SkillAutomationScope {
  const SkillAutomationScope({
    required this.id,
    this.allowedDomains = const [],
    this.allowedOperations = const [],
  });

  final String id;
  final List<SkillActionDomain> allowedDomains;
  final List<SkillActionOperation> allowedOperations;

  bool allows(SkillActionRequest request) {
    return allowedDomains.contains(request.domain) &&
        allowedOperations.contains(request.operation);
  }
}

/// Request shape evaluated before a skill/tool action is allowed to run.
@immutable
class SkillActionRequest {
  const SkillActionRequest({
    required this.toolId,
    required this.domain,
    required this.operation,
    required this.source,
    this.automationScope,
    this.payloadPreview,
  });

  final String toolId;
  final SkillActionDomain domain;
  final SkillActionOperation operation;
  final SkillActionSource source;
  final SkillAutomationScope? automationScope;

  /// Optional caller-local preview for debugging.
  ///
  /// The permission engine intentionally does not copy this into traces because
  /// tool payloads can contain prompt text, contacts, filenames, or secrets.
  final String? payloadPreview;
}

/// Redacted trace emitted for audit/debug UX.
@immutable
class SkillPermissionDecisionTrace {
  const SkillPermissionDecisionTrace({
    required this.toolId,
    required this.domain,
    required this.operation,
    required this.tier,
    required this.reason,
    this.automationScopeId,
  });

  final String toolId;
  final SkillActionDomain domain;
  final SkillActionOperation operation;
  final SkillTrustTier tier;
  final String reason;
  final String? automationScopeId;

  /// Always null for now: traces must not copy request payloads.
  Null get redactedPayload => null;

  Map<String, dynamic> toJson() => {
    'tool_id': toolId,
    'domain': domain.name,
    'operation': operation.name,
    'tier': tier.toJson(),
    'reason': reason,
    if (automationScopeId != null) 'automation_scope_id': automationScopeId,
  };
}

/// Final permission decision for a tool/action request.
@immutable
class SkillPermissionDecision {
  const SkillPermissionDecision({required this.tier, required this.trace});

  final SkillTrustTier tier;
  final SkillPermissionDecisionTrace trace;

  bool get requiresConfirmation => tier == SkillTrustTier.confirmationRequired;

  bool get canExecute =>
      tier == SkillTrustTier.readOnly || tier == SkillTrustTier.autoApproved;
}

/// Framework policy resolver for skill tool/action execution.
///
/// This is intentionally a pure, deterministic policy layer. It does not show UI
/// prompts or execute actions; callers must use [SkillPermissionDecision] to
/// decide whether to run, draft, confirm, or block downstream behavior.
class SkillPermissionEngine {
  const SkillPermissionEngine();

  SkillPermissionDecision resolve(SkillActionRequest request) {
    final decision = _resolveTier(request);
    return SkillPermissionDecision(
      tier: decision.tier,
      trace: SkillPermissionDecisionTrace(
        toolId: request.toolId,
        domain: request.domain,
        operation: request.operation,
        tier: decision.tier,
        reason: decision.reason,
        automationScopeId: request.automationScope?.id,
      ),
    );
  }

  _TierReason _resolveTier(SkillActionRequest request) {
    if (!_isKnownTool(request)) {
      return const _TierReason(
        SkillTrustTier.blocked,
        'Unknown tool is blocked by default',
      );
    }

    if (request.source == SkillActionSource.community ||
        request.source == SkillActionSource.localDraft) {
      return const _TierReason(
        SkillTrustTier.draftOnly,
        'Community or draft skill actions stay draft-only until reviewed',
      );
    }

    if (_isBlockedSensitiveAction(request)) {
      return const _TierReason(
        SkillTrustTier.blocked,
        'Sensitive destructive or financial action is blocked',
      );
    }

    final automationScope = request.automationScope;
    if (automationScope != null && automationScope.allows(request)) {
      return const _TierReason(
        SkillTrustTier.autoApproved,
        'Action is auto-approved by a matching scoped automation',
      );
    }

    if (request.operation == SkillActionOperation.read) {
      return const _TierReason(
        SkillTrustTier.readOnly,
        'Known read-only action can execute without confirmation',
      );
    }

    if (_requiresConfirmation(request)) {
      return const _TierReason(
        SkillTrustTier.confirmationRequired,
        'Action changes user state and requires confirmation',
      );
    }

    return const _TierReason(
      SkillTrustTier.blocked,
      'No matching permission policy allowed this action',
    );
  }

  bool _isKnownTool(SkillActionRequest request) {
    if (request.domain == SkillActionDomain.unknown) return false;
    return switch (request.toolId) {
      'calendar.events.list' =>
        request.domain == SkillActionDomain.calendar &&
            request.operation == SkillActionOperation.read,
      'reminders.create' =>
        request.domain == SkillActionDomain.reminders &&
            request.operation == SkillActionOperation.create,
      'finance.transfer.execute' =>
        request.domain == SkillActionDomain.finance &&
            request.operation == SkillActionOperation.transfer,
      'files.delete' =>
        request.domain == SkillActionDomain.fileSystem &&
            request.operation == SkillActionOperation.delete,
      _ => false,
    };
  }

  bool _isBlockedSensitiveAction(SkillActionRequest request) {
    return (request.domain == SkillActionDomain.finance &&
            request.operation == SkillActionOperation.transfer) ||
        (request.domain == SkillActionDomain.fileSystem &&
            request.operation == SkillActionOperation.delete);
  }

  bool _requiresConfirmation(SkillActionRequest request) {
    return request.operation == SkillActionOperation.create ||
        request.operation == SkillActionOperation.update ||
        request.operation == SkillActionOperation.notify ||
        request.operation == SkillActionOperation.execute;
  }
}

class _TierReason {
  const _TierReason(this.tier, this.reason);

  final SkillTrustTier tier;
  final String reason;
}
