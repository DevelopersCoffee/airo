import 'package:flutter_test/flutter_test.dart';
import 'package:platform_certification/platform_certification.dart';

void main() {
  group('Airo cross-platform validation matrix', () {
    test('exposes stable platform targets and gates', () {
      final matrix = AiroCrossPlatformValidation.matrix();

      expect(matrix.schemaVersion, kAiroValidationSchemaVersion);
      expect(matrix.targetById('android-tv-lite-receiver'), isNotNull);
      expect(matrix.targetById('android-mobile-companion'), isNotNull);
      expect(matrix.targetById('desktop-pointer-companion'), isNotNull);
      expect(matrix.targetById('apple-tv-tvos'), isNotNull);
      expect(matrix.targetById('backend-cloud-control-plane'), isNotNull);
      expect(
        matrix.missingGateIdsForTarget('android-tv-lite-receiver'),
        isEmpty,
      );
    });

    test('Android TV receiver requires remote and device evidence gates', () {
      final matrix = AiroCrossPlatformValidation.matrix();
      final target = matrix.targetById('android-tv-lite-receiver')!;

      expect(target.platform, AiroValidationPlatform.androidTv);
      expect(target.productProfile, AiroValidationProductProfile.liteReceiver);
      expect(target.requiresDeviceCertification, isTrue);
      expect(
        target.requiredGates,
        containsAll({
          AiroValidationGateId.remoteFocus,
          AiroValidationGateId.playbackEngine,
          AiroValidationGateId.pairingController,
          AiroValidationGateId.sessionSync,
          AiroValidationGateId.analyticsRedaction,
          AiroValidationGateId.dependencyGovernance,
          AiroValidationGateId.physicalDeviceEvidence,
        }),
      );
      expect(matrix.requiresPhysicalEvidence(target.targetId), isTrue);
      expect(
        matrix.canAdvertiseDeviceSupportWithHostOnlyEvidence(target.targetId),
        isFalse,
      );
    });

    test('mobile companion avoids TV-only remote receiver gates', () {
      final matrix = AiroCrossPlatformValidation.matrix();
      final target = matrix.targetById('android-mobile-companion')!;

      expect(target.platform, AiroValidationPlatform.androidMobile);
      expect(target.requiresDeviceCertification, isFalse);
      expect(target.requiredGates, contains(AiroValidationGateId.touchInput));
      expect(
        target.requiredGates,
        contains(AiroValidationGateId.localNetworkPrivacy),
      );
      expect(
        target.requiredGates,
        isNot(contains(AiroValidationGateId.remoteFocus)),
      );
      expect(
        target.requiredGates,
        isNot(contains(AiroValidationGateId.physicalDeviceEvidence)),
      );
    });

    test('desktop companion uses pointer and data governance gates', () {
      final matrix = AiroCrossPlatformValidation.matrix();
      final target = matrix.targetById('desktop-pointer-companion')!;

      expect(target.platform, AiroValidationPlatform.desktop);
      expect(target.requiredGates, contains(AiroValidationGateId.pointerInput));
      expect(
        target.requiredGates,
        contains(AiroValidationGateId.importExportDataGovernance),
      );
      expect(matrix.requiresPhysicalEvidence(target.targetId), isFalse);
    });

    test('tvOS receiver is blocked until native target evidence exists', () {
      final matrix = AiroCrossPlatformValidation.matrix();
      final target = matrix.targetById('apple-tv-tvos')!;

      expect(target.status, AiroValidationStatus.blocked);
      expect(target.requiredGates, contains(AiroValidationGateId.nativeTarget));
      expect(target.requiredGates, contains(AiroValidationGateId.storePolicy));
      expect(
        matrix.canAdvertiseDeviceSupportWithHostOnlyEvidence(target.targetId),
        isFalse,
      );
    });

    test('backend validation cannot claim playback-device certification', () {
      final matrix = AiroCrossPlatformValidation.matrix();
      final target = matrix.targetById('backend-cloud-control-plane')!;

      expect(target.platform, AiroValidationPlatform.backendCloud);
      expect(target.requiresDeviceCertification, isFalse);
      expect(
        target.requiredGates,
        contains(AiroValidationGateId.orchestrationStorage),
      );
      expect(target.requiredGates, contains(AiroValidationGateId.cloudPrivacy));
      expect(
        target.requiredGates,
        isNot(contains(AiroValidationGateId.playbackEngine)),
      );
      expect(
        matrix.canAdvertiseDeviceSupportWithHostOnlyEvidence(target.targetId),
        isFalse,
      );
    });

    test('host-only evidence tier is limited to deterministic gates', () {
      final matrix = AiroCrossPlatformValidation.matrix();

      expect(
        matrix
            .gateById(AiroValidationGateId.productCapabilities)!
            .canBeSatisfiedByHostAutomation,
        isTrue,
      );
      expect(
        matrix
            .gateById(AiroValidationGateId.packageContentScan)!
            .canBeSatisfiedByHostAutomation,
        isTrue,
      );
      expect(
        matrix
            .gateById(AiroValidationGateId.physicalDeviceEvidence)!
            .canBeSatisfiedByHostAutomation,
        isFalse,
      );
      expect(
        matrix
            .gateById(AiroValidationGateId.remoteFocus)!
            .requiresPhysicalDevice,
        isTrue,
      );
    });
  });

  group('Airo TV legacy certification matrix', () {
    final now = DateTime.utc(2026, 7, 14, 12);

    List<AiroCertificationEvidence> passingEvidenceFor({
      required AiroCertificationMatrix matrix,
      required String targetId,
      DateTime? capturedAt,
    }) {
      final target = matrix.targetById(targetId)!;
      return [
        for (final gateId in target.requiredGates)
          AiroCertificationEvidence(
            evidenceId: '${targetId}_${gateId.stableId}',
            targetId: targetId,
            gateId: gateId,
            kind: matrix.gateById(gateId)!.requiresPhysicalDevice
                ? AiroCertificationEvidenceKind.physicalDeviceRun
                : matrix.gateById(gateId)!.acceptedEvidenceKinds.first,
            capturedAt: capturedAt ?? now,
            passed: true,
          ),
      ];
    }

    test('default matrix exposes stable legacy targets and gates', () {
      final matrix = AiroTvLegacyCertification.matrix();

      expect(matrix.schemaVersion, kAiroCertificationSchemaVersion);
      expect(matrix.targetById('android-tv-api-26-lite'), isNotNull);
      expect(matrix.targetById('fire-tv-legacy-lite'), isNotNull);
      expect(
        matrix
            .targetById('android-tv-api-26-lite')!
            .requiredGates
            .contains(AiroCertificationGateId.installLaunch),
        isTrue,
      );
      expect(
        matrix
            .gateById(AiroCertificationGateId.dpadFocus)!
            .requiresPhysicalDevice,
        isTrue,
      );
      expect(
        matrix
            .gateById(AiroCertificationGateId.packageContentScan)!
            .requiresPhysicalDevice,
        isFalse,
      );
    });

    test('host-only evidence cannot satisfy physical-device gates', () {
      final matrix = AiroTvLegacyCertification.matrix();
      final result = matrix.evaluate(
        targetId: 'android-tv-api-26-lite',
        evidence: [
          AiroCertificationEvidence(
            evidenceId: 'host-only-focus',
            targetId: 'android-tv-api-26-lite',
            gateId: AiroCertificationGateId.dpadFocus,
            kind: AiroCertificationEvidenceKind.hostStaticScan,
            capturedAt: now,
            passed: true,
          ),
        ],
        now: now,
      );

      expect(result.passed, isFalse);
      expect(
        result.blockers,
        contains(
          const AiroCertificationBlocker(
            code: AiroCertificationBlockerCode.evidenceWrongKind,
            targetId: 'android-tv-api-26-lite',
            gateId: AiroCertificationGateId.dpadFocus,
          ),
        ),
      );
    });

    test('complete fresh evidence passes a supported target', () {
      final matrix = AiroTvLegacyCertification.matrix();
      final result = matrix.evaluate(
        targetId: 'android-tv-api-26-lite',
        evidence: passingEvidenceFor(
          matrix: matrix,
          targetId: 'android-tv-api-26-lite',
        ),
        now: now,
      );

      expect(result.passed, isTrue);
      expect(result.claimedLevel, AiroCertificationLevel.certified);
      expect(result.canAdvertiseSupport, isTrue);
    });

    test('stale evidence returns deterministic blocker code', () {
      final matrix = AiroTvLegacyCertification.matrix();
      final result = matrix.evaluate(
        targetId: 'android-tv-api-26-lite',
        evidence: passingEvidenceFor(
          matrix: matrix,
          targetId: 'android-tv-api-26-lite',
          capturedAt: now.subtract(const Duration(days: 30)),
        ),
        now: now,
      );

      expect(result.passed, isFalse);
      expect(
        result.blockers.map((blocker) => blocker.code),
        contains(AiroCertificationBlockerCode.evidenceStale),
      );
    });

    test('wrong-target evidence does not certify another target', () {
      final matrix = AiroTvLegacyCertification.matrix();
      final result = matrix.evaluate(
        targetId: 'android-tv-api-26-lite',
        evidence: passingEvidenceFor(
          matrix: matrix,
          targetId: 'android-tv-api-28-lite',
        ),
        now: now,
      );

      expect(result.passed, isFalse);
      expect(
        result.blockers.map((blocker) => blocker.code),
        contains(AiroCertificationBlockerCode.evidenceWrongTarget),
      );
    });

    test('unsupported lower API target cannot advertise support', () {
      final matrix = AiroTvLegacyCertification.matrix();
      final result = matrix.evaluate(
        targetId: 'lower-api-experimental',
        evidence: const [],
        now: now,
      );

      expect(result.passed, isFalse);
      expect(result.claimedLevel, AiroCertificationLevel.unsupported);
      expect(result.canAdvertiseSupport, isFalse);
      expect(
        result.blockers.single.code,
        AiroCertificationBlockerCode.unsupportedTarget,
      );
    });

    test('program report advertises only fully evidenced support claims', () {
      final matrix = AiroTvLegacyCertification.matrix();
      final program = AiroCertificationProgram(
        programId: 'legacy-device-v2',
        releaseLine: 'v2.0.0.1',
        targetIds: const [
          'android-tv-api-26-lite',
          'android-tv-api-28-lite',
          'fire-tv-legacy-lite',
        ],
        createdAt: now,
      );

      final report = program.evaluate(
        evidence: [
          ...passingEvidenceFor(
            matrix: matrix,
            targetId: 'android-tv-api-26-lite',
          ),
          ...passingEvidenceFor(
            matrix: matrix,
            targetId: 'android-tv-api-28-lite',
          ),
          ...passingEvidenceFor(
            matrix: matrix,
            targetId: 'fire-tv-legacy-lite',
          ),
        ],
        now: now,
      );

      expect(report.passed, isTrue);
      expect(report.blockedTargets, isEmpty);
      expect(
        report.advertisedSupportClaims.map((claim) => claim.targetId),
        const [
          'android-tv-api-26-lite',
          'android-tv-api-28-lite',
          'fire-tv-legacy-lite',
        ],
      );
      expect(
        report.advertisedSupportClaims.first.level,
        AiroCertificationLevel.certified,
      );
    });

    test('program report blocks only targets without matching evidence', () {
      final matrix = AiroTvLegacyCertification.matrix();
      final program = AiroCertificationProgram(
        programId: 'legacy-device-v2',
        releaseLine: 'v2.0.0.1',
        targetIds: const ['android-tv-api-26-lite', 'android-tv-api-28-lite'],
        createdAt: now,
      );

      final report = program.evaluate(
        evidence: passingEvidenceFor(
          matrix: matrix,
          targetId: 'android-tv-api-26-lite',
        ),
        now: now,
      );

      expect(report.passed, isFalse);
      expect(report.blockedTargets, const ['android-tv-api-28-lite']);
      expect(
        report.blockerCodes,
        contains(AiroCertificationBlockerCode.evidenceWrongTarget),
      );
      expect(
        report.advertisedSupportClaims.map((claim) => claim.targetId),
        const ['android-tv-api-26-lite'],
      );
    });

    test('program report keeps unsupported targets out of support claims', () {
      final program = AiroCertificationProgram(
        programId: 'legacy-device-v2',
        releaseLine: 'v2.0.0.1',
        targetIds: const ['lower-api-experimental'],
        createdAt: now,
      );

      final report = program.evaluate(evidence: const [], now: now);

      expect(report.passed, isFalse);
      expect(report.blockedTargets, const ['lower-api-experimental']);
      expect(report.advertisedSupportClaims, isEmpty);
      expect(
        report.blockerCodes,
        contains(AiroCertificationBlockerCode.unsupportedTarget),
      );
    });

    test('program report public map excludes raw evidence details', () {
      final matrix = AiroTvLegacyCertification.matrix();
      final program = AiroCertificationProgram(
        programId: 'legacy-device-v2',
        releaseLine: 'v2.0.0.1',
        targetIds: const ['android-tv-api-26-lite'],
        createdAt: now,
      );

      final report = program.evaluate(
        evidence: passingEvidenceFor(
          matrix: matrix,
          targetId: 'android-tv-api-26-lite',
        ),
        now: now,
      );
      final publicMap = report.toPublicMap();

      expect(publicMap, containsPair('programId', 'legacy-device-v2'));
      expect(publicMap, containsPair('releaseLine', 'v2.0.0.1'));
      expect(publicMap, isNot(contains('evidence')));
      expect(publicMap, isNot(contains('workspacePath')));
      expect(publicMap, isNot(contains('diagnosticsDump')));
    });

    test('empty program target list is deterministic', () {
      final program = AiroCertificationProgram(
        programId: 'empty-program',
        releaseLine: 'v2.0.0.1',
        targetIds: const [],
        createdAt: now,
      );

      final report = program.evaluate(evidence: const [], now: now);

      expect(report.passed, isTrue);
      expect(report.results, isEmpty);
      expect(report.blockedTargets, isEmpty);
      expect(report.advertisedSupportClaims, isEmpty);
    });
  });

  group('Airo TV legacy distribution matrix', () {
    final now = DateTime.utc(2026, 7, 14, 12);

    List<AiroDistributionEvidence> passingEvidenceFor({
      required AiroDistributionMatrix matrix,
      required String targetId,
      DateTime? capturedAt,
    }) {
      final target = matrix.targetById(targetId)!;
      return [
        for (final kind in target.requiredEvidenceKinds)
          AiroDistributionEvidence(
            evidenceId: '${targetId}_${kind.stableId}',
            targetId: targetId,
            kind: kind,
            capturedAt: capturedAt ?? now,
            passed: true,
          ),
      ];
    }

    test('default matrix exposes stable legacy distribution channels', () {
      final matrix = AiroTvLegacyDistribution.matrix();

      expect(matrix.schemaVersion, kAiroDistributionSchemaVersion);
      expect(matrix.targetById('google-play-tv-android-tv'), isNotNull);
      expect(matrix.targetById('amazon-appstore-fire-tv'), isNotNull);
      expect(matrix.targetById('direct-apk-legacy-android-tv'), isNotNull);
      expect(matrix.targetById('operator-box-legacy-receiver'), isNotNull);
      expect(
        matrix
            .targetsForChannel(AiroDistributionChannel.amazonAppstore)
            .single
            .platform,
        AiroValidationPlatform.fireTv,
      );
    });

    test('Google Play TV requires store and physical TV evidence', () {
      final matrix = AiroTvLegacyDistribution.matrix();
      final target = matrix.targetById('google-play-tv-android-tv')!;

      expect(target.channel, AiroDistributionChannel.googlePlayTv);
      expect(
        target.requiredEvidenceKinds,
        containsAll({
          AiroDistributionEvidenceKind.playAabArtifact,
          AiroDistributionEvidenceKind.storeListing,
          AiroDistributionEvidenceKind.contentRating,
          AiroDistributionEvidenceKind.dataSafety,
          AiroDistributionEvidenceKind.storePolicyReview,
          AiroDistributionEvidenceKind.physicalDeviceEvidence,
        }),
      );
    });

    test('Amazon Appstore Fire TV requires APK and remote evidence', () {
      final matrix = AiroTvLegacyDistribution.matrix();
      final target = matrix.targetById('amazon-appstore-fire-tv')!;
      final result = matrix.evaluate(
        targetId: target.targetId,
        evidence: passingEvidenceFor(matrix: matrix, targetId: target.targetId),
        now: now,
      );

      expect(target.channel, AiroDistributionChannel.amazonAppstore);
      expect(target.platform, AiroValidationPlatform.fireTv);
      expect(
        target.requiredEvidenceKinds,
        contains(AiroDistributionEvidenceKind.remoteNavigationEvidence),
      );
      expect(result.passed, isTrue);
      expect(result.canAdvertiseChannelSupport, isTrue);
    });

    test('direct APK requires checksum manifest and package scan', () {
      final matrix = AiroTvLegacyDistribution.matrix();
      final target = matrix.targetById('direct-apk-legacy-android-tv')!;
      final result = matrix.evaluate(
        targetId: target.targetId,
        evidence: [
          AiroDistributionEvidence(
            evidenceId: 'apk',
            targetId: 'direct-apk-legacy-android-tv',
            kind: AiroDistributionEvidenceKind.apkArtifact,
            capturedAt: DateTime.utc(2026, 7, 14, 12),
            passed: true,
          ),
        ],
        now: now,
      );

      expect(target.channel, AiroDistributionChannel.directApk);
      expect(
        result.blockers.map((blocker) => blocker.evidenceKind),
        containsAll({
          AiroDistributionEvidenceKind.sha256Sums,
          AiroDistributionEvidenceKind.releaseManifest,
          AiroDistributionEvidenceKind.packageContentScan,
        }),
      );
      expect(result.canAdvertiseChannelSupport, isFalse);
    });

    test('operator boxes require explicit approval evidence', () {
      final matrix = AiroTvLegacyDistribution.matrix();
      final target = matrix.targetById('operator-box-legacy-receiver')!;
      final result = matrix.evaluate(
        targetId: target.targetId,
        evidence: passingEvidenceFor(matrix: matrix, targetId: target.targetId)
            .where(
              (record) =>
                  record.kind != AiroDistributionEvidenceKind.operatorApproval,
            ),
        now: now,
      );

      expect(target.channel, AiroDistributionChannel.operatorBox);
      expect(
        result.blockers.map((blocker) => blocker.evidenceKind),
        contains(AiroDistributionEvidenceKind.operatorApproval),
      );
      expect(result.passed, isFalse);
    });

    test('wrong target and stale evidence return stable blockers', () {
      final matrix = AiroTvLegacyDistribution.matrix();
      final wrongTarget = matrix.evaluate(
        targetId: 'google-play-tv-android-tv',
        evidence: passingEvidenceFor(
          matrix: matrix,
          targetId: 'amazon-appstore-fire-tv',
        ),
        now: now,
      );
      final stale = matrix.evaluate(
        targetId: 'direct-apk-legacy-android-tv',
        evidence: passingEvidenceFor(
          matrix: matrix,
          targetId: 'direct-apk-legacy-android-tv',
          capturedAt: now.subtract(const Duration(days: 45)),
        ),
        now: now,
      );

      expect(
        wrongTarget.blockers.map((blocker) => blocker.code),
        contains(AiroDistributionBlockerCode.evidenceWrongTarget),
      );
      expect(
        stale.blockers.map((blocker) => blocker.code),
        contains(AiroDistributionBlockerCode.evidenceStale),
      );
    });

    test('public maps exclude release evidence internals', () {
      final matrix = AiroTvLegacyDistribution.matrix();
      final result = matrix.evaluate(
        targetId: 'google-play-tv-android-tv',
        evidence: passingEvidenceFor(
          matrix: matrix,
          targetId: 'google-play-tv-android-tv',
        ),
        now: now,
      );
      final flattened = result.toPublicMap().toString();

      expect(result.passed, isTrue);
      expect(
        flattened,
        contains(AiroDistributionChannel.googlePlayTv.stableId),
      );
      expect(flattened, isNot(contains('/Users/')));
      expect(flattened, isNot(contains('storeConsoleAccount')));
      expect(flattened, isNot(contains('signingMaterial')));
      expect(flattened, isNot(contains('providerPayload')));
    });
  });
}
