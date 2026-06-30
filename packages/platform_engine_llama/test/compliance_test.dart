import 'package:flutter_test/flutter_test.dart';
import 'package:platform_engine_sdk/platform_engine_sdk.dart';
import 'package:platform_engine_testkit/platform_engine_testkit.dart';
import 'package:platform_validation/platform_validation.dart';
import 'package:platform_downloads/platform_downloads.dart';
import 'package:platform_engine_llama/platform_engine_llama.dart';

class LlamaFixture implements EngineFixture {
  @override
  EngineProvider createProvider() => LlamaEngineProvider();

  @override
  InstalledArtifact createValidTextArtifact() => _createDummyArtifact('llama_text');

  @override
  InstalledArtifact? createValidEmbeddingArtifact() => _createDummyArtifact('llama_embed');

  @override
  InstalledArtifact? createValidVisionArtifact() => null; // Not supported by llama.cpp currently

  InstalledArtifact _createDummyArtifact(String id) {
    return InstalledArtifact(
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
