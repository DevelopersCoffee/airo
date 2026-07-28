import 'package:core_ai/core_ai.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_text_embeddings/platform_text_embeddings.dart';

void main() {
  group('MediaPipeTextEmbeddingProvider.open', () {
    test(
      'returns unavailable without invoking an unsupported platform',
      () async {
        final client = _FakeClient();

        final result = await MediaPipeTextEmbeddingProvider.open(
          modelPath: '/private/model.tflite',
          model: _descriptor(),
          client: client,
          isAndroid: false,
        );

        expect(result, isA<TextEmbeddingProviderOpenFailure>());
        expect(
          (result as TextEmbeddingProviderOpenFailure).failure.code,
          TextEmbeddingFailureCode.platformUnavailable,
        );
        expect(client.invocations, isEmpty);
        expect(result.toString(), isNot(contains('/private/model.tflite')));
      },
    );

    test('maps a ready response to an opaque provider session', () async {
      final client = _FakeClient()
        ..responses['initialize'] = {
          'status': 'ready',
          'sessionId': 'session-1',
        };

      final result = await MediaPipeTextEmbeddingProvider.open(
        modelPath: '/private/model.tflite',
        model: _descriptor(),
        client: client,
        isAndroid: true,
      );

      expect(result, isA<TextEmbeddingProviderReady>());
      final provider = (result as TextEmbeddingProviderReady).provider;
      expect(provider.model, same(_lastDescriptor));
      expect(client.invocations.single.method, 'initialize');
      expect(client.invocations.single.arguments, {
        'modelPath': '/private/model.tflite',
        'model': _lastDescriptor.toJson(),
      });
      expect(result.toString(), isNot(contains('session-1')));
    });

    test('maps integrity failure without exposing platform details', () async {
      final client = _FakeClient()
        ..responses['initialize'] = {
          'status': 'failure',
          'code': 'model_integrity_mismatch',
          'details': '/private/model.tflite',
        };

      final result = await MediaPipeTextEmbeddingProvider.open(
        modelPath: '/private/model.tflite',
        model: _descriptor(),
        client: client,
        isAndroid: true,
      );

      expect(result, isA<TextEmbeddingProviderOpenFailure>());
      final failure = (result as TextEmbeddingProviderOpenFailure).failure;
      expect(failure.code, TextEmbeddingFailureCode.modelIntegrityMismatch);
      expect(result.toString(), isNot(contains('/private/model.tflite')));
    });
  });

  group('MediaPipeTextEmbeddingProvider lifecycle', () {
    test(
      'maps a finite embedding and never includes it in diagnostics',
      () async {
        final fixture = _vector(384, {0: 1, 1: 0.125});
        final client = _FakeClient()
          ..responses['initialize'] = {
            'status': 'ready',
            'sessionId': 'session-1',
          }
          ..responses['embed'] = {'status': 'success', 'values': fixture};
        final provider = await _open(client);

        final result = await provider.embed('synthetic fixture');

        expect(result, isA<TextEmbeddingSuccess>());
        expect((result as TextEmbeddingSuccess).values, hasLength(384));
        expect(client.invocations.last.arguments, {
          'sessionId': 'session-1',
          'text': 'synthetic fixture',
        });
        expect(result.toString(), isNot(contains('0.125')));
      },
    );

    test(
      'rejects blank and over-limit UTF-8 input before channel use',
      () async {
        final client = _FakeClient()
          ..responses['initialize'] = {
            'status': 'ready',
            'sessionId': 'session-1',
          };
        final provider = await _open(client);
        final invocationCount = client.invocations.length;

        final blank = await provider.embed(' \n ');
        final overLimit = await provider.embed(List.filled(25601, 'é').join());

        expect(
          (blank as TextEmbeddingFailure).code,
          TextEmbeddingFailureCode.invalidInput,
        );
        expect(
          (overLimit as TextEmbeddingFailure).code,
          TextEmbeddingFailureCode.invalidInput,
        );
        expect(client.invocations, hasLength(invocationCount));
      },
    );

    test(
      'maps unknown and thrown platform failures to redacted codes',
      () async {
        final client = _FakeClient()
          ..responses['initialize'] = {
            'status': 'ready',
            'sessionId': 'session-1',
          }
          ..responses['embed'] = {
            'status': 'failure',
            'code': 'future_private_code',
            'details': 'UNIQUE-CANARY',
          };
        final provider = await _open(client);

        final unknown = await provider.embed('UNIQUE-CANARY');
        client.errors['embed'] = StateError('UNIQUE-CANARY');
        final thrown = await provider.embed('UNIQUE-CANARY');

        expect(
          (unknown as TextEmbeddingFailure).code,
          TextEmbeddingFailureCode.inferenceFailed,
        );
        expect(
          (thrown as TextEmbeddingFailure).code,
          TextEmbeddingFailureCode.inferenceFailed,
        );
        expect(unknown.toString(), isNot(contains('UNIQUE-CANARY')));
        expect(thrown.toString(), isNot(contains('UNIQUE-CANARY')));
      },
    );

    test('close is idempotent and further embedding is rejected', () async {
      final client = _FakeClient()
        ..responses['initialize'] = {
          'status': 'ready',
          'sessionId': 'session-1',
        }
        ..responses['close'] = {'status': 'closed'};
      final provider = await _open(client);

      await provider.close();
      await provider.close();
      final afterClose = await provider.embed('synthetic fixture');

      expect(
        client.invocations.where((call) => call.method == 'close'),
        hasLength(1),
      );
      expect(
        (afterClose as TextEmbeddingFailure).code,
        TextEmbeddingFailureCode.providerClosed,
      );
    });
  });
}

late TextEmbeddingModelDescriptor _lastDescriptor;

TextEmbeddingModelDescriptor _descriptor() {
  _lastDescriptor = TextEmbeddingModelDescriptor(
    modelId: 'sentence-transformers/all-MiniLM-L6-v2',
    revision: '1110a243',
    dimensions: 384,
    sha256: List.filled(64, 'a').join(),
  );
  return _lastDescriptor;
}

Future<MediaPipeTextEmbeddingProvider> _open(_FakeClient client) async {
  final result = await MediaPipeTextEmbeddingProvider.open(
    modelPath: '/private/model.tflite',
    model: _descriptor(),
    client: client,
    isAndroid: true,
  );
  return (result as TextEmbeddingProviderReady).provider;
}

List<double> _vector(int dimensions, Map<int, double> values) {
  return [
    for (var index = 0; index < dimensions; index += 1) values[index] ?? 0,
  ];
}

final class _Invocation {
  const _Invocation(this.method, this.arguments);

  final String method;
  final Map<String, Object?> arguments;
}

final class _FakeClient implements TextEmbeddingPlatformClient {
  final responses = <String, Map<String, Object?>>{};
  final errors = <String, Object>{};
  final invocations = <_Invocation>[];

  @override
  Future<Map<String, Object?>> invoke(
    String method,
    Map<String, Object?> arguments,
  ) async {
    invocations.add(_Invocation(method, arguments));
    final error = errors[method];
    if (error != null) {
      throw error;
    }
    return responses[method] ?? const {'status': 'failure'};
  }
}
