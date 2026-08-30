@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every macOS flavour shares one Runner target, so `AppInfo.xcconfig` is the
/// single place the shipped app's name comes from — and
/// `.github/workflows/airo-macos-release.yml` builds only the `tv` profile
/// against it, overriding nothing.
///
/// `app/tool/run_mind_macos.sh` rewrites `PRODUCT_NAME` for a local Mind run
/// and restores it through a trap on exit. When that restore is skipped, the
/// mutation is committable — and it was: `69aa847c` shipped
/// `PRODUCT_NAME = Airo Mind` into the TV release config, so the macOS TV
/// build produced an app named "Airo Mind".
void main() {
  test('macOS AppInfo.xcconfig still names the TV shell', () {
    final config = File('macos/Runner/Configs/AppInfo.xcconfig');
    expect(
      config.existsSync(),
      isTrue,
      reason:
          'Run from the app/ package root. Looked for ${config.absolute.path}.',
    );

    String value(String key) {
      final match = RegExp(
        '^$key\\s*=\\s*(.+?)\\s*\$',
        multiLine: true,
      ).firstMatch(config.readAsStringSync());
      expect(match, isNotNull, reason: 'No `$key` line in AppInfo.xcconfig.');
      return match!.group(1)!;
    }

    expect(
      value('PRODUCT_NAME'),
      'Airo TV',
      reason:
          'The macOS release builds the tv profile against this file. A '
          'different flavour name here means run_mind_macos.sh (or a similar '
          'script) rewrote it and the restore was skipped — revert the line '
          'rather than updating this test.',
    );
    expect(
      value('PRODUCT_BUNDLE_IDENTIFIER'),
      'com.developerscoffee.airo.tv',
      reason:
          'Changing the bundle identifier changes app identity for every '
          'already-installed macOS user.',
    );
  });
}
