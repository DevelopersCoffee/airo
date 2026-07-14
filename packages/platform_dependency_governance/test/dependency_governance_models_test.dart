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
  });
}
