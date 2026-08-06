/// Guards the Firebase variant selection for the Airo Mind shell.
///
/// Gradle installs this flavour as `io.airo.app.mind`
/// (`app/android/app/build.gradle.kts`, `APP_VARIANT=mind`). Dart therefore has
/// to hand `Firebase.initializeApp` *that* client's options. Before
/// `AppVariant.mind` existed, `APP_VARIANT=mind` fell through
/// `currentVariant`'s `default:` arm to `AppVariant.full` and the shell
/// initialized as `io.airo.app` — a package/signature mismatch that surfaces
/// only on a real device, as `ApiException: 10 (DEVELOPER_ERROR)` the first
/// time someone taps Google Sign-In on the assistant's profile screen.
///
/// **This suite must run with `--dart-define=APP_VARIANT=mind`.** `APP_VARIANT`
/// is read through `String.fromEnvironment`, which is resolved at compile time,
/// so there is no way to vary it from inside a test. Running `test_mind/`
/// without the define is running the wrong build, and the first test below says
/// so rather than passing vacuously. Both CI jobs pass it.
library;

import 'package:airo_app/firebase_options.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const variant = String.fromEnvironment('APP_VARIANT');

  test('the suite is compiled as the mind flavour', () {
    expect(
      variant,
      'mind',
      reason:
          'test_mind/ must run with --dart-define=APP_VARIANT=mind; '
          'without it this suite exercises the phone flavour instead.',
    );
  });

  test('APP_VARIANT=mind selects the mind variant', () {
    expect(DefaultFirebaseOptions.currentVariant, AppVariant.mind);
  });

  test('the mind variant resolves to its own Android client', () {
    // currentPlatform is the same accessor main_mind.dart calls. On the test
    // host defaultTargetPlatform is android, so this walks the real
    // _getAndroidOptions() switch rather than a re-implementation of it.
    expect(
      DefaultFirebaseOptions.currentPlatform.appId,
      DefaultFirebaseOptions.androidMind.appId,
    );
  });

  test('the mind client is distinct from the super app and TV clients', () {
    // The bug this file exists for is silent reuse of another variant's appId,
    // which is invisible unless the values are actually different.
    expect(
      DefaultFirebaseOptions.androidMind.appId,
      isNot(DefaultFirebaseOptions.android.appId),
    );
    expect(
      DefaultFirebaseOptions.androidMind.appId,
      isNot(DefaultFirebaseOptions.androidTv.appId),
    );
  });

  test('placeholder mind options are reported as unconfigured', () {
    // The checked-in firebase_options.dart ships placeholders; real values
    // arrive from FIREBASE_OPTIONS_DART_B64. isConfigured is what stops
    // main_mind.dart calling Firebase.initializeApp with a placeholder appId,
    // which would crash natively before Dart could recover.
    final options = DefaultFirebaseOptions.androidMind;
    final isPlaceholder =
        options.appId.contains('YOUR_') || options.appId.contains('TODO');
    expect(
      DefaultFirebaseOptions.isConfigured(options),
      !isPlaceholder,
      reason:
          'isConfigured must track whether androidMind still holds a '
          'placeholder appId, in both directions.',
    );
  });
}
