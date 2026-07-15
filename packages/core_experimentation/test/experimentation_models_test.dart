import 'package:core_experimentation/core_experimentation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Airo experimentation guardrails', () {
    AiroExperimentSubject subject({
      String assignmentKey = 'anonymous-install-1',
      AiroExperimentProductProfile productProfile =
          AiroExperimentProductProfile.fullTv,
      AiroExperimentReleaseChannel releaseChannel =
          AiroExperimentReleaseChannel.fullTvStable,
      String appVersion = '2.0.0',
      String regionBucket = 'us',
      Set<String> enabledModules = const {'playback', 'search', 'remote'},
      Set<String> entitlements = const {'plus'},
    }) {
      return AiroExperimentSubject(
        assignmentKey: assignmentKey,
        productProfile: productProfile,
        releaseChannel: releaseChannel,
        appVersion: appVersion,
        regionBucket: regionBucket,
        enabledModules: enabledModules,
        entitlements: entitlements,
      );
    }

    AiroExperimentDefinition experiment({
      String experimentId = 'search_ranking_v2',
      bool enabled = true,
      int rolloutBasisPoints = 10000,
    }) {
      return AiroExperimentDefinition(
        experimentId: experimentId,
        enabled: enabled,
        rolloutBasisPoints: rolloutBasisPoints,
        eligibleProfiles: const {AiroExperimentProductProfile.fullTv},
        eligibleReleaseChannels: const {
          AiroExperimentReleaseChannel.fullTvStable,
        },
        eligibleRegionBuckets: const {'us', 'in'},
        requiredModules: const {'search'},
        requiredEntitlements: const {'plus'},
        minAppVersion: '2.0.0',
        variants: const [
          AiroExperimentVariant(variantId: 'control', weightBasisPoints: 5000),
          AiroExperimentVariant(
            variantId: 'treatment',
            weightBasisPoints: 5000,
          ),
        ],
      );
    }

    test('stable assignment returns the same variant for a subject', () {
      final evaluator = AiroExperimentEvaluator();
      final first = evaluator.evaluateExperiment(
        experiment: experiment(),
        subject: subject(),
      );
      final second = evaluator.evaluateExperiment(
        experiment: experiment(),
        subject: subject(),
      );

      expect(first.accepted, isTrue);
      expect(first.variantId, isNotNull);
      expect(first.variantId, second.variantId);
      expect(first.assignmentBucket, second.assignmentBucket);
    });

    test('kill switch blocks experiment regardless of rollout', () {
      final evaluator = AiroExperimentEvaluator(
        killSwitches: AiroExperimentKillSwitchRegistry(
          disabledIds: const {'search_ranking_v2'},
        ),
      );

      final decision = evaluator.evaluateExperiment(
        experiment: experiment(),
        subject: subject(),
      );

      expect(decision.accepted, isFalse);
      expect(decision.codes, contains(AiroExperimentGuardrailCode.killed));
      expect(decision.variantId, isNull);
    });

    test('remote config blocks absent modules and unsafe overrides', () {
      final evaluator = AiroExperimentEvaluator();
      final flag = AiroRemoteConfigFlag(
        flagId: 'enable_ai_ranking',
        valueCategory: 'boolean',
        requiredModules: const {'ai_search'},
        requestedOverrides: const {
          AiroRemoteConfigOverrideKind.privacyConsent,
          AiroRemoteConfigOverrideKind.securityControl,
          AiroRemoteConfigOverrideKind.entitlement,
          AiroRemoteConfigOverrideKind.buildComposition,
        },
      );

      final decision = evaluator.evaluateRemoteConfig(
        flag: flag,
        subject: subject(),
      );

      expect(
        decision.codes,
        containsAll(const {
          AiroExperimentGuardrailCode.moduleAbsent,
          AiroExperimentGuardrailCode.privacyOverrideBlocked,
          AiroExperimentGuardrailCode.securityOverrideBlocked,
          AiroExperimentGuardrailCode.entitlementOverrideBlocked,
          AiroExperimentGuardrailCode.buildCompositionOverrideBlocked,
        }),
      );
    });

    test(
      'eligibility checks profile, channel, version, region, and rollout',
      () {
        final evaluator = AiroExperimentEvaluator();

        final decision = evaluator.evaluateExperiment(
          experiment: experiment(rolloutBasisPoints: 0),
          subject: subject(
            productProfile: AiroExperimentProductProfile.liteReceiver,
            releaseChannel: AiroExperimentReleaseChannel.liteReceiverStable,
            appVersion: '1.9.9',
            regionBucket: 'eu',
          ),
        );

        expect(
          decision.codes,
          containsAll(const {
            AiroExperimentGuardrailCode.profileNotEligible,
            AiroExperimentGuardrailCode.releaseChannelNotEligible,
            AiroExperimentGuardrailCode.appVersionTooLow,
            AiroExperimentGuardrailCode.regionNotEligible,
            AiroExperimentGuardrailCode.rolloutNotEligible,
          }),
        );
      },
    );

    test('public maps omit raw assignment and unsafe values', () {
      final publicMap = subject(
        assignmentKey: 'raw-user-id-123',
        enabledModules: const {'playback'},
        entitlements: const {'plus'},
      ).toPublicMap();
      final decision = AiroExperimentEvaluator().evaluateExperiment(
        experiment: experiment(),
        subject: subject(assignmentKey: 'raw-user-id-123'),
      );
      final flattened = '${publicMap.toString()} ${decision.toPublicMap()}';

      expect(flattened, contains('full_tv'));
      expect(flattened, contains('assignmentBucket'));
      expect(flattened, isNot(contains('raw-user-id-123')));
      expect(flattened, isNot(contains('https://')));
      expect(flattened, isNot(contains('/Users/')));
      expect(flattened, isNot(contains('192.168.')));
      expect(flattened, isNot(contains('Bearer')));
      expect(flattened, isNot(contains('providerPayload')));
    });
  });
}
