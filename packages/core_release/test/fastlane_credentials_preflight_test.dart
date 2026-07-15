import 'package:core_release/core_release.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Airo Fastlane credentials preflight', () {
    AiroFastlaneCredentialsPreflight run({
      String profileId = 'tv',
      Map<String, String> environment = const {},
      bool googlePlayCredentialFileExists = false,
      bool iosUploadInScope = false,
    }) {
      return AiroFastlaneCredentialsPreflightRunner(
        matrix: AiroReleaseMatrix.v2Default(),
      ).run(
        AiroFastlaneCredentialsPreflightRequest(
          profileId: profileId,
          environment: environment,
          googlePlayCredentialFileExists: googlePlayCredentialFileExists,
          iosUploadInScope: iosUploadInScope,
        ),
      );
    }

    test('accepts TV Play setup when package and credential are present', () {
      final preflight = run(
        environment: const {
          'SUPPLY_PACKAGE_NAME': 'io.airo.app.tv',
          'GOOGLE_PLAY_SERVICE_ACCOUNT_JSON': 'fixture-google-payload',
        },
      );

      expect(preflight.googlePlayReady, isTrue);
      expect(preflight.appStoreConnectReady, isFalse);
      expect(preflight.expectedAndroidPackageName, 'io.airo.app.tv');
      expect(preflight.androidPackageName, 'io.airo.app.tv');
      expect(
        preflight.googlePlayCredentialSource,
        'env:GOOGLE_PLAY_SERVICE_ACCOUNT_JSON',
      );
      expect(
        preflight.findings.map((finding) => finding.code),
        contains(AiroFastlaneCredentialFindingCode.iosUploadDeferred),
      );
    });

    test('blocks Play upload when credentials are missing', () {
      final preflight = run();

      expect(preflight.googlePlayReady, isFalse);
      expect(
        preflight.findings.map((finding) => finding.code),
        contains(AiroFastlaneCredentialFindingCode.missingGooglePlayCredential),
      );
    });

    test('requires package override for non-TV Play profiles', () {
      final preflight = run(
        profileId: 'iptv-standalone',
        environment: const {
          'GOOGLE_PLAY_SERVICE_ACCOUNT_JSON': 'fixture-google-payload',
        },
      );

      expect(preflight.googlePlayReady, isFalse);
      expect(preflight.expectedAndroidPackageName, 'io.airo.app.iptv');
      expect(preflight.androidPackageName, 'io.airo.app.tv');
      expect(
        preflight.findings.map((finding) => finding.code),
        contains(AiroFastlaneCredentialFindingCode.packageNameMismatch),
      );
    });

    test('blocks App Store Connect only when iOS upload is in scope', () {
      final deferred = run(
        environment: const {
          'SUPPLY_PACKAGE_NAME': 'io.airo.app.tv',
          'PLAY_STORE_CREDENTIALS': 'fixture-play-payload',
        },
      );
      final inScope = run(
        environment: const {
          'SUPPLY_PACKAGE_NAME': 'io.airo.app.tv',
          'PLAY_STORE_CREDENTIALS': 'fixture-play-payload',
        },
        iosUploadInScope: true,
      );

      expect(deferred.googlePlayReady, isTrue);
      expect(deferred.appStoreConnectReady, isFalse);
      expect(
        deferred.findings
            .where(
              (finding) =>
                  finding.target ==
                      AiroFastlaneCredentialTarget.appStoreConnect &&
                  finding.blocking,
            )
            .toList(),
        isEmpty,
      );
      expect(inScope.appStoreConnectReady, isFalse);
      expect(
        inScope.findings
            .where(
              (finding) =>
                  finding.code ==
                      AiroFastlaneCredentialFindingCode
                          .missingAppleCredential &&
                  finding.blocking,
            )
            .length,
        AiroFastlaneCredentialsPreflightRunner.appleCredentialVariables.length,
      );
    });

    test(
      'accepts App Store Connect credentials when iOS upload is in scope',
      () {
        final preflight = run(
          environment: const {
            'SUPPLY_PACKAGE_NAME': 'io.airo.app.tv',
            'GOOGLE_PLAY_SERVICE_ACCOUNT_JSON': 'fixture-google-payload',
            'MATCH_PASSWORD': 'fixture-match-value',
            'ASC_KEY_ID': 'key-id',
            'ASC_ISSUER_ID': 'issuer-id',
            'ASC_KEY_CONTENT': 'fixture-asc-content',
            'TEAM_ID': 'fixture-team-value',
            'APP_IDENTIFIER': 'com.developerscoffee.airo',
          },
          iosUploadInScope: true,
        );

        expect(preflight.googlePlayReady, isTrue);
        expect(preflight.appStoreConnectReady, isTrue);
        expect(preflight.findings, isEmpty);
      },
    );

    test('public output never exposes credential material', () {
      final output = run(
        environment: const {
          'SUPPLY_PACKAGE_NAME': 'io.airo.app.tv',
          'GOOGLE_PLAY_SERVICE_ACCOUNT_JSON': 'fixture-google-payload',
          'MATCH_PASSWORD': 'fixture-match-value',
          'ASC_KEY_ID': 'key-id',
          'ASC_ISSUER_ID': 'issuer-id',
          'ASC_KEY_CONTENT': 'fixture-asc-content',
          'TEAM_ID': 'fixture-team-value',
        },
        iosUploadInScope: true,
      ).toPublicMap().toString();

      expect(output, contains('env:GOOGLE_PLAY_SERVICE_ACCOUNT_JSON'));
      expect(output, isNot(contains('fixture-google-payload')));
      expect(output, isNot(contains('fixture-asc-content')));
      expect(output, isNot(contains('fixture-match-value')));
      expect(output, isNot(contains('fixture-team-value')));
    });
  });
}
