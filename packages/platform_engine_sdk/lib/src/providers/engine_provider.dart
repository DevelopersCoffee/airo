import 'package:platform_engine_sdk/src/capabilities/engine_capabilities.dart';
import 'package:platform_engine_sdk/src/capabilities/engine_descriptor.dart';
import 'package:platform_engine_sdk/src/sessions/engine_session.dart';
import 'package:platform_validation/platform_validation.dart';

abstract interface class EngineProvider {
  EngineDescriptor descriptor();
  EngineCapabilities capabilities();
  Future<EngineSession> createSession(InstalledArtifact artifact);
}
