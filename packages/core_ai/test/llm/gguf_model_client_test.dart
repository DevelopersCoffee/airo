import 'dart:convert';
import 'dart:io';

import 'package:core_ai/core_ai.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ActiveModelService activeModelService;
  late GGUFModelClient client;

  const testConfig = GGUFModelConfig(
    modelPath: '/path/to/model.gguf',
    modelName: 'Test Model',
    contextSize: 4096,
    temperature: 0.7,
    maxTokens: 1024,
  );

  setUp(() {
    ActiveModelService.resetInstance();
    activeModelService = ActiveModelService.forTesting();
    client = GGUFModelClient(
      modelConfig: testConfig,
      activeModelService: activeModelService,
    );
  });

  tearDown(() async {
    await client.dispose();
    await activeModelService.dispose();
    ActiveModelService.resetInstance();
  });

  group('GGUFModelClient', () {
    test('should have correct maxContextLength from config', () {
      expect(client.maxContextLength, 4096);
    });

    test('should expose modelConfig', () {
      expect(client.modelConfig.modelName, 'Test Model');
      expect(client.modelConfig.modelPath, '/path/to/model.gguf');
    });

    test('config should be derived from GGUFModelConfig', () {
      expect(client.config.modelName, 'Test Model');
      expect(client.config.temperature, 0.7);
      expect(client.config.maxOutputTokens, 1024);
    });

    test('isAvailable should return true when model path is set', () async {
      final available = await client.isAvailable();
      expect(available, true);
    });

    test('isAvailable should return true when model is loaded', () async {
      await client.ensureLoaded();
      final available = await client.isAvailable();
      expect(available, true);
    });

    test('ensureLoaded should load model', () async {
      final result = await client.ensureLoaded();
      expect(result, isA<Ok<ActiveModelInfo>>());
      expect(activeModelService.hasActiveModel, true);
    });

    test(
      'ensureLoaded should return existing model if already loaded',
      () async {
        await client.ensureLoaded();
        final loadedAt1 = activeModelService.activeModel!.loadedAt;

        // Small delay to ensure different timestamp if reloaded
        await Future.delayed(const Duration(milliseconds: 10));

        await client.ensureLoaded();
        final loadedAt2 = activeModelService.activeModel!.loadedAt;

        // Should be the same timestamp (not reloaded)
        expect(loadedAt1, loadedAt2);
      },
    );

    test('generate should return LLMResponse', () async {
      final result = await client.generate('Test prompt');

      expect(result, isA<Ok<LLMResponse>>());
      final response = (result as Ok<LLMResponse>).value;
      expect(response.text, contains('GGUF Model Response'));
      expect(response.provider, contains('gguf'));
      expect(response.promptTokens, greaterThan(0));
      expect(response.completionTokens, greaterThan(0));
      expect(response.latencyMs, greaterThan(0));
    });

    test('generate should update performance metrics', () async {
      await client.generate('Test prompt');

      expect(activeModelService.activeModel!.tokensPerSecond, isNotNull);
      expect(activeModelService.activeModel!.tokensPerSecond, greaterThan(0));
    });

    test('generateStream should yield tokens', () async {
      final tokens = <String>[];

      await for (final token in client.generateStream('Test prompt')) {
        tokens.add(token);
      }

      expect(tokens, isNotEmpty);
      expect(tokens.join(), contains('GGUF Streaming'));
    });

    test('estimateTokens should return reasonable estimate', () {
      final tokens = client.estimateTokens('Hello world this is a test');
      expect(tokens, greaterThan(0));
      expect(tokens, lessThan(100));
    });

    test('unloadModel should delegate to ActiveModelService', () async {
      await client.ensureLoaded();
      expect(activeModelService.hasActiveModel, true);

      await client.unloadModel();
      expect(activeModelService.hasActiveModel, false);
    });

    test('dispose should not unload model', () async {
      await client.ensureLoaded();
      await client.dispose();

      // Model should still be loaded (managed by ActiveModelService)
      expect(activeModelService.hasActiveModel, true);
    });
  });

  group('GGUFModelClient with custom LLMConfig', () {
    test('should use provided LLMConfig', () {
      final customConfig = LLMConfig(
        provider: 'custom-provider',
        modelName: 'Custom Name',
        temperature: 0.5,
        maxOutputTokens: 2048,
      );

      final customClient = GGUFModelClient(
        modelConfig: testConfig,
        llmConfig: customConfig,
        activeModelService: activeModelService,
      );

      expect(customClient.config.provider, 'custom-provider');
      expect(customClient.config.modelName, 'Custom Name');
      expect(customClient.config.temperature, 0.5);
    });
  });

  test(
    'routes configured GGUF server models through OpenAI compatibility',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      server.listen((request) async {
        request.response.headers.contentType = ContentType.json;
        if (request.uri.path.endsWith('/models')) {
          request.response
            ..statusCode = HttpStatus.ok
            ..write(
              jsonEncode({
                'data': [
                  {'id': 'remote-qwen'},
                ],
              }),
            );
        } else if (request.uri.path.endsWith('/chat/completions')) {
          request.response
            ..statusCode = HttpStatus.ok
            ..write(
              jsonEncode({
                'choices': [
                  {
                    'message': {'content': 'remote response'},
                    'finish_reason': 'stop',
                  },
                ],
              }),
            );
        } else {
          request.response.statusCode = HttpStatus.notFound;
        }
        await request.response.close();
      });

      final remote = GGUFModelClient(
        modelConfig: GGUFModelConfig(
          modelPath: '',
          modelName: 'remote-qwen',
          serverUrl: Uri(
            scheme: 'http',
            host: '127.0.0.1',
            port: server.port,
          ).toString(),
        ),
        activeModelService: activeModelService,
      );

      expect(await remote.isAvailable(), isTrue);
      final result = await remote.generate('hello');
      expect(result, isA<Ok<LLMResponse>>());
      expect((result as Ok<LLMResponse>).value.text, 'remote response');
    },
  );
}
