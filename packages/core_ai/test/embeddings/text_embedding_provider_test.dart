import 'package:core_ai/core_ai.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TextEmbeddingModelDescriptor', () {
    test('normalizes safe identity fields and exposes stable metadata', () {
      final descriptor = TextEmbeddingModelDescriptor(
        modelId: ' sentence-transformers/all-MiniLM-L6-v2 ',
        revision: ' 1110a243 ',
        dimensions: 384,
        sha256: ' ${_repeat('ABCDEF0123456789', 4)} ',
      );

      expect(descriptor.modelId, 'sentence-transformers/all-MiniLM-L6-v2');
      expect(descriptor.revision, '1110a243');
      expect(descriptor.dimensions, 384);
      expect(descriptor.sha256, _repeat('abcdef0123456789', 4));
      expect(descriptor.toJson(), {
        'modelId': 'sentence-transformers/all-MiniLM-L6-v2',
        'revision': '1110a243',
        'dimensions': 384,
        'sha256': _repeat('abcdef0123456789', 4),
      });
    });

    test(
      'rejects blank identity unsupported dimensions and invalid hashes',
      () {
        expect(
          () => TextEmbeddingModelDescriptor(
            modelId: ' ',
            revision: 'revision',
            dimensions: 384,
            sha256: _repeat('a', 64),
          ),
          throwsArgumentError,
        );
        expect(
          () => TextEmbeddingModelDescriptor(
            modelId: 'model',
            revision: ' ',
            dimensions: 384,
            sha256: _repeat('a', 64),
          ),
          throwsArgumentError,
        );
        expect(
          () => TextEmbeddingModelDescriptor(
            modelId: 'model',
            revision: 'revision',
            dimensions: 512,
            sha256: _repeat('a', 64),
          ),
          throwsArgumentError,
        );
        for (final invalidHash in [
          _repeat('a', 63),
          _repeat('g', 64),
          'model-path.tflite',
        ]) {
          expect(
            () => TextEmbeddingModelDescriptor(
              modelId: 'model',
              revision: 'revision',
              dimensions: 384,
              sha256: invalidHash,
            ),
            throwsArgumentError,
          );
        }
      },
    );
  });

  group('TextEmbeddingSuccess', () {
    test('snapshots float32 values and exposes an immutable vector', () {
      final descriptor = _descriptor();
      final callerValues = _vector(384, {0: 1, 1: 0.25});

      final outcome = TextEmbeddingSuccess(
        model: descriptor,
        values: callerValues,
      );
      callerValues[0] = -1;

      expect(outcome.model, same(descriptor));
      expect(outcome.values[0], 1);
      expect(outcome.values[1], 0.25);
      expect(outcome.values, hasLength(384));
      expect(() => outcome.values[0] = 2, throwsUnsupportedError);
      expect(outcome.toString(), isNot(contains('0.25')));
    });

    test('rejects malformed non-finite and zero vectors', () {
      final descriptor = _descriptor();

      expect(
        () => TextEmbeddingSuccess(
          model: descriptor,
          values: _vector(383, {0: 1}),
        ),
        throwsArgumentError,
      );
      for (final invalid in [double.nan, double.infinity, double.maxFinite]) {
        expect(
          () => TextEmbeddingSuccess(
            model: descriptor,
            values: _vector(384, {0: invalid}),
          ),
          throwsArgumentError,
        );
      }
      expect(
        () => TextEmbeddingSuccess(
          model: descriptor,
          values: _vector(384, const {}),
        ),
        throwsArgumentError,
      );
    });
  });

  group('TextEmbeddingFailure', () {
    test('uses stable redacted codes for every provider failure', () {
      expect(TextEmbeddingFailureCode.values.map((code) => code.stableId), [
        'platform_unavailable',
        'model_missing',
        'model_integrity_mismatch',
        'unsupported_dimensions',
        'invalid_input',
        'initialization_failed',
        'inference_failed',
        'cancelled',
        'provider_closed',
      ]);

      const failure = TextEmbeddingFailure(
        code: TextEmbeddingFailureCode.modelIntegrityMismatch,
      );
      expect(failure.toJson(), {
        'status': 'failure',
        'code': 'model_integrity_mismatch',
      });
      expect(failure.toString(), isNot(contains('/')));
    });

    test('provider interface returns only typed outcomes', () async {
      final provider = _FakeProvider(
        model: _descriptor(),
        outcome: const TextEmbeddingFailure(
          code: TextEmbeddingFailureCode.platformUnavailable,
        ),
      );

      final outcome = await provider.embed('synthetic fixture');
      await provider.close();

      expect(outcome, isA<TextEmbeddingFailure>());
      expect(provider.closed, isTrue);
    });
  });
}

TextEmbeddingModelDescriptor _descriptor() {
  return TextEmbeddingModelDescriptor(
    modelId: 'sentence-transformers/all-MiniLM-L6-v2',
    revision: '1110a243',
    dimensions: 384,
    sha256: _repeat('a', 64),
  );
}

String _repeat(String value, int count) => List.filled(count, value).join();

List<double> _vector(int dimensions, Map<int, double> values) {
  return [
    for (var index = 0; index < dimensions; index += 1) values[index] ?? 0,
  ];
}

class _FakeProvider implements LocalTextEmbeddingProvider {
  _FakeProvider({required this.model, required this.outcome});

  @override
  final TextEmbeddingModelDescriptor model;

  final TextEmbeddingOutcome outcome;
  bool closed = false;

  @override
  Future<TextEmbeddingOutcome> embed(String text) async => outcome;

  @override
  Future<void> close() async {
    closed = true;
  }
}
