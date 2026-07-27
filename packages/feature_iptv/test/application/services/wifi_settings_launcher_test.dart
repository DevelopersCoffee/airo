import 'package:feature_iptv/application/services/wifi_settings_launcher.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.airo/device_info');

  Future<void> mockChannel(
    Future<Object?> Function(MethodCall call)? handler,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, handler);
  }

  tearDown(() => mockChannel(null));

  test('isSupported is false when not Android', () {
    final launcher = WifiSettingsLauncher(isAndroid: () => false);
    expect(launcher.isSupported, isFalse);
  });

  test(
    'open() returns false without invoking the channel when unsupported',
    () async {
      var invoked = false;
      await mockChannel((call) async {
        invoked = true;
        return {'opened': true};
      });
      final launcher = WifiSettingsLauncher(isAndroid: () => false);

      expect(await launcher.open(), isFalse);
      expect(invoked, isFalse);
    },
  );

  test('open() returns true when the native side reports opened', () async {
    await mockChannel((call) async {
      expect(call.method, 'openWifiSettings');
      return {'opened': true};
    });
    final launcher = WifiSettingsLauncher(isAndroid: () => true);

    expect(await launcher.open(), isTrue);
  });

  test(
    'open() returns false when the native side reports not opened',
    () async {
      await mockChannel((call) async => {'opened': false});
      final launcher = WifiSettingsLauncher(isAndroid: () => true);

      expect(await launcher.open(), isFalse);
    },
  );

  test('open() returns false on a platform exception', () async {
    await mockChannel((call) async => throw PlatformException(code: 'error'));
    final launcher = WifiSettingsLauncher(isAndroid: () => true);

    expect(await launcher.open(), isFalse);
  });

  test('open() returns false when the plugin is not registered', () async {
    await mockChannel(null);
    final launcher = WifiSettingsLauncher(isAndroid: () => true);

    expect(await launcher.open(), isFalse);
  });
}
