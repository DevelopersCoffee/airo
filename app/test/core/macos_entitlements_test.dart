@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// macOS ships sandboxed, so a capability the code uses but the entitlement
/// file does not grant fails silently at runtime — and only in the profile
/// whose entitlement is missing. Both real cases behaved that way: meeting
/// export was granted `user-selected.read-only` while it creates directories
/// and writes files, and `network.server` was in DebugProfile only, so the
/// LAN share worked when run locally and failed in the shipped build.
void main() {
  final profiles = {
    'Release': File('macos/Runner/Release.entitlements'),
    'DebugProfile': File('macos/Runner/DebugProfile.entitlements'),
  };

  /// Capabilities every profile must grant, and the journey that needs each.
  const required = {
    'com.apple.security.device.audio-input': 'meeting recording',
    'com.apple.security.files.user-selected.read-write':
        'meeting export and notebook share write into a user-picked folder',
    'com.apple.security.network.client': 'model download',
    'com.apple.security.network.server': 'Backup and restore LAN share',
  };

  for (final entry in profiles.entries) {
    group('${entry.key}.entitlements', () {
      test('grants every capability a shipped journey depends on', () {
        final file = entry.value;
        expect(
          file.existsSync(),
          isTrue,
          reason:
              'Run from the app/ package root. Looked for '
              '${file.absolute.path}.',
        );
        final contents = file.readAsStringSync();

        for (final capability in required.entries) {
          expect(
            contents,
            contains('<key>${capability.key}</key>'),
            reason:
                'Missing ${capability.key}, which ${capability.value} needs. '
                'Under App Sandbox this fails silently at runtime rather '
                'than at build time.',
          );
        }
      });

      test('does not keep the read-only variant alongside read-write', () {
        // Both keys present is not an error to macOS, but it hides which one
        // the build is actually relying on.
        expect(
          entry.value.readAsStringSync(),
          isNot(contains('com.apple.security.files.user-selected.read-only')),
        );
      });
    });
  }
}
