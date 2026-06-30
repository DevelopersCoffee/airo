import 'package:platform_engine_sdk/platform_engine_sdk.dart';
import 'package:platform_validation/platform_validation.dart';
import 'package:platform_engine_llama/src/session/llama_engine_session.dart';

class LlamaEngineProvider implements EngineProvider {
  @override
  EngineDescriptor descriptor() {
    return const EngineDescriptor(
      identifier: 'llama.cpp',
      version: '1.0.0',
      vendor: 'AIRO',
      supportsStreaming: true,
    );
  }

  @override
  EngineCapabilities capabilities() {
    return const EngineCapabilities(
      supportedModalities: ['text', 'embeddings'],
    );
  }

  @override
  Future<EngineSession> createSession(InstalledArtifact artifact) async {
    return LlamaEngineSession();
  }
}
