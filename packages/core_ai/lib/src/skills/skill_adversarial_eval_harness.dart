import 'package:meta/meta.dart';

import 'skill_permission_engine.dart';
import 'skill_schema.dart';

/// Overall adversarial eval status.
enum SkillAdversarialEvalStatus { passing, failing }

/// Activation decision from adversarial evaluation.
enum SkillAdversarialEvalDecision { accept, downgradeToDraftOnly, reject }

/// Stable, user-safe reason codes for adversarial findings.
enum SkillAdversarialReasonCode {
  hiddenCapabilityRequest,
  promptInjectionBlocked,
  safeCommunitySkillDraftOnly,
  slopsquattingPackageId,
}

/// Fixture category for static package and prompt/tool adversarial checks.
enum SkillAdversarialFixtureKind { staticPackage, promptToolCall }

/// Deterministic adversarial fixture.
@immutable
class SkillAdversarialFixture {
  const SkillAdversarialFixture.staticPackage({
    required this.id,
    required this.packageId,
    required this.skillBody,
  }) : kind = SkillAdversarialFixtureKind.staticPackage,
       prompt = null,
       request = null;

  const SkillAdversarialFixture.promptToolCall({
    required this.id,
    required this.prompt,
    required this.request,
  }) : kind = SkillAdversarialFixtureKind.promptToolCall,
       packageId = null,
       skillBody = null;

  final String id;
  final SkillAdversarialFixtureKind kind;
  final String? packageId;
  final String? skillBody;
  final String? prompt;
  final SkillActionRequest? request;
}

/// One sanitized adversarial finding.
@immutable
class SkillAdversarialFinding {
  const SkillAdversarialFinding({
    required this.fixtureId,
    required this.reasonCode,
    required this.redactedEvidence,
    this.permissionTier,
    this.passed = true,
  });

  final String fixtureId;
  final SkillAdversarialReasonCode reasonCode;
  final String redactedEvidence;
  final SkillTrustTier? permissionTier;
  final bool passed;
}

/// Aggregated adversarial eval report.
@immutable
class SkillAdversarialEvalReport {
  const SkillAdversarialEvalReport({
    required this.decision,
    required this.findings,
  });

  final SkillAdversarialEvalDecision decision;
  final List<SkillAdversarialFinding> findings;

  SkillAdversarialEvalStatus get status =>
      findings.every((finding) => finding.passed)
      ? SkillAdversarialEvalStatus.passing
      : SkillAdversarialEvalStatus.failing;
}

/// Static and prompt/tool adversarial harness for imported skills.
class SkillAdversarialEvalHarness {
  const SkillAdversarialEvalHarness({
    required this.fixtures,
    this.reservedPackagePrefixes = const [],
    this.permissionEngine = const SkillPermissionEngine(),
  });

  final List<SkillAdversarialFixture> fixtures;
  final List<String> reservedPackagePrefixes;
  final SkillPermissionEngine permissionEngine;

  SkillAdversarialEvalReport evaluatePackage(Map<String, dynamic> packageJson) {
    final package = SkillPackage.fromJson(packageJson);
    final staticFixtures = fixtures.where(
      (fixture) =>
          fixture.kind == SkillAdversarialFixtureKind.staticPackage &&
          fixture.packageId == package.id,
    );
    final findings = <SkillAdversarialFinding>[];

    final slopsquattingPrefix = _matchedSlopsquattingPrefix(package.id);
    if (slopsquattingPrefix != null) {
      findings.add(
        SkillAdversarialFinding(
          fixtureId: staticFixtures.firstOrNull?.id ?? package.id,
          reasonCode: SkillAdversarialReasonCode.slopsquattingPackageId,
          redactedEvidence: 'Package id resembles reserved prefix [REDACTED]',
          passed: false,
        ),
      );
    }

    for (final fixture in staticFixtures) {
      final hiddenCapability = _hiddenCapabilityRequest(
        fixture.skillBody ?? '',
        package.permissions,
      );
      if (hiddenCapability != null) {
        findings.add(
          SkillAdversarialFinding(
            fixtureId: fixture.id,
            reasonCode: SkillAdversarialReasonCode.hiddenCapabilityRequest,
            redactedEvidence: _redactEvidence(hiddenCapability),
            passed: false,
          ),
        );
      }
    }

    if (findings.any((finding) => !finding.passed)) {
      return SkillAdversarialEvalReport(
        decision: SkillAdversarialEvalDecision.reject,
        findings: findings,
      );
    }

    if (package.provenance.source == SkillProvenanceSource.community ||
        package.provenance.source == SkillProvenanceSource.localDraft) {
      findings.add(
        const SkillAdversarialFinding(
          fixtureId: 'community-draft-gate',
          reasonCode: SkillAdversarialReasonCode.safeCommunitySkillDraftOnly,
          redactedEvidence:
              'Imported community skill remains draft-only until user activation.',
        ),
      );
      return SkillAdversarialEvalReport(
        decision: SkillAdversarialEvalDecision.downgradeToDraftOnly,
        findings: findings,
      );
    }

    return SkillAdversarialEvalReport(
      decision: SkillAdversarialEvalDecision.accept,
      findings: findings,
    );
  }

  SkillAdversarialEvalReport evaluatePromptToolCalls() {
    final findings = <SkillAdversarialFinding>[];
    for (final fixture in fixtures.where(
      (fixture) => fixture.kind == SkillAdversarialFixtureKind.promptToolCall,
    )) {
      final request = fixture.request;
      if (request == null) continue;
      final decision = permissionEngine.resolve(request);
      if (_isPromptInjection(fixture.prompt ?? '') &&
          decision.tier != SkillTrustTier.autoApproved &&
          decision.tier != SkillTrustTier.readOnly) {
        findings.add(
          SkillAdversarialFinding(
            fixtureId: fixture.id,
            reasonCode: SkillAdversarialReasonCode.promptInjectionBlocked,
            redactedEvidence: _redactEvidence(fixture.prompt ?? ''),
            permissionTier: decision.tier,
          ),
        );
      }
    }

    return SkillAdversarialEvalReport(
      decision: findings.isEmpty
          ? SkillAdversarialEvalDecision.accept
          : SkillAdversarialEvalDecision.reject,
      findings: findings,
    );
  }

  String? _hiddenCapabilityRequest(
    String skillBody,
    List<SkillPermission> declaredPermissions,
  ) {
    final lowerBody = skillBody.toLowerCase();
    final declaredScopes = declaredPermissions
        .map((permission) => permission.scope)
        .toSet();
    if ((lowerBody.contains('http://') || lowerBody.contains('https://')) &&
        !declaredScopes.contains(SkillPermissionScope.network)) {
      return skillBody;
    }
    if ((lowerBody.contains('~/.ssh') ||
            lowerBody.contains('write ') ||
            lowerBody.contains('file')) &&
        !declaredScopes.contains(SkillPermissionScope.fileSystem)) {
      return skillBody;
    }
    return null;
  }

  bool _isPromptInjection(String prompt) {
    return RegExp(
      r'(ignore previous|override|without user approval|bypass|disregard)',
      caseSensitive: false,
    ).hasMatch(prompt);
  }

  String? _matchedSlopsquattingPrefix(String packageId) {
    final normalizedPackageId = _normalizePackageId(packageId);
    for (final prefix in reservedPackagePrefixes) {
      if (!packageId.startsWith(prefix) &&
          normalizedPackageId.startsWith(_normalizePackageId(prefix))) {
        return prefix;
      }
    }
    return null;
  }

  String _normalizePackageId(String value) {
    return value.toLowerCase().replaceAll('0', 'o').replaceAll('1', 'l');
  }

  String _redactEvidence(String evidence) {
    return evidence
        .replaceAll(RegExp(r'https?://\S+', caseSensitive: false), '[REDACTED]')
        .replaceAll(RegExp(r'~\/\S+', caseSensitive: false), '[REDACTED]')
        .replaceAll(RegExp(r'\b\d{4,}\b'), '[REDACTED]');
  }
}
