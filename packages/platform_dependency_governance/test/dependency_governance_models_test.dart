import 'package:flutter_test/flutter_test.dart';
import 'package:platform_dependency_governance/platform_dependency_governance.dart';

void main() {
  group('Airo dependency governance checklist', () {
    const checklist = AiroDependencyGovernanceChecklist();

    AiroDependencyAuditRecord record({
      String packageName = 'video_player',
      String usedByModule = 'feature_iptv',
      AiroDependencyImportance importance = AiroDependencyImportance.required,
      int? minimumAndroidApi = 26,
      bool hasNativeCode = false,
      Set<AiroNativeArchitecture> nativeArchitectures = const {},
      int? estimatedBinarySizeKb = 1024,
      int? estimatedRuntimeMemoryMb = 8,
      bool hasBackgroundBehavior = false,
      String? backgroundBehavior,
      bool requiresShrinkerRules = false,
      bool shrinkerRulesValidated = false,
      bool tvIssuesReviewed = true,
      bool hasFallbackOrStub = false,
      String? maintenanceOwner = 'release-devex',
    }) {
      return AiroDependencyAuditRecord(
        packageName: packageName,
        version: '1.0.0',
        usedByModule: usedByModule,
        importance: importance,
        minimumAndroidApi: minimumAndroidApi,
        hasNativeCode: hasNativeCode,
        nativeArchitectures: nativeArchitectures,
        estimatedBinarySizeKb: estimatedBinarySizeKb,
        estimatedRuntimeMemoryMb: estimatedRuntimeMemoryMb,
        hasBackgroundBehavior: hasBackgroundBehavior,
        backgroundBehavior: backgroundBehavior,
        requiresShrinkerRules: requiresShrinkerRules,
        shrinkerRulesValidated: shrinkerRulesValidated,
        tvIssuesReviewed: tvIssuesReviewed,
        hasFallbackOrStub: hasFallbackOrStub,
        maintenanceOwner: maintenanceOwner,
      );
    }

    test('accepts a baseline API 26 dependency with reviewed ownership', () {
      final result = checklist.evaluate(record());

      expect(result.passed, isTrue);
      expect(result.blockers, isEmpty);
    });

    test('blocks dependencies without declared Android API floor', () {
      final result = checklist.evaluate(record(minimumAndroidApi: null));

      expect(result.passed, isFalse);
      expect(
        result.blockers.map((blocker) => blocker.code),
        contains(AiroDependencyBlockerCode.missingAndroidApiFloor),
      );
    });

    test('blocks required dependencies that raise the API floor', () {
      final result = checklist.evaluate(record(minimumAndroidApi: 28));

      expect(
        result.blockers.map((blocker) => blocker.code),
        containsAll(const {
          AiroDependencyBlockerCode.raisesAndroidApiFloor,
          AiroDependencyBlockerCode.missingFallbackForRaisedApi,
        }),
      );
    });

    test('allows optional raised-API dependencies only with fallback', () {
      final blocked = checklist.evaluate(
        record(
          packageName: 'optional_cast_sdk',
          importance: AiroDependencyImportance.optional,
          minimumAndroidApi: 28,
        ),
      );
      final accepted = checklist.evaluate(
        record(
          packageName: 'optional_cast_sdk',
          importance: AiroDependencyImportance.optional,
          minimumAndroidApi: 28,
          hasFallbackOrStub: true,
        ),
      );

      expect(
        blocked.blockers.map((blocker) => blocker.code),
        contains(AiroDependencyBlockerCode.missingFallbackForRaisedApi),
      );
      expect(
        accepted.blockers.map((blocker) => blocker.code),
        isNot(contains(AiroDependencyBlockerCode.missingFallbackForRaisedApi)),
      );
      expect(
        accepted.blockers.map((blocker) => blocker.code),
        isNot(contains(AiroDependencyBlockerCode.raisesAndroidApiFloor)),
      );
      expect(accepted.passed, isTrue);
    });

    test('blocks native dependencies without declared architectures', () {
      final result = checklist.evaluate(record(hasNativeCode: true));

      expect(
        result.blockers.map((blocker) => blocker.code),
        contains(AiroDependencyBlockerCode.missingNativeArchitectures),
      );
    });

    test(
      'blocks size, memory, background, shrinker, review, and owner gaps',
      () {
        final result = checklist.evaluate(
          record(
            estimatedBinarySizeKb: 8192,
            estimatedRuntimeMemoryMb: 64,
            hasBackgroundBehavior: true,
            requiresShrinkerRules: true,
            shrinkerRulesValidated: false,
            tvIssuesReviewed: false,
            maintenanceOwner: '',
          ),
        );

        expect(
          result.blockers.map((blocker) => blocker.code),
          containsAll(const {
            AiroDependencyBlockerCode.binarySizeBudgetExceeded,
            AiroDependencyBlockerCode.memoryBudgetExceeded,
            AiroDependencyBlockerCode.backgroundBehaviorUndeclared,
            AiroDependencyBlockerCode.shrinkerRulesMissing,
            AiroDependencyBlockerCode.tvIssuesNotReviewed,
            AiroDependencyBlockerCode.ownerMissing,
          }),
        );
      },
    );

    test('creates a passing empty audit report', () {
      final report = AiroDependencyGovernanceAuditReport.evaluate(
        profileName: 'tv',
        generatedAtUtc: DateTime.utc(2026, 7, 14, 12),
        records: const [],
      );

      expect(report.passed, isTrue);
      expect(report.entries, isEmpty);
      expect(report.failingEntries, isEmpty);
      expect(report.blockerCodes, isEmpty);
      expect(
        report.toJson(),
        containsPair('generatedAtUtc', '2026-07-14T12:00:00.000Z'),
      );
    });

    test('creates a passing audit report for reviewed dependencies', () {
      final report = AiroDependencyGovernanceAuditReport.evaluate(
        profileName: 'tv',
        generatedAtUtc: DateTime.utc(2026, 7, 14, 12),
        records: [
          record(packageName: 'platform_player'),
          record(packageName: 'feature_iptv', usedByModule: 'feature_iptv'),
        ],
      );

      expect(report.passed, isTrue);
      expect(report.entries, hasLength(2));
      expect(report.failingEntries, isEmpty);
      expect(report.toJson(), containsPair('passed', true));
    });

    test('aggregates stable blocker codes for failing dependencies', () {
      final report = AiroDependencyGovernanceAuditReport.evaluate(
        profileName: 'tv',
        generatedAtUtc: DateTime.utc(2026, 7, 14, 12),
        records: [
          record(packageName: 'large_native', hasNativeCode: true),
          record(
            packageName: 'api_raiser',
            minimumAndroidApi: 28,
            estimatedRuntimeMemoryMb: 64,
          ),
        ],
      );

      expect(report.passed, isFalse);
      expect(report.failingEntries, hasLength(2));
      expect(
        report.blockerCodes.map((code) => code.stableId),
        orderedEquals([
          'memory_budget_exceeded',
          'missing_fallback_for_raised_api',
          'missing_native_architectures',
          'raises_android_api_floor',
        ]),
      );
    });

    test('sorts audit entries for deterministic release output', () {
      final report = AiroDependencyGovernanceAuditReport.evaluate(
        profileName: 'tv',
        generatedAtUtc: DateTime.utc(2026, 7, 14, 12),
        records: [
          record(packageName: 'zeta', usedByModule: 'platform_player'),
          record(packageName: 'alpha', usedByModule: 'feature_iptv'),
          record(packageName: 'beta', usedByModule: 'feature_iptv'),
        ],
      );

      expect(
        report.entries.map((entry) => entry.record.packageName),
        orderedEquals(['alpha', 'beta', 'zeta']),
      );
    });

    test('captures checklist thresholds in audit output', () {
      const strictChecklist = AiroDependencyGovernanceChecklist(
        androidApiBaseline: 24,
        maxBinarySizeKb: 2048,
        maxRuntimeMemoryMb: 16,
      );
      final report = AiroDependencyGovernanceAuditReport.evaluate(
        profileName: 'legacy-tv',
        generatedAtUtc: DateTime.utc(2026, 7, 14, 12),
        checklist: strictChecklist,
        records: [record()],
      );
      final json = report.toJson();

      expect(json['profileName'], 'legacy-tv');
      expect(json['checklist'], containsPair('androidApiBaseline', 24));
      expect(json['checklist'], containsPair('maxBinarySizeKb', 2048));
      expect(json['checklist'], containsPair('maxRuntimeMemoryMb', 16));
    });

    test('release-line audit wrapper exposes public report metadata', () {
      final audit = AiroDependencyGovernanceAudit(
        auditId: 'audit-v2-lite',
        releaseLine: 'v2.0.0.1',
        targetProfile: 'lite_receiver',
        records: [
          record(packageName: 'video_player'),
          record(
            packageName: 'heavy_native_sdk',
            minimumAndroidApi: 28,
            estimatedRuntimeMemoryMb: 64,
          ),
        ],
        createdAt: DateTime.utc(2026, 7, 14, 15),
      );

      final report = audit.evaluate(
        checklist: checklist,
        generatedAt: DateTime.utc(2026, 7, 14, 16),
      );
      final publicMap = report.toPublicMap();

      expect(report.passed, isFalse);
      expect(report.blockedPackages, const ['heavy_native_sdk']);
      expect(publicMap, containsPair('auditId', 'audit-v2-lite'));
      expect(publicMap, containsPair('releaseLine', 'v2.0.0.1'));
      expect(publicMap, containsPair('targetProfile', 'lite_receiver'));
      expect(publicMap, isNot(contains('workspacePath')));
      expect(publicMap, isNot(contains('diagnosticsDump')));
    });
  });
}
