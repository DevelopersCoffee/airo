import 'package:airo_app/core/services/device_actions_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('opens Wi-Fi settings through the platform action channel', () async {
    const channel = MethodChannel('test.device-actions');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => call.method == 'openWifiSettings'
          ? const {'opened': true}
          : fail('Unexpected method call: ${call.method}'),
    );

    expect(
      await DeviceActionsService(channel: channel).openWifiSettings(),
      isTrue,
    );
  });

  test('reports unavailable platform actions without throwing', () async {
    const channel = MethodChannel('test.device-actions.failure');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    messenger.setMockMethodCallHandler(
      channel,
      (_) => throw PlatformException(code: 'UNAVAILABLE'),
    );

    expect(
      await DeviceActionsService(channel: channel).openWifiSettings(),
      isFalse,
    );
  });
}
