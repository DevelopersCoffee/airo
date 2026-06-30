import 'package:flutter_test/flutter_test.dart';
import 'package:platform_engine_testkit/platform_engine_testkit.dart';

class CrossEngineSuite {
  static void run(List<EngineFixture> fixtures) {
    for (final fixture in fixtures) {
      final identifier = fixture.createProvider().descriptor().identifier;
      group('Conformance: $identifier', () {
        // Run identical tests on the fixture ensuring it passes the same engine suite
        EngineComplianceSuite.run(fixture);
      });
    }
  }
}
