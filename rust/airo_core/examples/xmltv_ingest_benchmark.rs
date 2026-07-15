use std::fs::File;
use std::io::BufReader;
use std::path::PathBuf;
use std::time::Instant;

use airo_core::api::xmltv::parse_xmltv_programmes_reader;

fn main() {
    let config = match Config::parse(std::env::args().skip(1).collect()) {
        Ok(config) => config,
        Err(error) => {
            eprintln!("{error}");
            eprintln!(
                "Usage: cargo run -p airo_core --example xmltv_ingest_benchmark -- \
                 <xmltv-file> [--max-programmes 0]"
            );
            std::process::exit(2);
        }
    };

    let metadata = std::fs::metadata(&config.fixture_path).unwrap_or_else(|error| {
        panic!(
            "failed to read XMLTV fixture metadata at {}: {error}",
            config.fixture_path.display()
        )
    });
    let file = File::open(&config.fixture_path).unwrap_or_else(|error| {
        panic!(
            "failed to open XMLTV fixture at {}: {error}",
            config.fixture_path.display()
        )
    });
    let reader = BufReader::with_capacity(1024 * 1024, file);

    let baseline_rss = max_rss_bytes();
    let started = Instant::now();
    let result = parse_xmltv_programmes_reader(reader, config.max_programmes)
        .unwrap_or_else(|error| panic!("failed to parse XMLTV fixture: {error}"));
    let elapsed = started.elapsed();
    let peak_rss = max_rss_bytes();

    println!("{{");
    println!("  \"schemaVersion\": \"1.0.0\",");
    println!(
        "  \"fixturePath\": \"{}\",",
        json_string(&config.fixture_path.display().to_string())
    );
    println!("  \"byteCount\": {},", metadata.len());
    println!("  \"maxProgrammes\": {},", config.max_programmes);
    println!("  \"storedProgrammes\": {},", result.programmes.len());
    println!("  \"programmeCount\": {},", result.stats.programme_count);
    println!(
        "  \"skippedProgrammeCount\": {},",
        result.stats.skipped_programme_count
    );
    println!("  \"truncated\": {},", result.stats.truncated);
    println!("  \"wallTimeMs\": {},", elapsed.as_millis());
    match baseline_rss {
        Some(bytes) => println!("  \"baselineMaxRssBytes\": {bytes},"),
        None => println!("  \"baselineMaxRssBytes\": null,"),
    }
    match peak_rss {
        Some(bytes) => println!("  \"maxRssBytes\": {bytes},"),
        None => println!("  \"maxRssBytes\": null,"),
    }
    match (baseline_rss, peak_rss) {
        (Some(baseline), Some(peak)) => {
            println!("  \"maxRssDeltaBytes\": {}", peak.saturating_sub(baseline));
        }
        _ => println!("  \"maxRssDeltaBytes\": null"),
    }
    println!("}}");
}

struct Config {
    fixture_path: PathBuf,
    max_programmes: usize,
}

impl Config {
    fn parse(args: Vec<String>) -> Result<Self, String> {
        let mut fixture_path = None;
        let mut max_programmes = 0usize;
        let mut index = 0;

        while index < args.len() {
            match args[index].as_str() {
                "--help" | "-h" => return Err("XMLTV ingest benchmark".to_string()),
                "--max-programmes" => {
                    index += 1;
                    let value = args
                        .get(index)
                        .ok_or_else(|| "missing value for --max-programmes".to_string())?;
                    max_programmes = value.parse().map_err(|_| {
                        format!("invalid --max-programmes value `{value}`; expected integer")
                    })?;
                }
                arg if arg.starts_with('-') => {
                    return Err(format!("unknown argument `{arg}`"));
                }
                path => {
                    if fixture_path.is_some() {
                        return Err(format!("unexpected extra fixture path `{path}`"));
                    }
                    fixture_path = Some(PathBuf::from(path));
                }
            }
            index += 1;
        }

        Ok(Self {
            fixture_path: fixture_path.ok_or_else(|| "missing XMLTV fixture path".to_string())?,
            max_programmes,
        })
    }
}

fn json_string(value: &str) -> String {
    value
        .replace('\\', "\\\\")
        .replace('"', "\\\"")
        .replace('\n', "\\n")
        .replace('\r', "\\r")
}

#[cfg(any(target_os = "linux", target_os = "android"))]
fn max_rss_bytes() -> Option<i64> {
    let mut usage = std::mem::MaybeUninit::<libc::rusage>::uninit();
    // SAFETY: getrusage writes a rusage struct when called with RUSAGE_SELF and
    // a valid pointer. `usage` is initialized only after a zero return code.
    let result = unsafe { libc::getrusage(libc::RUSAGE_SELF, usage.as_mut_ptr()) };
    if result == 0 {
        // SAFETY: getrusage succeeded and initialized `usage`.
        let usage = unsafe { usage.assume_init() };
        Some(usage.ru_maxrss.saturating_mul(1024))
    } else {
        None
    }
}

#[cfg(any(target_os = "macos", target_os = "ios"))]
fn max_rss_bytes() -> Option<i64> {
    let mut usage = std::mem::MaybeUninit::<libc::rusage>::uninit();
    // SAFETY: getrusage writes a rusage struct when called with RUSAGE_SELF and
    // a valid pointer. `usage` is initialized only after a zero return code.
    let result = unsafe { libc::getrusage(libc::RUSAGE_SELF, usage.as_mut_ptr()) };
    if result == 0 {
        // SAFETY: getrusage succeeded and initialized `usage`.
        let usage = unsafe { usage.assume_init() };
        Some(usage.ru_maxrss)
    } else {
        None
    }
}

#[cfg(not(any(
    target_os = "linux",
    target_os = "android",
    target_os = "macos",
    target_os = "ios"
)))]
fn max_rss_bytes() -> Option<i64> {
    None
}
