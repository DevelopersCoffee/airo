import 'dart:convert';
import 'dart:io';

import 'package:core_ai/core_ai.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizes a host-only URL and reports discovered models', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    server.listen((request) async {
      expect(request.uri.path, '/v1/models');
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode({
            'data': [
              {'id': 'qwen2.5-3b'},
            ],
          }),
        );
      await request.response.close();
    });

    final client = OpenAICompatibleClient(
      baseUrl: 'http://127.0.0.1:${server.port}',
      model: 'qwen2.5-3b',
    );
    final diagnostics = await client.diagnose();

    expect(diagnostics.health, RemoteServerHealth.ready);
    expect(diagnostics.isReady, isTrue);
    expect(diagnostics.modelIds, ['qwen2.5-3b']);
    expect(diagnostics.baseUrl, endsWith('/v1'));
  });

  test('explains a missing OpenAI-compatible endpoint', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    server.listen((request) async {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
    });

    final client = OpenAICompatibleClient(
      baseUrl: 'http://127.0.0.1:${server.port}',
      model: 'missing',
    );
    final diagnostics = await client.diagnose();

    expect(diagnostics.health, RemoteServerHealth.notFound);
    expect(diagnostics.statusCode, HttpStatus.notFound);
    expect(diagnostics.message, contains('/v1'));
    expect(await client.isAvailable(), isFalse);
  });

  test(
    'reports credential failures separately from network failures',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      server.listen((request) async {
        request.response.statusCode = HttpStatus.unauthorized;
        await request.response.close();
      });

      final client = OpenAICompatibleClient(
        baseUrl: 'http://127.0.0.1:${server.port}/v1',
        model: 'private-model',
        apiKey: 'bad-key',
      );
      final diagnostics = await client.diagnose();

      expect(diagnostics.health, RemoteServerHealth.unauthorized);
      expect(diagnostics.message, contains('API key'));
    },
  );

  test(
    'reports configured model missing from remote server model list',
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
                {'id': 'llama3.2'},
                {'id': 'qwen2.5:7b'},
              ],
            }),
          );
        await request.response.close();
      });

      final client = OpenAICompatibleClient(
        baseUrl: 'http://127.0.0.1:${server.port}/v1',
        model: 'missing-model',
      );
      final diagnostics = await client.diagnose();

      expect(diagnostics.health, RemoteServerHealth.modelMissing);
      expect(diagnostics.isReady, isFalse);
      expect(diagnostics.modelIds, ['llama3.2', 'qwen2.5:7b']);
      expect(diagnostics.message, contains('missing-model'));
      expect(await client.isAvailable(), isFalse);
    },
  );
}
