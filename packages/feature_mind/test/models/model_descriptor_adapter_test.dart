import 'package:core_ai/core_ai.dart';
import 'package:feature_mind/src/models/model_descriptor_adapter.dart';
import 'package:feature_mind/src/models/model_provider.dart';
import 'package:feature_mind/src/whisper/api/setup.dart' as rust;
import 'package:flutter_test/flutter_test.dart';

/// [RequiredModel] (feature_mind's bridge-isolated identity type) and
/// [OfflineModelInfo] (core_ai's canonical, presentation-carrying model
/// descriptor) used to be two disjoint shapes with no proven mapping between
/// them (#1630). `model_descriptor_adapter.dart::offlineModelInfoFromRequiredModel`
/// is the single translation point (#1673); these tests prove it actually
/// preserves the identity fields `RequiredModel` carries — `sizeBytes` and
/// `sha256` — the exact two fields the pinned Rust registry proves are
/// correct, and that every caller-supplied presentation field passes through
/// untouched rather than being silently dropped or defaulted over.
void main() {
  const required = RequiredModel(
    fileName: 'qwen2.5-0.5b-instruct-q4_k_m.gguf',
    sizeBytes: 491400032,
    sha256: '74a4da8c9fdbcd15bd1f6d01d621410d31c6fc00986f5eb687824e7b93d7a9db',
  );

  group('offlineModelInfoFromRequiredModel', () {
    test('carries the identity fields RequiredModel pins, verbatim', () {
      final info = offlineModelInfoFromRequiredModel(
        required,
        id: 'mind-scribe-qwen2.5-0.5b-instruct',
        name: 'Qwen2.5 0.5B Instruct (Q4_K_M)',
        family: ModelFamily.qwen,
      );

      // The two fields RequiredModel exists to carry -- what proves these
      // are the correct bytes -- must survive the translation exactly.
      expect(info.fileSizeBytes, required.sizeBytes);
      expect(info.sha256, required.sha256);
    });

    test('passes every caller-supplied presentation field through', () {
      final info = offlineModelInfoFromRequiredModel(
        required,
        id: 'mind-scribe-qwen2.5-0.5b-instruct',
        name: 'Qwen2.5 0.5B Instruct (Q4_K_M)',
        family: ModelFamily.qwen,
        description: 'Powers the Airo Mind Scribe.',
        filePath: '/models/qwen2.5-0.5b-instruct-q4_k_m.gguf',
        downloadUrl: 'https://example.test/qwen2.5-0.5b-instruct-q4_k_m.gguf',
        quantization: ModelQuantization.q4,
        parameterCount: 500000000,
        modalities: const [ModelModality.text],
        capabilities: const [ModelCapability.documents],
        credibility: ModelCredibility.official,
        provider: AIProvider.custom,
        author: 'Alibaba Qwen',
        license: 'Apache-2.0',
        huggingFaceId: 'Qwen/Qwen2.5-0.5B-Instruct-GGUF',
        tags: const ['mind-scribe'],
      );

      expect(info.id, 'mind-scribe-qwen2.5-0.5b-instruct');
      expect(info.name, 'Qwen2.5 0.5B Instruct (Q4_K_M)');
      expect(info.family, ModelFamily.qwen);
      expect(info.description, 'Powers the Airo Mind Scribe.');
      expect(info.filePath, '/models/qwen2.5-0.5b-instruct-q4_k_m.gguf');
      expect(
        info.downloadUrl,
        'https://example.test/qwen2.5-0.5b-instruct-q4_k_m.gguf',
      );
      expect(info.quantization, ModelQuantization.q4);
      expect(info.parameterCount, 500000000);
      expect(info.modalities, [ModelModality.text]);
      expect(info.capabilities, [ModelCapability.documents]);
      expect(info.credibility, ModelCredibility.official);
      expect(info.provider, AIProvider.custom);
      expect(info.author, 'Alibaba Qwen');
      expect(info.license, 'Apache-2.0');
      expect(info.huggingFaceId, 'Qwen/Qwen2.5-0.5B-Instruct-GGUF');
      expect(info.tags, ['mind-scribe']);
    });

    test('survives a JSON round trip once bridged into OfflineModelInfo', () {
      final info = offlineModelInfoFromRequiredModel(
        required,
        id: 'mind-scribe-qwen2.5-0.5b-instruct',
        name: 'Qwen2.5 0.5B Instruct (Q4_K_M)',
        family: ModelFamily.qwen,
      );

      final restored = OfflineModelInfo.fromJson(info.toJson());

      expect(restored.fileSizeBytes, required.sizeBytes);
      expect(restored.sha256, required.sha256);
      expect(restored.id, info.id);
      expect(restored.family, info.family);
    });

    test('defaults presentation fields sanely when the caller omits them', () {
      final info = offlineModelInfoFromRequiredModel(
        required,
        id: 'unknown',
        name: required.fileName,
        family: ModelFamily.other,
      );

      expect(info.quantization, ModelQuantization.unknown);
      expect(info.modalities, [ModelModality.text]);
      expect(info.capabilities, isEmpty);
      expect(info.credibility, ModelCredibility.community);
      expect(info.provider, AIProvider.custom);
      expect(info.filePath, isNull);
      expect(info.isDownloaded, isFalse);
    });
  });

  group('bridge translators', () {
    test(
      'requiredModelFromBridge casts BigInt size to int, keeps identity',
      () {
        final bridged = requiredModelFromBridge(
          rust.RequiredModel(
            fileName: required.fileName,
            sizeBytes: BigInt.from(required.sizeBytes),
            sha256: required.sha256,
          ),
        );

        expect(bridged.fileName, required.fileName);
        expect(bridged.sizeBytes, required.sizeBytes);
        expect(bridged.sha256, required.sha256);
      },
    );

    test('installedModelFromBridge copies fields unchanged', () {
      final bridged = installedModelFromBridge(
        const rust.InstalledModel(
          fileName: 'qwen2.5-0.5b-instruct-q4_k_m.gguf',
          present: true,
          verified: true,
          detail: 'verified',
        ),
      );

      expect(bridged.fileName, 'qwen2.5-0.5b-instruct-q4_k_m.gguf');
      expect(bridged.present, isTrue);
      expect(bridged.verified, isTrue);
      expect(bridged.detail, 'verified');
    });
  });
}
