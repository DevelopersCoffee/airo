import 'package:flutter_test/flutter_test.dart';
import 'package:platform_certification/platform_certification.dart';

void main() {
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
  });
}
