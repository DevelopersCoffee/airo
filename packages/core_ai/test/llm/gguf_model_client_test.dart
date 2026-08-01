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

    test(
      'isAvailable should be false without a native llama.cpp backend',
      () async {
        final available = await client.isAvailable();
        expect(available, false);
      },
    );

    test(
      'isAvailable remains false when only a model artifact is present',
      () async {
        await client.ensureLoaded();
        final available = await client.isAvailable();
        expect(available, false);
      },
    );

    test('ensureLoaded reports the missing native backend', () async {
      final result = await client.ensureLoaded();
      expect(result, isA<Err<ActiveModelInfo>>());
      expect(result.getErrorOrNull().toString(), contains('llama.cpp'));
      expect(activeModelService.hasActiveModel, false);
    });

    test(
      'generate reports the missing native backend instead of fake text',
      () async {
        final result = await client.generate('Test prompt');
        expect(result, isA<Err<LLMResponse>>());
        expect(result.getErrorOrNull().toString(), contains('llama.cpp'));
      },
    );

    test('generate does not fabricate performance metrics', () async {
      await client.generate('Test prompt');
      expect(activeModelService.activeModel, isNull);
    });

    test('generateStream reports the missing native backend', () async {
      final tokens = <String>[];

      await for (final token in client.generateStream('Test prompt')) {
        tokens.add(token);
      }

      expect(tokens, hasLength(1));
      expect(tokens.single, contains('llama.cpp'));
    });

    test('estimateTokens should return reasonable estimate', () {
      final tokens = client.estimateTokens('Hello world this is a test');
      expect(tokens, greaterThan(0));
      expect(tokens, lessThan(100));
    });

    test('unloadModel remains safe when no native model is loaded', () async {
      await client.unloadModel();
      expect(activeModelService.hasActiveModel, false);
    });

    test('dispose does not create or unload a fake local model', () async {
      await client.dispose();
      expect(activeModelService.hasActiveModel, false);
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

  test(
    'exposes remote diagnostics without claiming local model readiness',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      server.listen((request) async {
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'data': [
                {'id': 'remote-qwen'},
              ],
            }),
          );
        await request.response.close();
      });

      final remote = GGUFModelClient(
        modelConfig: GGUFModelConfig(
          modelPath: '',
          modelName: 'remote-qwen',
          serverUrl: 'http://127.0.0.1:${server.port}',
        ),
        activeModelService: activeModelService,
      );

      final diagnostics = await remote.diagnoseRemoteServer();
      expect(diagnostics?.isReady, isTrue);
      expect(diagnostics?.modelIds, ['remote-qwen']);
      expect(
        (await remote.ensureLoaded()).getErrorOrNull().toString(),
        contains('do not load'),
      );
    },
  );
}
