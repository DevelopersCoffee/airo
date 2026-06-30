import 'package:platform_engine_sdk/platform_engine_sdk.dart';
import 'package:platform_pipeline/platform_pipeline.dart';

abstract interface class RuntimeOrchestrator {
  Future<EngineSession> load(Artifact artifact);
  Future<void> unload(String sessionId);
  Future<void> unloadAll();
}
