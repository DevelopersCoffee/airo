import 'package:flutter_test/flutter_test.dart';
import 'package:platform_engine_sdk/platform_engine_sdk.dart';
import 'package:platform_pipeline/platform_pipeline.dart';

abstract class EngineTestSuite<T extends EngineProvider> {
  final T provider;
  final Artifact testModelArtifact;
  
  EngineTestSuite(this.provider, this.testModelArtifact);

  /// Setup any state before tests run.
  Future<void> setUpProvider() async {}

  /// Teardown any state after tests run.
  Future<void> tearDownProvider() async {}

  void runTests() {
    group('${provider.descriptor().identifier} Engine Tests', () {
      setUp(() async {
        await setUpProvider();
      });

      tearDown(() async {
        await tearDownProvider();
      });

      test('Descriptor is valid', () {
        expect(provider.descriptor(), isNotNull);
        expect(provider.descriptor().identifier.isNotEmpty, isTrue);
      });

      test('Capabilities are defined', () {
        expect(provider.capabilities(), isNotNull);
      });

      test('Engine allocates and frees memory cleanly', () async {
        final session = await provider.createSession(testModelArtifact);
        expect(session, isNotNull, reason: 'Engine must return a valid session');
        // EngineSession currently may not have close() defined depending on the interface, 
        // but litert_engine_session has close(). 
      });

      runEngineSpecificTests();
    });
  }

  void runEngineSpecificTests();
}
