@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `app/android/app/build.gradle.kts` points the `main` source set at
/// `src/mind/AndroidManifest.xml` when `APP_VARIANT=mind`. That **replaces**
/// `src/main/AndroidManifest.xml` rather than merging with it, so anything the
/// full app declares and Mind still needs has to be restated here — and
/// nothing warns when it is not.
///
/// That is how scheduled agent notifications came to be silently dead on
/// Android: `zonedSchedule` succeeded, and the notification never arrived,
/// because neither `flutter_local_notifications` receiver was declared (the
/// plugin's own AAR manifest declares only VIBRATE and POST_NOTIFICATIONS).
///
/// CI builds no Mind APK, so no Gradle manifest merge ever runs against this
/// file. This test is the only thing standing in for that.
void main() {
  late String manifest;

  /// Comment-free copy: the header comment names the IPTV deep links it
  /// deliberately drops, which a naive substring check would read as a
  /// declaration.
  late String declarations;

  setUpAll(() {
    final file = File('android/app/src/mind/AndroidManifest.xml');
    expect(
      file.existsSync(),
      isTrue,
      reason:
          'Run from the app/ package root. Looked for ${file.absolute.path}.',
    );
    manifest = file.readAsStringSync();
    declarations = manifest.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
  });

  /// Declarations Mind's own code depends on, and what silently breaks
  /// without each. Deliberately curated rather than diffed against
  /// `src/main`: Mind drops the IPTV deep links and picture-in-picture on
  /// purpose, so a blanket comparison would be noise.
  const required = {
    'com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver':
        'scheduled agent notifications fire',
    'com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver':
        'scheduled notifications survive a reboot',
    'android.permission.RECEIVE_BOOT_COMPLETED':
        'the boot receiver is allowed to run',
    'android.permission.RECORD_AUDIO': 'meeting capture can open the mic',
    'android.permission.FOREGROUND_SERVICE_MICROPHONE':
        'the capture service starts on Android 14+',
    'android.permission.POST_NOTIFICATIONS':
        'the recording notification can be shown',
    '.MeetingRecordingService': 'capture survives backgrounding',
  };

  test('declares everything Mind depends on', () {
    for (final entry in required.entries) {
      expect(
        manifest,
        contains(entry.key),
        reason:
            'Missing ${entry.key}, without which ${entry.value}. This manifest '
            'replaces src/main, so the declaration must be restated here.',
      );
    }
  });

  test('keeps Auto Backup off', () {
    // Airo Mind's claim is that meetings and the vault stay on the device.
    // Auto Backup would copy that database to the user's Google Drive.
    expect(
      manifest,
      contains('android:allowBackup="false"'),
      reason:
          'Auto Backup would upload on-device meeting data to Google Drive, '
          'contradicting the product promise. Explicit transfer already '
          'exists in Settings -> Backup and restore.',
    );
  });

  test('does not let optional hardware filter the Play listing', () {
    // CAMERA is only used for bug-report attachments, which fall back to the
    // gallery. Declaring the permission without the feature opt-out makes
    // Play treat a camera as required.
    expect(
      manifest,
      contains('android:name="android.hardware.camera"'),
      reason:
          'CAMERA is declared, so android.hardware.camera must be declared '
          'android:required="false" or Play hides Mind from camera-less '
          'devices.',
    );
    expect(manifest, contains('android:required="false"'));
  });

  test('does not claim the IPTV deep links', () {
    // The reason this variant manifest exists at all.
    expect(declarations, isNot(contains('airo://iptv')));
    expect(declarations, isNot(contains('/airo/iptv')));
    expect(declarations, isNot(contains('supportsPictureInPicture')));
  });
}
