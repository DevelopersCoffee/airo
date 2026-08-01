import 'package:airo_app/core/ai/ai_router_service.dart';
import 'package:core_ai/core_ai.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const nanoChannel = MethodChannel('com.airo.gemini_nano');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(nanoChannel, null);
    final router = AIRouterService();
    router
      ..setProvider(AIProvider.auto)
      ..configureRemoteServer(baseUrl: '', model: '');
  });

  test(
    'remote diagnostics stay null when no remote server is configured',
    () async {
      final router = AIRouterService()
        ..configureRemoteServer(baseUrl: '   ', model: 'local-model');

      expect(router.hasRemoteServer, isFalse);
      await expectLater(router.diagnoseRemoteServer(), completion(isNull));
      expect(router.getAllProviderStatuses(), isEmpty);
    },
  );

  test('availability records unavailable Nano and cloud states', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(nanoChannel, (call) async {
          if (call.method == 'isAvailable') return false;
          return null;
        });
    final router = AIRouterService();

    await router.checkAvailability();

    final statuses = router.getAllProviderStatuses();
    expect(statuses[AIProvider.nano]?.isAvailable, isFalse);
    expect(statuses[AIProvider.cloud]?.isAvailable, isFalse);
    expect(router.getProviderStatus(AIProvider.nano), isNotNull);
    expect(router.getBestProvider(), AIProvider.cloud);
  });

  test(
    'explicit unavailable local providers do not silently use cloud',
    () async {
      final router = AIRouterService();
      router.setProvider(AIProvider.gguf);

      expect(router.getBestProvider(), AIProvider.gguf);
      final response = await router.processQuery('hello');

      expect(response, contains('native local runtime is unavailable'));
      expect(response, contains('OpenAI-compatible'));

      router.setProvider(AIProvider.auto);
    },
  );

  test(
    'explicit local provider streams an actionable unavailable result',
    () async {
      final router = AIRouterService();
      router.setProvider(AIProvider.gemma);

      final values = await router.processQueryStream('hello').toList();
      expect(values.single, contains('native local runtime is unavailable'));

      router.setProvider(AIProvider.auto);
    },
  );

  test(
    'cloud fallback includes context and streams accumulated words',
    () async {
      final router = AIRouterService()..setProvider(AIProvider.cloud);

      final response = await router.processQuery(
        'hello',
        fileContext: 'private context',
        systemPrompt: 'system',
      );
      final chunks = await router
          .processQueryStream(
            'hello',
            fileContext: 'private context',
            systemPrompt: 'system',
          )
          .toList();

      expect(response, contains('Gemini Cloud is unavailable'));
      expect(chunks, isNotEmpty);
      expect(chunks.last, response);
    },
  );
}
