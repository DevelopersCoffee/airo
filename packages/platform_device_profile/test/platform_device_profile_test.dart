import 'package:flutter_test/flutter_test.dart';
import 'package:platform_device_profile/platform_device_profile.dart';

void main() {
  group('platform_device_profile shim', () {
    test('re-exports RegionResolution from airo_device_profile', () {
      const resolution = RegionResolution.unavailable();

      expect(resolution.isAvailable, isFalse);
      expect(resolution.source, RegionResolutionSource.unavailable);
    });

    test('re-exports AiroNoOpRuntimeDeviceProfiler', () {
      final profiler = AiroNoOpRuntimeDeviceProfiler();
      expect(profiler, isA<AiroRuntimeDeviceProfiler>());
    });
  });
}
