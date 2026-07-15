import 'package:core_release/core_release.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Airo Play upload planner', () {
    AiroPlayUploadPlan plan({
      String profileId = 'tv',
      String requestedTrack = 'none',
      bool serviceAccountAvailable = false,
      bool expectedAabExists = true,
      bool enforceConfirmedTrack = false,
    }) {
      return AiroPlayUploadPlanner(matrix: AiroReleaseMatrix.v2Default()).plan(
        AiroPlayUploadPlanRequest(
          profileId: profileId,
          versionLabel: 'v2.0.0',
          buildName: '2.0.0',
          buildNumber: '200',
          requestedTrack: requestedTrack,
          serviceAccountAvailable: serviceAccountAvailable,
          expectedAabExists: expectedAabExists,
          enforceConfirmedTrack: enforceConfirmedTrack,
        ),
      );
    }

    test('treats none as no-upload without requiring credentials', () {
      final uploadPlan = plan();

      expect(uploadPlan.mode, AiroPlayUploadMode.noUpload);
      expect(uploadPlan.uploadRequested, isFalse);
      expect(uploadPlan.canUpload, isFalse);
      expect(uploadPlan.packageId, 'io.airo.app.tv');
      expect(
        uploadPlan.expectedAabFileName,
        'Airo-TV-2.0.0-200-Play-Store.aab',
      );
      expect(uploadPlan.playConsoleUrl, isNull);
      expect(uploadPlan.findings, isEmpty);
    });

    test('resolves mobile package, AAB, and Play URL for real tracks', () {
      final uploadPlan = plan(
        profileId: 'iptv-standalone',
        requestedTrack: 'internal',
        serviceAccountAvailable: true,
      );

      expect(uploadPlan.mode, AiroPlayUploadMode.upload);
      expect(uploadPlan.canUpload, isTrue);
      expect(uploadPlan.packageId, 'io.airo.app.iptv');
      expect(
        uploadPlan.expectedAabFileName,
        'Airo-IPTV-2.0.0-200-Play-Store.aab',
      );
      expect(
        uploadPlan.playConsoleUrl,
        'https://play.google.com/console/u/0/developers/app/'
        'io.airo.app.iptv/tracks/internal',
      );
      expect(
        uploadPlan.findings.map((finding) => finding.code),
        contains(AiroPlayUploadFindingCode.pendingPlayDecision),
      );
      expect(uploadPlan.findings.any((finding) => finding.blocking), isFalse);
    });

    test('blocks upload when service account or AAB is missing', () {
      final uploadPlan = plan(
        requestedTrack: 'beta',
        serviceAccountAvailable: false,
        expectedAabExists: false,
      );

      expect(uploadPlan.canUpload, isFalse);
      expect(
        uploadPlan.findings.map((finding) => finding.code),
        containsAll(const {
          AiroPlayUploadFindingCode.missingServiceAccount,
          AiroPlayUploadFindingCode.missingAab,
        }),
      );
    });

    test('can enforce confirmed track decisions for production runs', () {
      final uploadPlan = plan(
        requestedTrack: 'production',
        serviceAccountAvailable: true,
        enforceConfirmedTrack: true,
      );

      expect(uploadPlan.canUpload, isFalse);
      expect(
        uploadPlan.findings
            .singleWhere(
              (finding) =>
                  finding.code == AiroPlayUploadFindingCode.pendingPlayDecision,
            )
            .blocking,
        isTrue,
      );
    });

    test('rejects unsupported tracks and unknown profiles', () {
      final uploadPlan = plan(profileId: 'missing', requestedTrack: 'canary');

      expect(uploadPlan.canUpload, isFalse);
      expect(
        uploadPlan.findings.map((finding) => finding.code),
        containsAll(const {
          AiroPlayUploadFindingCode.unknownProfile,
          AiroPlayUploadFindingCode.unsupportedTrack,
        }),
      );
    });

    test('rejects deferred and validation-only profiles', () {
      final iosPlan = plan(
        profileId: 'ios-spm',
        requestedTrack: 'alpha',
        serviceAccountAvailable: true,
      );
      final webPlan = plan(
        profileId: 'web-validation',
        requestedTrack: 'alpha',
        serviceAccountAvailable: true,
      );

      expect(
        iosPlan.findings.map((finding) => finding.code),
        contains(AiroPlayUploadFindingCode.profileNotPlayEligible),
      );
      expect(
        webPlan.findings.map((finding) => finding.code),
        contains(AiroPlayUploadFindingCode.profileNotPlayEligible),
      );
      expect(iosPlan.expectedAabFileName, isNull);
      expect(webPlan.expectedAabFileName, isNull);
    });

    test('public maps do not expose credential material', () {
      final publicMap = plan(
        requestedTrack: 'internal',
        serviceAccountAvailable: true,
      ).toPublicMap().toString();

      expect(publicMap, contains('io.airo.app.tv'));
      expect(publicMap, contains('Play-Store.aab'));
      expect(publicMap, isNot(contains('private_key')));
      expect(publicMap, isNot(contains('client_email')));
      expect(publicMap, isNot(contains('play-store-credentials.json')));
      expect(publicMap, isNot(contains('/Users/')));
    });
  });
}
