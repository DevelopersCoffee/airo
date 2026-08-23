//! Runtime resource / thermal / battery governor for live intelligence.
//!
//! Recording is never refused by this governor. Live STT and deeper
//! intelligence are.

/// Thermal band derived from platform probes (Dart fills the snapshot).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ThermalBand {
    Normal,
    Warm,
    Hot,
    Critical,
}

/// Battery band. Thresholds match the production-qualification contract.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum BatteryBand {
    Normal,
    /// Below 20%.
    Low,
    /// Below 10%.
    Critical,
}

/// What live intelligence is allowed to do under the current snapshot.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum IntelligencePolicy {
    Full,
    ReduceFrequency,
    DisableDeep,
    CaptureAndSttOnly,
}

/// Why live STT must not start. File recording is still allowed.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum LiveAdmission {
    Allowed,
    Rejected { needs_mb: u32, available_mb: u32 },
}

/// Point-in-time view. Total RAM is classification-only; admission uses
/// available RAM plus a reserved headroom for the Flutter UI.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct ResourceSnapshot {
    pub total_ram_mb: u32,
    pub available_ram_mb: u32,
    pub stt_model_mb: u32,
    /// Flutter / app reserve that must remain after the STT model loads.
    pub app_headroom_mb: u32,
    pub thermal: ThermalBand,
    pub battery_percent: u8,
}

impl ResourceSnapshot {
    pub fn unconstrained(stt_model_mb: u32) -> Self {
        Self {
            total_ram_mb: 16_384,
            available_ram_mb: 8_192,
            stt_model_mb,
            app_headroom_mb: 512,
            thermal: ThermalBand::Normal,
            battery_percent: 80,
        }
    }

    pub fn battery_band(&self) -> BatteryBand {
        if self.battery_percent < 10 {
            BatteryBand::Critical
        } else if self.battery_percent < 20 {
            BatteryBand::Low
        } else {
            BatteryBand::Normal
        }
    }
}

/// Stateless policy. Callers supply a fresh snapshot each decision.
pub struct ResourceGovernor;

impl ResourceGovernor {
    /// Live STT is refused when available RAM cannot hold the model plus
    /// application headroom. Total RAM is ignored on purpose.
    pub fn admit_live_stt(snapshot: &ResourceSnapshot) -> LiveAdmission {
        let needs = snapshot
            .stt_model_mb
            .saturating_add(snapshot.app_headroom_mb);
        if snapshot.available_ram_mb < needs {
            LiveAdmission::Rejected {
                needs_mb: needs,
                available_mb: snapshot.available_ram_mb,
            }
        } else {
            LiveAdmission::Allowed
        }
    }

    pub fn policy(snapshot: &ResourceSnapshot) -> IntelligencePolicy {
        if snapshot.thermal == ThermalBand::Critical
            || snapshot.battery_band() == BatteryBand::Critical
        {
            return IntelligencePolicy::CaptureAndSttOnly;
        }
        if snapshot.thermal == ThermalBand::Hot {
            return IntelligencePolicy::DisableDeep;
        }
        if snapshot.thermal == ThermalBand::Warm || snapshot.battery_band() == BatteryBand::Low {
            return IntelligencePolicy::ReduceFrequency;
        }
        IntelligencePolicy::Full
    }

    /// Intelligence may degrade; capture must not.
    pub const fn recording_must_continue() -> bool {
        true
    }

    /// Incremental Conversation IR is cheap surface extraction. It stays on
    /// unless the policy has already collapsed to capture+STT only.
    pub const fn live_ir_enabled(policy: IntelligencePolicy) -> bool {
        !matches!(policy, IntelligencePolicy::CaptureAndSttOnly)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn live_stt_uses_available_ram_not_total() {
        let mut snap = ResourceSnapshot::unconstrained(512);
        snap.total_ram_mb = 16_384;
        snap.available_ram_mb = 256;
        snap.stt_model_mb = 512;
        snap.app_headroom_mb = 512;
        assert!(matches!(
            ResourceGovernor::admit_live_stt(&snap),
            LiveAdmission::Rejected { .. }
        ));
    }

    #[test]
    fn live_stt_allowed_when_headroom_fits() {
        let snap = ResourceSnapshot::unconstrained(512);
        assert_eq!(
            ResourceGovernor::admit_live_stt(&snap),
            LiveAdmission::Allowed
        );
    }

    #[test]
    fn thermal_and_battery_map_to_policy() {
        let mut snap = ResourceSnapshot::unconstrained(512);
        assert_eq!(ResourceGovernor::policy(&snap), IntelligencePolicy::Full);

        snap.thermal = ThermalBand::Warm;
        assert_eq!(
            ResourceGovernor::policy(&snap),
            IntelligencePolicy::ReduceFrequency
        );

        snap.thermal = ThermalBand::Hot;
        assert_eq!(
            ResourceGovernor::policy(&snap),
            IntelligencePolicy::DisableDeep
        );

        snap.thermal = ThermalBand::Critical;
        assert_eq!(
            ResourceGovernor::policy(&snap),
            IntelligencePolicy::CaptureAndSttOnly
        );

        snap.thermal = ThermalBand::Normal;
        snap.battery_percent = 15;
        assert_eq!(
            ResourceGovernor::policy(&snap),
            IntelligencePolicy::ReduceFrequency
        );

        snap.battery_percent = 5;
        assert_eq!(
            ResourceGovernor::policy(&snap),
            IntelligencePolicy::CaptureAndSttOnly
        );
    }

    #[test]
    fn recording_survives_every_intelligence_policy() {
        assert!(ResourceGovernor::recording_must_continue());
    }

    #[test]
    fn live_ir_stops_only_when_policy_is_capture_and_stt() {
        assert!(ResourceGovernor::live_ir_enabled(IntelligencePolicy::Full));
        assert!(ResourceGovernor::live_ir_enabled(
            IntelligencePolicy::ReduceFrequency
        ));
        assert!(ResourceGovernor::live_ir_enabled(
            IntelligencePolicy::DisableDeep
        ));
        assert!(!ResourceGovernor::live_ir_enabled(
            IntelligencePolicy::CaptureAndSttOnly
        ));
    }
}
