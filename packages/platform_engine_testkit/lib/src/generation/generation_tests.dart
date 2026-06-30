import 'package:flutter_test/flutter_test.dart';
import 'package:platform_engine_sdk/platform_engine_sdk.dart';
import 'package:platform_engine_testkit/src/fixtures/engine_fixture.dart';

class GenerationTests {
  static void run(EngineFixture fixture) {
    group('Generation Tests', () {
      test('generation completes successfully', () async {
        final session = await fixture.createProvider().createSession(fixture.createValidTextArtifact());
        await session.initialize();
        
        final chunks = await session.generate(const GenerationRequest(prompt: 'Test', maxTokens: 5)).toList();
        
        expect(chunks, isNotEmpty);
        expect(chunks.last.isFinished, isTrue);
        
        await session.unload();
      });
    });
  }
}
