@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Play Console scored Aika Stream 19 at 26% R8 optimization / obfuscation /
/// shrinking. 0.0.2 must keep minify+resource shrinking on, keep R8 full mode
/// plus optimized resource shrinking, and must not reintroduce the GMS /
/// Firebase / ML Kit / lifecycle blanket keeps that caused the score.
void main() {
  late String gradle;
  late String properties;
  late String proguard;

  setUpAll(() {
    gradle = File('android/app/build.gradle.kts').readAsStringSync();
    properties = File('android/gradle.properties').readAsStringSync();
    proguard = File('android/app/proguard-rules.pro').readAsStringSync();
  });

  test('release build still minifies and shrinks resources', () {
    expect(gradle, contains('isMinifyEnabled = true'));
    expect(gradle, contains('isShrinkResources = true'));
  });

  test('R8 full mode and optimized resource shrinking stay on', () {
    expect(properties, contains('android.enableR8.fullMode=true'));
    expect(properties, contains('android.r8.optimizedResourceShrinking=true'));
  });

  test('Play-flagged blanket keeps stay gone', () {
    const forbidden = <String>[
      '-keep class com.google.mlkit.** { *; }',
      '-keep class com.google.mlkit.genai.** { *; }',
      '-keep class com.google.firebase.** { *; }',
      '-keep class com.google.android.gms.** { *; }',
      '-keep class androidx.lifecycle.** { *; }',
    ];
    for (final rule in forbidden) {
      expect(
        proguard.contains(rule),
        isFalse,
        reason: 'Re-adding `$rule` would tank Play\'s R8 score again.',
      );
    }
  });
}
