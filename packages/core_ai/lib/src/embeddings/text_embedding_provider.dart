import 'dart:typed_data';

/// Safe, immutable identity metadata for a local text-embedding model.
final class TextEmbeddingModelDescriptor {
  factory TextEmbeddingModelDescriptor({
    required String modelId,
    required String revision,
    required int dimensions,
    required String sha256,
  }) {
    final normalizedModelId = modelId.trim();
    final normalizedRevision = revision.trim();
    final normalizedSha256 = sha256.trim().toLowerCase();

    if (normalizedModelId.isEmpty) {
      throw ArgumentError.value(modelId, 'modelId', 'must not be blank');
    }
    if (normalizedRevision.isEmpty) {
      throw ArgumentError.value(revision, 'revision', 'must not be blank');
    }
    if (!supportedDimensions.contains(dimensions)) {
      throw ArgumentError.value(
        dimensions,
        'dimensions',
        'must be one of $supportedDimensions',
      );
    }
    if (!_sha256Pattern.hasMatch(normalizedSha256)) {
      throw ArgumentError.value(
        sha256,
        'sha256',
        'must be a 64-character hexadecimal digest',
      );
    }

    return TextEmbeddingModelDescriptor._(
      modelId: normalizedModelId,
      revision: normalizedRevision,
      dimensions: dimensions,
      sha256: normalizedSha256,
    );
  }

  const TextEmbeddingModelDescriptor._({
    required this.modelId,
    required this.revision,
    required this.dimensions,
    required this.sha256,
  });

  static const supportedDimensions = {256, 384};
  static final _sha256Pattern = RegExp(r'^[0-9a-f]{64}$');

  final String modelId;
  final String revision;
  final int dimensions;
  final String sha256;

  Map<String, Object> toJson() => {
    'modelId': modelId,
    'revision': revision,
    'dimensions': dimensions,
    'sha256': sha256,
  };
}

/// A typed result from local text embedding.
sealed class TextEmbeddingOutcome {
  const TextEmbeddingOutcome();
}

/// An immutable float32 embedding associated with its exact model identity.
final class TextEmbeddingSuccess extends TextEmbeddingOutcome {
  factory TextEmbeddingSuccess({
    required TextEmbeddingModelDescriptor model,
    required List<num> values,
  }) {
    if (values.length != model.dimensions) {
      throw ArgumentError.value(
        values.length,
        'values.length',
        'must equal ${model.dimensions}',
      );
    }

    final floatValues = Float32List(values.length);
    var normSquared = 0.0;
    for (var index = 0; index < values.length; index += 1) {
      final sourceValue = values[index].toDouble();
      if (!sourceValue.isFinite) {
        throw ArgumentError.value(
          sourceValue,
          'values[$index]',
          'must be finite',
        );
      }

      floatValues[index] = sourceValue;
      final storedValue = floatValues[index];
      if (!storedValue.isFinite) {
        throw ArgumentError.value(
          sourceValue,
          'values[$index]',
          'must fit in float32',
        );
      }
      normSquared += storedValue * storedValue;
    }
    if (!normSquared.isFinite || normSquared == 0) {
      throw ArgumentError.value(values, 'values', 'must have a finite norm');
    }

    return TextEmbeddingSuccess._(
      model: model,
      values: List<double>.unmodifiable(floatValues),
    );
  }

  const TextEmbeddingSuccess._({required this.model, required this.values});

  final TextEmbeddingModelDescriptor model;
  final List<double> values;

  @override
  String toString() {
    return 'TextEmbeddingSuccess('
        'modelId: ${model.modelId}, dimensions: ${model.dimensions})';
  }
}

/// Stable, redacted failure classes shared across platform implementations.
enum TextEmbeddingFailureCode {
  platformUnavailable('platform_unavailable'),
  modelMissing('model_missing'),
  modelIntegrityMismatch('model_integrity_mismatch'),
  unsupportedDimensions('unsupported_dimensions'),
  invalidInput('invalid_input'),
  initializationFailed('initialization_failed'),
  inferenceFailed('inference_failed'),
  cancelled('cancelled'),
  providerClosed('provider_closed');

  const TextEmbeddingFailureCode(this.stableId);

  final String stableId;
}

/// A provider failure without payload, path, or stack-trace leakage.
final class TextEmbeddingFailure extends TextEmbeddingOutcome {
  const TextEmbeddingFailure({required this.code});

  final TextEmbeddingFailureCode code;

  Map<String, String> toJson() => {'status': 'failure', 'code': code.stableId};

  @override
  String toString() => 'TextEmbeddingFailure(${code.stableId})';
}

/// Platform-neutral contract for an asynchronous local embedding provider.
abstract interface class LocalTextEmbeddingProvider {
  TextEmbeddingModelDescriptor get model;

  Future<TextEmbeddingOutcome> embed(String text);

  Future<void> close();
}
