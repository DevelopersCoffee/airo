import 'package:core_ai/core_ai.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GeminiNanoClient', () {
    test(
      'warmup initializes the client and invokes the native warmup hook',
      () async {
        const channel = MethodChannel('test.gemini_nano');
        final calls = <MethodCall>[];

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              calls.add(call);
              return switch (call.method) {
                'initialize' => true,
                'warmup' => true,
                'isAvailable' => true,
                _ => null,
              };
            });
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, null);
        });

        final client = GeminiNanoClient(channel: channel);

        final warmed = await client.warmup();

        expect(warmed, isTrue);
        expect(
          calls.map((call) => call.method),
          containsAllInOrder(<String>['initialize', 'warmup']),
        );
      },
    );

    test('warmup returns false when the native hook throws', () async {
      const channel = MethodChannel('test.gemini_nano.error');

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            return switch (call.method) {
              'initialize' => true,
              'warmup' => throw PlatformException(
                code: 'WARMUP_FAILED',
                message: 'boom',
              ),
              _ => null,
            };
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      final client = GeminiNanoClient(channel: channel);

      expect(await client.warmup(), isFalse);
    });
  });
}
