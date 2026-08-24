//! Best-effort OS probes for [`ResourceSnapshot`].
//!
//! Missing files, failed commands, or unsupported hosts leave that field on
//! the unconstrained snapshot. Recording is never refused by a failed probe.
//! No `unsafe` — `airo_mind_audio` denies it; hosts are read via files or
//! stock OS commands.

use crate::governor::{ResourceSnapshot, ThermalBand};

/// Flutter / UI reserve that must remain after the STT model loads.
const APP_HEADROOM_MB: u32 = 512;

/// Read a point-in-time snapshot.
///
/// - Linux: `/proc/meminfo`, sysfs battery + thermal
/// - macOS: `sysctl` / `vm_stat` RAM, `pmset` battery when present
/// - Windows: `wmic` RAM + battery when present
/// - Thermal stays Linux-only (no stock command without extra crates)
pub fn probe_resource_snapshot(stt_model_mb: u32) -> ResourceSnapshot {
    #[cfg(target_os = "linux")]
    {
        linux_snapshot(stt_model_mb)
    }
    #[cfg(target_os = "macos")]
    {
        macos_snapshot(stt_model_mb)
    }
    #[cfg(target_os = "windows")]
    {
        windows_snapshot(stt_model_mb)
    }
    #[cfg(not(any(target_os = "linux", target_os = "macos", target_os = "windows")))]
    {
        ResourceSnapshot::unconstrained(stt_model_mb)
    }
}

fn base_snapshot(stt_model_mb: u32) -> ResourceSnapshot {
    let mut snap = ResourceSnapshot::unconstrained(stt_model_mb);
    snap.app_headroom_mb = APP_HEADROOM_MB;
    snap.stt_model_mb = stt_model_mb;
    snap
}

#[cfg(target_os = "linux")]
fn linux_snapshot(stt_model_mb: u32) -> ResourceSnapshot {
    let mut snap = base_snapshot(stt_model_mb);
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

#[cfg(target_os = "macos")]
fn macos_snapshot(stt_model_mb: u32) -> ResourceSnapshot {
    let mut snap = base_snapshot(stt_model_mb);
    if let Some(total) =
        run_text("sysctl", &["-n", "hw.memsize"]).and_then(|raw| parse_sysctl_memsize_mb(&raw))
    {
        snap.total_ram_mb = total;
    }
    if let Some(available) =
        run_text("vm_stat", &[]).and_then(|raw| parse_vm_stat_available_mb(&raw))
    {
        snap.available_ram_mb = available;
    }
    if let Some(percent) =
        run_text("pmset", &["-g", "batt"]).and_then(|raw| parse_pmset_battery_percent(&raw))
    {
        snap.battery_percent = percent;
    }
    snap
}

#[cfg(target_os = "windows")]
fn windows_snapshot(stt_model_mb: u32) -> ResourceSnapshot {
    let mut snap = base_snapshot(stt_model_mb);
    if let Some((total, available)) = run_text(
        "wmic",
        &[
            "OS",
            "get",
            "FreePhysicalMemory,TotalVisibleMemorySize",
            "/Value",
        ],
    )
    .and_then(|raw| parse_wmic_memory_mb(&raw))
    {
        snap.total_ram_mb = total;
        snap.available_ram_mb = available;
    }
    if let Some(percent) = run_text(
        "wmic",
        &[
            "path",
            "Win32_Battery",
            "get",
            "EstimatedChargeRemaining",
            "/Value",
        ],
    )
    .and_then(|raw| parse_wmic_battery_percent(&raw))
    {
        snap.battery_percent = percent;
    }
    snap
}

#[cfg(any(target_os = "macos", target_os = "windows"))]
fn run_text(program: &str, args: &[&str]) -> Option<String> {
    let output = std::process::Command::new(program)
        .args(args)
        .output()
        .ok()?;
    if !output.status.success() {
        return None;
    }
    String::from_utf8(output.stdout).ok()
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

/// `sysctl -n hw.memsize` prints total RAM in bytes.
pub fn parse_sysctl_memsize_mb(raw: &str) -> Option<u32> {
    let bytes: u64 = raw.trim().parse().ok()?;
    Some(bytes_to_mb(bytes))
}

/// `vm_stat` free + inactive + speculative pages → available MB.
pub fn parse_vm_stat_available_mb(raw: &str) -> Option<u32> {
    let page_size = parse_vm_stat_page_size(raw)?;
    let free = pages_after_label(raw, "Pages free:")?;
    let inactive = pages_after_label(raw, "Pages inactive:").unwrap_or(0);
    let speculative = pages_after_label(raw, "Pages speculative:").unwrap_or(0);
    let bytes = free
        .saturating_add(inactive)
        .saturating_add(speculative)
        .saturating_mul(page_size);
    Some(bytes_to_mb(bytes))
}

/// `pmset -g batt` line such as `87%; discharging`.
pub fn parse_pmset_battery_percent(raw: &str) -> Option<u8> {
    for token in raw.split([' ', '\t', ';', '\n', '\r']) {
        let trimmed = token.trim();
        let Some(digits) = trimmed.strip_suffix('%') else {
            continue;
        };
        if let Ok(percent) = digits.parse::<u8>() {
            return Some(percent.min(100));
        }
    }
    None
}

/// `wmic OS get FreePhysicalMemory,TotalVisibleMemorySize /Value` (KB).
pub fn parse_wmic_memory_mb(raw: &str) -> Option<(u32, u32)> {
    let total = wmic_u64(raw, "TotalVisibleMemorySize")?;
    let available = wmic_u64(raw, "FreePhysicalMemory")?;
    Some((kb_to_mb(total), kb_to_mb(available)))
}

/// `wmic path Win32_Battery get EstimatedChargeRemaining /Value`.
pub fn parse_wmic_battery_percent(raw: &str) -> Option<u8> {
    let value = wmic_u64(raw, "EstimatedChargeRemaining")?;
    if value > 100 {
        return None;
    }
    Some(value as u8)
}

fn parse_vm_stat_page_size(raw: &str) -> Option<u64> {
    let key = "page size of ";
    let start = raw.find(key)? + key.len();
    let rest = raw[start..].split_whitespace().next()?;
    rest.parse().ok()
}

fn pages_after_label(raw: &str, label: &str) -> Option<u64> {
    for line in raw.lines() {
        let Some(rest) = line.trim().strip_prefix(label) else {
            continue;
        };
        let digits = rest.trim().trim_end_matches('.').replace(',', "");
        if let Ok(n) = digits.parse::<u64>() {
            return Some(n);
        }
    }
    None
}

fn wmic_u64(raw: &str, key: &str) -> Option<u64> {
    let prefix = format!("{key}=");
    for line in raw.lines() {
        let line = line.trim().trim_start_matches('\u{feff}');
        if let Some(value) = line.strip_prefix(&prefix) {
            let value = value.trim();
            if value.is_empty() {
                return None;
            }
            return value.parse().ok();
        }
    }
    None
}

fn kb_after_label(line: &str, label: &str) -> Option<u64> {
    let rest = line.strip_prefix(label)?.trim();
    let digits = rest.split_whitespace().next()?;
    digits.parse().ok()
}

fn kb_to_mb(kb: u64) -> u32 {
    (kb / 1024).min(u64::from(u32::MAX)) as u32
}

fn bytes_to_mb(bytes: u64) -> u32 {
    (bytes / 1024 / 1024).min(u64::from(u32::MAX)) as u32
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
    fn sysctl_memsize_parses_bytes() {
        assert_eq!(parse_sysctl_memsize_mb("17179869184\n"), Some(16_384));
        assert_eq!(parse_sysctl_memsize_mb("not-a-number"), None);
    }

    #[test]
    fn vm_stat_sums_reclaimable_pages() {
        let sample = "\
Mach Virtual Memory Statistics: (page size of 16384 bytes)
Pages free:                                65536.
Pages active:                             100000.
Pages inactive:                            32768.
Pages speculative:                          4096.
Pages wired down:                          20000.
";
        // (65536 + 32768 + 4096) * 16384 / 1024 / 1024 = 1600
        assert_eq!(parse_vm_stat_available_mb(sample), Some(1_600));
    }

    #[test]
    fn pmset_reads_internal_battery_percent() {
        let sample = "\
Now drawing from 'Battery Power'
 -InternalBattery-0 (id=123)	87%; discharging; 3:45 remaining present: true
";
        assert_eq!(parse_pmset_battery_percent(sample), Some(87));
        assert_eq!(parse_pmset_battery_percent("no battery listed"), None);
    }

    #[test]
    fn wmic_memory_parses_kb_fields() {
        let sample = "\
FreePhysicalMemory=8388608\r
TotalVisibleMemorySize=16777216\r
";
        assert_eq!(parse_wmic_memory_mb(sample), Some((16_384, 8_192)));
        assert_eq!(parse_wmic_memory_mb("FreePhysicalMemory=\n"), None);
    }

    #[test]
    fn wmic_battery_parses_charge() {
        assert_eq!(
            parse_wmic_battery_percent("EstimatedChargeRemaining=42\r\n"),
            Some(42)
        );
        assert_eq!(
            parse_wmic_battery_percent("EstimatedChargeRemaining=\r\n"),
            None
        );
        assert_eq!(
            parse_wmic_battery_percent("EstimatedChargeRemaining=250\r\n"),
            None
        );
    }

    #[test]
    fn probe_always_returns_a_snapshot() {
        let snap = probe_resource_snapshot(512);
        assert_eq!(snap.stt_model_mb, 512);
        assert!(snap.available_ram_mb > 0);
    }
}
