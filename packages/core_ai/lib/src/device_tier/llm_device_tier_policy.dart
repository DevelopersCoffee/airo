import 'package:meta/meta.dart';

import 'llm_device_signals.dart';
import 'llm_device_tier.dart';

/// Why [LlmDeviceTierPolicy.evaluate] returned the tier it did.
///
/// A routing-decision log that says only "small" tells a support engineer
/// nothing about which axis capped it. These codes are the answer.
enum LlmTierReasonCode {
  ramSufficientForLarge,
  ramLimitsToMedium,
  ramLimitsToSmall,
  ramBelowMinimum,
  storageBelowFloorForTier,
  chipsetCapsAtSmall,
  chipsetUnknownCapsAtSmall,
  thermalCriticalBlocksLocal,
  thermalSeriousCapsAtSmall;

  String get stableId => name;
}

/// The tier a policy computed, plus the reasons and the signals it read --
/// everything #1631's "routing decision logged + inspectable" AC needs to
/// render a "why local vs cloud" explanation.
@immutable
class LlmDeviceTierEvaluation {
  const LlmDeviceTierEvaluation({
    required this.tier,
    required this.reasons,
    required this.signals,
  });

  final LlmDeviceTier tier;
  final List<LlmTierReasonCode> reasons;
  final LlmDeviceSignals signals;

  Map<String, Object?> toPublicMap() => {
    'tier': tier.stableId,
    'reasons': reasons.map((reason) => reason.stableId).toList(growable: false),
    'signals': signals.toPublicMap(),
  };
}

/// Computes [LlmDeviceTier] from RAM, available storage, chipset class, and
/// thermal pressure.
///
/// Pure and synchronous: it never probes anything itself, so the tier matrix
/// is exhaustively table-testable against constructed [LlmDeviceSignals]
/// (#1631's "unit tests for tier matrix" AC) without a device, a platform
/// channel, or a fake probe in the loop.
///
/// Evaluation order matters and is deliberate: thermal-critical is checked
/// first because it is a full override (skip local entirely, regardless of
/// how much RAM the device has), then RAM sets a starting tier, then storage
/// and chipset and thermal-serious can only cap that tier downward -- never
/// grant a tier RAM did not already support.
class LlmDeviceTierPolicy {
  const LlmDeviceTierPolicy({
    this.minRamMbForSmall = 3072,
    this.minRamMbForMedium = 5120,
    this.minRamMbForLarge = 7680,
    this.minStorageMbForSmall = 1024,
    this.minStorageMbForMedium = 2560,
    this.minStorageMbForLarge = 6144,
  });

  final int minRamMbForSmall;
  final int minRamMbForMedium;
  final int minRamMbForLarge;
  final int minStorageMbForSmall;
  final int minStorageMbForMedium;
  final int minStorageMbForLarge;

  LlmDeviceTierEvaluation evaluate(LlmDeviceSignals signals) {
    final reasons = <LlmTierReasonCode>[];

    if (signals.thermalPressure.blocksLocalInference) {
      reasons.add(LlmTierReasonCode.thermalCriticalBlocksLocal);
      return LlmDeviceTierEvaluation(
        tier: LlmDeviceTier.none,
        reasons: reasons,
        signals: signals,
      );
    }

    var tier = _tierForRam(signals.totalRamMb, reasons);
    tier = _capForStorage(tier, signals.availableStorageMb, reasons);
    tier = _capForChipset(tier, signals.chipsetClass, reasons);
    tier = _capForThermal(tier, signals.thermalPressure, reasons);

    if (reasons.isEmpty) {
      reasons.add(LlmTierReasonCode.ramSufficientForLarge);
    }

    return LlmDeviceTierEvaluation(
      tier: tier,
      reasons: reasons,
      signals: signals,
    );
  }

  LlmDeviceTier _tierForRam(int ramMb, List<LlmTierReasonCode> reasons) {
    if (ramMb >= minRamMbForLarge) return LlmDeviceTier.large;
    if (ramMb >= minRamMbForMedium) {
      reasons.add(LlmTierReasonCode.ramLimitsToMedium);
      return LlmDeviceTier.medium;
    }
    if (ramMb >= minRamMbForSmall) {
      reasons.add(LlmTierReasonCode.ramLimitsToSmall);
      return LlmDeviceTier.small;
    }
    reasons.add(LlmTierReasonCode.ramBelowMinimum);
    return LlmDeviceTier.none;
  }

  int _storageFloorFor(LlmDeviceTier tier) => switch (tier) {
    LlmDeviceTier.large => minStorageMbForLarge,
    LlmDeviceTier.medium => minStorageMbForMedium,
    LlmDeviceTier.small => minStorageMbForSmall,
    LlmDeviceTier.none => 0,
  };

  LlmDeviceTier _capForStorage(
    LlmDeviceTier tier,
    int storageMb,
    List<LlmTierReasonCode> reasons,
  ) {
    var capped = tier;
    while (capped != LlmDeviceTier.none && storageMb < _storageFloorFor(capped)) {
      reasons.add(LlmTierReasonCode.storageBelowFloorForTier);
      capped = _oneTierDown(capped);
    }
    return capped;
  }

  LlmDeviceTier _capForChipset(
    LlmDeviceTier tier,
    LlmChipsetClass chipset,
    List<LlmTierReasonCode> reasons,
  ) {
    if (tier == LlmDeviceTier.none) return tier;
    if (chipset == LlmChipsetClass.entry) {
      reasons.add(LlmTierReasonCode.chipsetCapsAtSmall);
      return _min(tier, LlmDeviceTier.small);
    }
    if (chipset == LlmChipsetClass.unknown) {
      reasons.add(LlmTierReasonCode.chipsetUnknownCapsAtSmall);
      return _min(tier, LlmDeviceTier.small);
    }
    return tier;
  }

  LlmDeviceTier _capForThermal(
    LlmDeviceTier tier,
    LlmThermalPressure pressure,
    List<LlmTierReasonCode> reasons,
  ) {
    if (tier == LlmDeviceTier.none) return tier;
    if (pressure == LlmThermalPressure.serious) {
      reasons.add(LlmTierReasonCode.thermalSeriousCapsAtSmall);
      return _min(tier, LlmDeviceTier.small);
    }
    return tier;
  }

  LlmDeviceTier _oneTierDown(LlmDeviceTier tier) => switch (tier) {
    LlmDeviceTier.large => LlmDeviceTier.medium,
    LlmDeviceTier.medium => LlmDeviceTier.small,
    LlmDeviceTier.small => LlmDeviceTier.none,
    LlmDeviceTier.none => LlmDeviceTier.none,
  };

  LlmDeviceTier _min(LlmDeviceTier a, LlmDeviceTier b) =>
      a.index <= b.index ? a : b;
}
