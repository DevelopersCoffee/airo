@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Play dual form-factor for Aika Stream is a Console job. The TV APK must
/// keep both launchers and must not mark leanback as required — otherwise
/// Play hides Pixel 9 even when form factors are enabled.
void main() {
  late String manifest;

  setUpAll(() {
    final file = File('android/app/src/tv/AndroidManifest.xml');
    expect(
      file.existsSync(),
      isTrue,
      reason:
          'Run from the app/ package root. Looked for ${file.absolute.path}.',
    );
    manifest = file.readAsStringSync();
  });

  test('TV manifest keeps leanback and touchscreen optional', () {
    expect(
      manifest,
      contains(
        '<uses-feature android:name="android.software.leanback" android:required="false"/>',
      ),
    );
    expect(
      manifest,
      contains(
        '<uses-feature android:name="android.hardware.touchscreen" android:required="false"/>',
      ),
    );
    expect(
      manifest.contains('android.software.leanback" android:required="true"'),
      isFalse,
      reason: 'Do not set leanback required — that makes the listing TV-only.',
    );
  });

  test('TV manifest declares both phone and leanback launchers', () {
    expect(
      manifest,
      contains('<category android:name="android.intent.category.LAUNCHER"/>'),
    );
    expect(
      manifest,
      contains(
        '<category android:name="android.intent.category.LEANBACK_LAUNCHER"/>',
      ),
    );
  });
}
