import 'package:flutter_test/flutter_test.dart';
import 'package:platform_provider/platform_provider.dart';
import 'provider_test_suite.dart';

abstract class PipelineTestSuite<T extends PlatformProvider> extends ProviderTestSuite<T> {
  PipelineTestSuite(super.provider);

  @override
  void runCustomTests() {
    test('Pipeline provider returns correct capabilities', () {
      expect(
        provider.descriptor.capabilities.isNotEmpty,
        isTrue,
        reason: 'Pipeline providers must declare at least one capability',
      );
    });

    runPipelineSpecificTests();
  }

  void runPipelineSpecificTests();
}
