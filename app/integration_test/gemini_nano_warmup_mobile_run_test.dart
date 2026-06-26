import 'package:airo_app/core/services/gemini_nano_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.airo.gemini_nano');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  testWidgets(
    'mobile run pre-warms Gemini Nano after support check and initialization',
    (_) async {
      final calls = <String>[];

      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        return switch (call.method) {
          'isAvailable' => true,
          'initialize' => true,
          'warmup' => true,
          _ => fail('Unexpected Gemini Nano method call: ${call.method}'),
        };
      });

      final service = GeminiNanoService();
      final isSupported = await service.isSupported();
      final initialized = isSupported && await service.initialize();
      final warmed = initialized && await service.warmup();

      expect(isSupported, isTrue);
      expect(initialized, isTrue);
      expect(warmed, isTrue);
      expect(calls, ['isAvailable', 'isAvailable', 'initialize', 'warmup']);
    },
  );
}
