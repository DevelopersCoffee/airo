import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_player/platform_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.airo.player/background_audio_mode');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    AiroBackgroundAudioMode.debugSetMethodChannel(channel);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('setEnabled(true) invokes platform and updates isEnabled', () async {
    await AiroBackgroundAudioMode.setEnabled(true);
    expect(calls.single.method, 'setEnabled');
    expect(calls.single.arguments, {'enabled': true});
    expect(AiroBackgroundAudioMode.isEnabled, isTrue);
  });

  test('setEnabled(false) invokes platform and updates isEnabled', () async {
    await AiroBackgroundAudioMode.setEnabled(true);
    await AiroBackgroundAudioMode.setEnabled(false);
    expect(calls.last.arguments, {'enabled': false});
    expect(AiroBackgroundAudioMode.isEnabled, isFalse);
  });

  test('setEnabled swallows MissingPluginException', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          throw MissingPluginException();
        });
    await AiroBackgroundAudioMode.setEnabled(true);
    // Local state still reflects intent even if the platform call failed,
    // so UI toggles remain consistent with what the user asked for.
    expect(AiroBackgroundAudioMode.isEnabled, isTrue);
  });
}
