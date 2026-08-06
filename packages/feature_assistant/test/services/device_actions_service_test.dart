import 'package:feature_assistant/src/services/device_actions_service.dart';
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

  test('forwards supported Mobile Actions with typed arguments', () async {
    const channel = MethodChannel('test.device-actions.typed');
    final calls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return switch (call.method) {
        'setFlashlight' => const {'changed': true},
        'composeEmail' ||
        'createContact' ||
        'openMap' => const {'opened': true},
        _ => fail('Unexpected method call: ${call.method}'),
      };
    });

    final service = DeviceActionsService(channel: channel);
    expect(await service.setFlashlight(enabled: true), isTrue);
    expect(
      await service.composeEmail(to: 'airo@example.com', subject: 'Hello'),
      isTrue,
    );
    expect(await service.createContact(name: 'Airo', phone: '123'), isTrue);
    expect(await service.openMap(query: 'Airo HQ'), isTrue);
    expect(calls.map((call) => call.method), [
      'setFlashlight',
      'composeEmail',
      'createContact',
      'openMap',
    ]);
    expect(calls.first.arguments, {'enabled': true});
  });
}
