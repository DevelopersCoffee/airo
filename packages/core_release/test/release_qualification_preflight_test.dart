import 'package:core_release/core_release.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Airo release qualification preflight', () {
    AiroReleaseArtifactEvidence tvArtifact({
      String filename = 'Airo-TV-v2.0.0.apk',
      String sha256 =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    }) {
      return AiroReleaseArtifactEvidence(
        profileId: 'tv',
        packageId: 'io.airo.app.tv',
        filename: filename,
        artifactType: 'apk',
        sha256: sha256,
      );
    }

    AiroReleaseQualificationCheck check({
      AiroReleaseDeviceClass deviceClass = AiroReleaseDeviceClass.androidTv,
      AiroReleaseQualificationEvidenceType evidenceType =
          AiroReleaseQualificationEvidenceType.physicalDevice,
      String deviceModel = 'Chromecast with Google TV',
      String osVersion = 'Android 12',
      AiroReleaseQualificationResult result =
          AiroReleaseQualificationResult.passed,
    }) {
      return AiroReleaseQualificationCheck(
        profileId: 'tv',
        filename: 'Airo-TV-v2.0.0.apk',
        deviceClass: deviceClass,
        evidenceType: evidenceType,
        deviceModel: deviceModel,
        osVersion: osVersion,
        result: result,
        notes: 'Installed release APK and launched Leanback entrypoint.',
      );
    }

    AiroReleaseQualificationWaiver waiver({
      String reason = 'Fire TV remains compatible/experimental.',
      String approvedBy = 'release-manager',
    }) {
      return AiroReleaseQualificationWaiver(
        profileId: 'tv',
        filename: 'Airo-TV-v2.0.0.apk',
        deviceClass: AiroReleaseDeviceClass.fireTv,
        reason: reason,
        approvedBy: approvedBy,
      );
    }

    AiroReleaseQualificationPreflight run({
      AiroReleaseQualificationMode mode = AiroReleaseQualificationMode.public,
      Iterable<AiroReleaseArtifactEvidence>? artifacts,
      Iterable<AiroReleaseQualificationCheck> checks = const [],
      Iterable<AiroReleaseQualificationWaiver> waivers = const [],
    }) {
      return const AiroReleaseQualificationPreflightRunner().run(
        AiroReleaseQualificationPreflightRequest(
          mode: mode,
          artifacts: artifacts ?? [tvArtifact()],
          checks: checks,
          waivers: waivers,
        ),
      );
    }

    test('accepts public TV qualification with evidence and waiver', () {
      final preflight = run(checks: [check()], waivers: [waiver()]);

      expect(preflight.publicReady, isTrue);
      expect(preflight.dispatchReady, isTrue);
      expect(preflight.findings, isEmpty);
      expect(
        preflight.rows.map((row) => row.result),
        containsAll([
          AiroReleaseQualificationResult.passed,
          AiroReleaseQualificationResult.waived,
        ]),
      );
    });

    test('blocks public qualification when required evidence is missing', () {
      final preflight = run();

      expect(preflight.publicReady, isFalse);
      expect(
        preflight.findings.map((finding) => finding.code),
        everyElement(
          AiroReleaseQualificationFindingCode.missingRequiredEvidence,
        ),
      );
      expect(preflight.findings, hasLength(2));
      expect(
        preflight.rows.map((row) => row.result),
        everyElement(AiroReleaseQualificationResult.missing),
      );
    });

    test(
      'allows internal dispatch to render incomplete qualification reports',
      () {
        final preflight = run(mode: AiroReleaseQualificationMode.internal);

        expect(preflight.publicReady, isFalse);
        expect(preflight.dispatchReady, isTrue);
        expect(preflight.toMarkdown(), contains('missing_required_evidence'));
      },
    );

    test('blocks passed evidence without device model or OS version', () {
      final preflight = run(
        checks: [check(deviceModel: '', osVersion: '')],
        waivers: [waiver()],
      );

      expect(preflight.publicReady, isFalse);
      expect(
        preflight.findings.map((finding) => finding.code),
        contains(AiroReleaseQualificationFindingCode.incompleteEvidenceDevice),
      );
    });

    test('blocks incomplete waivers', () {
      final preflight = run(
        checks: [check()],
        waivers: [waiver(approvedBy: '')],
      );

      expect(preflight.publicReady, isFalse);
      expect(
        preflight.findings.map((finding) => finding.code),
        contains(AiroReleaseQualificationFindingCode.incompleteWaiver),
      );
    });

    test('blocks missing artifact checksums and unknown profiles', () {
      final preflight = run(
        artifacts: [
          tvArtifact(sha256: ''),
          const AiroReleaseArtifactEvidence(
            profileId: 'unknown',
            packageId: 'io.airo.unknown',
            filename: 'unknown.apk',
            artifactType: 'apk',
            sha256:
                'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
          ),
        ],
        checks: [check()],
        waivers: [waiver()],
      );

      expect(preflight.publicReady, isFalse);
      expect(
        preflight.findings.map((finding) => finding.code),
        containsAll([
          AiroReleaseQualificationFindingCode.missingArtifactChecksum,
          AiroReleaseQualificationFindingCode.unknownProfile,
        ]),
      );
    });
  });
}
