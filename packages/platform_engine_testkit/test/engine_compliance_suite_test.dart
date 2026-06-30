import 'package:platform_engine_sdk/platform_engine_sdk.dart';
import 'package:platform_engine_testkit/platform_engine_testkit.dart';
import 'package:platform_validation/platform_validation.dart';

import 'package:platform_downloads/platform_downloads.dart';

class DummyEngineProvider implements EngineProvider {
  @override
  EngineDescriptor descriptor() {
    return const EngineDescriptor(
      identifier: 'dummy',
      version: '1.0',
      vendor: 'test',
      supportsStreaming: true,
    );
  }

  @override
  EngineCapabilities capabilities() {
    return const EngineCapabilities(
      supportedModalities: ['text', 'embeddings', 'vision'],
    );
  }

  @override
  Future<EngineSession> createSession(InstalledArtifact artifact) async {
    return DummyEngineSession();
  }
}

class DummyEngineSession implements EngineSession {
  @override
  Future<void> initialize() async {}

  @override
  Stream<GenerationChunk> generate(GenerationRequest request) async* {
    yield const GenerationChunk(text: 'Hello');
    yield const GenerationChunk(text: ' world', isFinished: true);
  }

  @override
  Future<EmbeddingResult> embed(EmbeddingRequest request) async {
    return const EmbeddingResult(embeddings: [[0.1, 0.2, 0.3]]);
  }

  @override
  Future<VisionResult> analyzeImage(VisionRequest request) async {
    return const VisionResult(description: 'A dummy image');
  }

  @override
  Future<AudioResult> transcribe(AudioRequest request) async {
    throw const CapabilityException('Audio not supported');
  }

  @override
  Future<void> unload() async {}
}

class DummyEngineFixture implements EngineFixture {
  @override
  EngineProvider createProvider() => DummyEngineProvider();

  @override
  InstalledArtifact createValidTextArtifact() {
    return _createDummyArtifact('dummy_text');
  }

  @override
  InstalledArtifact? createValidEmbeddingArtifact() {
    return _createDummyArtifact('dummy_embed');
  }

  @override
  InstalledArtifact? createValidVisionArtifact() {
    return _createDummyArtifact('dummy_vision');
  }

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
  EngineComplianceSuite.run(DummyEngineFixture());
}
