import 'package:flutter_test/flutter_test.dart';
import 'package:platform_downloads/platform_downloads.dart';
import 'package:platform_engine_llama/platform_engine_llama.dart';
import 'package:platform_engine_sdk/platform_engine_sdk.dart';
import 'package:platform_engine_testkit/platform_engine_testkit.dart';
import 'package:platform_pipeline/platform_pipeline.dart';

class LlamaFixture implements EngineFixture {
  @override
  EngineProvider createProvider() => LlamaEngineProvider();

  @override
  Artifact createValidTextArtifact() => _createDummyArtifact('llama_text');

  @override
  Artifact? createValidEmbeddingArtifact() => _createDummyArtifact('llama_embed');

  @override
  Artifact? createValidVisionArtifact() => null; // Not supported by llama.cpp currently

  Artifact _createDummyArtifact(String id) {
    return Artifact(
      installationId: 'inst_$id',
      artifactId: id,
      descriptor: const DownloadArtifactDescriptor(
        name: 'model',
        primaryUrl: 'https://example.com/model',
        sizeInBytes: 1000,
        sha256Checksum: '123',
      ),
      installLocation: '/tmp/$id',
      validationReport: const ValidationReport(
        status: ValidationStatus.success,
        errors: [],
      ),
      installedVersion: '1.0.0',
    );
  }
}

void main() {
  EngineComplianceSuite.run(LlamaFixture());
}
