import 'package:core_app_shell/src/device_form_factor.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.airo/device_info');

  tearDown(() {
    DeviceFormFactorDetector.clearCache();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'detectIsDesktopWindowed reads the native isDesktopWindowed method and '
    'caches it for isDesktopWindowedSync',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'isDesktopWindowed');
            return true;
          });

      expect(DeviceFormFactorDetector.isDesktopWindowedSync(), isFalse);

      final result = await DeviceFormFactorDetector.detectIsDesktopWindowed();

      expect(result, isTrue);
      expect(DeviceFormFactorDetector.isDesktopWindowedSync(), isTrue);
    },
  );

  test(
    'detectIsDesktopWindowed defaults to false when the platform channel '
    'is not implemented',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (call) async => throw MissingPluginException(),
          );

      final result = await DeviceFormFactorDetector.detectIsDesktopWindowed();

      expect(result, isFalse);
      expect(DeviceFormFactorDetector.isDesktopWindowedSync(), isFalse);
    },
  );

  test('debug override short-circuits both the async and sync readers', () {
    DeviceFormFactorDetector.debugIsDesktopWindowedOverride = true;

    expect(DeviceFormFactorDetector.isDesktopWindowedSync(), isTrue);
  });

  test('clearCache resets the cached value and both debug overrides', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => true);
    await DeviceFormFactorDetector.detectIsDesktopWindowed();
    expect(DeviceFormFactorDetector.isDesktopWindowedSync(), isTrue);

    DeviceFormFactorDetector.clearCache();

    expect(DeviceFormFactorDetector.isDesktopWindowedSync(), isFalse);
  });
}
