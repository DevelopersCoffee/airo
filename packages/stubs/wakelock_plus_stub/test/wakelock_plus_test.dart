import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('io.airo.tv/wakelock');
  final calls = <MethodCall>[];
  var enabled = false;

  setUp(() {
    calls.clear();
    enabled = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'toggle') {
            enabled = call.arguments as bool;
            return null;
          }
          if (call.method == 'enabled') return enabled;
          throw MissingPluginException();
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('forwards enable, status, and disable to the Android channel', () async {
    await WakelockPlus.enable();
    expect(await WakelockPlus.enabled, isTrue);
    await WakelockPlus.disable();
    expect(await WakelockPlus.enabled, isFalse);

    expect(calls.map((call) => call.method), [
      'toggle',
      'enabled',
      'toggle',
      'enabled',
    ]);
    expect(calls.map((call) => call.arguments), [true, null, false, null]);
  });
}
