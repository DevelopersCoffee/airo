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

    test('marks real Firebase app ids as configured', () {
      if (usingPlaceholderConfig) {
        markTestSkipped(
          'firebase_options.dart is the placeholder template -- no '
          'FIREBASE_OPTIONS_DART_B64 secret configured for this run.',
        );
        return;
      }
      expect(
        DefaultFirebaseOptions.isConfigured(DefaultFirebaseOptions.web),
        isTrue,
      );
      expect(
        DefaultFirebaseOptions.isConfigured(DefaultFirebaseOptions.android),
        isTrue,
      );
      expect(
        DefaultFirebaseOptions.isConfigured(DefaultFirebaseOptions.androidTv),
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
      expect(
        DefaultFirebaseOptions.androidTv.appId,
        '1:906799550225:android:dfa957aac3a2fdc62206b0',
      );
    });

    test('selects the supported full and TV variants', () {
      expect(AppVariant.values, containsAll([AppVariant.full, AppVariant.tv]));
      expect(AppVariant.values, hasLength(2));
    });
  });
}
