import 'package:core_ai/core_ai.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FakeLlmDeviceSignalsProbe returns exactly the injected signals', () async {
    const injected = LlmDeviceSignals(
      totalRamMb: 4096,
      availableStorageMb: 2048,
      chipsetClass: LlmChipsetClass.mainstream,
      thermalPressure: LlmThermalPressure.fair,
    );
    final probe = FakeLlmDeviceSignalsProbe(injected);

    final result = await probe.probe();

    expect(result, injected);
  });

  test('equality and copyWith', () {
    const base = LlmDeviceSignals(totalRamMb: 4096, availableStorageMb: 2048);
    final copy = base.copyWith(totalRamMb: 8192);

    expect(copy.totalRamMb, 8192);
    expect(copy.availableStorageMb, base.availableStorageMb);
    expect(copy, isNot(equals(base)));
    expect(
      base,
      const LlmDeviceSignals(totalRamMb: 4096, availableStorageMb: 2048),
    );
  });

  test('thermal pressure helpers', () {
    expect(LlmThermalPressure.critical.blocksLocalInference, isTrue);
    expect(LlmThermalPressure.serious.blocksLocalInference, isFalse);
    expect(LlmThermalPressure.serious.shouldPauseBatchJobs, isTrue);
    expect(LlmThermalPressure.critical.shouldPauseBatchJobs, isTrue);
    expect(LlmThermalPressure.fair.shouldPauseBatchJobs, isFalse);
    expect(LlmThermalPressure.nominal.shouldPauseBatchJobs, isFalse);
  });

  test('toPublicMap exposes stable string ids, not enum names that could '
      'drift', () {
    const signals = LlmDeviceSignals(
      totalRamMb: 4096,
      availableStorageMb: 2048,
      chipsetClass: LlmChipsetClass.flagship,
      thermalPressure: LlmThermalPressure.serious,
    );
    final map = signals.toPublicMap();
    expect(map['chipsetClass'], 'flagship');
    expect(map['thermalPressure'], 'serious');
  });
}
