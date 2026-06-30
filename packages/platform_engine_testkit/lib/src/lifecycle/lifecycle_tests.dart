import 'package:flutter_test/flutter_test.dart';
import 'package:platform_engine_testkit/src/fixtures/engine_fixture.dart';

class LifecycleTests {
  static void run(EngineFixture fixture) {
    group('Lifecycle Tests', () {
      test('initialize completes without error', () async {
        final provider = fixture.createProvider();
        final session = await provider.createSession(fixture.createValidTextArtifact());
        await expectLater(session.initialize(), completes);
        await session.unload();
      });

      test('multiple unloads do not crash', () async {
        final provider = fixture.createProvider();
        final session = await provider.createSession(fixture.createValidTextArtifact());
        await session.initialize();
        await expectLater(session.unload(), completes);
        await expectLater(session.unload(), completes);
      });
      
      test('repeated initialization does not crash', () async {
        final provider = fixture.createProvider();
        final session = await provider.createSession(fixture.createValidTextArtifact());
        await session.initialize();
        await expectLater(session.initialize(), completes);
        await session.unload();
      });
    });
  }
}
