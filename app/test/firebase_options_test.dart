import 'package:airo_app/firebase_options.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // CI without the FIREBASE_OPTIONS_DART_B64 secret falls back to
  // firebase_options.dart.template, whose appIds are intentional
  // `YOUR_`/`TODO` placeholders (see the template's own doc comment).
  // Assertions that require a real Firebase project are skipped in that
  // mode instead of failing, and run fully whenever a real
  // firebase_options.dart is present (local dev, or CI once configured).
  final usingPlaceholderConfig = !DefaultFirebaseOptions.isConfigured(
    DefaultFirebaseOptions.android,
  );

  group('DefaultFirebaseOptions', () {
    test('marks placeholder desktop options as not configured', () {
      expect(
        DefaultFirebaseOptions.isConfigured(DefaultFirebaseOptions.macos),
        isFalse,
      );
      expect(
        DefaultFirebaseOptions.isConfigured(DefaultFirebaseOptions.windows),
        isFalse,
      );
    });

    test('marks the provisioned Android app ids as configured', () {
      if (usingPlaceholderConfig) {
        markTestSkipped(
          'firebase_options.dart is the placeholder template -- no '
          'FIREBASE_OPTIONS_DART_B64 secret configured for this run.',
        );
        return;
      }
      // Android only. FIREBASE_OPTIONS_DART_B64 carries real values for the
      // three registered Android clients; `web`, `ios`, `macos`, `windows` and
      // `androidStreaming` are still placeholders because those apps are not
      // registered in the Firebase project. `usingPlaceholderConfig` is read
      // off `android`, so asserting `web` here would fail the moment the
      // Android clients alone were provisioned -- which is exactly what
      // happened.
      expect(
        DefaultFirebaseOptions.isConfigured(DefaultFirebaseOptions.android),
        isTrue,
      );
      expect(
        DefaultFirebaseOptions.isConfigured(DefaultFirebaseOptions.androidTv),
        isTrue,
      );
      expect(
        DefaultFirebaseOptions.isConfigured(DefaultFirebaseOptions.androidMind),
        isTrue,
      );
    });

    test('uses the registered Android TV Firebase app id', () {
      if (usingPlaceholderConfig) {
        markTestSkipped(
          'firebase_options.dart is the placeholder template -- no '
          'FIREBASE_OPTIONS_DART_B64 secret configured for this run.',
        );
        return;
      }
      // Play listing `com.developerscoffee.tv.midas` — not the retired
      // `io.airo.app.tv` client (`dfa957aac3a2fdc62206b0`).
      expect(
        DefaultFirebaseOptions.androidTv.appId,
        '1:906799550225:android:c5df8d843e7dd6002206b0',
      );
    });

    test('selects the supported full, streaming, TV, and Mind variants', () {
      expect(
        AppVariant.values,
        containsAll([
          AppVariant.full,
          AppVariant.streaming,
          AppVariant.tv,
          AppVariant.mind,
        ]),
      );
      // Exact length, not just containsAll: a new variant needs a matching
      // `_getAndroidOptions()` arm and its own registered Firebase client, or
      // it silently initializes as `io.airo.app` and Google Sign-In fails with
      // `ApiException: 10` on device. Failing here is the cheap reminder.
      expect(AppVariant.values, hasLength(4));
    });
  });
}
