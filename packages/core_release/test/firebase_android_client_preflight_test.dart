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
            'io.airo.app.iptv': '1:906799550225:android:iptvreal',
            'io.airo.app.streaming': '1:906799550225:android:streamreal',
          }),
          firebaseOptionsSource: _firebaseOptionsSource({
            'androidIptv': '1:906799550225:android:iptvreal',
            'androidStreaming': '1:906799550225:android:streamreal',
          }),
        ),
      );

      expect(preflight.ready, isTrue);
      expect(preflight.findings, isEmpty);
      expect(preflight.googleServicesClients.length, 2);
      expect(preflight.firebaseOptions.length, 2);
    });

    test('blocks missing google-services clients and option blocks', () {
      final preflight = const AiroFirebaseAndroidClientPreflightRunner().run(
        AiroFirebaseAndroidClientPreflightRequest(
          expectedClients: expectations,
          googleServicesJson: _googleServicesJson({
            'io.airo.app': '1:906799550225:android:full',
          }),
          firebaseOptionsSource: _firebaseOptionsSource({
            'androidStreaming': 'TODO_REGISTER_IO_AIRO_APP_STREAMING',
          }),
        ),
      );

      expect(preflight.ready, isFalse);
      expect(
        preflight.findings.map((finding) => finding.code),
        containsAll(const {
          AiroFirebaseAndroidClientFindingCode.missingGoogleServicesClient,
          AiroFirebaseAndroidClientFindingCode.missingFirebaseOptionsBlock,
          AiroFirebaseAndroidClientFindingCode.placeholderFirebaseOptionsAppId,
        }),
      );
    });

    test('reports mismatched app ids without exposing raw API keys', () {
      final preflight = const AiroFirebaseAndroidClientPreflightRunner().run(
        AiroFirebaseAndroidClientPreflightRequest(
          expectedClients: expectations,
          googleServicesJson: _googleServicesJson({
            'io.airo.app.iptv': '1:906799550225:android:iptvreal',
            'io.airo.app.streaming': '1:906799550225:android:streamreal',
          }),
          firebaseOptionsSource: _firebaseOptionsSource({
            'androidIptv': '1:906799550225:android:wrong1',
            'androidStreaming': '1:906799550225:android:wrong2',
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
      expect(publicOutput, isNot(contains('iptvreal')));
      expect(publicOutput, contains('1:...tvreal'));
    });

    test(
      'derives default v2 mobile/tablet expectations from release profiles',
      () {
        final expected =
            AiroFirebaseAndroidClientPreflightRunner.expectationsFromReleaseProfiles(
              matrix: AiroReleaseMatrix.v2Default(),
              profileIds: const ['iptv-standalone', 'mobile-streaming'],
            );

        expect(expected.map((client) => client.packageName), [
          'io.airo.app.iptv',
          'io.airo.app.streaming',
        ]);
        expect(expected.map((client) => client.firebaseOptionsName), [
          'androidIptv',
          'androidStreaming',
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
      expect(markdown, contains('io.airo.app.streaming'));
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
