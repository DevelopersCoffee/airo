import 'package:airo_app/firebase_options.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
      expect(
        DefaultFirebaseOptions.androidTv.appId,
        '1:906799550225:android:dfa957aac3a2fdc62206b0',
      );
    });

    test('keeps streaming disabled until its Firebase app is registered', () {
      expect(
        DefaultFirebaseOptions.isConfigured(
          DefaultFirebaseOptions.androidStreaming,
        ),
        isFalse,
      );
    });
  });
}
