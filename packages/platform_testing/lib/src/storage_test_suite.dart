import 'package:flutter_test/flutter_test.dart';
import 'package:platform_provider/platform_provider.dart';
import 'provider_test_suite.dart';

abstract class StorageTestSuite<T extends PlatformProvider> extends ProviderTestSuite<T> {
  StorageTestSuite(super.provider);

  @override
  void runCustomTests() {
    test('Storage handles read/write consistency', () async {
      await testReadWriteConsistency();
    });

    test('Storage cleans up resources', () async {
      await testCleanup();
    });

    runStorageSpecificTests();
  }
  
  Future<void> testReadWriteConsistency();
  Future<void> testCleanup();
  void runStorageSpecificTests();
}
