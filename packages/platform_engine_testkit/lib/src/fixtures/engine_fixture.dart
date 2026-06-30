import 'package:platform_engine_sdk/platform_engine_sdk.dart';
import 'package:platform_pipeline/platform_pipeline.dart';

abstract interface class EngineFixture {
  EngineProvider createProvider();
  
  /// Returns a valid artifact that can be used for generation/streaming tests
  Artifact createValidTextArtifact();
  
  /// Returns a valid artifact that can be used for embedding tests (optional, may return null if unsupported)
  Artifact? createValidEmbeddingArtifact();
  
  /// Returns a valid artifact that can be used for vision tests (optional)
  Artifact? createValidVisionArtifact();
}
