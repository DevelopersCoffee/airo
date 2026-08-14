import '../device/device_capability_service.dart';
import 'llm_device_signals.dart';

/// Builds [LlmDeviceSignals] from the platform probes `core_ai` already has
/// wired.
///
/// RAM is real: [DeviceCapabilityService.getMemoryInfo] already reads a
/// native platform channel on Android/iOS. Chipset class and storage
/// headroom are honest best-effort seams, documented rather than silently
/// approximated:
///
/// - Chipset: the native bridge (`com.airo.gemini_nano`) reports a Pixel
///   flag and a Gemini Nano capability flag, not a chipset SKU. This probe
///   treats either as [LlmChipsetClass.flagship] and everything else with a
///   resolvable device model as [LlmChipsetClass.mainstream] --
///   [LlmChipsetClass.entry] is a policy concept this probe never emits.
///   Tightening this to a real SoC lookup is a follow-up, not a #1631
///   blocker: the policy already treats [LlmChipsetClass.unknown] the same
///   conservative way [LlmChipsetClass.entry] is treated.
/// - Storage: no platform channel here exposes free filesystem bytes today.
///   [availableStorageMb] is supplied by the caller (typically derived from
///   `ModelStorageManager`'s enforced budget headroom), not read directly by
///   this class -- a real free-disk-space probe is a separate, additive
///   change to the native bridge.
class RealLlmDeviceSignalsProbe implements LlmDeviceSignalsProbe {
  RealLlmDeviceSignalsProbe({
    required Future<int> Function() availableStorageMb,
    DeviceCapabilityService? deviceCapability,
  }) : _availableStorageMb = availableStorageMb,
       _deviceCapability = deviceCapability ?? DeviceCapabilityService();

  final Future<int> Function() _availableStorageMb;
  final DeviceCapabilityService _deviceCapability;

  @override
  Future<LlmDeviceSignals> probe() async {
    final memory = await _deviceCapability.getMemoryInfo();
    final device = await _deviceCapability.getDeviceInfo();
    final availableStorageMb = await _availableStorageMb();

    return LlmDeviceSignals(
      totalRamMb: memory.totalMB.round(),
      availableStorageMb: availableStorageMb,
      chipsetClass: _chipsetClassFor(device),
      thermalPressure: _thermalPressureFor(device),
    );
  }

  LlmChipsetClass _chipsetClassFor(DeviceInfo device) {
    if (device.isPixelDevice || device.supportsOnDeviceAI) {
      return LlmChipsetClass.flagship;
    }
    if (device.manufacturer == 'Unknown' && device.model == 'Unknown') {
      return LlmChipsetClass.unknown;
    }
    return LlmChipsetClass.mainstream;
  }

  LlmThermalPressure _thermalPressureFor(DeviceInfo device) {
    final summary = device.thermalSummary?.toLowerCase().trim();
    if (summary == null || summary.isEmpty) {
      return LlmThermalPressure.nominal;
    }
    if (summary.contains('critical') || summary.contains('shutdown')) {
      return LlmThermalPressure.critical;
    }
    if (summary.contains('severe') || summary.contains('serious')) {
      return LlmThermalPressure.serious;
    }
    if (summary.contains('moderate') || summary.contains('fair')) {
      return LlmThermalPressure.fair;
    }
    return LlmThermalPressure.nominal;
  }
}
