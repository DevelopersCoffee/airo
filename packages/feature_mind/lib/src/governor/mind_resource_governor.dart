import 'package:flutter/foundation.dart';

import '../runtime/models/model_models.dart' show ThermalState, ModelResidency;

/// Canonical model lifecycle states (spec §10). The codebase historically
/// tracks lifecycle across several parallel enums (`ModelResidency`,
/// `ActiveModelState`, `EngineState`, `ModelReadinessPhase`); this is the one
/// vocabulary the governor and UI reason about.
enum MindModelLifecycleState {
  available,
  loading,
  loaded,
  active,
  unloading,
  rejected,
  failed;

  /// The model can serve inference right now.
  bool get isUsable =>
      this == MindModelLifecycleState.loaded ||
      this == MindModelLifecycleState.active;

  /// A terminal state the caller must handle (admission refused or crash).
  bool get isTerminal =>
      this == MindModelLifecycleState.rejected ||
      this == MindModelLifecycleState.failed;

  /// Maps the model-bench residency enum onto the canonical lifecycle.
  static MindModelLifecycleState fromResidency(ModelResidency residency) =>
      switch (residency) {
        ModelResidency.loaded => MindModelLifecycleState.active,
        ModelResidency.resident => MindModelLifecycleState.loaded,
        ModelResidency.available => MindModelLifecycleState.available,
      };
}

/// Thermal levels with the spec §11 names. Mapped from the hardware-facing
/// [ThermalState] so the governor policy is expressed in the spec's vocabulary.
enum MindThermalLevel {
  normal,
  warm,
  hot,
  critical;

  int get rank => index;

  static MindThermalLevel fromThermalState(ThermalState state) =>
      switch (state) {
        ThermalState.nominal => MindThermalLevel.normal,
        ThermalState.fair => MindThermalLevel.warm,
        ThermalState.serious => MindThermalLevel.hot,
        ThermalState.critical => MindThermalLevel.critical,
      };
}

/// How often the fast (classification/extraction) intelligence tier may run.
enum MindIntelligenceFrequency {
  /// Run on every semantic boundary.
  full,

  /// Run less often (e.g. only on strong boundaries) to shed load.
  reduced,

  /// Do not run the fast tier.
  off;

  /// Ordered so `min` selects the more restrictive of two levels.
  int get rank => switch (this) {
    MindIntelligenceFrequency.full => 2,
    MindIntelligenceFrequency.reduced => 1,
    MindIntelligenceFrequency.off => 0,
  };

  MindIntelligenceFrequency mostRestrictive(MindIntelligenceFrequency other) =>
      rank <= other.rank ? this : other;
}

/// Runtime signals the governor decides from. Memory is expressed as *available
/// headroom* plus per-tier estimates, never total RAM (spec §10): a model is
/// only admitted when it fits the current headroom with a safety reserve.
@immutable
class MindGovernorSignals {
  const MindGovernorSignals({
    this.thermal = MindThermalLevel.normal,
    this.batteryPercent,
    this.charging = false,
    this.availableMemoryMb,
    this.deepModelEstimateMb = 2600,
    this.fastModelEstimateMb = 700,
    this.reserveMemoryMb = 512,
  });

  final MindThermalLevel thermal;

  /// 0–100, or null when unknown.
  final int? batteryPercent;
  final bool charging;

  /// Available (not total) RAM in MB, or null when unknown.
  final int? availableMemoryMb;

  /// Admission cost estimates for the two intelligence tiers.
  final int deepModelEstimateMb;
  final int fastModelEstimateMb;

  /// Headroom that must remain free after admitting a tier.
  final int reserveMemoryMb;

  bool get _batteryConstrains => !charging && batteryPercent != null;
}

/// The governor's decision. Recording and STT are invariants — they are never
/// disabled by resource pressure (spec §22: intelligence must never destroy
/// capture). Only the intelligence tiers degrade.
@immutable
class MindGovernorDecision {
  const MindGovernorDecision({
    required this.fastIntelligenceFrequency,
    required this.deepIntelligenceEnabled,
    required this.reasons,
  });

  /// Always true. Present so call sites read the invariant explicitly.
  bool get recordingEnabled => true;

  /// Always true while a session is live. Admission (can the STT model load at
  /// all) is a separate gate; the governor never turns STT off under pressure.
  bool get sttEnabled => true;

  final MindIntelligenceFrequency fastIntelligenceFrequency;
  final bool deepIntelligenceEnabled;

  /// Human-readable constraints that shaped this decision (for the degraded
  /// banner and diagnostics).
  final List<String> reasons;

  bool get fastIntelligenceEnabled =>
      fastIntelligenceFrequency != MindIntelligenceFrequency.off;

  /// True when the runtime is fully unconstrained.
  bool get isFullIntelligence =>
      deepIntelligenceEnabled &&
      fastIntelligenceFrequency == MindIntelligenceFrequency.full;
}

/// A single `decide` policy that folds thermal, battery, and memory pressure
/// into one decision by taking the most restrictive of each dimension. Pure and
/// deterministic so it is fully unit-testable without hardware.
class MindResourceGovernor {
  const MindResourceGovernor();

  MindGovernorDecision decide(MindGovernorSignals signals) {
    var frequency = MindIntelligenceFrequency.full;
    var deepEnabled = true;
    final reasons = <String>[];

    void apply(
      MindIntelligenceFrequency freq, {
      required bool deep,
      required String reason,
    }) {
      final tightenedFreq = frequency.mostRestrictive(freq);
      final tightenedDeep = deepEnabled && deep;
      if (tightenedFreq != frequency || tightenedDeep != deepEnabled) {
        reasons.add(reason);
      }
      frequency = tightenedFreq;
      deepEnabled = tightenedDeep;
    }

    // Thermal (spec §11).
    switch (signals.thermal) {
      case MindThermalLevel.normal:
        break;
      case MindThermalLevel.warm:
        apply(
          MindIntelligenceFrequency.reduced,
          deep: true,
          reason: 'Thermal warm: reduced fast-intelligence frequency',
        );
      case MindThermalLevel.hot:
        apply(
          MindIntelligenceFrequency.reduced,
          deep: false,
          reason: 'Thermal hot: deep intelligence disabled',
        );
      case MindThermalLevel.critical:
        apply(
          MindIntelligenceFrequency.off,
          deep: false,
          reason: 'Thermal critical: STT/capture only',
        );
    }

    // Battery (spec §11). Only when discharging and known.
    if (signals._batteryConstrains) {
      final pct = signals.batteryPercent!;
      if (pct < 10) {
        apply(
          MindIntelligenceFrequency.off,
          deep: false,
          reason: 'Battery < 10%: capture/STT priority',
        );
      } else if (pct < 20) {
        apply(
          MindIntelligenceFrequency.reduced,
          deep: false,
          reason: 'Battery < 20%: reduced intelligence',
        );
      }
    }

    // Memory headroom (spec §10) — admit tiers against available headroom, not
    // total RAM. Unknown headroom is not used to restrict.
    final available = signals.availableMemoryMb;
    if (available != null) {
      final fitsDeep =
          available >= signals.deepModelEstimateMb + signals.reserveMemoryMb;
      final fitsFast =
          available >= signals.fastModelEstimateMb + signals.reserveMemoryMb;
      if (!fitsDeep) {
        apply(
          fitsFast
              ? MindIntelligenceFrequency.full
              : MindIntelligenceFrequency.off,
          deep: false,
          reason: fitsFast
              ? 'Low memory headroom: deep intelligence disabled'
              : 'Insufficient memory headroom: intelligence disabled',
        );
      }
    }

    return MindGovernorDecision(
      fastIntelligenceFrequency: frequency,
      deepIntelligenceEnabled: deepEnabled,
      reasons: List.unmodifiable(reasons),
    );
  }
}
