@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The Dart↔Rust path contract, asserted against the Rust source itself.
///
/// Rust derives `STORE_PARENT_DIR` once, in
/// `airo_mind_whisper::api::meetings::initialize`, as
/// `dirname(config.store_path)`. Dart passes
/// `{applicationSupport}/airo_mind/meetings.log` as that store path, so the
/// shared root is `{applicationSupport}/airo_mind`.
///
/// Both Dart sides had resolved against plain application support instead —
/// one segment short. Nothing threw: the live fan-out WAV was written by Rust
/// somewhere Dart never looked, and the live-intelligence sidecar was written
/// by Dart somewhere Rust never read, so the setting was permanently inert.
///
/// A unit test cannot catch that (each side is self-consistent), so this
/// compares the two sources of truth directly.
void main() {
  File rustSource() {
    for (final candidate in [
      // From packages/feature_mind (package test run).
      '../../rust/airo_mind_whisper/src/api/meetings.rs',
      // From the repo root (melos / IDE run).
      'rust/airo_mind_whisper/src/api/meetings.rs',
    ]) {
      final file = File(candidate);
      if (file.existsSync()) return file;
    }
    fail(
      'Could not locate airo_mind_whisper meetings.rs from ${Directory.current.path}',
    );
  }

  test('Rust still derives its store parent from the store path', () {
    // If this changes shape, `mindStoreParentDirectory` needs rereading — the
    // whole contract rests on the parent being dirname(store_path).
    expect(
      rustSource().readAsStringSync(),
      contains('*lock(&STORE_PARENT_DIR) = PathBuf::from(&config.store_path)'),
      reason:
          'STORE_PARENT_DIR is no longer derived from config.store_path, so '
          'mind_store_paths.dart may now point somewhere Rust does not use.',
    );
  });

  test('Rust still joins mind_recordings under the store parent', () {
    expect(
      rustSource().readAsStringSync(),
      contains('.join("mind_recordings")'),
      reason:
          'live_fanout_path changed; nextLiveFanoutRecordingPath must follow.',
    );
  });

  test(
    'Rust still reads the live-intelligence sidecar from the store parent',
    () {
      expect(
        rustSource().readAsStringSync(),
        contains('parent.join("mind_live_intelligence_mode")'),
        reason:
            'persistLiveIntelligenceModeToNative writes this file; if Rust '
            'moved it, the setting goes silently inert again.',
      );
    },
  );

  test('Dart resolves both Rust-coupled paths through the store parent', () {
    // Anchored on each function's *declaration*, not its name: the name also
    // appears at call sites, and the bug lived in the body.
    const coupled = {
      'lib/src/capture/application/meeting_capture_providers.dart':
          'Future<String> nextLiveFanoutRecordingPath(String meetingId) async {',
      'lib/src/capture/application/live_capture_preferences.dart':
          'Future<void> persistLiveIntelligenceModeToNative(',
    };

    for (final entry in coupled.entries) {
      final file = File(entry.key).existsSync()
          ? File(entry.key)
          : File('packages/feature_mind/${entry.key}');
      expect(file.existsSync(), isTrue, reason: 'Missing ${entry.key}');

      final source = file.readAsStringSync();
      final start = source.indexOf(entry.value);
      expect(
        start,
        isNonNegative,
        reason: 'Declaration moved or was renamed in ${entry.key}.',
      );
      final body = source.substring(start, source.indexOf('\n}', start));

      expect(
        body,
        contains('mindStoreParentDirectory()'),
        reason:
            'This path must land under {applicationSupport}/airo_mind to '
            'match Rust STORE_PARENT_DIR.',
      );
      // The Dart-only .m4a and processing-queue paths still use plain
      // application support legitimately, so this is scoped to these bodies.
      expect(
        body,
        isNot(contains('getApplicationSupportDirectory()')),
        reason:
            'Resolving against plain application support is one segment short '
            'of the directory Rust uses, and fails silently.',
      );
    }
  });
}
