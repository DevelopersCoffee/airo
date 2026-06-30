import 'package:flutter_test/flutter_test.dart';
import 'package:platform_engine_sdk/platform_engine_sdk.dart';
import 'package:platform_engine_testkit/src/assertions/engine_assertions.dart';
import 'package:platform_engine_testkit/src/fixtures/engine_fixture.dart';

class VisionTests {
  static void run(EngineFixture fixture) {
    group('Vision Tests', () {
      test('analyzeImage succeeds or throws CapabilityException', () async {
        final provider = fixture.createProvider();
        final artifact = fixture.createValidVisionArtifact();
        
        if (artifact == null) {
          expect(provider.capabilities().supportedModalities.contains('vision'), isFalse);
          return;
        }
        
        final session = await provider.createSession(artifact);
        await session.initialize();
        
        if (provider.capabilities().supportedModalities.contains('vision')) {
          final result = await session.analyzeImage(const VisionRequest(imagePath: 'dummy.jpg'));
          expect(result.description, isNotNull);
        } else {
          await EngineAssertions.expectException<CapabilityException>(() async {
            await session.analyzeImage(const VisionRequest(imagePath: 'dummy.jpg'));
          });
        }
        
        await session.unload();
      });
    });
  }
}
