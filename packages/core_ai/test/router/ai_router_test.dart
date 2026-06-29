import 'package:core_ai/core_ai.dart';
import 'package:core_ai/src/client/fake_llm_client.dart';
import 'package:core_ai/src/client/llm_client.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AIRouter local-only policy', () {
    test('local-only config disables cloud fallback by default', () {
      const config = AIRouterConfig.localOnly();

      expect(config.defaultStrategy, AIRoutingStrategy.onDeviceOnly);
      expect(config.autoFallback, isFalse);
      expect(config.isLocalOnly, isTrue);
    });

    test('policy converts into local-only router config', () {
      const policy = LocalOnlyAiPolicy(onDeviceMaxPromptLength: 2048);
      final config = policy.toRouterConfig();

      expect(config.defaultStrategy, AIRoutingStrategy.onDeviceOnly);
      expect(config.onDeviceMaxPromptLength, 2048);
      expect(config.autoFallback, isFalse);
    });

    test(
      'never invokes cloud generation when local-only policy is active',
      () async {
        final onDevice = FakeLLMClient(simulateError: true);
        final cloud = FakeLLMClient(defaultResponse: 'cloud response');
        final router = AIRouter(
          onDeviceClient: onDevice,
          cloudClient: cloud,
          config: const AIRouterConfig.localOnly(),
        );

        final result = await router.generateText('hello');

        expect(result.isErr, isTrue);
        expect(onDevice.generateTextCalls, ['hello']);
        expect(cloud.generateTextCalls, isEmpty);
        expect(result.getErrorOrNull(), isA<UnknownError>());
      },
    );

    test(
      'returns a local-only capability error when no on-device model is available',
      () async {
        final onDevice = FakeLLMClient(simulateUnavailable: true);
        final cloud = FakeLLMClient(defaultResponse: 'cloud response');
        final router = AIRouter(
          onDeviceClient: onDevice,
          cloudClient: cloud,
          config: const AIRouterConfig.localOnly(),
        );

        final result = await router.generateText('hello');

        expect(result.isErr, isTrue);
        expect(onDevice.generateTextCalls, isEmpty);
        expect(cloud.generateTextCalls, isEmpty);
        expect(
          (result.getErrorOrNull() as AIError).message,
          'Local-only AI is active, but no on-device model is available.',
        );
      },
    );

    test('chat never invokes cloud when local-only policy is active', () async {
      final onDevice = FakeLLMClient(simulateUnavailable: true);
      final cloud = FakeLLMClient(defaultResponse: 'cloud response');
      final router = AIRouter(
        onDeviceClient: onDevice,
        cloudClient: cloud,
        config: const AIRouterConfig.localOnly(),
      );

      final result = await router.chat([ChatMessage.user('hello')]);

      expect(result.isErr, isTrue);
      expect(onDevice.chatCalls, isEmpty);
      expect(cloud.chatCalls, isEmpty);
      expect(
        (result.getErrorOrNull() as AIError).message,
        'Local-only AI is active, but no on-device model is available.',
      );
    });

    test(
      'on-device-only routing still avoids cloud fallback even if autoFallback is true',
      () async {
        final onDevice = FakeLLMClient(simulateError: true);
        final cloud = FakeLLMClient(defaultResponse: 'cloud response');
        final router = AIRouter(
          onDeviceClient: onDevice,
          cloudClient: cloud,
          config: const AIRouterConfig(
            defaultStrategy: AIRoutingStrategy.onDeviceOnly,
            autoFallback: true,
          ),
        );

        final result = await router.generateText('hello');

        expect(result.isErr, isTrue);
        expect(onDevice.generateTextCalls, ['hello']);
        expect(cloud.generateTextCalls, isEmpty);
      },
    );
  });
}
