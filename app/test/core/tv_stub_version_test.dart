@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Airo TV overrides `package_info_plus` with a stub (see the
/// `dependency_overrides` block in `app/pubspec_tv.yaml`), so on TV the
/// "App version" row is served by hardcoded constants rather than the real
/// `versionName`/`versionCode` Gradle stamps into the APK.
///
/// Gradle takes both from whichever pubspec Flutter was pointed at
/// (`versionCode = flutter.versionCode` in `app/android/app/build.gradle.kts`),
/// so the stub is only truthful while its fallbacks equal `pubspec_tv.yaml`.
/// They did not: the stub said `0.0.2 (2)` against a real `0.0.7-preview+12`
/// build, which is exactly the value support would triage against.
///
/// This test reads both files as text rather than importing the stub —
/// the app package resolves `package_info_plus` to the real plugin, so the
/// stub is not importable from here.
void main() {
  test('TV package_info stub reports the version pubspec_tv.yaml ships', () {
    final pubspec = File('pubspec_tv.yaml');
    final stub = File(
      '../packages/stubs/package_info_plus_stub/lib/package_info_plus.dart',
    );
    expect(
      pubspec.existsSync() && stub.existsSync(),
      isTrue,
      reason:
          'Run from the app/ package root. Looked for ${pubspec.absolute.path} '
          'and ${stub.absolute.path}.',
    );

    // e.g. `version: 0.0.7-preview+12`
    final declared = RegExp(
      r'^version:\s*(\S+?)\+(\S+)\s*$',
      multiLine: true,
    ).firstMatch(pubspec.readAsStringSync());
    expect(
      declared,
      isNotNull,
      reason:
          'pubspec_tv.yaml has no `version: <name>+<build>` line to check '
          'the stub against.',
    );

    final source = stub.readAsStringSync();
    String constant(String name) {
      final match = RegExp(
        "const String $name = '([^']*)';",
      ).firstMatch(source);
      expect(
        match,
        isNotNull,
        reason:
            'Could not find $name in the stub. If its shape changed, update '
            'this test rather than deleting it — it is the only thing keeping '
            'the TV version string honest.',
      );
      return match!.group(1)!;
    }

    expect(
      constant('_stubVersion'),
      declared!.group(1),
      reason:
          'pubspec_tv.yaml ships version ${declared.group(1)} but the TV '
          'package_info stub reports a different one, so Settings -> App '
          'version will mislead support.',
    );
    expect(
      constant('_stubBuildNumber'),
      declared.group(2),
      reason:
          'pubspec_tv.yaml ships build ${declared.group(2)} but the TV '
          'package_info stub reports a different one.',
    );
  });
}
