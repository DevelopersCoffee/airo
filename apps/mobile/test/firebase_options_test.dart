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
    });
  });
}
