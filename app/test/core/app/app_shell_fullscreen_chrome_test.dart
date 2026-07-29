import 'package:airo_app/core/app/app_shell.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('leaving fullscreen restores the system-default orientation instead of '
      'forcing portrait, so tablets and foldables already in landscape are not '
      'rotated out of it', () async {
    final orientationCalls = <List<Object?>>[];
    final uiModeCalls = <Object?>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      switch (call.method) {
        case 'SystemChrome.setPreferredOrientations':
          orientationCalls.add(call.arguments as List<Object?>);
        case 'SystemChrome.setEnabledSystemUIMode':
          uiModeCalls.add(call.arguments);
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );

    restoreChromeAfterFullscreen();
    await Future<void>.delayed(Duration.zero);

    expect(
      orientationCalls,
      [<Object?>[]],
      reason:
          'an empty orientation list hands control back to the OS; a '
          'portraitUp entry would pin tablets to portrait',
    );
    expect(uiModeCalls, ['SystemUiMode.edgeToEdge']);
  });
}
