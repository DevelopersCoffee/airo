import 'package:airo_app/core/services/gemini_nano_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.airo.gemini_nano');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test(
    'warmup delegates to the native Gemini Nano warmup channel method',
    () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return switch (call.method) {
          'warmup' => true,
          _ => fail('Unexpected method call: ${call.method}'),
        };
      });

      final warmed = await GeminiNanoService().warmup();

      expect(warmed, isTrue);
      expect(calls.map((call) => call.method), ['warmup']);
    },
  );

  test(
    'warmup returns false instead of throwing when native warmup fails',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        return switch (call.method) {
          'warmup' => throw PlatformException(
            code: 'WARMUP_FAILED',
            message: 'synthetic failure',
          ),
          _ => fail('Unexpected method call: ${call.method}'),
        };
      });

      final warmed = await GeminiNanoService().warmup();

      expect(warmed, isFalse);
    },
  );
}
