import 'package:platform_engine_sdk/platform_engine_sdk.dart';

abstract interface class EngineSessionManager {
  void addSession(String sessionId, EngineSession session);
  EngineSession? getSession(String sessionId);
  Future<void> removeSession(String sessionId);
  Future<void> unloadAll();
}
