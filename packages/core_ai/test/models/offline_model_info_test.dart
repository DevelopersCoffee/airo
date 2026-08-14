import 'package:core_ai/core_ai.dart';
import 'package:flutter_test/flutter_test.dart';

/// [OfflineModelInfo] is the canonical model-descriptor type (#1630): every
/// producer of model metadata — `core_ai`'s own registry/catalog and
/// `feature_mind`'s pinned-registry adapter
/// (`model_descriptor_adapter.dart::offlineModelInfoFromRequiredModel`) —
/// converges on this shape rather than inventing a second one. These tests
/// prove the round trip a persisted/rehydrated descriptor depends on: every
/// field survives `toJson`/`fromJson`, including the two fields
/// (`fileSizeBytes`, `sha256`) that `feature_mind`'s narrower
/// `RequiredModel` carries and that the adapter maps straight through.
void main() {
  group('OfflineModelInfo JSON round trip', () {
    test('every field survives toJson/fromJson unchanged', () {
      const original = OfflineModelInfo(
        id: 'mind-scribe-qwen2.5-0.5b-instruct',
        name: 'Qwen2.5 0.5B Instruct (Q4_K_M)',
        family: ModelFamily.qwen,
        fileSizeBytes: 491400032,
        filePath: '/models/qwen2.5-0.5b-instruct-q4_k_m.gguf',
        downloadUrl: 'https://example.test/qwen2.5-0.5b-instruct-q4_k_m.gguf',
        quantization: ModelQuantization.q4,
        parameterCount: 500000000,
        contextLength: 4096,
        supportsVision: false,
        supportsFunctionCalling: true,
        modalities: [ModelModality.text, ModelModality.audio],
        capabilities: [ModelCapability.documents, ModelCapability.chat],
        backendPreference: ModelBackendPreference.gpu,
        licenseState: ModelLicenseState.open,
        languages: ['en', 'hi'],
        credibility: ModelCredibility.official,
        provider: AIProvider.gguf,
        description: 'Powers the Airo Mind Scribe.',
        version: '2.5',
        author: 'Alibaba Qwen',
        license: 'Apache-2.0',
        learnMoreUrl: 'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF',
        huggingFaceId: 'Qwen/Qwen2.5-0.5B-Instruct-GGUF',
        sha256:
            '74a4da8c9fdbcd15bd1f6d01d621410d31c6fc00986f5eb687824e7b93d7a9db',
        tags: ['mind-scribe'],
        minMemoryBytes: 600000000,
        recommendedMemoryBytes: 900000000,
        supportsWebRuntime: true,
        webAssetUrl: 'https://example.test/qwen2.5-0.5b.task',
      );

      final restored = OfflineModelInfo.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.family, original.family);
      expect(restored.fileSizeBytes, original.fileSizeBytes);
      expect(restored.filePath, original.filePath);
      expect(restored.downloadUrl, original.downloadUrl);
      expect(restored.quantization, original.quantization);
      expect(restored.parameterCount, original.parameterCount);
      expect(restored.contextLength, original.contextLength);
      expect(restored.supportsVision, original.supportsVision);
      expect(
        restored.supportsFunctionCalling,
        original.supportsFunctionCalling,
      );
      expect(restored.modalities, original.modalities);
      expect(restored.capabilities, original.capabilities);
      expect(restored.backendPreference, original.backendPreference);
      expect(restored.licenseState, original.licenseState);
      expect(restored.languages, original.languages);
      expect(restored.credibility, original.credibility);
      expect(restored.provider, original.provider);
      expect(restored.description, original.description);
      expect(restored.version, original.version);
      expect(restored.author, original.author);
      expect(restored.license, original.license);
      expect(restored.learnMoreUrl, original.learnMoreUrl);
      expect(restored.huggingFaceId, original.huggingFaceId);
      // The identity fields RequiredModel (feature_mind) also carries — the
      // ones the pinned Rust registry proves are correct. These must never
      // drop across a persist/rehydrate cycle: they are what integrity
      // verification checks against.
      expect(restored.sha256, original.sha256);
      expect(restored.fileSizeBytes, original.fileSizeBytes);
      expect(restored.tags, original.tags);
      expect(restored.minMemoryBytes, original.minMemoryBytes);
      expect(restored.recommendedMemoryBytes, original.recommendedMemoryBytes);
      expect(restored.supportsWebRuntime, original.supportsWebRuntime);
      expect(restored.webAssetUrl, original.webAssetUrl);
    });

    test('optional fields round trip as null when absent', () {
      const original = OfflineModelInfo(
        id: 'bare',
        name: 'Bare',
        family: ModelFamily.other,
        fileSizeBytes: 1024,
      );

      final restored = OfflineModelInfo.fromJson(original.toJson());

      expect(restored.filePath, isNull);
      expect(restored.downloadUrl, isNull);
      expect(restored.sha256, isNull);
      expect(restored.parameterCount, isNull);
      expect(restored.minMemoryBytes, isNull);
      expect(restored.recommendedMemoryBytes, isNull);
      expect(restored.webAssetUrl, isNull);
      expect(restored.isDownloaded, isFalse);
    });

    test('unrecognized enum values fall back to a safe default', () {
      const original = OfflineModelInfo(
        id: 'x',
        name: 'X',
        family: ModelFamily.other,
        fileSizeBytes: 1,
      );
      final json = original.toJson()
        ..['family'] = 'not-a-real-family'
        ..['quantization'] = 'not-a-real-quant'
        ..['licenseState'] = 'not-a-real-state';

      final restored = OfflineModelInfo.fromJson(json);

      expect(restored.family, ModelFamily.other);
      expect(restored.quantization, ModelQuantization.unknown);
      expect(restored.licenseState, ModelLicenseState.open);
    });
  });

  group('copyWith', () {
    test('leaves untouched fields alone and applies overrides', () {
      const original = OfflineModelInfo(
        id: 'a',
        name: 'A',
        family: ModelFamily.gemma,
        fileSizeBytes: 10,
        sha256: 'abc',
      );

      final copy = original.copyWith(name: 'B', fileSizeBytes: 20);

      expect(copy.id, 'a');
      expect(copy.family, ModelFamily.gemma);
      expect(copy.sha256, 'abc');
      expect(copy.name, 'B');
      expect(copy.fileSizeBytes, 20);
    });

    test(
      'clearFilePath drops filePath even with a non-null override absent',
      () {
        const original = OfflineModelInfo(
          id: 'a',
          name: 'A',
          family: ModelFamily.gemma,
          fileSizeBytes: 10,
          filePath: '/models/a.gguf',
        );

        final copy = original.copyWith(clearFilePath: true);

        expect(copy.filePath, isNull);
        expect(copy.isDownloaded, isFalse);
      },
    );
  });
}
