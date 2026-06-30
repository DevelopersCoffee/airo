import 'package:platform_engine_sdk/platform_engine_sdk.dart';
import 'package:platform_validation/platform_validation.dart';
import 'package:platform_delegates/platform_delegates.dart';
import 'package:platform_engine_litert/src/session/litert_engine_session.dart';

class LitertEngineProvider implements EngineProvider {
  final DelegateSelection delegateSelection;

  const LitertEngineProvider({required this.delegateSelection});

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
  Future<EngineSession> createSession(InstalledArtifact artifact) async {
    return LitertEngineSession(delegateSelection: delegateSelection);
  }
}
