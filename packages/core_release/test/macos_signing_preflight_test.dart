import 'package:core_release/core_release.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Airo macOS signing preflight', () {
    AiroMacosSigningPreflight run({
      String profileId = 'tv',
      Map<String, String> environment = const {},
      bool requireSigning = true,
      bool requireNotarization = true,
      bool certificateFileExists = false,
    }) {
      return AiroMacosSigningPreflightRunner(
        matrix: AiroReleaseMatrix.v2Default(),
      ).run(
        AiroMacosSigningPreflightRequest(
          profileId: profileId,
          environment: environment,
          requireSigning: requireSigning,
          requireNotarization: requireNotarization,
          certificateFileExists: certificateFileExists,
        ),
      );
    }

    test('accepts public macOS release setup when all inputs are present', () {
      final preflight = run(
        environment: const {
          'APPLE_CERTIFICATE_BASE64': 'Zml4dHVyZS1kZXZlbG9wZXItaWQtY2VydA==',
          'APPLE_CERTIFICATE_PASSWORD': 'fixture-certificate-password',
          'APPLE_KEYCHAIN_PASSWORD': 'fixture-keychain-password',
          'MACOS_CODESIGN_IDENTITY':
              'Developer ID Application: DevelopersCoffee',
          'APPLE_ID': 'release@example.com',
          'APPLE_TEAM_ID': 'TEAM123456',
          'APPLE_APP_SPECIFIC_PASSWORD': 'fixture-app-password',
        },
      );

      expect(preflight.ready, isTrue);
      expect(preflight.signingReady, isTrue);
      expect(preflight.notarizationReady, isTrue);
      expect(preflight.bundleId, 'com.developerscoffee.airo.tv');
      expect(preflight.findings, isEmpty);
    });

    test('blocks public macOS release setup when inputs are missing', () {
      final preflight = run();

      expect(preflight.ready, isFalse);
      expect(
        preflight.findings.map((finding) => finding.code),
        containsAll([
          AiroMacosSigningFindingCode.missingSigningInput,
          AiroMacosSigningFindingCode.missingNotarizationInput,
        ]),
      );
      expect(preflight.findings.length, 7);
    });

    test(
      'treats unsigned validation artifacts as non-blocking when allowed',
      () {
        final preflight = run(
          requireSigning: false,
          requireNotarization: false,
        );

        expect(preflight.ready, isTrue);
        expect(
          preflight.findings.map((finding) => finding.code),
          containsAll([
            AiroMacosSigningFindingCode.signingDisabled,
            AiroMacosSigningFindingCode.notarizationDisabled,
          ]),
        );
        expect(
          preflight.findings.every((finding) => !finding.blocking),
          isTrue,
        );
      },
    );

    test('requires signing when notarization is required', () {
      final preflight = run(requireSigning: false, requireNotarization: true);

      expect(preflight.requireSigning, isTrue);
      expect(
        preflight.findings.map((finding) => finding.code),
        contains(AiroMacosSigningFindingCode.missingSigningInput),
      );
    });

    test('rejects non-macOS release profiles', () {
      final preflight = run(profileId: 'full');

      expect(preflight.ready, isFalse);
      expect(
        preflight.findings.map((finding) => finding.code),
        contains(AiroMacosSigningFindingCode.profileNotMacosEligible),
      );
    });

    test('rejects malformed certificate base64', () {
      final preflight = run(
        environment: const {
          'APPLE_CERTIFICATE_BASE64': 'not base64',
          'APPLE_CERTIFICATE_PASSWORD': 'fixture-certificate-password',
          'APPLE_KEYCHAIN_PASSWORD': 'fixture-keychain-password',
          'MACOS_CODESIGN_IDENTITY':
              'Developer ID Application: DevelopersCoffee',
          'APPLE_ID': 'release@example.com',
          'APPLE_TEAM_ID': 'TEAM123456',
          'APPLE_APP_SPECIFIC_PASSWORD': 'fixture-app-password',
        },
      );

      expect(preflight.ready, isFalse);
      expect(
        preflight.findings.map((finding) => finding.code),
        contains(AiroMacosSigningFindingCode.invalidCertificateBase64),
      );
    });

    test('public output never exposes credential values', () {
      final output = run(
        environment: const {
          'APPLE_CERTIFICATE_BASE64': 'Zml4dHVyZS1kZXZlbG9wZXItaWQtY2VydA==',
          'APPLE_CERTIFICATE_PASSWORD': 'fixture-certificate-password',
          'APPLE_KEYCHAIN_PASSWORD': 'fixture-keychain-password',
          'MACOS_CODESIGN_IDENTITY':
              'Developer ID Application: DevelopersCoffee',
          'APPLE_ID': 'release@example.com',
          'APPLE_TEAM_ID': 'TEAM123456',
          'APPLE_APP_SPECIFIC_PASSWORD': 'fixture-app-password',
        },
      ).toPublicMap().toString();

      expect(output, contains('env:APPLE_CERTIFICATE_BASE64'));
      expect(output, isNot(contains('Zml4dHVyZS1kZXZlbG9wZXItaWQtY2VydA==')));
      expect(output, isNot(contains('fixture-certificate-password')));
      expect(output, isNot(contains('fixture-keychain-password')));
      expect(output, isNot(contains('Developer ID Application')));
      expect(output, isNot(contains('release@example.com')));
      expect(output, isNot(contains('TEAM123456')));
      expect(output, isNot(contains('fixture-app-password')));
    });

    test('renders markdown findings for issue evidence', () {
      final markdown = run().toMarkdown();

      expect(markdown, contains('# macOS Signing And Notarization Preflight'));
      expect(markdown, contains('missing_signing_input'));
      expect(markdown, contains('missing_notarization_input'));
    });
  });
}
