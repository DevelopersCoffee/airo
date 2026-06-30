import 'package:flutter_test/flutter_test.dart';
import 'package:platform_provider/platform_provider.dart';

/// The base test suite that every provider must pass.
abstract class ProviderTestSuite<T extends PlatformProvider> {
  final T provider;
  
  /// Setup any state before tests run.
  Future<void> setUpProvider() async {}

  /// Teardown any state after tests run.
  Future<void> tearDownProvider() async {}

  ProviderTestSuite(this.provider);

  void runTests() {
    group('${provider.descriptor.id.value} Provider Tests', () {
      setUp(() async {
        await setUpProvider();
      });

      tearDown(() async {
        await tearDownProvider();
      });

      test('Descriptor is valid and well-formed', () {
        expect(provider.descriptor, isNotNull, reason: 'Provider must expose a descriptor');
        expect(provider.descriptor.id.value.isNotEmpty, isTrue, reason: 'Provider ID cannot be empty');
        expect(provider.descriptor.version, isNotNull, reason: 'Provider must declare a version');
        expect(provider.descriptor.version.toString().isNotEmpty, isTrue);
      });
      
      test('Capabilities are defined', () {
        expect(provider.descriptor.capabilities, isNotNull, reason: 'Capabilities must be non-null');
        expect(provider.descriptor.capabilities, isNotEmpty, reason: 'Provider must declare at least one capability');
      });

      // Allow subclass to run custom logic
      runCustomTests();
    });
  }

  /// Subclasses must implement specific testing logic for their provider capability
  void runCustomTests();
}
