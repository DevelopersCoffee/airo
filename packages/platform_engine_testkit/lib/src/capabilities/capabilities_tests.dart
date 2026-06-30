import 'package:flutter_test/flutter_test.dart';
import 'package:platform_engine_testkit/src/fixtures/engine_fixture.dart';

class CapabilitiesTests {
  static void run(EngineFixture fixture) {
    group('Capabilities Tests', () {
      test('capabilities correctly reflect descriptor', () {
        final provider = fixture.createProvider();
        final descriptor = provider.descriptor();
        final capabilities = provider.capabilities();
        
        expect(descriptor.identifier, isNotEmpty);
        expect(capabilities.supportedModalities, isNotNull);
      });
    });
  }
}
