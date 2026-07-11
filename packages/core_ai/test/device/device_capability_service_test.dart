import 'package:core_ai/core_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.airo.gemini_nano');

  late DeviceCapabilityService service;
  late DebugPrintCallback originalDebugPrint;
  late List<String> debugLogs;

  setUp(() {
    service = DeviceCapabilityService();
    service.clearCache();
    debugLogs = <String>[];
    originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) {
        debugLogs.add(message);
      }
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  tearDown(() {
    service.clearCache();
    debugPrint = originalDebugPrint;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('DeviceCapabilityService', () {
    test('suppresses known binding initialization errors', () {
      expect(
        DeviceCapabilityService.shouldSuppressPlatformChannelErrorLog(
          StateError(
            'Binding has not yet been initialized.\n'
            'Call WidgetsFlutterBinding.ensureInitialized() first.',
          ),
        ),
        isTrue,
      );
      expect(
        DeviceCapabilityService.shouldSuppressPlatformChannelErrorLog(
          StateError(
            'ServicesBinding.defaultBinaryMessenger was accessed before the '
            'binding was initialized.',
          ),
        ),
        isTrue,
      );
    });

    test('does not suppress unrelated platform channel failures', () {
      expect(
        DeviceCapabilityService.shouldSuppressPlatformChannelErrorLog(
          PlatformException(code: 'boom', message: 'native failure'),
        ),
        isFalse,
      );
    });

    test(
      'logs unexpected memory lookup failures and returns unknown memory',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (_) async {
              throw PlatformException(code: 'boom', message: 'native failure');
            });

        final memoryInfo = await service.getMemoryInfo(forceRefresh: true);

        expect(memoryInfo.isAvailable, isFalse);
        expect(
          debugLogs,
          contains(
            'Error getting memory info: PlatformException(boom, native failure, null, null)',
          ),
        );
      },
    );
  });
}
