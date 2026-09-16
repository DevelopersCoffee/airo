import 'package:flutter_test/flutter_test.dart';
import 'package:platform_device_profile/platform_device_profile.dart';

void main() {
  test('platform_device_profile shim re-exports airo_device_profile contracts correctly', () {
    final signals = AiroRuntimeDeviceSignals(
      signalId: 'sig-test',
      platformCategory: AiroNodePlatformCategory.androidTv,
      apiLevel: 28,
      memoryMb: 2048,
      freeStorageMb: 4096,
      gpuClass: AiroRuntimeGpuClass.standard,
      decoderCount: 4,
      supportedCodecs: const {
        MediaCodecCapability.h264,
        MediaCodecCapability.aac,
        MediaCodecCapability.hls,
      },
      remoteInputs: const {AiroRuntimeRemoteInput.dpad},
      networkClass: AiroRuntimeNetworkClass.stableWifi,
    );

    final policy = AiroRuntimeDeviceProfilePolicy();
    final profile = policy.evaluate(signals: signals, now: DateTime.now());

    expect(profile.supportTier, AiroRuntimeSupportTier.fullySupported);
  });
}
