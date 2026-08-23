//! Best-effort OS probes for [`ResourceSnapshot`].
//!
//! Missing files or unsupported hosts return an unconstrained snapshot.
//! Recording is never refused by a failed probe.

use crate::governor::{ResourceSnapshot, ThermalBand};

/// Flutter / UI reserve that must remain after the STT model loads.
const APP_HEADROOM_MB: u32 = 512;

/// Read a point-in-time snapshot. Linux fills RAM / battery / thermal when
/// the usual sysfs and proc files exist; every other host is unconstrained.
pub fn probe_resource_snapshot(stt_model_mb: u32) -> ResourceSnapshot {
    #[cfg(target_os = "linux")]
    {
        linux_snapshot(stt_model_mb)
    }
    #[cfg(not(target_os = "linux"))]
    {
        ResourceSnapshot::unconstrained(stt_model_mb)
    }
}

#[cfg(target_os = "linux")]
fn linux_snapshot(stt_model_mb: u32) -> ResourceSnapshot {
    let mut snap = ResourceSnapshot::unconstrained(stt_model_mb);
    snap.app_headroom_mb = APP_HEADROOM_MB;
    snap.stt_model_mb = stt_model_mb;
    if let Ok(meminfo) = std::fs::read_to_string("/proc/meminfo") {
        if let Some((total, available)) = parse_meminfo_mb(&meminfo) {
            snap.total_ram_mb = total;
            snap.available_ram_mb = available;
        }
    }
    if let Some(percent) = read_linux_battery_percent() {
        snap.battery_percent = percent;
    }
    if let Some(thermal) = read_linux_thermal() {
        snap.thermal = thermal;
    }
    snap
}

/// Parse `/proc/meminfo` into `(total_mb, available_mb)`.
pub fn parse_meminfo_mb(contents: &str) -> Option<(u32, u32)> {
    let mut total_kb = None;
    let mut available_kb = None;
    for line in contents.lines() {
        if let Some(kb) = kb_after_label(line, "MemTotal:") {
            total_kb = Some(kb);
        } else if let Some(kb) = kb_after_label(line, "MemAvailable:") {
            available_kb = Some(kb);
        }
    }
    Some((kb_to_mb(total_kb?), kb_to_mb(available_kb?)))
}

fn kb_after_label(line: &str, label: &str) -> Option<u64> {
    let rest = line.strip_prefix(label)?.trim();
    let digits = rest.split_whitespace().next()?;
    digits.parse().ok()
}

fn kb_to_mb(kb: u64) -> u32 {
    (kb / 1024).min(u64::from(u32::MAX)) as u32
}

/// Map millidegree thermal-zone readings to a policy band.
pub fn thermal_from_millideg_c(millideg: i32) -> ThermalBand {
    let c = millideg / 1000;
    if c >= 90 {
        ThermalBand::Critical
    } else if c >= 75 {
        ThermalBand::Hot
    } else if c >= 60 {
        ThermalBand::Warm
    } else {
        ThermalBand::Normal
    }
}

#[cfg(target_os = "linux")]
fn read_linux_battery_percent() -> Option<u8> {
    let Ok(entries) = std::fs::read_dir("/sys/class/power_supply") else {
        return None;
    };
    for entry in entries.flatten() {
        let name = entry.file_name();
        let name = name.to_string_lossy();
        if !name.starts_with("BAT") {
            continue;
        }
        let path = entry.path().join("capacity");
        if let Ok(raw) = std::fs::read_to_string(path) {
            if let Ok(percent) = raw.trim().parse::<u8>() {
                return Some(percent.min(100));
            }
        }
    }
    None
}

#[cfg(target_os = "linux")]
fn read_linux_thermal() -> Option<ThermalBand> {
    let raw = std::fs::read_to_string("/sys/class/thermal/thermal_zone0/temp").ok()?;
    let millideg = raw.trim().parse::<i32>().ok()?;
    Some(thermal_from_millideg_c(millideg))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn meminfo_parses_total_and_available() {
        let sample = "\
MemTotal:       16384000 kB
MemFree:         2000000 kB
MemAvailable:    8192000 kB
";
        assert_eq!(parse_meminfo_mb(sample), Some((16_000, 8_000)));
    }

    #[test]
    fn meminfo_rejects_incomplete() {
        assert_eq!(parse_meminfo_mb("MemTotal: 1024 kB\n"), None);
    }

    #[test]
    fn thermal_bands_match_qualification_thresholds() {
        assert_eq!(thermal_from_millideg_c(45_000), ThermalBand::Normal);
        assert_eq!(thermal_from_millideg_c(60_000), ThermalBand::Warm);
        assert_eq!(thermal_from_millideg_c(75_000), ThermalBand::Hot);
        assert_eq!(thermal_from_millideg_c(90_000), ThermalBand::Critical);
    }

    #[test]
    fn probe_always_returns_a_snapshot() {
        let snap = probe_resource_snapshot(512);
        assert_eq!(snap.stt_model_mb, 512);
        assert!(snap.available_ram_mb > 0);
    }
}
