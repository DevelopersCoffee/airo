import 'dart:math' as math;
import 'dart:typed_data';

/// A stable record ID and an embedding supplied by a model/storage owner.
class VectorRecord {
  VectorRecord({required String id, required List<num> vector})
    : id = id.trim(),
      vector = List<double>.unmodifiable(
        vector.map((value) => value.toDouble()),
      );

  final String id;
  final List<double> vector;
}

/// An immutable exact-search result that never exposes an internal row index.
class VectorSearchResult {
  const VectorSearchResult({required this.id, required this.score});

  final String id;
  final double score;
}

/// A rebuildable in-memory exact cosine index for local embeddings.
///
/// Durable storage remains caller-owned. Large production snapshots and
/// searches must be invoked through an existing worker or native boundary.
class ExactVectorIndex {
  ExactVectorIndex({
    required this.dimensions,
    Iterable<VectorRecord> records = const [],
  }) {
    _validateDimensions(dimensions);
    _rows = _validateRecords(records);
  }

  static const supportedDimensions = {256, 384};

  final int dimensions;
  late List<_VectorRow> _rows;

  int get length => _rows.length;

  bool get isEmpty => _rows.isEmpty;

  void append(VectorRecord record) {
    final candidate = _validateRecord(record);
    if (_rows.any((row) => row.id == candidate.id)) {
      throw ArgumentError.value(record.id, 'record.id', 'must be unique');
    }
    _rows = List<_VectorRow>.unmodifiable([..._rows, candidate]);
  }

  /// Replaces the live snapshot only after every replacement row is valid.
  void rebuild(Iterable<VectorRecord> records) {
    final replacement = _validateRecords(records);
    _rows = replacement;
  }

  List<VectorSearchResult> search(List<num> query, {required int topK}) {
    if (topK <= 0) {
      throw ArgumentError.value(topK, 'topK', 'must be positive');
    }
    final validatedQuery = _validateVector(query, name: 'query');
    if (_rows.isEmpty) {
      return const [];
    }

    final results =
        [
          for (final row in _rows)
            VectorSearchResult(id: row.id, score: _cosine(row, validatedQuery)),
        ]..sort((left, right) {
          final scoreOrder = right.score.compareTo(left.score);
          return scoreOrder != 0 ? scoreOrder : left.id.compareTo(right.id);
        });

    final resultCount = math.min(topK, results.length);
    return List<VectorSearchResult>.unmodifiable(results.take(resultCount));
  }

  List<_VectorRow> _validateRecords(Iterable<VectorRecord> records) {
    final rows = <_VectorRow>[];
    final ids = <String>{};
    for (final record in records) {
      final row = _validateRecord(record);
      if (!ids.add(row.id)) {
        throw ArgumentError.value(record.id, 'record.id', 'must be unique');
      }
      rows.add(row);
    }
    return List<_VectorRow>.unmodifiable(rows);
  }

  _VectorRow _validateRecord(VectorRecord record) {
    if (record.id.isEmpty) {
      throw ArgumentError.value(record.id, 'record.id', 'must not be blank');
    }
    final validated = _validateVector(record.vector, name: 'record.vector');
    return _VectorRow(
      id: record.id,
      vector: validated.vector,
      norm: validated.norm,
    );
  }

  _ValidatedVector _validateVector(List<num> values, {required String name}) {
    if (values.length != dimensions) {
      throw ArgumentError.value(
        values.length,
        '$name.length',
        'must equal $dimensions',
      );
    }

    final vector = Float32List(dimensions);
    var normSquared = 0.0;
    for (var index = 0; index < values.length; index += 1) {
      final value = values[index].toDouble();
      if (!value.isFinite) {
        throw ArgumentError.value(value, '$name[$index]', 'must be finite');
      }
      vector[index] = value;
      final floatValue = vector[index];
      if (!floatValue.isFinite) {
        throw ArgumentError.value(
          value,
          '$name[$index]',
          'must remain finite after float32 conversion',
        );
      }
      normSquared += floatValue * floatValue;
    }

    if (normSquared == 0 || !normSquared.isFinite) {
      throw ArgumentError.value(
        values,
        name,
        'must have a finite non-zero float32 norm',
      );
    }
    return _ValidatedVector(vector: vector, norm: math.sqrt(normSquared));
  }

  double _cosine(_VectorRow row, _ValidatedVector query) {
    var dot = 0.0;
    for (var index = 0; index < dimensions; index += 1) {
      dot += row.vector[index] * query.vector[index];
    }
    return (dot / (row.norm * query.norm)).clamp(-1.0, 1.0);
  }

  static void _validateDimensions(int dimensions) {
    if (!supportedDimensions.contains(dimensions)) {
      throw ArgumentError.value(dimensions, 'dimensions', 'must be 256 or 384');
    }
  }
}

class _ValidatedVector {
  const _ValidatedVector({required this.vector, required this.norm});

  final Float32List vector;
  final double norm;
}

class _VectorRow extends _ValidatedVector {
  const _VectorRow({
    required this.id,
    required super.vector,
    required super.norm,
  });

  final String id;
}
