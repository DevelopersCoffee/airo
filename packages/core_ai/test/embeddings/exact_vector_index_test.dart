import 'dart:math' as math;

import 'package:core_ai/core_ai.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExactVectorIndex', () {
    for (final dimensions in [256, 384]) {
      test('matches scalar cosine reference for $dimensions dimensions', () {
        final records = [
          VectorRecord(
            id: 'alpha',
            vector: _vector(dimensions, {0: 1, 1: 0.25}),
          ),
          VectorRecord(id: 'beta', vector: _vector(dimensions, {0: 0.4, 1: 1})),
          VectorRecord(
            id: 'gamma',
            vector: _vector(dimensions, {0: -1, 1: 0.1}),
          ),
        ];
        final query = _vector(dimensions, {0: 0.8, 1: 0.6});
        final index = ExactVectorIndex(
          dimensions: dimensions,
          records: records,
        );

        final actual = index.search(query, topK: records.length);
        final expected =
            [
              for (final record in records)
                (id: record.id, score: _referenceCosine(record.vector, query)),
            ]..sort((left, right) {
              final scoreOrder = right.score.compareTo(left.score);
              return scoreOrder != 0 ? scoreOrder : left.id.compareTo(right.id);
            });

        expect(
          actual.map((result) => result.id),
          expected.map((result) => result.id),
        );
        for (var index = 0; index < actual.length; index += 1) {
          expect(actual[index].score, closeTo(expected[index].score, 1e-6));
        }
      });
    }

    test('uses stable ID ordering when cosine scores tie', () {
      final index = ExactVectorIndex(
        dimensions: 256,
        records: [
          VectorRecord(id: 'zeta', vector: _vector(256, {0: 1})),
          VectorRecord(id: 'alpha', vector: _vector(256, {0: 1})),
        ],
      );

      final results = index.search(_vector(256, {0: 1}), topK: 2);

      expect(results.map((result) => result.id), ['alpha', 'zeta']);
    });

    test('snapshots caller vectors and exposes immutable results', () {
      final mutableVector = _vector(256, {0: 1});
      final record = VectorRecord(id: 'stable', vector: mutableVector);
      final index = ExactVectorIndex(dimensions: 256, records: [record]);
      mutableVector[0] = -1;

      final results = index.search(_vector(256, {0: 1}), topK: 1);

      expect(results.single.id, 'stable');
      expect(results.single.score, closeTo(1, 1e-6));
      expect(
        () => results.add(const VectorSearchResult(id: 'mutated', score: 0)),
        throwsUnsupportedError,
      );
    });

    test('append keeps IDs aligned and rejects mutation before commit', () {
      final index = ExactVectorIndex(
        dimensions: 256,
        records: [
          VectorRecord(id: 'first', vector: _vector(256, {0: 1})),
        ],
      );
      index.append(VectorRecord(id: 'second', vector: _vector(256, {1: 1})));

      expect(index.length, 2);
      expect(
        index.search(_vector(256, {1: 1}), topK: 2).map((result) => result.id),
        ['second', 'first'],
      );

      expect(
        () => index.append(
          VectorRecord(id: 'second', vector: _vector(256, {2: 1})),
        ),
        throwsArgumentError,
      );
      expect(index.length, 2);
    });

    test(
      'rebuild replaces reordered updated and deleted records atomically',
      () {
        final index = ExactVectorIndex(
          dimensions: 256,
          records: [
            VectorRecord(id: 'deleted', vector: _vector(256, {0: 1})),
            VectorRecord(id: 'updated', vector: _vector(256, {1: 1})),
          ],
        );

        index.rebuild([
          VectorRecord(id: 'new', vector: _vector(256, {2: 1})),
          VectorRecord(id: 'updated', vector: _vector(256, {0: 1})),
        ]);

        expect(
          index
              .search(_vector(256, {0: 1}), topK: 3)
              .map((result) => result.id),
          ['updated', 'new'],
        );
        expect(index.length, 2);

        expect(
          () => index.rebuild([
            VectorRecord(id: 'duplicate', vector: _vector(256, {0: 1})),
            VectorRecord(id: 'duplicate', vector: _vector(256, {1: 1})),
          ]),
          throwsArgumentError,
        );
        expect(
          index
              .search(_vector(256, {0: 1}), topK: 3)
              .map((result) => result.id),
          ['updated', 'new'],
        );
      },
    );

    test('empty configured corpus returns no hits for a valid query', () {
      final index = ExactVectorIndex(dimensions: 384);

      expect(index.isEmpty, isTrue);
      expect(index.search(_vector(384, {0: 1}), topK: 5), isEmpty);
    });

    test('rejects unsupported dimensions', () {
      expect(() => ExactVectorIndex(dimensions: 128), throwsArgumentError);
      expect(() => ExactVectorIndex(dimensions: 512), throwsArgumentError);
    });

    test('rejects blank duplicate and dimension-mismatched records', () {
      expect(
        () => ExactVectorIndex(
          dimensions: 256,
          records: [
            VectorRecord(id: '  ', vector: _vector(256, {0: 1})),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => ExactVectorIndex(
          dimensions: 256,
          records: [
            VectorRecord(id: 'same', vector: _vector(256, {0: 1})),
            VectorRecord(id: 'same', vector: _vector(256, {1: 1})),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => ExactVectorIndex(
          dimensions: 256,
          records: [
            VectorRecord(id: 'short', vector: _vector(255, {0: 1})),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('rejects values invalid after float32 conversion', () {
      for (final invalidValue in [
        double.nan,
        double.infinity,
        -double.infinity,
        double.maxFinite,
      ]) {
        expect(
          () => ExactVectorIndex(
            dimensions: 256,
            records: [
              VectorRecord(
                id: 'invalid-$invalidValue',
                vector: _vector(256, {0: invalidValue}),
              ),
            ],
          ),
          throwsArgumentError,
        );
      }

      expect(
        () => ExactVectorIndex(
          dimensions: 256,
          records: [
            VectorRecord(id: 'underflow', vector: _vector(256, {0: 5e-324})),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => ExactVectorIndex(
          dimensions: 256,
          records: [VectorRecord(id: 'zero', vector: _vector(256, const {}))],
        ),
        throwsArgumentError,
      );
    });

    test('rejects invalid queries and topK values', () {
      final index = ExactVectorIndex(
        dimensions: 256,
        records: [
          VectorRecord(id: 'valid', vector: _vector(256, {0: 1})),
        ],
      );

      expect(
        () => index.search(_vector(255, {0: 1}), topK: 1),
        throwsArgumentError,
      );
      expect(
        () => index.search(_vector(256, const {}), topK: 1),
        throwsArgumentError,
      );
      expect(
        () => index.search(_vector(256, {0: double.nan}), topK: 1),
        throwsArgumentError,
      );
      expect(
        () => index.search(_vector(256, {0: 1}), topK: 0),
        throwsArgumentError,
      );
      expect(
        () => index.search(_vector(256, {0: 1}), topK: -1),
        throwsArgumentError,
      );
    });
  });
}

List<double> _vector(int dimensions, Map<int, double> values) {
  return [
    for (var index = 0; index < dimensions; index += 1) values[index] ?? 0,
  ];
}

double _referenceCosine(List<double> left, List<double> right) {
  var dot = 0.0;
  var leftSquared = 0.0;
  var rightSquared = 0.0;
  for (var index = 0; index < left.length; index += 1) {
    dot += left[index] * right[index];
    leftSquared += left[index] * left[index];
    rightSquared += right[index] * right[index];
  }
  return dot / (math.sqrt(leftSquared) * math.sqrt(rightSquared));
}
