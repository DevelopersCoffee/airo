import 'package:platform_engine_sdk/platform_engine_sdk.dart';
import 'package:platform_validation/platform_validation.dart';

abstract interface class RuntimeOrchestrator {
  Future<EngineSession> load(InstalledArtifact artifact);
  Future<void> unload(String sessionId);
  Future<void> unloadAll();
}
