import 'package:core_ai/src/client/fake_llm_client.dart';
import 'package:core_ai/src/client/llm_client.dart';
import 'package:core_ai/src/provider/ai_provider.dart';
import 'package:core_ai/src/router/ai_router.dart';
import 'package:core_domain/core_domain.dart';
import 'package:core_ai/src/router/model_health_checker.dart';
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

  group('AIRouter', () {
    test('offlinePreferred uses on-device when healthy', () async {
      final local = FakeLLMClient(defaultResponse: 'local');
      final cloud = FakeLLMClient(defaultResponse: 'cloud');
      final router = AIRouter(
        onDeviceClient: local,
        cloudClient: cloud,
        config: const AIRouterConfig(
          defaultStrategy: AIRoutingStrategy.offlinePreferred,
        ),
      );

      final result = await router.generateText('hi');

      expect(result.getOrNull()?.content, 'local');
      expect(local.generateTextCalls, ['hi']);
      expect(cloud.generateTextCalls, isEmpty);
    });

    test('specificModel prefers cloud when requested', () async {
      final local = FakeLLMClient(defaultResponse: 'local');
      final cloud = FakeLLMClient(defaultResponse: 'cloud');
      final router = AIRouter(
        onDeviceClient: local,
        cloudClient: cloud,
        config: const AIRouterConfig(
          defaultStrategy: AIRoutingStrategy.specificModel,
          specificModel: AIProvider.cloud,
        ),
      );

      final result = await router.generateText('hi');

      expect(result.getOrNull()?.content, 'cloud');
      expect(cloud.generateTextCalls, ['hi']);
      expect(local.generateTextCalls, isEmpty);
    });

    test('falls back to cloud when the preferred client errors', () async {
      final local = FakeLLMClient(
        defaultResponse: 'local',
        simulateError: true,
      );
      final cloud = FakeLLMClient(defaultResponse: 'cloud');
      final router = AIRouter(
        onDeviceClient: local,
        cloudClient: cloud,
        config: const AIRouterConfig(
          defaultStrategy: AIRoutingStrategy.offlinePreferred,
          autoFallback: true,
        ),
      );

      final result = await router.generateText('hello');

      expect(result.getOrNull()?.content, 'cloud');
      expect(local.generateTextCalls, ['hello']);
      expect(cloud.generateTextCalls, ['hello']);
    });
  });

  group('ModelHealthChecker', () {
    test('reports unavailable clients as unhealthy', () async {
      final checker = const ModelHealthChecker();
      final client = FakeLLMClient(simulateUnavailable: true);

      final health = await checker.check(AIProvider.nano, client);

      expect(health.isHealthy, isFalse);
      expect(health.reason, 'Client unavailable');
    });
  });
}
