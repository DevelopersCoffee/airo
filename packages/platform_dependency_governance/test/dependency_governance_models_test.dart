import 'package:flutter_test/flutter_test.dart';
import 'package:platform_dependency_governance/platform_dependency_governance.dart';

void main() {
  group('Airo dependency governance checklist', () {
    const checklist = AiroDependencyGovernanceChecklist();

    AiroDependencyAuditRecord record({
      String packageName = 'video_player',
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
        usedByModule: 'feature_iptv',
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

    test('builds a passing dependency audit report', () {
      final audit = AiroDependencyGovernanceAudit(
        auditId: 'audit-v2-lite',
        releaseLine: 'v2.0.0.1',
        targetProfile: 'lite_receiver',
        records: [
          record(packageName: 'video_player'),
          record(packageName: 'platform_device_profile'),
        ],
        createdAt: DateTime.utc(2026, 7, 14, 15),
      );

      final report = audit.evaluate(
        checklist: checklist,
        generatedAt: DateTime.utc(2026, 7, 14, 16),
      );

      expect(report.passed, isTrue);
      expect(report.blockedPackages, isEmpty);
      expect(report.blockerCodes, isEmpty);
      expect(report.results, hasLength(2));
    });

    test('summarizes blocked packages and blocker codes', () {
      final audit = AiroDependencyGovernanceAudit(
        auditId: 'audit-v2-lite',
        releaseLine: 'v2.0.0.1',
        targetProfile: 'lite_receiver',
        records: [
          record(packageName: 'video_player'),
          record(
            packageName: 'heavy_native_sdk',
            minimumAndroidApi: 28,
            estimatedBinarySizeKb: 8192,
            tvIssuesReviewed: false,
          ),
          record(
            packageName: 'background_worker',
            hasBackgroundBehavior: true,
            backgroundBehavior: '',
          ),
        ],
        createdAt: DateTime.utc(2026, 7, 14, 15),
      );

      final report = audit.evaluate(
        checklist: checklist,
        generatedAt: DateTime.utc(2026, 7, 14, 16),
      );

      expect(report.passed, isFalse);
      expect(report.blockedPackages, const [
        'heavy_native_sdk',
        'background_worker',
      ]);
      expect(
        report.blockerCodes,
        containsAll(const {
          AiroDependencyBlockerCode.raisesAndroidApiFloor,
          AiroDependencyBlockerCode.missingFallbackForRaisedApi,
          AiroDependencyBlockerCode.binarySizeBudgetExceeded,
          AiroDependencyBlockerCode.tvIssuesNotReviewed,
          AiroDependencyBlockerCode.backgroundBehaviorUndeclared,
        }),
      );
    });

    test('serializes audit report without local machine details', () {
      final audit = AiroDependencyGovernanceAudit(
        auditId: 'audit-v2-lite',
        releaseLine: 'v2.0.0.1',
        targetProfile: 'lite_receiver',
        records: [
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

      expect(publicMap, containsPair('auditId', 'audit-v2-lite'));
      expect(publicMap, containsPair('targetProfile', 'lite_receiver'));
      expect(publicMap, isNot(contains('workspacePath')));
      expect(publicMap, isNot(contains('diagnosticsDump')));
      expect(publicMap['results'], isA<List<Object?>>());
    });

    test('empty audit report is deterministic', () {
      final audit = AiroDependencyGovernanceAudit(
        auditId: 'audit-empty',
        releaseLine: 'v2.0.0.1',
        targetProfile: 'lite_receiver',
        records: const [],
        createdAt: DateTime.utc(2026, 7, 14, 15),
      );

      final report = audit.evaluate(
        checklist: checklist,
        generatedAt: DateTime.utc(2026, 7, 14, 16),
      );

      expect(report.passed, isTrue);
      expect(report.results, isEmpty);
      expect(report.toPublicMap()['blockedPackages'], isEmpty);
    });
  });
}
