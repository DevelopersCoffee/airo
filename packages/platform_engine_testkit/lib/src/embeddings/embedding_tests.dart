import 'package:flutter_test/flutter_test.dart';
import 'package:platform_engine_sdk/platform_engine_sdk.dart';
import 'package:platform_engine_testkit/src/assertions/engine_assertions.dart';
import 'package:platform_engine_testkit/src/fixtures/engine_fixture.dart';

class EmbeddingTests {
  static void run(EngineFixture fixture) {
    group('Embedding Tests', () {
      test('embed returns correct dimensions or capability exception', () async {
        final provider = fixture.createProvider();
        final artifact = fixture.createValidEmbeddingArtifact();
        
        if (artifact == null) {
          // If no artifact is provided for embeddings, it shouldn't be supported
          expect(provider.capabilities().supportedModalities.contains('embeddings'), isFalse);
          return;
        }
        
        final session = await provider.createSession(artifact);
        await session.initialize();
        
        if (provider.capabilities().supportedModalities.contains('embeddings')) {
          final result = await session.embed(const EmbeddingRequest(texts: ['Hello']));
          expect(result.embeddings, isNotEmpty);
          expect(result.embeddings.first, isNotEmpty);
        } else {
          await EngineAssertions.expectException<CapabilityException>(() async {
            await session.embed(const EmbeddingRequest(texts: ['Hello']));
          });
        }
        
        await session.unload();
      });
    });
  }
}
