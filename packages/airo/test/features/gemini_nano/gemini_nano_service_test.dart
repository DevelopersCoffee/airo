import 'package:airo/airo.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.airo.gemini_nano');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
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

      final warmed = await GeminiNanoService.instance.warmup();

      expect(warmed, isTrue);
      expect(calls.map((call) => call.method), ['warmup']);
    },
  );
}
