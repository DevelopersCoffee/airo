// ignore_for_file: cascade_invocations
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_models/platform_models.dart';

void main() {
  group('InMemoryModelCatalog', () {
    late InMemoryModelCatalog catalog;

    setUp(() {
      catalog = InMemoryModelCatalog();
      catalog.addModel(
        const ModelDescriptor(
          identifier: 'model-1',
          family: 'llama3',
          modality: ModelModality.textToText,
          version: '1.0.0',
          parameterCount: 8000000000,
          quantization: 'Q4_K_M',
          contextWindow: 8192,
          capabilities: ModelCapabilities(supportsFunctionCalling: true),
          minimumRamMb: 6000,
          downloadManifest: DownloadManifest(
            identifier: 'llama-3-8b-instruct',
            version: '1.0.0',
            artifacts: [
              DownloadArtifactDescriptor(
                name: 'model.gguf',
                primaryUrl: 'https://models.airo.com/llama-3-8b/ggml-model-q4_k_m.gguf',
                sha256Checksum: 'dummy-hash',
                sizeInBytes: 4800000000,
              ),
            ],
          ),
        ),
      );
      catalog.addModel(
        const ModelDescriptor(
          identifier: 'model-2',
          family: 'phi3',
          modality: ModelModality.textToText,
          version: '1.0.0',
          parameterCount: 3800000000,
          quantization: 'Q4_K_M',
          contextWindow: 4096,
          capabilities: ModelCapabilities(),
          minimumRamMb: 4000,
          downloadManifest: DownloadManifest(
            identifier: 'phi-3-mini-4k',
            version: '1.0.0',
            artifacts: [
              DownloadArtifactDescriptor(
                name: 'model.gguf',
                primaryUrl: 'https://models.airo.com/phi-3-mini/ggml-model-q4_0.gguf',
                sha256Checksum: 'dummy-hash2',
                sizeInBytes: 2200000000,
              ),
            ],
          ),
        ),
      );
    });

    test('findById returns correct model', () {
      final model = catalog.findById('model-1');
      expect(model, isNotNull);
      expect(model!.identifier, 'model-1');
    });

    test('findById returns null if not found', () {
      final model = catalog.findById('non-existent');
      expect(model, isNull);
    });

    test('findByFamily returns correct models', () {
      final models = catalog.findByFamily('llama3');
      expect(models.length, 1);
      expect(models.first.family, 'llama3');
    });

    test('findByModality returns correct models', () {
      final models = catalog.findByModality(ModelModality.textToText);
      expect(models.length, 2);
    });
  });
}
