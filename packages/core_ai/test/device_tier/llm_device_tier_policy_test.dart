import 'package:core_ai/core_ai.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const policy = LlmDeviceTierPolicy();

  LlmDeviceSignals signals({
    required int ramMb,
    int storageMb = 8192,
    LlmChipsetClass chipset = LlmChipsetClass.flagship,
    LlmThermalPressure thermal = LlmThermalPressure.nominal,
  }) => LlmDeviceSignals(
    totalRamMb: ramMb,
    availableStorageMb: storageMb,
    chipsetClass: chipset,
    thermalPressure: thermal,
  );

  group('RAM axis (flagship chipset, ample storage, nominal thermal)', () {
    final matrix = <int, LlmDeviceTier>{
      512: LlmDeviceTier.none,
      1024: LlmDeviceTier.none,
      3071: LlmDeviceTier.none,
      3072: LlmDeviceTier.small,
      5119: LlmDeviceTier.small,
      5120: LlmDeviceTier.medium,
      7679: LlmDeviceTier.medium,
      7680: LlmDeviceTier.large,
      16384: LlmDeviceTier.large,
    };

    for (final entry in matrix.entries) {
      test('${entry.key} MB RAM -> ${entry.value.stableId}', () {
        final evaluation = policy.evaluate(signals(ramMb: entry.key));
        expect(evaluation.tier, entry.value);
        expect(evaluation.reasons, isNotEmpty);
      });
    }
  });

  test('none tier below the RAM floor reports ramBelowMinimum', () {
    final evaluation = policy.evaluate(signals(ramMb: 2048));
    expect(evaluation.tier, LlmDeviceTier.none);
    expect(evaluation.reasons, contains(LlmTierReasonCode.ramBelowMinimum));
  });

  test('storage below the tier floor caps the tier down, not to unsupported',
      () {
    // RAM alone would grant large, but storage only fits small.
    final evaluation = policy.evaluate(
      signals(ramMb: 16384, storageMb: 1200),
    );
    expect(evaluation.tier, LlmDeviceTier.small);
    expect(
      evaluation.reasons,
      contains(LlmTierReasonCode.storageBelowFloorForTier),
    );
  });

  test('storage far below any floor caps all the way to none', () {
    final evaluation = policy.evaluate(signals(ramMb: 16384, storageMb: 10));
    expect(evaluation.tier, LlmDeviceTier.none);
  });

  test('entry-level chipset caps a RAM-qualified large device at small', () {
    final evaluation = policy.evaluate(
      signals(ramMb: 16384, chipset: LlmChipsetClass.entry),
    );
    expect(evaluation.tier, LlmDeviceTier.small);
    expect(evaluation.reasons, contains(LlmTierReasonCode.chipsetCapsAtSmall));
  });

  test('unknown chipset is treated as conservatively as entry-level', () {
    final evaluation = policy.evaluate(
      signals(ramMb: 16384, chipset: LlmChipsetClass.unknown),
    );
    expect(evaluation.tier, LlmDeviceTier.small);
    expect(
      evaluation.reasons,
      contains(LlmTierReasonCode.chipsetUnknownCapsAtSmall),
    );
  });

  test('mainstream chipset does not cap a medium-RAM device', () {
    final evaluation = policy.evaluate(
      signals(ramMb: 6000, chipset: LlmChipsetClass.mainstream),
    );
    expect(evaluation.tier, LlmDeviceTier.medium);
  });

  group('thermal pressure', () {
    test('critical thermal pressure blocks local inference entirely', () {
      final evaluation = policy.evaluate(
        signals(ramMb: 16384, thermal: LlmThermalPressure.critical),
      );
      expect(evaluation.tier, LlmDeviceTier.none);
      expect(
        evaluation.reasons,
        contains(LlmTierReasonCode.thermalCriticalBlocksLocal),
      );
    });

    test('critical thermal pressure overrides an otherwise-large device',
        () {
      final evaluation = policy.evaluate(
        signals(
          ramMb: 16384,
          chipset: LlmChipsetClass.flagship,
          storageMb: 16384,
          thermal: LlmThermalPressure.critical,
        ),
      );
      expect(evaluation.tier, LlmDeviceTier.none);
    });

    test('serious thermal pressure caps a large-RAM device at small', () {
      final evaluation = policy.evaluate(
        signals(ramMb: 16384, thermal: LlmThermalPressure.serious),
      );
      expect(evaluation.tier, LlmDeviceTier.small);
      expect(
        evaluation.reasons,
        contains(LlmTierReasonCode.thermalSeriousCapsAtSmall),
      );
    });

    test('fair thermal pressure does not cap the tier', () {
      final evaluation = policy.evaluate(
        signals(ramMb: 16384, thermal: LlmThermalPressure.fair),
      );
      expect(evaluation.tier, LlmDeviceTier.large);
    });
  });

  test('toPublicMap round-trips tier, reasons, and signals', () {
    final evaluation = policy.evaluate(signals(ramMb: 5200));
    final map = evaluation.toPublicMap();
    expect(map['tier'], 'medium');
    expect(map['reasons'], isA<List<Object?>>());
    expect(map['signals'], isA<Map<String, Object?>>());
  });
}
