import 'package:airo_app/core/ai/ai_router_service.dart';
import 'package:core_ai/core_ai.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
}
