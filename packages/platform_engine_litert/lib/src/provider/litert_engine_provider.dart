import 'package:platform_delegates/platform_delegates.dart';
import 'package:platform_engine_litert/src/session/litert_engine_session.dart';
import 'package:platform_engine_sdk/platform_engine_sdk.dart';
import 'package:platform_pipeline/platform_pipeline.dart';
class LitertEngineProvider implements EngineProvider {

  const LitertEngineProvider({required this.delegateSelection});
  final DelegateSelection delegateSelection;

  @override
  EngineDescriptor descriptor() {
    return const EngineDescriptor(
      identifier: 'litert',
      version: '1.0.0',
      vendor: 'AIRO',
      supportsStreaming: true,
    );
  }

  @override
  EngineCapabilities capabilities() {
    return const EngineCapabilities(
      supportedModalities: ['text', 'vision'],
    );
  }

  @override
  Future<EngineSession> createSession(Artifact artifact) async {
    return LitertEngineSession(delegateSelection: delegateSelection);
  }
}
