import 'package:flutter_test/flutter_test.dart';
import 'package:platform_engine_sdk/platform_engine_sdk.dart';
import 'package:platform_engine_testkit/src/fixtures/engine_fixture.dart';

class StreamingTests {
  static void run(EngineFixture fixture) {
    group('Streaming Tests', () {
      test('stream emits chunks and completes', () async {
        if (!fixture.createProvider().descriptor().supportsStreaming) return;
        
        final session = await fixture.createProvider().createSession(fixture.createValidTextArtifact());
        await session.initialize();
        
        final stream = session.generate(const GenerationRequest(prompt: 'Hello', maxTokens: 10));
        final chunks = await stream.toList();
        
        expect(chunks, isNotEmpty);
        expect(chunks.last.isFinished, isTrue);
        
        await session.unload();
      });
    });
  }
}
