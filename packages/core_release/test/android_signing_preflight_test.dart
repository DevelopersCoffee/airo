import 'package:core_release/core_release.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Airo Android signing preflight', () {
    AiroAndroidSigningPreflight run({
      Map<String, String> environment = const {},
      bool productionSigning = true,
      bool keystoreFileExists = false,
    }) {
      return const AiroAndroidSigningPreflightRunner().run(
        AiroAndroidSigningPreflightRequest(
          environment: environment,
          productionSigning: productionSigning,
          keystoreFileExists: keystoreFileExists,
        ),
      );
    }

    test('accepts production signing when all inputs are present', () {
      final preflight = run(
        environment: const {
          'ANDROID_RELEASE_KEYSTORE_BASE64': 'YWlyby1maXh0dXJlLWtleQ==',
          'KEYSTORE_PASSWORD': 'fixture-store-password',
          'KEY_ALIAS': 'fixture-alias',
          'KEY_PASSWORD': 'fixture-key-password',
        },
      );

      expect(preflight.ready, isTrue);
      expect(preflight.findings, isEmpty);
      expect(
        preflight.inputs.map((input) => input.input),
        AiroAndroidSigningPreflightRunner.requiredInputs,
      );
    });

    test('blocks production signing when workflow secrets are missing', () {
      final preflight = run();

      expect(preflight.ready, isFalse);
      expect(
        preflight.findings.map((finding) => finding.code),
        everyElement(AiroAndroidSigningFindingCode.missingSigningInput),
      );
      expect(preflight.findings.length, 4);
    });

    test(
      'marks validation signing as non-blocking when production is disabled',
      () {
        final preflight = run(productionSigning: false);

        expect(preflight.ready, isTrue);
        expect(
          preflight.findings.single.code,
          AiroAndroidSigningFindingCode.productionSigningDisabled,
        );
        expect(preflight.findings.single.blocking, isFalse);
      },
    );

    test(
      'allows a local keystore file source without exposing its path value',
      () {
        final preflight = run(
          environment: const {
            'KEYSTORE_PASSWORD': 'fixture-store-password',
            'KEY_ALIAS': 'fixture-alias',
            'KEY_PASSWORD': 'fixture-key-password',
          },
          keystoreFileExists: true,
        );

        expect(preflight.ready, isTrue);
        expect(
          preflight.inputs
              .firstWhere(
                (input) =>
                    input.input == AiroAndroidSigningInput.keystoreBase64,
              )
              .source,
          'file:app/android/release.keystore',
        );
      },
    );

    test('rejects malformed base64 keystore env values', () {
      final preflight = run(
        environment: const {
          'ANDROID_RELEASE_KEYSTORE_BASE64': 'not base64',
          'KEYSTORE_PASSWORD': 'fixture-store-password',
          'KEY_ALIAS': 'fixture-alias',
          'KEY_PASSWORD': 'fixture-key-password',
        },
      );

      expect(preflight.ready, isFalse);
      expect(
        preflight.findings.map((finding) => finding.code),
        contains(AiroAndroidSigningFindingCode.invalidKeystoreBase64),
      );
    });

    test('public output never exposes secret values', () {
      final output = run(
        environment: const {
          'ANDROID_RELEASE_KEYSTORE_BASE64': 'YWlyby1maXh0dXJlLWtleQ==',
          'KEYSTORE_PASSWORD': 'fixture-store-password',
          'KEY_ALIAS': 'fixture-alias',
          'KEY_PASSWORD': 'fixture-key-password',
        },
      ).toPublicMap().toString();

      expect(output, contains('env:ANDROID_RELEASE_KEYSTORE_BASE64'));
      expect(output, isNot(contains('YWlyby1maXh0dXJlLWtleQ==')));
      expect(output, isNot(contains('fixture-store-password')));
      expect(output, isNot(contains('fixture-alias')));
      expect(output, isNot(contains('fixture-key-password')));
    });
  });
}
