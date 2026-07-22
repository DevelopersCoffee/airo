import 'dart:convert';

import 'package:core_release/core_release.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Airo Firebase Android client preflight', () {
    const expectations =
        AiroFirebaseAndroidClientPreflightRunner.v2MobileTabletExpectations;

    test('accepts configured google-services clients and Firebase options', () {
      final preflight = const AiroFirebaseAndroidClientPreflightRunner().run(
        AiroFirebaseAndroidClientPreflightRequest(
          expectedClients: expectations,
          googleServicesJson: _googleServicesJson({
            'io.airo.app': '1:906799550225:android:fullreal',
          }),
          firebaseOptionsSource: _firebaseOptionsSource({
            'android': '1:906799550225:android:fullreal',
          }),
        ),
      );

      expect(preflight.ready, isTrue);
      expect(preflight.findings, isEmpty);
      expect(preflight.googleServicesClients.length, 1);
      expect(preflight.firebaseOptions.length, 1);
    });

    test('blocks missing google-services clients and option blocks', () {
      final preflight = const AiroFirebaseAndroidClientPreflightRunner().run(
        AiroFirebaseAndroidClientPreflightRequest(
          expectedClients: expectations,
          googleServicesJson: _googleServicesJson({
            'io.airo.app': '1:906799550225:android:full',
          }),
          firebaseOptionsSource: _firebaseOptionsSource({
            'android': 'TODO_REGISTER_IO_AIRO_APP',
          }),
        ),
      );

      expect(preflight.ready, isFalse);
      expect(
        preflight.findings.map((finding) => finding.code),
        contains(
          AiroFirebaseAndroidClientFindingCode.placeholderFirebaseOptionsAppId,
        ),
      );
    });

    test('reports mismatched app ids without exposing raw API keys', () {
      final preflight = const AiroFirebaseAndroidClientPreflightRunner().run(
        AiroFirebaseAndroidClientPreflightRequest(
          expectedClients: expectations,
          googleServicesJson: _googleServicesJson({
            'io.airo.app': '1:906799550225:android:fullreal',
          }),
          firebaseOptionsSource: _firebaseOptionsSource({
            'android': '1:906799550225:android:wrong1',
          }),
        ),
      );

      final publicOutput = preflight.toPublicMap().toString();

      expect(preflight.ready, isFalse);
      expect(
        preflight.findings.map((finding) => finding.code),
        everyElement(
          AiroFirebaseAndroidClientFindingCode.mismatchedFirebaseOptionsAppId,
        ),
      );
      expect(publicOutput, isNot(contains('fixture-api-key')));
      expect(publicOutput, isNot(contains('fullreal')));
      expect(publicOutput, contains('1:...wrong1'));
    });

    test(
      'derives default v2 mobile/tablet expectations from release profiles',
      () {
        final expected =
            AiroFirebaseAndroidClientPreflightRunner.expectationsFromReleaseProfiles(
              matrix: AiroReleaseMatrix.v2Default(),
              profileIds: const ['full', 'tv'],
            );

        expect(expected.map((client) => client.packageName), [
          'io.airo.app',
          'io.airo.app.tv',
        ]);
        expect(expected.map((client) => client.firebaseOptionsName), [
          'android',
          'androidTv',
        ]);
      },
    );

    test('renders markdown findings for issue evidence', () {
      final preflight = const AiroFirebaseAndroidClientPreflightRunner().run(
        AiroFirebaseAndroidClientPreflightRequest(
          expectedClients: expectations,
          googleServicesJson: '',
          firebaseOptionsSource: '',
        ),
      );

      final markdown = preflight.toMarkdown();

      expect(markdown, contains('# Firebase Android Client Preflight'));
      expect(markdown, contains('missing_google_services_client'));
      expect(markdown, contains('io.airo.app'));
    });
  });
}

String _googleServicesJson(Map<String, String> clients) {
  return jsonEncode({
    'project_info': {
      'project_number': '906799550225',
      'project_id': 'devscoffee-airo',
    },
    'client': [
      for (final entry in clients.entries)
        {
          'client_info': {
            'mobilesdk_app_id': entry.value,
            'android_client_info': {'package_name': entry.key},
          },
          'api_key': [
            {'current_key': 'fixture-api-key'},
          ],
        },
    ],
  });
}

String _firebaseOptionsSource(Map<String, String> options) {
  return options.entries
      .map(
        (entry) =>
            '''
  static const FirebaseOptions ${entry.key} = FirebaseOptions(
    apiKey: 'fixture-api-key',
    appId: '${entry.value}',
    messagingSenderId: '906799550225',
    projectId: 'devscoffee-airo',
  );
''',
      )
      .join('\n');
}
