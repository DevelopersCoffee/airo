import 'package:core_release/core_release.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Airo Firebase distribution preflight', () {
    AiroFirebaseDistributionPreflight run({
      AiroFirebaseDistributionMode mode = AiroFirebaseDistributionMode.upload,
      bool serviceAccountPresent = true,
      Map<String, String> appIds = const {'tv': '1:906799550225:android:tv'},
      Map<String, String> testerGroups = const {'tv': 'tv-qa'},
      List<String> profileIds = const ['tv'],
    }) {
      return const AiroFirebaseDistributionPreflightRunner().run(
        AiroFirebaseDistributionPreflightRequest(
          mode: mode,
          serviceAccountPresent: serviceAccountPresent,
          targets:
              AiroFirebaseDistributionPreflightRunner.targetsFromReleaseProfiles(
                matrix: AiroReleaseMatrix.v2Default(),
                profileIds: profileIds,
                firebaseAppIds: appIds,
                testerGroups: testerGroups,
              ),
        ),
      );
    }

    test(
      'accepts upload mode when app id, groups, and service account exist',
      () {
        final preflight = run();

        expect(preflight.ready, isTrue);
        expect(preflight.findings, isEmpty);
        expect(preflight.targets.single.packageId, 'io.airo.app.tv');
        expect(
          preflight.targets.single.toPublicMap(),
          containsPair('testerGroupCount', 1),
        );
      },
    );

    test('treats disabled distribution as non-blocking', () {
      final preflight = run(
        mode: AiroFirebaseDistributionMode.none,
        serviceAccountPresent: false,
        appIds: const {},
        testerGroups: const {},
      );

      expect(preflight.ready, isTrue);
      expect(
        preflight.findings.single.code,
        AiroFirebaseDistributionFindingCode.distributionDisabled,
      );
      expect(preflight.findings.single.blocking, isFalse);
    });

    test('blocks upload mode when setup inputs are missing', () {
      final preflight = run(
        serviceAccountPresent: false,
        appIds: const {},
        testerGroups: const {},
        profileIds: const ['iptv-standalone', 'tv'],
      );

      expect(preflight.ready, isFalse);
      expect(
        preflight.findings.map((finding) => finding.code),
        containsAll(const {
          AiroFirebaseDistributionFindingCode.missingServiceAccount,
          AiroFirebaseDistributionFindingCode.missingFirebaseAppId,
          AiroFirebaseDistributionFindingCode.missingTesterGroups,
        }),
      );
    });

    test('blocks placeholder app ids', () {
      final preflight = run(appIds: const {'tv': 'TODO_FIREBASE_APP_ID'});

      expect(preflight.ready, isFalse);
      expect(
        preflight.findings.map((finding) => finding.code),
        contains(AiroFirebaseDistributionFindingCode.placeholderFirebaseAppId),
      );
    });

    test(
      'redacts Firebase app ids and tester group names in public output',
      () {
        final output = run(
          appIds: const {'tv': '1:906799550225:android:secret-tv-id'},
          testerGroups: const {'tv': 'private-tv-testers,founders'},
        ).toPublicMap().toString();

        expect(output, contains('1:...v-id'));
        expect(output, isNot(contains('secret-tv-id')));
        expect(output, isNot(contains('private-tv-testers')));
        expect(output, isNot(contains('founders')));
      },
    );

    test('renders markdown findings for issue evidence', () {
      final markdown = run(
        serviceAccountPresent: false,
        appIds: const {},
        testerGroups: const {},
      ).toMarkdown();

      expect(markdown, contains('# Firebase App Distribution Preflight'));
      expect(markdown, contains('missing_service_account'));
      expect(markdown, contains('missing_firebase_app_id'));
    });
  });
}
