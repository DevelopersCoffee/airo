import 'package:core_ai/core_ai.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GGUFModelConfig', () {
    test('should create config with required parameters', () {
      const config = GGUFModelConfig(
        modelPath: '/path/to/model.gguf',
        modelName: 'Test Model',
      );

      expect(config.modelPath, '/path/to/model.gguf');
      expect(config.modelName, 'Test Model');
      expect(config.provider, AIProvider.gguf);
    });

    test('should have correct default values', () {
      const config = GGUFModelConfig(
        modelPath: '/path/to/model.gguf',
        modelName: 'Test Model',
      );

      expect(config.contextSize, 2048);
      expect(config.batchSize, 512);
      expect(config.gpuLayers, 0);
      expect(config.gpuBackend, GpuBackend.auto);
      expect(config.threads, 4);
      expect(config.temperature, 0.7);
      expect(config.topK, 40);
      expect(config.topP, 0.95);
      expect(config.repeatPenalty, 1.1);
      expect(config.maxTokens, 1024);
      expect(config.mmprojPath, isNull);
      expect(config.seed, isNull);
      expect(config.useMmap, true);
      expect(config.useMlock, false);
      expect(config.vocabOnly, false);
    });

    test('should create config with custom values', () {
      const config = GGUFModelConfig(
        modelPath: '/path/to/gemma.gguf',
        modelName: 'Gemma 2B',
        provider: AIProvider.gemma,
        contextSize: 4096,
        batchSize: 256,
        gpuLayers: 32,
        gpuBackend: GpuBackend.metal,
        threads: 8,
        temperature: 0.5,
        topK: 50,
        topP: 0.9,
        repeatPenalty: 1.2,
        maxTokens: 2048,
        seed: 42,
        useMmap: false,
        useMlock: true,
      );

      expect(config.provider, AIProvider.gemma);
      expect(config.contextSize, 4096);
      expect(config.gpuLayers, 32);
      expect(config.gpuBackend, GpuBackend.metal);
      expect(config.threads, 8);
      expect(config.temperature, 0.5);
      expect(config.seed, 42);
      expect(config.useMmap, false);
      expect(config.useMlock, true);
    });

    test('isVisionModel should return true when mmprojPath is set', () {
      const config = GGUFModelConfig(
        modelPath: '/path/to/llava.gguf',
        modelName: 'LLaVA',
        mmprojPath: '/path/to/mmproj.gguf',
      );

      expect(config.isVisionModel, true);
    });

    test('isVisionModel should return false when mmprojPath is null', () {
      const config = GGUFModelConfig(
        modelPath: '/path/to/model.gguf',
        modelName: 'Text Model',
      );

      expect(config.isVisionModel, false);
    });

    test('estimatedMemoryBytes should calculate based on context and batch', () {
      const config = GGUFModelConfig(
        modelPath: '/path/to/model.gguf',
        modelName: 'Test Model',
        contextSize: 2048,
        batchSize: 512,
      );

      // contextSize * 4 * 2 + batchSize * 4 * 2
      // 2048 * 4 * 2 + 512 * 4 * 2 = 16384 + 4096 = 20480
      expect(config.estimatedMemoryBytes, 20480);
    });

    test('copyWith should create new config with modified values', () {
      const original = GGUFModelConfig(
        modelPath: '/path/to/model.gguf',
        modelName: 'Original',
        temperature: 0.7,
      );

      final modified = original.copyWith(
        modelName: 'Modified',
        temperature: 0.5,
        contextSize: 4096,
      );

      expect(modified.modelPath, '/path/to/model.gguf');
      expect(modified.modelName, 'Modified');
      expect(modified.temperature, 0.5);
      expect(modified.contextSize, 4096);
      // Original should be unchanged
      expect(original.modelName, 'Original');
      expect(original.temperature, 0.7);
    });
  });

  group('GpuBackend', () {
    test('should have all expected values', () {
      expect(GpuBackend.values, contains(GpuBackend.none));
      expect(GpuBackend.values, contains(GpuBackend.metal));
      expect(GpuBackend.values, contains(GpuBackend.openCL));
      expect(GpuBackend.values, contains(GpuBackend.vulkan));
      expect(GpuBackend.values, contains(GpuBackend.auto));
    });
  });
}

