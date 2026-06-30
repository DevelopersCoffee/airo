import 'package:platform_engine_sdk/platform_engine_sdk.dart';
import 'package:platform_validation/platform_validation.dart';

abstract interface class EngineFixture {
  EngineProvider createProvider();
  
  /// Returns a valid artifact that can be used for generation/streaming tests
  InstalledArtifact createValidTextArtifact();
  
  /// Returns a valid artifact that can be used for embedding tests (optional, may return null if unsupported)
  InstalledArtifact? createValidEmbeddingArtifact();
  
  /// Returns a valid artifact that can be used for vision tests (optional)
  InstalledArtifact? createValidVisionArtifact();
}
