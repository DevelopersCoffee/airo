import 'package:core_release/core_release.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Airo data safety preflight', () {
    AiroDataSafetyPreflight run({
      String profileId = 'tv',
      bool analyticsSdkPresent = false,
      bool crashlyticsSdkPresent = false,
      bool advertisingSdkPresent = false,
      Set<String> sensitiveAndroidPermissions = const {},
      bool localPlaylistUrls = true,
      bool localPreferences = true,
      bool localPlaybackState = true,
      bool accountRequiredForPlayback = false,
      bool appStorePrivacyInScope = false,
    }) {
      return AiroDataSafetyPreflightRunner(
        matrix: AiroReleaseMatrix.v2Default(),
      ).run(
        AiroDataSafetyPreflightRequest(
          profileId: profileId,
          analyticsSdkPresent: analyticsSdkPresent,
          crashlyticsSdkPresent: crashlyticsSdkPresent,
          advertisingSdkPresent: advertisingSdkPresent,
          sensitiveAndroidPermissions: sensitiveAndroidPermissions,
          localPlaylistUrls: localPlaylistUrls,
          localPreferences: localPreferences,
          localPlaybackState: localPlaybackState,
          accountRequiredForPlayback: accountRequiredForPlayback,
          appStorePrivacyInScope: appStorePrivacyInScope,
        ),
      );
    }

    test('builds ready default posture for Airo TV', () {
      final preflight = run();

      expect(preflight.readyForConsoleEntry, isTrue);
      expect(preflight.profileId, 'tv');
      expect(preflight.packageId, 'io.airo.app.tv');
      expect(preflight.analyticsSdkPresent, isFalse);
      expect(preflight.crashlyticsSdkPresent, isFalse);
      expect(preflight.advertisingSdkPresent, isFalse);
      expect(preflight.sensitiveAndroidPermissions, isEmpty);
      expect(
        preflight.declarations.map((declaration) => declaration.dataType),
        containsAll(const [
          'Personal info',
          'Location',
          'Contacts',
          'Photos, videos, or audio files',
          'App activity',
          'IPTV playlist URLs',
        ]),
      );
      expect(
        preflight.declarations
            .singleWhere(
              (declaration) => declaration.dataType == 'IPTV playlist URLs',
            )
            .collected,
        'Local only',
      );
    });

    test('keeps console submission as non-blocking finding', () {
      final preflight = run();

      expect(
        preflight.findings.map((finding) => finding.code),
        contains(AiroDataSafetyFindingCode.consoleSubmissionRequired),
      );
      expect(
        preflight.findings
            .where(
              (finding) =>
                  finding.code ==
                      AiroDataSafetyFindingCode.consoleSubmissionRequired &&
                  finding.blocking,
            )
            .toList(),
        isEmpty,
      );
    });

    test('marks App Store Privacy deferred unless it is in scope', () {
      final deferred = run();
      final inScope = run(appStorePrivacyInScope: true);

      expect(
        deferred.findings.map((finding) => finding.code),
        contains(AiroDataSafetyFindingCode.appStorePrivacyDeferred),
      );
      expect(
        inScope.findings.map((finding) => finding.code),
        isNot(contains(AiroDataSafetyFindingCode.appStorePrivacyDeferred)),
      );
      expect(inScope.readyForConsoleEntry, isTrue);
    });

    test('blocks when analytics, crash, or ads SDKs are present', () {
      final preflight = run(
        analyticsSdkPresent: true,
        crashlyticsSdkPresent: true,
        advertisingSdkPresent: true,
      );

      expect(preflight.readyForConsoleEntry, isFalse);
      expect(
        preflight.findings.map((finding) => finding.code),
        containsAll(const {
          AiroDataSafetyFindingCode.analyticsSdkPresent,
          AiroDataSafetyFindingCode.crashlyticsSdkPresent,
          AiroDataSafetyFindingCode.advertisingSdkPresent,
        }),
      );
    });

    test('blocks sensitive TV permissions', () {
      final preflight = run(
        sensitiveAndroidPermissions: const {
          'android.permission.ACCESS_FINE_LOCATION',
          'android.permission.CAMERA',
        },
      );

      expect(preflight.readyForConsoleEntry, isFalse);
      expect(preflight.sensitiveAndroidPermissions, hasLength(2));
      expect(
        preflight.findings
            .where(
              (finding) =>
                  finding.code ==
                  AiroDataSafetyFindingCode.sensitivePermissionPresent,
            )
            .length,
        2,
      );
    });

    test('blocks changed local-only data assumptions', () {
      final preflight = run(
        localPlaylistUrls: false,
        localPreferences: false,
        localPlaybackState: false,
        accountRequiredForPlayback: true,
      );

      expect(preflight.readyForConsoleEntry, isFalse);
      expect(
        preflight.findings.map((finding) => finding.code),
        contains(AiroDataSafetyFindingCode.localDataDeclarationChanged),
      );
      expect(
        preflight.declarations
            .singleWhere(
              (declaration) => declaration.dataType == 'Personal info',
            )
            .collected,
        'Review required',
      );
    });

    test('rejects unknown profiles', () {
      final preflight = run(profileId: 'missing');

      expect(preflight.readyForConsoleEntry, isFalse);
      expect(preflight.packageId, isNull);
      expect(
        preflight.findings.map((finding) => finding.code),
        contains(AiroDataSafetyFindingCode.unknownProfile),
      );
    });

    test(
      'public output identifies console submission without raw user data',
      () {
        final output = run().toPublicMap();

        expect(output['packageId'], 'io.airo.app.tv');
        expect(
          (output['googlePlayDataSafety']!
              as Map<String, Object?>)['consoleSubmissionRequired'],
          isTrue,
        );
        expect(output.toString(), isNot(contains('http://user-playlist')));
        expect(output.toString(), isNot(contains('user@example.com')));
      },
    );
  });
}
