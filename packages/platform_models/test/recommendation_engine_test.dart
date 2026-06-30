// ignore_for_file: cascade_invocations
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_models/platform_models.dart';

void main() {
  group('RecommendationEngine', () {
    late InMemoryModelCatalog catalog;
    late RecommendationEngine engine;

    setUp(() {
      catalog = InMemoryModelCatalog();
      // 8B parameter model needing 6GB RAM
      catalog.addModel(
        const ModelDescriptor(
          identifier: 'llama3-8b',
          family: 'llama3',
          modality: ModelModality.textToText,
          version: '1.0.0',
          parameterCount: 8000000000,
          quantization: 'Q4_K_M',
          contextWindow: 8192,
          capabilities: ModelCapabilities(supportsFunctionCalling: true),
          minimumRamMb: 6000,
          downloadManifest: DownloadManifest(
            identifier: 'llama-3-8b',
            version: '1.0.0',
            artifacts: [
              DownloadArtifactDescriptor(
                name: 'model.gguf',
                primaryUrl: 'https://dummy',
                sha256Checksum: 'hash',
                sizeInBytes: 4800000000,
              ),
            ],
          ),
        ),
      );
      // 3.8B parameter model needing 4GB RAM
      catalog.addModel(
        const ModelDescriptor(
          identifier: 'phi3-3.8b',
          family: 'phi3',
          modality: ModelModality.textToText,
          version: '1.0.0',
          parameterCount: 3800000000,
          quantization: 'Q4_K_M',
          contextWindow: 4096,
          capabilities: ModelCapabilities(),
          minimumRamMb: 4000,
          downloadManifest: DownloadManifest(
            identifier: 'phi-3-mini',
            version: '1.0.0',
            artifacts: [
              DownloadArtifactDescriptor(
                name: 'model.gguf',
                primaryUrl: 'https://dummy2',
                sha256Checksum: 'hash2',
                sizeInBytes: 2200000000,
              ),
            ],
          ),
        ),
      );

      engine = RecommendationEngine(catalog);
    });

    test('recommends best model fitting RAM constraints', () {
      const constraints = ModelConstraints(
        modality: ModelModality.textToText,
        availableRamMb: 4500, // Not enough for llama3-8b
      );

      final recommendation = engine.recommend(constraints);
      expect(recommendation, isNotNull);
      expect(recommendation!.identifier, 'phi3-3.8b');
    });

    test('recommends highest param count model if multiple fit', () {
      const constraints = ModelConstraints(
        modality: ModelModality.textToText,
        availableRamMb: 8000, // Enough for both
      );

      final recommendation = engine.recommend(constraints);
      expect(recommendation, isNotNull);
      expect(recommendation!.identifier, 'llama3-8b');
    });

    test('filters by capability constraints', () {
      const constraints = ModelConstraints(
        modality: ModelModality.textToText,
        availableRamMb: 8000,
        requiresFunctionCalling: true,
      );

      final recommendation = engine.recommend(constraints);
      expect(recommendation, isNotNull);
      expect(recommendation!.identifier, 'llama3-8b');
    });

    test('returns null if no model satisfies constraints', () {
      const constraints = ModelConstraints(
        modality: ModelModality.textToText,
        availableRamMb: 2000, // Too small for anything
      );

      final recommendation = engine.recommend(constraints);
      expect(recommendation, isNull);
    });
  });
}
