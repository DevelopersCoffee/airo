import 'package:core_release/core_release.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Airo legal release preflight', () {
    AiroLegalReleasePreflight run({
      Iterable<String> profileIds = const ['iptv-standalone', 'tv'],
      bool rootLicensePresent = true,
      String rootLicenseText =
          'MIT License\n\nPermission is hereby granted, free of charge',
      bool licenseReviewPresent = true,
      bool thirdPartyNoticesPresent = true,
      Iterable<AiroPackageLicenseStatus> packageLicenses = const [
        AiroPackageLicenseStatus(
          packageName: 'core_ui',
          path: 'packages/core_ui',
          licensePresent: true,
          matchesRootLicense: true,
        ),
      ],
      AiroPrivateDependencyConfirmation privateDependencyConfirmation =
          AiroPrivateDependencyConfirmation.confirmedAbsent,
      AiroReleaseProvenanceDecision provenanceDecision =
          AiroReleaseProvenanceDecision.sha256OnlyAccepted,
    }) {
      return AiroLegalReleasePreflightRunner(
        matrix: AiroReleaseMatrix.v2Default(),
      ).run(
        AiroLegalReleasePreflightRequest(
          profileIds: profileIds,
          rootLicensePresent: rootLicensePresent,
          rootLicenseText: rootLicenseText,
          licenseReviewPresent: licenseReviewPresent,
          thirdPartyNoticesPresent: thirdPartyNoticesPresent,
          packageLicenses: packageLicenses,
          privateDependencyConfirmation: privateDependencyConfirmation,
          provenanceDecision: provenanceDecision,
        ),
      );
    }

    test('accepts legal release readiness when all decisions are recorded', () {
      final preflight = run();

      expect(preflight.ready, isTrue);
      expect(preflight.rootLicenseKind, 'MIT');
      expect(preflight.findings, isEmpty);
    });

    test('blocks missing root license and legal docs', () {
      final preflight = run(
        rootLicensePresent: false,
        rootLicenseText: '',
        licenseReviewPresent: false,
        thirdPartyNoticesPresent: false,
      );

      expect(preflight.ready, isFalse);
      expect(
        preflight.findings.map((finding) => finding.code),
        containsAll([
          AiroLegalReleaseFindingCode.missingRootLicense,
          AiroLegalReleaseFindingCode.missingLicenseReview,
          AiroLegalReleaseFindingCode.missingThirdPartyNotices,
        ]),
      );
    });

    test('blocks mismatched package licenses', () {
      final preflight = run(
        packageLicenses: const [
          AiroPackageLicenseStatus(
            packageName: 'core_ui',
            path: 'packages/core_ui',
            licensePresent: true,
            matchesRootLicense: false,
          ),
        ],
      );

      expect(preflight.ready, isFalse);
      expect(
        preflight.findings.single.code,
        AiroLegalReleaseFindingCode.packageLicenseMismatch,
      );
    });

    test('blocks missing package licenses', () {
      final preflight = run(
        packageLicenses: const [
          AiroPackageLicenseStatus(
            packageName: 'feature_iptv',
            path: 'packages/feature_iptv',
            licensePresent: false,
            matchesRootLicense: false,
          ),
        ],
      );

      expect(preflight.ready, isFalse);
      expect(
        preflight.findings.single.code,
        AiroLegalReleaseFindingCode.missingPackageLicense,
      );
    });

    test('blocks missing human legal and provenance decisions', () {
      final preflight = run(
        privateDependencyConfirmation:
            AiroPrivateDependencyConfirmation.unknown,
        provenanceDecision: AiroReleaseProvenanceDecision.unknown,
      );

      expect(preflight.ready, isFalse);
      expect(
        preflight.findings.map((finding) => finding.code),
        containsAll([
          AiroLegalReleaseFindingCode.privateDependencyConfirmationMissing,
          AiroLegalReleaseFindingCode.provenanceDecisionMissing,
        ]),
      );
    });

    test(
      'accepts approved present private dependencies as a recorded decision',
      () {
        final preflight = run(
          privateDependencyConfirmation:
              AiroPrivateDependencyConfirmation.confirmedPresentApproved,
          provenanceDecision:
              AiroReleaseProvenanceDecision.signedOrSlsaRequired,
        );

        expect(preflight.ready, isTrue);
        expect(
          preflight.privateDependencyConfirmation,
          AiroPrivateDependencyConfirmation.confirmedPresentApproved,
        );
      },
    );

    test('rejects unknown release profiles', () {
      final preflight = run(profileIds: const ['unknown-profile']);

      expect(preflight.ready, isFalse);
      expect(
        preflight.findings.single.code,
        AiroLegalReleaseFindingCode.unknownProfile,
      );
    });

    test('renders markdown findings for issue evidence', () {
      final markdown = run(
        privateDependencyConfirmation:
            AiroPrivateDependencyConfirmation.unknown,
      ).toMarkdown();

      expect(markdown, contains('# Legal Release Preflight'));
      expect(markdown, contains('private_dependency_confirmation_missing'));
    });
  });
}
