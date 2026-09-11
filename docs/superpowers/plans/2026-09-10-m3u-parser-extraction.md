# M3U Parser Extraction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract the M3U/M3U8 playlist parser into a standalone, publishable
Flutter+Rust package (`packages/m3u_parser`) with no impact on the running
Aika Stream (Airo TV) app, since nothing consumes it yet.

**Architecture:** Fork `rust/airo_core/src/api/m3u.rs` (already
self-contained — zero internal `crate::` coupling) into a new minimal Rust
crate at `packages/m3u_parser/rust/`, with its own `flutter_rust_bridge`
codegen and its own cargokit build wiring copied from the proven
`packages/core_native` pattern. Ship a hand-written Dart wrapper mirroring
`core_native/lib/src/m3u.dart`'s native-preferred-with-Dart-fallback
dispatch, minus the file-path parsing API (out of scope per the ADR — file
I/O belongs to the caller). This plan stops at a working, tested,
standalone package; swapping Airo's own packages over to consume it is
issue #1502, explicitly deferred.

**Tech Stack:** Rust (`flutter_rust_bridge` 2.11.1, `memchr`), Dart/Flutter
(ffiPlugin), cargokit (vendored build tool, copied per-package in this
repo's convention), Melos workspace.

**Spec:** [docs/adr/0026-m3u-parser-extraction.md](../../adr/0026-m3u-parser-extraction.md)

## Global Constraints

- Rust: `flutter_rust_bridge = "=2.11.1"` exact pin (must match the
  generator version used, per this repo's existing crates).
- Android: `compileSdk = 37`, `ndkVersion = "27.0.12077973"`, `minSdk = 24`,
  Java 17 — must track `gradle/libs.versions.toml` `airo-compile-sdk`.
- iOS: platform `11.0`. macOS: platform `10.15`.
- Dart SDK: `^3.12.2`, `flutter: ">=3.0.0"` (matches every other package
  here).
- Package scope: parser only. No file-path API, no HTTP fetch, no caching,
  no `ChannelVariantClassifier`/dedup-ranking logic — those stay in
  `platform_playlist_import`.
- No isolate spawning inside the package (per `CLAUDE.md`'s off-main
  parsing rule) — pure functions only; the README must say so explicitly.
- Nothing in this plan changes `app/`, `core_native`, or
  `platform_playlist_import` — the new package is additive and unconsumed.
  Every task that could plausibly affect the running app ends with an
  explicit "Aika Stream regression check" step, and Task 7 runs a final
  whole-workspace one.
- `publish_to: none` for now — the pub.dev publish itself is gated on issue
  #1501 (publishing pipeline), not part of this plan.

---

### Task 1: Fork the Rust parser into its own crate

**Files:**
- Create: `packages/m3u_parser/rust/Cargo.toml`
- Create: `packages/m3u_parser/rust/.gitignore`
- Create: `packages/m3u_parser/rust/src/lib.rs`
- Create: `packages/m3u_parser/rust/src/api/mod.rs`
- Create: `packages/m3u_parser/rust/src/api/m3u.rs`

**Interfaces:**
- Produces (consumed by Task 2's FRB codegen and Task 6's benchmark): pure
  functions `parse_m3u_entries(content: String) -> Vec<M3uEntry>`,
  `parse_m3u_playlist(content: String) -> M3uPlaylist`,
  `parse_m3u_with_stats(content: String) -> M3uParseResult`,
  `parse_m3u_channels_with_stats(content: String) -> M3uChannelParseResult`,
  all in `crate::api::m3u`. Types `M3uEntry`, `M3uPlaylist`,
  `M3uParseStats`, `M3uParseResult`, `M3uChannel`, `M3uChannelParseResult`
  (all `pub`, `Clone + Debug + Eq + PartialEq`, several `Default`).

This ports already-proven logic (verbatim from
`rust/airo_core/src/api/m3u.rs`, which has zero internal `crate::`
dependencies) — the file-path functions (`parse_m3u_file_with_stats`,
`parse_m3u_file_channels_with_stats`) and their shared reader helper are
dropped per the ADR's "no file API" scope decision, since they're now
unused. Tests are expected to pass immediately, not follow a red/green
cycle — there's no new behavior here, only relocation.

- [ ] **Step 1: Create the crate manifest**

```toml
# packages/m3u_parser/rust/Cargo.toml
[package]
name = "m3u_parser"
version = "0.1.0"
edition = "2021"
description = "M3U/M3U8 playlist parser — Rust core with an identical pure-Dart fallback"
license = "MIT"

[lib]
name = "m3u_parser"
crate-type = ["cdylib", "staticlib", "rlib"]

[dependencies]
flutter_rust_bridge = "=2.11.1"
memchr = "2"

[dev-dependencies]
criterion = "0.5"

[[bench]]
name = "m3u_parser"
harness = false
```

```gitignore
# packages/m3u_parser/rust/.gitignore
target
```

- [ ] **Step 2: Create the crate entry point**

```rust
// packages/m3u_parser/rust/src/lib.rs
// m3u_parser — FFI entry point.
// All public functions exposed to Flutter must be declared in api/ modules.
// No panics across the FFI boundary; use Result types.

pub mod api;
```

Note: `mod frb_generated;` is deliberately **not** added yet — that file
doesn't exist until Task 2 generates it, and adding the declaration first
would break compilation. Task 2 adds it.

```rust
// packages/m3u_parser/rust/src/api/mod.rs
// Public API surface — these functions are exposed to Flutter via FFI.
// Rules:
//   - No panics. Use anyhow::Result or plain return values.
//   - Every function must have a pure-Dart fallback path on the Dart side.

pub mod m3u;
```

- [ ] **Step 3: Fork the parser**

```rust
// packages/m3u_parser/rust/src/api/m3u.rs
use std::collections::HashMap;
use std::time::Instant;

use memchr::memchr;

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct M3uEntry {
    pub name: String,
    pub url: String,
    pub logo: Option<String>,
    pub group: Option<String>,
    pub tvg_id: Option<String>,
    pub tvg_name: Option<String>,
    pub language: Option<String>,
    /// EXTINF duration in seconds. `-1` means live/unknown; a positive value
    /// indicates VOD. `None` when absent or unparseable.
    pub duration: Option<i64>,
    /// EXTINF attributes outside the known set (e.g. `tvg-chno`,
    /// `catchup-days`, `radio`), preserved instead of dropped.
    pub extras: HashMap<String, String>,
}

/// Full parse result: channel entries plus attributes from the `#EXTM3U`
/// header line (e.g. `x-tvg-url` / `url-tvg` EPG source URLs).
#[derive(Clone, Debug, Default, Eq, PartialEq)]
pub struct M3uPlaylist {
    pub entries: Vec<M3uEntry>,
    pub headers: HashMap<String, String>,
}

/// Aggregate-only results for a playlist parse. These counters deliberately
/// contain no source URL, channel name, or other user playlist content so they
/// can safely be used in import progress and release diagnostics.
#[derive(Clone, Debug, Default, Eq, PartialEq)]
pub struct M3uParseStats {
    pub parsed_count: u32,
    pub skipped_count: u32,
    pub malformed_count: u32,
    pub elapsed_millis: i64,
}

#[derive(Clone, Debug, Default, Eq, PartialEq)]
pub struct M3uParseResult {
    pub playlist: M3uPlaylist,
    pub stats: M3uParseStats,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct M3uChannel {
    pub name: String,
    pub url: String,
    pub logo: Option<String>,
    pub group: Option<String>,
    pub tvg_id: Option<String>,
    pub tvg_name: Option<String>,
    pub language: Option<String>,
    pub aliases: Vec<String>,
    pub country: Option<String>,
    pub provider: Option<String>,
    pub tags: Vec<String>,
}

#[derive(Clone, Debug, Default, Eq, PartialEq)]
pub struct M3uChannelParseResult {
    pub channels: Vec<M3uChannel>,
    pub stats: M3uParseStats,
}

#[flutter_rust_bridge::frb(ignore)]
#[derive(Clone, Debug, Default, Eq, PartialEq)]
struct PendingExtInf {
    name: String,
    logo: Option<String>,
    group: Option<String>,
    tvg_id: Option<String>,
    tvg_name: Option<String>,
    language: Option<String>,
    duration: Option<i64>,
    extras: HashMap<String, String>,
}

pub fn parse_m3u_entries(content: String) -> Vec<M3uEntry> {
    parse_m3u_playlist(content).entries
}

pub fn parse_m3u_playlist(content: String) -> M3uPlaylist {
    parse_m3u_playlist_str(&content)
}

/// Parse through the same Rust parser while retaining only safe aggregate
/// counters for large-playlist import progress reporting.
pub fn parse_m3u_with_stats(content: String) -> M3uParseResult {
    parse_m3u_playlist_str_with_stats(&content)
}

/// Parse, validate, normalize, and deduplicate M3U channels in Rust.
///
/// Native imports use this API to keep large playlist shaping off the Dart
/// isolate and reduce duplicated temporary allocations on constrained TV
/// devices.
pub fn parse_m3u_channels_with_stats(content: String) -> M3uChannelParseResult {
    channels_from_parse_result(parse_m3u_playlist_str_with_stats(&content))
}

fn parse_m3u_playlist_str(content: &str) -> M3uPlaylist {
    parse_m3u_playlist_str_with_stats(content).playlist
}

fn parse_m3u_playlist_str_with_stats(content: &str) -> M3uParseResult {
    let started_at = Instant::now();
    let bytes = content.as_bytes();
    let mut playlist = M3uPlaylist::default();
    let mut pending: Option<PendingExtInf> = None;
    let mut stats = M3uParseStats::default();
    let mut offset = 0;

    while offset <= bytes.len() {
        let remaining = &bytes[offset..];
        let Some(newline_index) = memchr(b'\n', remaining) else {
            parse_line(&content[offset..], &mut pending, &mut playlist, &mut stats);
            break;
        };

        parse_line(
            &content[offset..offset + newline_index],
            &mut pending,
            &mut playlist,
            &mut stats,
        );
        offset += newline_index + 1;
    }

    if pending.is_some() {
        stats.skipped_count += 1;
    }
    stats.parsed_count = playlist.entries.len().try_into().unwrap_or(u32::MAX);
    stats.elapsed_millis = started_at
        .elapsed()
        .as_millis()
        .try_into()
        .unwrap_or(i64::MAX);

    M3uParseResult { playlist, stats }
}

fn parse_line(
    line: &str,
    pending: &mut Option<PendingExtInf>,
    playlist: &mut M3uPlaylist,
    stats: &mut M3uParseStats,
) {
    let line = line.trim();
    if line.starts_with("#EXTINF:") {
        if pending.is_some() {
            stats.skipped_count += 1;
        }
        match parse_extinf(line) {
            Some(entry) => *pending = Some(entry),
            None => {
                stats.malformed_count += 1;
                *pending = None;
            }
        }
        return;
    }

    if let Some(header_attributes) = line.strip_prefix("#EXTM3U") {
        for (key, value) in AttributeIter::new(header_attributes) {
            playlist.headers.insert(key.to_string(), value.to_string());
        }
        return;
    }

    if line.is_empty() || line.starts_with('#') {
        return;
    }

    if let Some(info) = pending.take() {
        playlist.entries.push(M3uEntry {
            name: info.name,
            url: line.to_string(),
            logo: info.logo,
            group: info.group,
            tvg_id: info.tvg_id,
            tvg_name: info.tvg_name,
            language: info.language,
            duration: info.duration,
            extras: info.extras,
        });
    }
}

fn parse_extinf(line: &str) -> Option<PendingExtInf> {
    let comma_index = line.rfind(',')?;
    let name = line[comma_index + 1..].trim().to_string();

    let head = line["#EXTINF:".len()..comma_index].trim_start();
    let duration_token = head.split([' ', '\t']).next().unwrap_or("");
    let duration = duration_token.parse::<i64>().ok();

    let mut info = PendingExtInf {
        name,
        duration,
        ..PendingExtInf::default()
    };

    for (key, value) in AttributeIter::new(&line[..comma_index]) {
        match key {
            "tvg-logo" => info.logo = Some(value.to_string()),
            "group-title" => info.group = Some(value.to_string()),
            "tvg-id" => info.tvg_id = Some(value.to_string()),
            "tvg-name" => info.tvg_name = Some(value.to_string()),
            "tvg-language" => info.language = Some(value.to_string()),
            _ => {
                info.extras.insert(key.to_string(), value.to_string());
            }
        }
    }

    Some(info)
}

struct AttributeIter<'a> {
    line: &'a str,
    offset: usize,
}

impl<'a> AttributeIter<'a> {
    fn new(line: &'a str) -> Self {
        Self { line, offset: 0 }
    }
}

impl<'a> Iterator for AttributeIter<'a> {
    type Item = (&'a str, &'a str);

    fn next(&mut self) -> Option<Self::Item> {
        let bytes = self.line.as_bytes();

        while self.offset < bytes.len() {
            while self.offset < bytes.len() && !is_attr_key_byte(bytes[self.offset]) {
                self.offset += 1;
            }

            let key_start = self.offset;
            while self.offset < bytes.len() && is_attr_key_byte(bytes[self.offset]) {
                self.offset += 1;
            }

            if key_start == self.offset || self.offset + 1 >= bytes.len() {
                continue;
            }

            if bytes[self.offset] != b'=' || bytes[self.offset + 1] != b'"' {
                continue;
            }

            let key_end = self.offset;
            self.offset += 2;
            let value_start = self.offset;
            let Some(relative_end) = memchr(b'"', &bytes[value_start..]) else {
                self.offset = bytes.len();
                return None;
            };

            let value_end = value_start + relative_end;
            self.offset = value_end + 1;
            return Some((
                &self.line[key_start..key_end],
                &self.line[value_start..value_end],
            ));
        }

        None
    }
}

fn is_attr_key_byte(byte: u8) -> bool {
    byte.is_ascii_alphanumeric() || byte == b'_' || byte == b'-'
}

fn channel_aliases(tvg_name: Option<&str>, tvg_id: Option<&str>) -> Vec<String> {
    let mut aliases = Vec::new();
    for value in [tvg_name, tvg_id].into_iter().flatten() {
        let value = value.trim();
        if !value.is_empty() && !aliases.iter().any(|alias| alias == value) {
            aliases.push(value.to_string());
        }
    }
    aliases
}

fn first_extra(extras: &HashMap<String, String>, keys: &[&str]) -> Option<String> {
    keys.iter()
        .find_map(|key| extras.get(*key))
        .map(|value| value.trim())
        .filter(|value| !value.is_empty())
        .map(str::to_string)
}

fn list_extra(extras: &HashMap<String, String>, keys: &[&str]) -> Vec<String> {
    let mut values = Vec::new();
    for raw in keys.iter().filter_map(|key| extras.get(*key)) {
        for value in raw.split([',', ';', '|']) {
            let value = value.trim();
            if !value.is_empty() && !values.iter().any(|existing| existing == value) {
                values.push(value.to_string());
            }
        }
    }
    values
}

fn channels_from_parse_result(result: M3uParseResult) -> M3uChannelParseResult {
    let mut channels = Vec::<M3uChannel>::new();
    let mut seen_channels = HashMap::<String, usize>::new();

    for entry in result.playlist.entries {
        let Some(stream_url) = normalize_stream_url(&entry.url) else {
            continue;
        };

        let normalized_name = normalize_channel_name(&entry.name);
        let logo = entry.logo.as_deref().and_then(normalize_logo_url);
        let aliases = channel_aliases(entry.tvg_name.as_deref(), entry.tvg_id.as_deref());
        let country = first_extra(&entry.extras, &["tvg-country", "country"]);
        let provider = first_extra(&entry.extras, &["provider", "tvg-provider"]);
        let tags = list_extra(&entry.extras, &["tvg-tags", "tags"]);
        let channel = M3uChannel {
            name: format_channel_name(&entry.name),
            url: stream_url,
            logo,
            group: entry.group,
            tvg_id: entry.tvg_id,
            tvg_name: entry.tvg_name,
            language: entry.language,
            aliases,
            country,
            provider,
            tags,
        };

        if let Some(existing_index) = seen_channels.get(&normalized_name).copied() {
            if channels[existing_index].logo.is_none() && channel.logo.is_some() {
                channels[existing_index] = channel;
            }
        } else {
            seen_channels.insert(normalized_name, channels.len());
            channels.push(channel);
        }
    }

    M3uChannelParseResult {
        channels,
        stats: result.stats,
    }
}

fn normalize_channel_name(name: &str) -> String {
    name.chars()
        .filter(|c| c.is_ascii_alphanumeric())
        .map(|c| c.to_ascii_lowercase())
        .collect()
}

fn format_channel_name(name: &str) -> String {
    name.split_whitespace()
        .map(|word| {
            let upper = word.to_uppercase();
            if word.len() <= 4 && word == upper {
                word.to_string()
            } else {
                let mut chars = word.chars();
                let Some(first) = chars.next() else {
                    return String::new();
                };
                format!(
                    "{}{}",
                    first.to_uppercase().collect::<String>(),
                    chars.as_str().to_lowercase()
                )
            }
        })
        .collect::<Vec<_>>()
        .join(" ")
}

fn normalize_stream_url(value: &str) -> Option<String> {
    normalize_network_url(value, true, false)
}

fn normalize_logo_url(value: &str) -> Option<String> {
    normalize_network_url(value, true, false)
}

fn normalize_network_url(
    value: &str,
    allow_http: bool,
    allow_private_hosts: bool,
) -> Option<String> {
    let raw = value.trim();
    if raw.is_empty() {
        return None;
    }

    let (scheme, authority_start) = split_scheme(raw)?;
    let scheme = scheme.to_ascii_lowercase();
    if scheme != "https" && !(allow_http && scheme == "http") {
        return None;
    }

    let authority_end = raw[authority_start..]
        .find(['/', '?', '#'])
        .map(|index| authority_start + index)
        .unwrap_or(raw.len());
    let authority = &raw[authority_start..authority_end];
    if authority.is_empty() || authority.contains('@') {
        return None;
    }

    let host = parse_authority_host(authority)?;
    if !allow_private_hosts && is_private_or_local_host(host) {
        return None;
    }

    Some(raw.to_string())
}

fn split_scheme(raw: &str) -> Option<(&str, usize)> {
    let scheme_end = raw.find(':')?;
    if raw.get(scheme_end + 1..scheme_end + 3)? != "//" {
        return None;
    }
    Some((&raw[..scheme_end], scheme_end + 3))
}

fn parse_authority_host(authority: &str) -> Option<&str> {
    if let Some(rest) = authority.strip_prefix('[') {
        let end = rest.find(']')?;
        let host = &rest[..end];
        if host.is_empty() {
            return None;
        }
        let remaining = &rest[end + 1..];
        if !remaining.is_empty() && !remaining.starts_with(':') {
            return None;
        }
        return Some(host);
    }

    let host = authority.split(':').next().unwrap_or("").trim();
    if host.is_empty() {
        None
    } else {
        Some(host)
    }
}

fn is_private_or_local_host(host: &str) -> bool {
    let normalized = host.trim().to_ascii_lowercase();
    if normalized.is_empty() {
        return true;
    }
    if normalized == "localhost" || normalized.ends_with(".localhost") {
        return true;
    }
    if normalized.ends_with(".local") {
        return true;
    }

    if let Some(ipv4) = parse_ipv4(&normalized) {
        let first = ipv4[0];
        let second = ipv4[1];
        return first == 0
            || first == 10
            || first == 127
            || (first == 100 && (64..=127).contains(&second))
            || (first == 169 && second == 254)
            || (first == 172 && (16..=31).contains(&second))
            || (first == 192 && second == 168)
            || first >= 224;
    }

    if normalized.contains(':') {
        return normalized == "::"
            || normalized == "::1"
            || normalized == "0:0:0:0:0:0:0:1"
            || normalized.starts_with("fe80:")
            || normalized.starts_with("fc")
            || normalized.starts_with("fd");
    }

    false
}

fn parse_ipv4(host: &str) -> Option<[u8; 4]> {
    let mut octets = [0_u8; 4];
    let mut count = 0;
    for part in host.split('.') {
        if count >= 4 || part.is_empty() {
            return None;
        }
        octets[count] = part.parse::<u8>().ok()?;
        count += 1;
    }
    if count == 4 {
        Some(octets)
    } else {
        None
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn parse_entries(content: &str) -> Vec<M3uEntry> {
        parse_m3u_playlist_str(content).entries
    }

    #[test]
    fn parses_extinf_entry_with_attributes() {
        let entries = parse_entries(
            r#"#EXTM3U
#EXTINF:-1 tvg-id="news.one" tvg-name="News One" tvg-logo="https://example.com/news.png" group-title="News" tvg-language="en",News One
https://example.com/news.m3u8
"#,
        );

        assert_eq!(entries.len(), 1);
        assert_eq!(entries[0].name, "News One");
        assert_eq!(entries[0].url, "https://example.com/news.m3u8");
        assert_eq!(
            entries[0].logo.as_deref(),
            Some("https://example.com/news.png")
        );
        assert_eq!(entries[0].group.as_deref(), Some("News"));
        assert_eq!(entries[0].tvg_id.as_deref(), Some("news.one"));
        assert_eq!(entries[0].tvg_name.as_deref(), Some("News One"));
        assert_eq!(entries[0].language.as_deref(), Some("en"));
    }

    #[test]
    fn ignores_comments_and_entries_without_urls() {
        let entries = parse_entries(
            r#"#EXTM3U
#EXTINF:-1,No Url
#EXTVLCOPT:http-user-agent=demo
#EXTINF:-1,Has Url
https://example.com/has-url.m3u8
"#,
        );

        assert_eq!(entries.len(), 1);
        assert_eq!(entries[0].name, "Has Url");
    }

    #[test]
    fn resets_pending_entry_after_first_uri_line() {
        let entries = parse_entries(
            r#"#EXTM3U
#EXTINF:-1,First
not-a-valid-url
https://example.com/ignored-without-extinf.m3u8
"#,
        );

        assert_eq!(entries.len(), 1);
        assert_eq!(entries[0].name, "First");
        assert_eq!(entries[0].url, "not-a-valid-url");
    }

    #[test]
    fn parses_extinf_duration() {
        let entries = parse_entries(
            r#"#EXTM3U
#EXTINF:-1,Live Channel
https://example.com/live.m3u8
#EXTINF:120 tvg-id="movie.one",VOD Movie
https://example.com/movie.mp4
#EXTINF:,No Duration
https://example.com/noduration.m3u8
"#,
        );

        assert_eq!(entries.len(), 3);
        assert_eq!(entries[0].duration, Some(-1));
        assert_eq!(entries[1].duration, Some(120));
        assert_eq!(entries[2].duration, None);
    }

    #[test]
    fn preserves_unknown_attributes_in_extras() {
        let entries = parse_entries(
            r#"#EXTM3U
#EXTINF:-1 tvg-id="news.one" tvg-chno="42" catchup-days="7" radio="true" tvg-name="News One",News One
https://example.com/news.m3u8
"#,
        );

        assert_eq!(entries.len(), 1);
        assert_eq!(entries[0].extras.len(), 3);
        assert_eq!(
            entries[0].extras.get("tvg-chno").map(String::as_str),
            Some("42")
        );
        assert_eq!(
            entries[0].extras.get("catchup-days").map(String::as_str),
            Some("7")
        );
        assert_eq!(
            entries[0].extras.get("radio").map(String::as_str),
            Some("true")
        );
        assert!(!entries[0].extras.contains_key("tvg-id"));
        assert!(!entries[0].extras.contains_key("tvg-name"));
    }

    #[test]
    fn captures_extm3u_header_attributes() {
        let playlist = parse_m3u_playlist_str(
            r#"#EXTM3U x-tvg-url="https://provider.com/epg.xml" url-tvg="https://provider.com/epg-alt.xml"
#EXTINF:-1,News One
https://example.com/news.m3u8
"#,
        );

        assert_eq!(playlist.entries.len(), 1);
        assert_eq!(playlist.headers.len(), 2);
        assert_eq!(
            playlist.headers.get("x-tvg-url").map(String::as_str),
            Some("https://provider.com/epg.xml")
        );
        assert_eq!(
            playlist.headers.get("url-tvg").map(String::as_str),
            Some("https://provider.com/epg-alt.xml")
        );
    }

    #[test]
    fn bare_extm3u_line_yields_no_headers() {
        let playlist = parse_m3u_playlist_str(
            r#"#EXTM3U
#EXTINF:-1,News One
https://example.com/news.m3u8
"#,
        );

        assert_eq!(playlist.entries.len(), 1);
        assert!(playlist.headers.is_empty());
    }

    #[test]
    fn reports_safe_parse_stats_for_malformed_and_skipped_rows() {
        let result = parse_m3u_playlist_str_with_stats(
            r#"#EXTM3U
#EXTINF:-1 This row has no comma
#EXTINF:-1,Skipped without URL
# a comment does not consume the pending row
#EXTINF:-1,Parsed channel
https://example.com/parsed.m3u8
#EXTINF:-1,Trailing without URL
"#,
        );

        assert_eq!(result.playlist.entries.len(), 1);
        assert_eq!(result.stats.parsed_count, 1);
        assert_eq!(result.stats.skipped_count, 2);
        assert_eq!(result.stats.malformed_count, 1);
        assert!(result.stats.elapsed_millis >= 0);
    }

    #[test]
    fn normalizes_and_deduplicates_channels_in_stable_order() {
        let result = parse_m3u_channels_with_stats(
            r#"#EXTM3U
#EXTINF:-1 group-title="News",News One
https://example.com/news-no-logo.m3u8
#EXTINF:-1 tvg-logo="https://example.com/news.png" group-title="News", news-one
https://example.com/news-logo.m3u8
#EXTINF:-1,  BBC    WORLD   news
https://example.com/bbc-world-news.m3u8
"#
            .to_string(),
        );

        assert_eq!(result.channels.len(), 2);
        assert_eq!(result.channels[0].name, "News-one");
        assert_eq!(result.channels[0].url, "https://example.com/news-logo.m3u8");
        assert_eq!(
            result.channels[0].logo.as_deref(),
            Some("https://example.com/news.png")
        );
        assert_eq!(result.channels[1].name, "BBC World News");
    }

    #[test]
    fn shaped_channels_apply_playlist_url_policy() {
        let result = parse_m3u_channels_with_stats(
            r#"#EXTM3U
#EXTINF:-1,Local File
file:///etc/passwd
#EXTINF:-1,Private Host
http://192.168.1.1/live.m3u8
#EXTINF:-1,Script
javascript:alert(1)
#EXTINF:-1 tvg-logo="file:///private/logo.png",Public Stream
https://cdn.example.com/live.m3u8
#EXTINF:-1,IPv6 Local
http://[fd00::1]/live.m3u8
"#
            .to_string(),
        );

        assert_eq!(result.channels.len(), 1);
        assert_eq!(result.channels[0].name, "Public Stream");
        assert_eq!(result.channels[0].url, "https://cdn.example.com/live.m3u8");
        assert_eq!(result.channels[0].logo, None);
        assert_eq!(result.stats.parsed_count, 5);
    }
}
```

- [ ] **Step 4: Run the ported test suite**

Run: `cd packages/m3u_parser/rust && cargo test`
Expected: PASS — 10 tests (`parses_extinf_entry_with_attributes`,
`ignores_comments_and_entries_without_urls`,
`resets_pending_entry_after_first_uri_line`, `parses_extinf_duration`,
`preserves_unknown_attributes_in_extras`,
`captures_extm3u_header_attributes`, `bare_extm3u_line_yields_no_headers`,
`reports_safe_parse_stats_for_malformed_and_skipped_rows`,
`normalizes_and_deduplicates_channels_in_stable_order`,
`shaped_channels_apply_playlist_url_policy`).

- [ ] **Step 5: Aika Stream regression check**

This crate is not yet referenced by `rust/Cargo.toml`'s workspace members,
any Melos package, or any Android/iOS/macOS build file — it's a fresh
directory nothing points at. Confirm that with:

Run: `grep -rn "m3u_parser" rust/Cargo.toml app/pubspec*.yaml 2>/dev/null`
Expected: no output (zero matches) — proves the app's build graph doesn't
see this crate yet, so it cannot have changed Aika Stream's behavior.

- [ ] **Step 6: Commit**

```bash
git add packages/m3u_parser/rust
git commit -m "feat(m3u_parser): fork the M3U Rust parser into a standalone crate

Ports rust/airo_core/src/api/m3u.rs, which has zero internal crate::
coupling. Drops the file-path functions and their shared reader helper
per ADR-0026's parser-only scope (file I/O belongs to the caller). Not
yet wired into any build — packages/m3u_parser is a fresh, unreferenced
directory at this point.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 2: Generate the FRB bindings and wire them into the crate

**Files:**
- Create: `flutter_rust_bridge_m3u_parser.yaml` (repo root)
- Create: `scripts/regenerate-m3u-parser-frb.sh`
- Modify: `packages/m3u_parser/rust/src/lib.rs`
- Generate (do not hand-write): `packages/m3u_parser/rust/src/frb_generated.rs`,
  `packages/m3u_parser/lib/src/frb_generated.dart`,
  `packages/m3u_parser/lib/src/frb_generated.io.dart`,
  `packages/m3u_parser/lib/src/frb_generated.web.dart`,
  `packages/m3u_parser/lib/src/api/m3u.dart`

**Interfaces:**
- Consumes: Task 1's `crate::api::m3u` public functions/types.
- Produces (consumed by Task 4's hand-written wrapper): `RustLib.init()`
  (async, throws on failure — same shape as `core_native`'s
  `frb.RustLib.init()`), and Dart-side generated functions
  `RustLib.instance.api.crateApiM3UParseM3uEntries({required String
  content})` etc. under `package:m3u_parser/src/api/m3u.dart` (exact
  generated names confirmed only after codegen runs — this is FRB's
  standard `crateApi<Module><Function>` naming convention, already seen in
  `core_native/lib/src/api/m3u.dart`).

- [ ] **Step 1: Write the codegen config**

```yaml
# flutter_rust_bridge_m3u_parser.yaml (repo root)
# m3u_parser's own FRB bridge — a standalone crate/dylib (`libm3u_parser`),
# deliberately separate from airo_core's `libairo_core` so the two can
# coexist in one process without symbol/dylib-name collisions once Airo
# consumes this package (#1502).
rust_root: packages/m3u_parser/rust
rust_input: crate::api
dart_output: packages/m3u_parser/lib/src
rust_output: packages/m3u_parser/rust/src/frb_generated.rs
```

- [ ] **Step 2: Write the regeneration script**

```bash
#!/usr/bin/env bash
# packages/../scripts/regenerate-m3u-parser-frb.sh
# Regenerates m3u_parser's FRB bindings from packages/m3u_parser/rust.
#
# Requires flutter_rust_bridge_codegen 2.11.1 (pinned to match the crate's
# `flutter_rust_bridge = "=2.11.1"` dependency).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="${ROOT}/flutter_rust_bridge_m3u_parser.yaml"

if ! command -v flutter_rust_bridge_codegen >/dev/null 2>&1; then
  echo "Installing flutter_rust_bridge_codegen 2.11.1..."
  cargo install flutter_rust_bridge_codegen --version 2.11.1 --locked --force
fi

export PATH="${HOME}/.cargo/bin:${PATH}"

echo "Regenerating m3u_parser FRB bindings..."
cd "${ROOT}"
flutter_rust_bridge_codegen generate --config-file "${CONFIG}"

echo "Done. Review diffs in:"
echo "  packages/m3u_parser/lib/src/"
echo "  packages/m3u_parser/rust/src/frb_generated.rs"
```

Run: `chmod +x scripts/regenerate-m3u-parser-frb.sh`

- [ ] **Step 3: Run codegen**

Run: `./scripts/regenerate-m3u-parser-frb.sh`
Expected: creates `packages/m3u_parser/rust/src/frb_generated.rs`,
`packages/m3u_parser/lib/src/frb_generated.dart`,
`packages/m3u_parser/lib/src/frb_generated.io.dart`,
`packages/m3u_parser/lib/src/frb_generated.web.dart`,
`packages/m3u_parser/lib/src/api/m3u.dart`. If it instead prints "Done!"
with none of those files created, the `rust_input: crate::api` scan found
nothing — re-check Task 1's `pub mod api;` / `pub mod m3u;` wiring before
continuing (this exact failure mode is called out in
`[[rust-never-shipped-to-flutter]]`'s codegen traps).

- [ ] **Step 4: Wire the generated module into the crate**

```rust
// packages/m3u_parser/rust/src/lib.rs
#![allow(unexpected_cfgs)]

mod frb_generated; /* AUTO INJECTED BY flutter_rust_bridge. This line may not be accurate, and you can change it according to your needs. */
// m3u_parser — FFI entry point.
// All public functions exposed to Flutter must be declared in api/ modules.
// No panics across the FFI boundary; use Result types.

pub mod api;
```

- [ ] **Step 5: Verify the crate still builds and tests pass with the generated glue wired in**

Run: `cd packages/m3u_parser/rust && cargo test`
Expected: PASS — same 10 tests as Task 1, now compiling alongside
`frb_generated.rs`.

- [ ] **Step 6: Aika Stream regression check**

Same as Task 1 Step 5 — this crate and the new root-level config/script are
still unreferenced by anything the app builds.

Run: `grep -rln "m3u_parser" rust/Cargo.toml app/pubspec*.yaml packages/core_native packages/platform_playlist_import 2>/dev/null`
Expected: no output.

- [ ] **Step 7: Commit**

```bash
git add flutter_rust_bridge_m3u_parser.yaml scripts/regenerate-m3u-parser-frb.sh packages/m3u_parser/rust/src/lib.rs packages/m3u_parser/rust/src/frb_generated.rs packages/m3u_parser/lib/src
git commit -m "feat(m3u_parser): generate FRB bindings for the standalone crate

Own rust_root/dart_output/rust_output, separate from core_native's
flutter_rust_bridge.yaml — this is a distinct crate/dylib (libm3u_parser
vs libairo_core), matching the mind_whisper/mind_llama per-engine config
pattern already in this repo. Still unwired into any Dart package or
app build.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 3: Scaffold the Dart package and platform build wiring

**Files:**
- Create: `packages/m3u_parser/pubspec.yaml`
- Create: `packages/m3u_parser/module.yaml`
- Create: `packages/m3u_parser/LICENSE`
- Create: `packages/m3u_parser/CHANGELOG.md`
- Create: `packages/m3u_parser/android/build.gradle`
- Create: `packages/m3u_parser/android/settings.gradle`
- Create: `packages/m3u_parser/android/.gitignore`
- Create: `packages/m3u_parser/ios/m3u_parser.podspec`
- Create: `packages/m3u_parser/ios/Classes/dummy_file.c`
- Create: `packages/m3u_parser/macos/m3u_parser.podspec`
- Create: `packages/m3u_parser/macos/Classes/dummy_file.c`
- Create: `packages/m3u_parser/linux/CMakeLists.txt`
- Create: `packages/m3u_parser/windows/CMakeLists.txt`
- Copy: `packages/core_native/cargokit` → `packages/m3u_parser/cargokit`

**Interfaces:**
- Consumes: nothing from earlier tasks directly (this is build-system
  wiring, parallel to the Rust/Dart code).
- Produces: a package Melos can resolve (`melos bootstrap` picks it up via
  the `packages/**` glob in `melos.yaml` automatically — no registration
  step needed) and, later, a real Android/iOS/macOS/Linux/Windows build
  target once something depends on it.

- [ ] **Step 1: Copy cargokit wholesale**

Run: `cp -r packages/core_native/cargokit packages/m3u_parser/cargokit`

This is the vendored build tool itself (hundreds of files, MIT-licensed,
identical for every ffiPlugin package in this repo — `feature_mind` and
`core_native` each carry their own copy already; this is the established
convention, not a symlink).

- [ ] **Step 2: Write the pubspec**

```yaml
# packages/m3u_parser/pubspec.yaml
name: m3u_parser
description: "M3U/M3U8 playlist parser for Flutter — Rust-accelerated on native platforms with an identical pure-Dart fallback (including web)."
version: 0.1.0
publish_to: none

environment:
  sdk: ^3.12.2
  flutter: ">=3.0.0"

dependencies:
  flutter:
    sdk: flutter
  flutter_rust_bridge: 2.11.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0

flutter:
  plugin:
    platforms:
      android:
        ffiPlugin: true
      ios:
        ffiPlugin: true
      macos:
        ffiPlugin: true
      linux:
        ffiPlugin: true
      windows:
        ffiPlugin: true
```

(Web has no `plugin.platforms.web` entry, matching `core_native` — the FRB
web fallback works through `frb_generated.web.dart`'s conditional import,
not plugin federation. No `analysis_options.yaml` either, matching
`core_native` exactly; generated files self-silence via their own
`// ignore_for_file:` header.)

- [ ] **Step 3: Write the module manifest**

```yaml
# packages/m3u_parser/module.yaml
name: m3u_parser
owner: Platform Architect
reviewers:
  - Chief Architect
  - Rust Architect
  - Chief Open Source Officer
  - Media Intelligence Architect
allowed_dependencies: []
forbidden_dependencies:
  - app
quality_gates: {}
status: pre-wired
```

`status: pre-wired` is required here — per `docs/agents/COUNCIL.md`'s
schema, `scripts/check-package-reachability.py` (#1681) fails CI for any
non-`app`-reachable package with no `status:` set, and this package is
genuinely unreachable until #1502.

- [ ] **Step 4: Write LICENSE and CHANGELOG**

```
# packages/m3u_parser/LICENSE
MIT License

Copyright (c) 2026 DevelopersCoffee

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

```markdown
# packages/m3u_parser/CHANGELOG.md
## 0.1.0

- Initial extraction from Airo's `core_native`/`platform_playlist_import`.
  Not yet published to pub.dev — internal (`publish_to: none`) until the
  publishing pipeline (#1501) exists.
```

- [ ] **Step 5: Android build wiring**

```gradle
// packages/m3u_parser/android/build.gradle
// Cargokit cross-compiles m3u_parser for each Android ABI using the NDK as
// part of the ordinary Gradle build. Mirrors packages/core_native's
// pattern (#1677) with its own crate/dylib so the two never collide.
group = "com.developerscoffee.airo.m3u_parser"
version = "0.1.0"

buildscript {
    repositories { google(); mavenCentral() }
    dependencies { classpath("com.android.tools.build:gradle:8.7.3") }
}

rootProject.allprojects {
    repositories { google(); mavenCentral() }
}

apply plugin: "com.android.library"
apply from: "../cargokit/gradle/plugin.gradle"

cargokit {
    // The crate lives inside this package (packages/m3u_parser/rust), not
    // in the shared rust/ cargo workspace — a pub.dev consumer outside this
    // monorepo needs the source to resolve from inside the package tree.
    manifestDir = "../rust"
    libname = "m3u_parser"
}

android {
    namespace = "com.developerscoffee.airo.m3u_parser"
    // Must track gradle/libs.versions.toml airo-compile-sdk (#1575).
    compileSdk = 37
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        minSdk = 24
    }
}
```

```gradle
// packages/m3u_parser/android/settings.gradle
rootProject.name = 'm3u_parser'
```

```gitignore
# packages/m3u_parser/android/.gitignore
*.iml
.gradle
/local.properties
/.idea/workspace.xml
/.idea/libraries
.DS_Store
/build
/captures
.cxx
```

- [ ] **Step 6: iOS and macOS build wiring**

```c
// packages/m3u_parser/ios/Classes/dummy_file.c
// CocoaPods requires at least one source file in a pod. The runtime itself
// is a Rust static library that cargokit builds and force-loads; nothing
// here is called at run time.
```

```ruby
# packages/m3u_parser/ios/m3u_parser.podspec
#
# Cargokit builds m3u_parser as part of the Xcode build, so it's compiled
# by the normal Flutter build rather than by a script someone has to
# remember to run. Mirrors packages/core_native's pattern (#1677).
#
Pod::Spec.new do |s|
  s.name             = 'm3u_parser'
  s.version          = '0.1.0'
  s.summary          = 'M3U/M3U8 playlist parser — Rust core with a pure-Dart fallback.'
  s.description      = <<-DESC
Parses M3U/M3U8 playlists into structured channel entries. Rust-accelerated
on native platforms, falls back to an identical pure-Dart implementation
when the native bridge is unavailable (including web).
                       DESC
  s.homepage         = 'https://github.com/DevelopersCoffee/airo'
  s.license          = { :type => 'MIT' }
  s.author           = { 'DevelopersCoffee' => 'coffee.devloper@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '11.0'

  s.script_phase = {
    :name => 'Build m3u_parser',
    :script => 'sh "$PODS_TARGET_SRCROOT/../cargokit/build_pod.sh" ../rust m3u_parser',
    :execution_position => :before_compile,
    :input_files => ['${BUILT_PRODUCTS_DIR}/cargokit_phony'],
    :output_files => ["${BUILT_PRODUCTS_DIR}/libm3u_parser.a"],
  }
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    # Flutter.framework does not contain an i386 slice.
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'OTHER_LDFLAGS' => '-force_load ${BUILT_PRODUCTS_DIR}/libm3u_parser.a',
  }
  s.swift_version = '5.0'
end
```

```c
// packages/m3u_parser/macos/Classes/dummy_file.c
// CocoaPods requires at least one source file in a pod. The runtime itself
// is a Rust static library that cargokit builds and force-loads; nothing
// here is called at run time.
```

```ruby
# packages/m3u_parser/macos/m3u_parser.podspec
#
# Cargokit builds m3u_parser as part of the Xcode build, so it's compiled
# by the normal Flutter build rather than by a script someone has to
# remember to run. Mirrors packages/core_native's pattern (#1677).
#
Pod::Spec.new do |s|
  s.name             = 'm3u_parser'
  s.version          = '0.1.0'
  s.summary          = 'M3U/M3U8 playlist parser — Rust core with a pure-Dart fallback.'
  s.description      = <<-DESC
Parses M3U/M3U8 playlists into structured channel entries. Rust-accelerated
on native platforms, falls back to an identical pure-Dart implementation
when the native bridge is unavailable (including web).
                       DESC
  s.homepage         = 'https://github.com/DevelopersCoffee/airo'
  s.license          = { :type => 'MIT' }
  s.author           = { 'DevelopersCoffee' => 'coffee.devloper@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'FlutterMacOS'
  s.platform = :osx, '10.15'
  s.swift_version = '5.0'

  s.script_phase = {
    :name => 'Build m3u_parser',
    :script => 'sh "$PODS_TARGET_SRCROOT/../cargokit/build_pod.sh" ../rust m3u_parser',
    :execution_position => :before_compile,
    :input_files => ['${BUILT_PRODUCTS_DIR}/cargokit_phony'],
    :output_files => ["${BUILT_PRODUCTS_DIR}/libm3u_parser.a"],
  }
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'OTHER_LDFLAGS' => '-force_load ${BUILT_PRODUCTS_DIR}/libm3u_parser.a',
  }
end
```

- [ ] **Step 7: Linux and Windows build wiring**

```cmake
# packages/m3u_parser/linux/CMakeLists.txt
# Cargokit builds m3u_parser as part of the CMake configure/build, so the
# desktop targets need no separate step. Mirrors packages/core_native's
# pattern (#1677).
cmake_minimum_required(VERSION 3.10)

set(PROJECT_NAME "m3u_parser")
project(${PROJECT_NAME} LANGUAGES CXX)

include("${CMAKE_CURRENT_SOURCE_DIR}/../cargokit/cmake/cargokit.cmake")
apply_cargokit(${PROJECT_NAME} ../rust m3u_parser "")

set(m3u_parser_bundled_libraries
  "${m3u_parser_cargokit_lib}"
  PARENT_SCOPE
)
```

```cmake
# packages/m3u_parser/windows/CMakeLists.txt
# Cargokit builds m3u_parser as part of the CMake configure/build, so the
# desktop targets need no separate step. Mirrors packages/core_native's
# pattern (#1677).
cmake_minimum_required(VERSION 3.14)

set(PROJECT_NAME "m3u_parser")
project(${PROJECT_NAME} LANGUAGES CXX)

include("${CMAKE_CURRENT_SOURCE_DIR}/../cargokit/cmake/cargokit.cmake")
apply_cargokit(${PROJECT_NAME} ../rust m3u_parser "")

set(m3u_parser_bundled_libraries
  "${m3u_parser_cargokit_lib}"
  PARENT_SCOPE
)
```

- [ ] **Step 8: Confirm the package resolves in the workspace**

Run: `melos bootstrap`
Expected: succeeds; `packages/m3u_parser` appears in its output (Melos
discovers it via the `packages/**` glob in `melos.yaml` with no manual
registration needed). This runs `dart pub get` across the whole workspace
including `app/` — a failure here would be the first sign of an actual
regression risk, so this step doubles as an early Aika Stream check.

- [ ] **Step 9: Aika Stream regression check**

Run: `grep -rln "m3u_parser" app/pubspec*.yaml app/lib packages/core_native/pubspec.yaml packages/platform_playlist_import/pubspec.yaml 2>/dev/null`
Expected: no output — `app/` and the packages it depends on still don't
reference `m3u_parser` anywhere, so this scaffolding cannot have changed
what ships.

- [ ] **Step 10: Commit**

```bash
git add packages/m3u_parser/pubspec.yaml packages/m3u_parser/module.yaml packages/m3u_parser/LICENSE packages/m3u_parser/CHANGELOG.md packages/m3u_parser/android packages/m3u_parser/ios packages/m3u_parser/macos packages/m3u_parser/linux packages/m3u_parser/windows packages/m3u_parser/cargokit
git commit -m "feat(m3u_parser): scaffold the Dart package and cargokit build wiring

pubspec, module.yaml (status: pre-wired — not yet app-reachable, matching
docs/agents/COUNCIL.md's reachability-gate convention), and
android/ios/macos/linux/windows build hooks copied from core_native's
proven cargokit pattern, renamed to build the standalone m3u_parser
crate/dylib. melos bootstrap resolves the new package; nothing in app/
references it yet.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 4: Write the Dart public API

**Files:**
- Create: `packages/m3u_parser/lib/m3u_parser.dart`
- Create: `packages/m3u_parser/lib/src/m3u_parser.dart`
- Create: `packages/m3u_parser/lib/src/native_bridge.dart`

**Interfaces:**
- Consumes: Task 2's generated `RustLib.init()` and
  `RustLib.instance.api.crateApiM3U*` functions (exact names confirmed
  from the generated `packages/m3u_parser/lib/src/api/m3u.dart` — verify
  and adjust the call sites below to match if codegen's naming differs
  from `core_native`'s observed convention).
- Produces (consumed by Task 5's tests and any future Airo consumer):
  `M3uEntry`, `M3uPlaylist`, `M3uParseStats`, `M3uParseResult`,
  `M3uChannel`, `M3uChannelParseResult` (plain Dart classes),
  `parseM3u(String content) -> M3uPlaylist` (sync, pure Dart),
  `parseM3uWithStats(String content) -> M3uParseResult` (sync),
  `parseM3uChannelsWithStats(String content) -> M3uChannelParseResult`
  (sync), `parseM3uAsync(String content) -> Future<M3uPlaylist>`
  (Rust-preferred, falls back to sync), `parseM3uWithStatsAsync(String
  content) -> Future<M3uParseResult>`,
  `parseM3uChannelsWithStatsAsync(String content) ->
  Future<M3uChannelParseResult>`, `initializeM3uParserBridge() ->
  Future<bool>`.

This ports proven logic from `core_native/lib/src/m3u.dart` (the Dart
fallback parser and native/web dispatch), dropping the `Native`-prefixed
naming (this package *is* the standalone thing now) and the file-path
variants (out of scope). Tests in Task 5 are expected to pass immediately.

- [ ] **Step 1: Write the bridge initializer**

```dart
// packages/m3u_parser/lib/src/native_bridge.dart
import 'package:flutter/foundation.dart' show kIsWeb;

import 'frb_generated.dart' as frb;

bool _initialized = false;
Future<bool>? _initializing;

/// Initializes the Rust bridge. Returns `false` on web (no native bridge
/// exists there) or when the native library fails to load, so callers can
/// fall back to the pure-Dart parser deterministically.
Future<bool> initializeM3uParserBridge() async {
  if (kIsWeb) return false;
  if (_initialized) return true;

  final existing = _initializing;
  if (existing != null) return existing;

  return _initializing = () async {
    try {
      await frb.RustLib.init();
      _initialized = true;
      return true;
    } on Object {
      return false;
    } finally {
      _initializing = null;
    }
  }();
}
```

- [ ] **Step 2: Write the public API and Dart fallback parser**

```dart
// packages/m3u_parser/lib/src/m3u_parser.dart
import 'package:flutter/foundation.dart' show kIsWeb;

import 'api/m3u.dart' as native_m3u;
import 'native_bridge.dart';

class M3uEntry {
  const M3uEntry({
    required this.name,
    required this.url,
    this.logo,
    this.group,
    this.tvgId,
    this.tvgName,
    this.language,
    this.duration,
    this.extras = const {},
  });

  final String name;
  final String url;
  final String? logo;
  final String? group;
  final String? tvgId;
  final String? tvgName;
  final String? language;

  /// EXTINF duration in seconds. `-1` means live/unknown; a positive value
  /// indicates VOD. Null when absent or unparseable.
  final int? duration;

  /// EXTINF attributes outside the known set (e.g. `tvg-chno`,
  /// `catchup-days`, `radio`), preserved instead of dropped.
  final Map<String, String> extras;
}

/// Full parse result: channel entries plus attributes from the `#EXTM3U`
/// header line (e.g. `x-tvg-url` / `url-tvg` EPG source URLs).
class M3uPlaylist {
  const M3uPlaylist({required this.entries, required this.headers});

  final List<M3uEntry> entries;
  final Map<String, String> headers;
}

/// Aggregate-only parser telemetry. Never contains a source URL, channel
/// name, or other playlist content, so it's safe to log or report.
class M3uParseStats {
  const M3uParseStats({
    required this.parsedCount,
    required this.skippedCount,
    required this.malformedCount,
    required this.elapsedMillis,
  });

  final int parsedCount;
  final int skippedCount;
  final int malformedCount;
  final int elapsedMillis;
}

class M3uParseResult {
  const M3uParseResult({required this.playlist, required this.stats});

  final M3uPlaylist playlist;
  final M3uParseStats stats;
}

class M3uChannel {
  const M3uChannel({
    required this.name,
    required this.url,
    this.logo,
    this.group,
    this.tvgId,
    this.tvgName,
    this.language,
    this.aliases = const [],
    this.country,
    this.provider,
    this.tags = const [],
  });

  final String name;
  final String url;
  final String? logo;
  final String? group;
  final String? tvgId;
  final String? tvgName;
  final String? language;
  final List<String> aliases;
  final String? country;
  final String? provider;
  final List<String> tags;
}

class M3uChannelParseResult {
  const M3uChannelParseResult({required this.channels, required this.stats});

  final List<M3uChannel> channels;
  final M3uParseStats stats;
}

/// Parse M3U content (entries + `#EXTM3U` header attributes) with the
/// synchronous, pure-Dart parser. This is the deterministic/test/web path
/// and never touches the native bridge — prefer [parseM3uAsync] when you
/// want Rust acceleration with automatic fallback.
///
/// This package spawns no isolates internally: parses over ~50 KB should be
/// wrapped in your own off-main boundary by the caller.
M3uPlaylist parseM3u(String content) => parseM3uWithStats(content).playlist;

/// Synchronous, pure-Dart parse with aggregate stats.
M3uParseResult parseM3uWithStats(String content) =>
    _dartParseM3uWithStats(content);

/// Synchronous, pure-Dart parse into validated, normalized, deduplicated
/// channel records.
M3uChannelParseResult parseM3uChannelsWithStats(String content) =>
    _dartChannelsFromResult(_dartParseM3uWithStats(content));

/// Parse M3U content through the Rust core parser, falling back to the
/// identical Dart implementation on web or when the native bridge is
/// unavailable.
Future<M3uPlaylist> parseM3uAsync(String content) async =>
    (await parseM3uWithStatsAsync(content)).playlist;

/// Parse and retain aggregate stats through Rust, falling back to the
/// identical Dart implementation when unavailable.
Future<M3uParseResult> parseM3uWithStatsAsync(String content) async {
  if (kIsWeb) {
    return _dartParseM3uWithStats(content);
  }
  if (!await initializeM3uParserBridge()) {
    return _dartParseM3uWithStats(content);
  }
  try {
    final result = await native_m3u.parseM3uWithStats(content: content);
    return M3uParseResult(
      playlist: M3uPlaylist(
        entries: result.playlist.entries.map(_fromNative).toList(),
        headers: result.playlist.headers,
      ),
      stats: M3uParseStats(
        parsedCount: result.stats.parsedCount,
        skippedCount: result.stats.skippedCount,
        malformedCount: result.stats.malformedCount,
        // PlatformInt64 is int on IO and BigInt on web. Native execution is
        // the only path here, but the conversion keeps web builds compiling.
        // ignore: noop_primitive_operations
        elapsedMillis: result.stats.elapsedMillis.toInt(),
      ),
    );
  } on Object {
    return _dartParseM3uWithStats(content);
  }
}

/// Parse, validate, normalize, and deduplicate M3U channels through Rust,
/// falling back to identical Dart behavior when unavailable.
Future<M3uChannelParseResult> parseM3uChannelsWithStatsAsync(
  String content,
) async {
  if (kIsWeb) {
    return _dartChannelsFromResult(_dartParseM3uWithStats(content));
  }
  if (!await initializeM3uParserBridge()) {
    return _dartChannelsFromResult(_dartParseM3uWithStats(content));
  }
  try {
    final result = await native_m3u.parseM3uChannelsWithStats(
      content: content,
    );
    return M3uChannelParseResult(
      channels: result.channels.map(_fromNativeChannel).toList(),
      stats: M3uParseStats(
        parsedCount: result.stats.parsedCount,
        skippedCount: result.stats.skippedCount,
        malformedCount: result.stats.malformedCount,
        // ignore: noop_primitive_operations
        elapsedMillis: result.stats.elapsedMillis.toInt(),
      ),
    );
  } on Object {
    return _dartChannelsFromResult(_dartParseM3uWithStats(content));
  }
}

M3uEntry _fromNative(native_m3u.M3uEntry entry) => M3uEntry(
  name: entry.name,
  url: entry.url,
  logo: entry.logo,
  group: entry.group,
  tvgId: entry.tvgId,
  tvgName: entry.tvgName,
  language: entry.language,
  // ignore: noop_primitive_operations
  duration: entry.duration?.toInt(),
  extras: entry.extras,
);

M3uChannel _fromNativeChannel(native_m3u.M3uChannel channel) => M3uChannel(
  name: channel.name,
  url: channel.url,
  logo: channel.logo,
  group: channel.group,
  tvgId: channel.tvgId,
  tvgName: channel.tvgName,
  language: channel.language,
  aliases: channel.aliases,
  country: channel.country,
  provider: channel.provider,
  tags: channel.tags,
);

M3uChannelParseResult _dartChannelsFromResult(M3uParseResult result) {
  final channels = <M3uChannel>[];
  final seenChannels = <String, M3uChannel>{};

  for (final entry in result.playlist.entries) {
    final streamUri = _normalizeNetworkUrl(entry.url);
    if (streamUri == null) continue;

    final normalizedName = _normalizeChannelName(entry.name);
    final logoUri = entry.logo == null
        ? null
        : _normalizeNetworkUrl(entry.logo!);
    final aliases = {
      if (entry.tvgName?.trim().isNotEmpty ?? false) entry.tvgName!.trim(),
      if (entry.tvgId?.trim().isNotEmpty ?? false) entry.tvgId!.trim(),
    }.toList(growable: false);

    final channel = M3uChannel(
      name: _formatChannelName(entry.name),
      url: streamUri,
      logo: logoUri,
      group: entry.group,
      tvgId: entry.tvgId,
      tvgName: entry.tvgName,
      language: entry.language,
      aliases: aliases,
      country: entry.extras['tvg-country'] ?? entry.extras['country'],
      provider: entry.extras['provider'] ?? entry.extras['tvg-provider'],
      tags: _splitMetadataList(
        entry.extras['tvg-tags'] ?? entry.extras['tags'],
      ),
    );

    final existing = seenChannels[normalizedName];
    if (existing == null) {
      seenChannels[normalizedName] = channel;
    } else if (existing.logo == null && channel.logo != null) {
      seenChannels[normalizedName] = channel;
    }
  }

  channels.addAll(seenChannels.values);
  return M3uChannelParseResult(channels: channels, stats: result.stats);
}

List<String> _splitMetadataList(String? value) {
  if (value == null) return const [];
  return value
      .split(RegExp('[,;|]'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toSet()
      .toList(growable: false);
}

M3uParseResult _dartParseM3uWithStats(String content) {
  final stopwatch = Stopwatch()..start();
  final entries = <M3uEntry>[];
  final headers = <String, String>{};
  _PendingM3uEntry? pending;
  var skippedCount = 0;
  var malformedCount = 0;

  for (final rawLine in content.split('\n')) {
    final line = rawLine.trim();
    if (line.startsWith('#EXTINF:')) {
      if (pending != null) {
        skippedCount++;
      }
      final parsed = _parseExtInf(line);
      if (parsed == null) {
        malformedCount++;
      }
      pending = parsed;
      continue;
    }

    if (line.startsWith('#EXTM3U')) {
      headers.addAll(_parseAttributes(line.substring('#EXTM3U'.length)));
      continue;
    }

    if (line.isEmpty || line.startsWith('#')) {
      continue;
    }

    final info = pending;
    if (info == null) continue;

    entries.add(
      M3uEntry(
        name: info.name,
        url: line,
        logo: info.logo,
        group: info.group,
        tvgId: info.tvgId,
        tvgName: info.tvgName,
        language: info.language,
        duration: info.duration,
        extras: info.extras,
      ),
    );
    pending = null;
  }

  if (pending != null) {
    skippedCount++;
  }
  stopwatch.stop();
  return M3uParseResult(
    playlist: M3uPlaylist(entries: entries, headers: headers),
    stats: M3uParseStats(
      parsedCount: entries.length,
      skippedCount: skippedCount,
      malformedCount: malformedCount,
      elapsedMillis: stopwatch.elapsedMilliseconds,
    ),
  );
}

_PendingM3uEntry? _parseExtInf(String line) {
  final commaIndex = line.lastIndexOf(',');
  if (commaIndex == -1) return null;

  final head = line.substring('#EXTINF:'.length, commaIndex).trimLeft();
  final durationTokenEnd = _indexOfWhitespace(head);
  final durationToken = durationTokenEnd == -1
      ? head
      : head.substring(0, durationTokenEnd);
  final duration = int.tryParse(durationToken);

  final attributes = _parseAttributes(line.substring(0, commaIndex));
  final extras = Map<String, String>.of(attributes)
    ..remove('tvg-logo')
    ..remove('group-title')
    ..remove('tvg-id')
    ..remove('tvg-name')
    ..remove('tvg-language');

  return _PendingM3uEntry(
    name: line.substring(commaIndex + 1).trim(),
    logo: attributes['tvg-logo'],
    group: attributes['group-title'],
    tvgId: attributes['tvg-id'],
    tvgName: attributes['tvg-name'],
    language: attributes['tvg-language'],
    duration: duration,
    extras: extras,
  );
}

int _indexOfWhitespace(String value) {
  for (var index = 0; index < value.length; index++) {
    final codeUnit = value.codeUnitAt(index);
    if (codeUnit == 0x20 || codeUnit == 0x09) {
      return index;
    }
  }
  return -1;
}

/// Scan `key="value"` attribute pairs, mirroring the Rust `AttributeIter`.
Map<String, String> _parseAttributes(String attributes) {
  final result = <String, String>{};
  var index = 0;

  while (index < attributes.length) {
    while (index < attributes.length &&
        !_isAttributeKeyCode(attributes.codeUnitAt(index))) {
      index++;
    }

    final keyStart = index;
    while (index < attributes.length &&
        _isAttributeKeyCode(attributes.codeUnitAt(index))) {
      index++;
    }

    if (keyStart == index || index + 1 >= attributes.length) {
      continue;
    }

    if (attributes.codeUnitAt(index) != 0x3D ||
        attributes.codeUnitAt(index + 1) != 0x22) {
      continue;
    }

    final key = attributes.substring(keyStart, index);
    index += 2;
    final valueStart = index;
    while (index < attributes.length && attributes.codeUnitAt(index) != 0x22) {
      index++;
    }
    if (index >= attributes.length) break;

    result[key] = attributes.substring(valueStart, index);
    index++;
  }

  return result;
}

bool _isAttributeKeyCode(int codeUnit) {
  return (codeUnit >= 0x30 && codeUnit <= 0x39) ||
      (codeUnit >= 0x41 && codeUnit <= 0x5A) ||
      (codeUnit >= 0x61 && codeUnit <= 0x7A) ||
      codeUnit == 0x5F ||
      codeUnit == 0x2D;
}

String? _normalizeNetworkUrl(String value) {
  final raw = value.trim();
  if (raw.isEmpty) return null;

  final uri = Uri.tryParse(raw);
  if (uri == null || !_isAllowedNetworkUri(uri)) return null;
  return uri.toString();
}

bool _isAllowedNetworkUri(Uri uri) {
  if (!uri.hasScheme || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
    return false;
  }

  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'https' && scheme != 'http') {
    return false;
  }

  return !_isPrivateOrLocalHost(uri.host);
}

bool _isPrivateOrLocalHost(String host) {
  final normalized = host.trim().toLowerCase();
  if (normalized.isEmpty) return true;
  if (normalized == 'localhost' || normalized.endsWith('.localhost')) {
    return true;
  }
  if (normalized.endsWith('.local')) return true;

  final ipv4 = _parseIpv4(normalized);
  if (ipv4 != null) {
    final first = ipv4[0];
    final second = ipv4[1];
    return first == 0 ||
        first == 10 ||
        first == 127 ||
        (first == 100 && second >= 64 && second <= 127) ||
        (first == 169 && second == 254) ||
        (first == 172 && second >= 16 && second <= 31) ||
        (first == 192 && second == 168) ||
        first >= 224;
  }

  if (normalized.contains(':')) {
    return normalized == '::' ||
        normalized == '::1' ||
        normalized == '0:0:0:0:0:0:0:1' ||
        normalized.startsWith('fe80:') ||
        normalized.startsWith('fc') ||
        normalized.startsWith('fd');
  }

  return false;
}

List<int>? _parseIpv4(String host) {
  final parts = host.split('.');
  if (parts.length != 4) return null;

  final octets = <int>[];
  for (final part in parts) {
    if (part.isEmpty) return null;
    final octet = int.tryParse(part);
    if (octet == null || octet < 0 || octet > 255) {
      return null;
    }
    octets.add(octet);
  }
  return octets;
}

String _normalizeChannelName(String name) {
  final buffer = StringBuffer();
  for (var i = 0; i < name.length; i++) {
    final codeUnit = name.codeUnitAt(i);

    if (codeUnit >= 0x30 && codeUnit <= 0x39) {
      buffer.writeCharCode(codeUnit);
    } else if (codeUnit >= 0x41 && codeUnit <= 0x5A) {
      buffer.writeCharCode(codeUnit + 0x20);
    } else if (codeUnit >= 0x61 && codeUnit <= 0x7A) {
      buffer.writeCharCode(codeUnit);
    }
  }
  return buffer.toString();
}

String _formatChannelName(String name) {
  final buffer = StringBuffer();
  var index = 0;

  while (index < name.length) {
    while (index < name.length && _isWhitespace(name.codeUnitAt(index))) {
      index++;
    }
    if (index >= name.length) break;

    final wordStart = index;
    while (index < name.length && !_isWhitespace(name.codeUnitAt(index))) {
      index++;
    }

    if (buffer.isNotEmpty) {
      buffer.write(' ');
    }

    final word = name.substring(wordStart, index);
    if (word.length <= 4 && word == word.toUpperCase()) {
      buffer.write(word);
    } else {
      buffer
        ..write(word[0].toUpperCase())
        ..write(word.substring(1).toLowerCase());
    }
  }

  return buffer.toString();
}

bool _isWhitespace(int codeUnit) => codeUnit == 0x20 || codeUnit == 0x09;

class _PendingM3uEntry {
  const _PendingM3uEntry({
    required this.name,
    this.logo,
    this.group,
    this.tvgId,
    this.tvgName,
    this.language,
    this.duration,
    this.extras = const {},
  });

  final String name;
  final String? logo;
  final String? group;
  final String? tvgId;
  final String? tvgName;
  final String? language;
  final int? duration;
  final Map<String, String> extras;
}
```

- [ ] **Step 3: Write the public barrel export**

```dart
// packages/m3u_parser/lib/m3u_parser.dart
library;

export 'src/m3u_parser.dart';
export 'src/native_bridge.dart' show initializeM3uParserBridge;
```

- [ ] **Step 4: Confirm the package analyzes cleanly**

Run: `cd packages/m3u_parser && flutter analyze lib`
Expected: no issues. If the generated `api/m3u.dart` function names don't
match `native_m3u.parseM3uWithStats`/`native_m3u.parseM3uChannelsWithStats`
exactly, this step surfaces it — open the generated file and adjust the
call sites in this task's Step 2 to match (FRB's naming is deterministic
from the Rust function name, but confirm rather than assume).

- [ ] **Step 5: Aika Stream regression check**

Run: `grep -rln "m3u_parser" app/pubspec*.yaml app/lib packages/core_native/lib packages/platform_playlist_import/lib 2>/dev/null`
Expected: no output.

- [ ] **Step 6: Commit**

```bash
git add packages/m3u_parser/lib
git commit -m "feat(m3u_parser): add the public Dart API

parseM3u/parseM3uWithStats/parseM3uChannelsWithStats (sync, pure-Dart) and
their *Async Rust-preferred-with-fallback counterparts, ported from
core_native/lib/src/m3u.dart minus the Native-prefixed naming (this is the
standalone package now) and the file-path variants (out of scope per
ADR-0026). Not yet exported from any package app/ depends on.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 5: Port the test suite and add a parity check

**Files:**
- Create: `packages/m3u_parser/test/m3u_parser_test.dart`
- Create: `packages/m3u_parser/test/m3u_parser_native_parity_test.dart`

**Interfaces:**
- Consumes: `parseM3u`, `parseM3uWithStats`, `parseM3uChannelsWithStats`,
  `parseM3uAsync`, `parseM3uWithStatsAsync`, `initializeM3uParserBridge`
  from Task 4.

- [ ] **Step 1: Port the Dart-fallback test corpus**

```dart
// packages/m3u_parser/test/m3u_parser_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:m3u_parser/m3u_parser.dart';

void main() {
  group('parseM3u (sync, pure-Dart)', () {
    test('parses EXTINF entries with attributes', () {
      final playlist = parseM3u('''
#EXTM3U
#EXTINF:-1 tvg-id="news.one" tvg-name="News One" tvg-logo="https://example.com/news.png" group-title="News" tvg-language="en",News One
https://example.com/news.m3u8
''');

      expect(playlist.entries, hasLength(1));
      final entry = playlist.entries.single;
      expect(entry.name, 'News One');
      expect(entry.url, 'https://example.com/news.m3u8');
      expect(entry.logo, 'https://example.com/news.png');
      expect(entry.group, 'News');
      expect(entry.tvgId, 'news.one');
      expect(entry.tvgName, 'News One');
      expect(entry.language, 'en');
    });

    test('ignores comments and entries without URLs', () {
      final playlist = parseM3u('''
#EXTM3U
#EXTINF:-1,No Url
#EXTVLCOPT:http-user-agent=demo
#EXTINF:-1,Has Url
https://example.com/has-url.m3u8
''');

      expect(playlist.entries, hasLength(1));
      expect(playlist.entries.single.name, 'Has Url');
    });

    test('parses EXTINF duration', () {
      final playlist = parseM3u('''
#EXTM3U
#EXTINF:-1,Live Channel
https://example.com/live.m3u8
#EXTINF:120 tvg-id="movie.one",VOD Movie
https://example.com/movie.mp4
''');

      expect(playlist.entries[0].duration, -1);
      expect(playlist.entries[1].duration, 120);
    });

    test('preserves unknown attributes in extras', () {
      final playlist = parseM3u('''
#EXTM3U
#EXTINF:-1 tvg-id="news.one" tvg-chno="42" catchup-days="7" radio="true" tvg-name="News One",News One
https://example.com/news.m3u8
''');

      final extras = playlist.entries.single.extras;
      expect(extras, hasLength(3));
      expect(extras['tvg-chno'], '42');
      expect(extras['catchup-days'], '7');
      expect(extras['radio'], 'true');
      expect(extras.containsKey('tvg-id'), isFalse);
    });

    test('captures EXTM3U header attributes', () {
      final playlist = parseM3u('''
#EXTM3U x-tvg-url="https://provider.com/epg.xml" url-tvg="https://provider.com/epg-alt.xml"
#EXTINF:-1,News One
https://example.com/news.m3u8
''');

      expect(playlist.headers, hasLength(2));
      expect(playlist.headers['x-tvg-url'], 'https://provider.com/epg.xml');
      expect(
        playlist.headers['url-tvg'],
        'https://provider.com/epg-alt.xml',
      );
    });
  });

  group('parseM3uWithStats', () {
    test('reports safe parse stats for malformed and skipped rows', () {
      final result = parseM3uWithStats('''
#EXTM3U
#EXTINF:-1 This row has no comma
#EXTINF:-1,Skipped without URL
# a comment does not consume the pending row
#EXTINF:-1,Parsed channel
https://example.com/parsed.m3u8
#EXTINF:-1,Trailing without URL
''');

      expect(result.playlist.entries, hasLength(1));
      expect(result.stats.parsedCount, 1);
      expect(result.stats.skippedCount, 2);
      expect(result.stats.malformedCount, 1);
      expect(result.stats.elapsedMillis, greaterThanOrEqualTo(0));
    });
  });

  group('parseM3uChannelsWithStats', () {
    test('normalizes and deduplicates channels, preferring logo entries', () {
      final result = parseM3uChannelsWithStats('''
#EXTM3U
#EXTINF:-1 group-title="News",News One
https://example.com/news-no-logo.m3u8
#EXTINF:-1 tvg-logo="https://example.com/news.png" group-title="News", news-one
https://example.com/news-logo.m3u8
#EXTINF:-1,  BBC    WORLD   news
https://example.com/bbc-world-news.m3u8
''');

      expect(result.channels, hasLength(2));
      expect(result.channels[0].name, 'News-one');
      expect(result.channels[0].url, 'https://example.com/news-logo.m3u8');
      expect(result.channels[0].logo, 'https://example.com/news.png');
      expect(result.channels[1].name, 'BBC World News');
    });

    test('drops disallowed stream and logo URLs', () {
      final result = parseM3uChannelsWithStats('''
#EXTM3U
#EXTINF:-1,Local File
file:///etc/passwd
#EXTINF:-1,Private Host
http://192.168.1.1/live.m3u8
#EXTINF:-1 tvg-logo="file:///private/logo.png",Public Stream
https://cdn.example.com/live.m3u8
''');

      expect(result.channels, hasLength(1));
      expect(result.channels.single.name, 'Public Stream');
      expect(result.channels.single.url, 'https://cdn.example.com/live.m3u8');
      expect(result.channels.single.logo, isNull);
    });
  });
}
```

- [ ] **Step 2: Run the ported Dart test suite**

Run: `cd packages/m3u_parser && flutter test test/m3u_parser_test.dart`
Expected: PASS — 9 tests, all green immediately (proven logic, ported not
newly written).

- [ ] **Step 3: Add the native/Dart-fallback parity check**

```dart
// packages/m3u_parser/test/m3u_parser_native_parity_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:m3u_parser/m3u_parser.dart';

/// Whichever path parseM3uWithStatsAsync actually took (Rust or the Dart
/// fallback — this test doesn't assume which, since the native bridge may
/// or may not load in a given test environment), its output must match the
/// deterministic Dart-only path exactly. This is the parity requirement
/// ADR-0026 calls out under "Which conformance tests become invalid?" — it
/// must hold in Task 5 and keep holding after any future codegen refresh.
const _corpus = '''
#EXTM3U x-tvg-url="https://provider.example/guide.xml"
#EXTINF:-1 tvg-id="news.one" tvg-name="News One" tvg-logo="https://example.com/news.png" group-title="News" tvg-language="en",News One
https://example.com/news.m3u8
#EXTINF:-1 tvg-chno="42" catchup-days="7",Unusual Attrs
https://example.com/unusual.m3u8
#EXTINF:-1,  BBC    WORLD   news
https://example.com/bbc-world-news.m3u8
#EXTINF:-1,Private Host
http://192.168.1.1/live.m3u8
''';

void main() {
  test('async (Rust-preferred) parity with sync Dart fallback', () async {
    final asyncResult = await parseM3uWithStatsAsync(_corpus);
    final syncResult = parseM3uWithStats(_corpus);

    expect(asyncResult.playlist.entries.length, syncResult.playlist.entries.length);
    expect(asyncResult.playlist.headers, syncResult.playlist.headers);
    expect(asyncResult.stats.parsedCount, syncResult.stats.parsedCount);
    expect(asyncResult.stats.skippedCount, syncResult.stats.skippedCount);
    expect(asyncResult.stats.malformedCount, syncResult.stats.malformedCount);

    for (var i = 0; i < syncResult.playlist.entries.length; i++) {
      final a = asyncResult.playlist.entries[i];
      final s = syncResult.playlist.entries[i];
      expect(a.name, s.name);
      expect(a.url, s.url);
      expect(a.logo, s.logo);
      expect(a.group, s.group);
      expect(a.tvgId, s.tvgId);
      expect(a.tvgName, s.tvgName);
      expect(a.language, s.language);
      expect(a.duration, s.duration);
      expect(a.extras, s.extras);
    }
  });

  test('async channel parity with sync Dart fallback', () async {
    final asyncResult = await parseM3uChannelsWithStatsAsync(_corpus);
    final syncResult = parseM3uChannelsWithStats(_corpus);

    expect(asyncResult.channels.length, syncResult.channels.length);
    for (var i = 0; i < syncResult.channels.length; i++) {
      expect(asyncResult.channels[i].name, syncResult.channels[i].name);
      expect(asyncResult.channels[i].url, syncResult.channels[i].url);
      expect(asyncResult.channels[i].logo, syncResult.channels[i].logo);
    }
  });
}
```

- [ ] **Step 4: Run the parity test**

Run: `cd packages/m3u_parser && flutter test test/m3u_parser_native_parity_test.dart`
Expected: PASS. This test environment is the Dart VM, not a compiled
Android/iOS build with the cargokit-built dylib present — expect
`initializeM3uParserBridge()` to fail to load the native library here and
both async functions to silently take the Dart-fallback branch. That's
fine: the test's assertion is Rust/Dart *parity*, not "the Rust path
definitely ran." A real on-device native-path check is a follow-up
(mirroring `core_native`'s own
`test/xmltv_native_bridge_verification_test.dart`, gated behind an env var
and skipped by default), not required here.

- [ ] **Step 5: Run the whole package's test suite together**

Run: `cd packages/m3u_parser && flutter test`
Expected: PASS — 11 tests total (9 from Step 1 + 2 from Step 3).

- [ ] **Step 6: Aika Stream regression check**

Run: `grep -rln "m3u_parser" app/pubspec*.yaml app/lib packages/core_native/lib packages/platform_playlist_import/lib packages/platform_playlist_import/test 2>/dev/null`
Expected: no output.

- [ ] **Step 7: Commit**

```bash
git add packages/m3u_parser/test
git commit -m "test(m3u_parser): port the parser test corpus and add a Rust/Dart parity check

9 tests ported from core_native's Dart-fallback coverage (already-proven
behavior, not new). 2 new parity tests assert parseM3uWithStatsAsync's
output matches the deterministic sync Dart path exactly, whichever branch
it actually took — the conformance requirement ADR-0026 calls out.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 6: Fork the benchmark, write the README, verify the full crate builds

**Files:**
- Create: `packages/m3u_parser/rust/benches/m3u_parser.rs`
- Create: `packages/m3u_parser/README.md`
- Modify: `packages/m3u_parser/rust/Cargo.toml` (already has the `[[bench]]`
  section from Task 1 — no change needed, listed here for traceability)

**Interfaces:**
- Consumes: `m3u_parser::api::m3u::{parse_m3u_entries,
  parse_m3u_channels_with_stats}` from Task 1.

- [ ] **Step 1: Fork the benchmark, dropping the file-based groups**

```rust
// packages/m3u_parser/rust/benches/m3u_parser.rs
use std::fs;

use m3u_parser::api::m3u::{parse_m3u_channels_with_stats, parse_m3u_entries};
use criterion::{black_box, criterion_group, criterion_main, BenchmarkId, Criterion, Throughput};

fn iptv_org_fixture() -> String {
    // Reaches the monorepo's shared fixture — fine for a dev-only bench
    // that never ships as part of the published Dart package. From
    // packages/m3u_parser/rust/benches, climb to the repo root.
    let path = std::path::PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("../../../iptv-data/fixtures/iptv-org/index.m3u");
    fs::read_to_string(&path).unwrap_or_else(|error| {
        panic!("failed to read iptv-org fixture at {}: {error}", path.display())
    })
}

fn bench_m3u_parser(c: &mut Criterion) {
    let fixture = iptv_org_fixture();
    let byte_count = fixture.len() as u64;
    let channel_count = parse_m3u_entries(fixture.clone()).len();

    let mut group = c.benchmark_group("m3u_parser");
    group.throughput(Throughput::Bytes(byte_count));
    group.bench_with_input(
        BenchmarkId::new("iptv_org_index", channel_count),
        &fixture,
        |b, content| {
            b.iter(|| {
                let entries = parse_m3u_entries(black_box(content.clone()));
                black_box(entries.len())
            });
        },
    );
    group.bench_with_input(
        BenchmarkId::new("iptv_org_index_channels", channel_count),
        &fixture,
        |b, content| {
            b.iter(|| {
                let result = parse_m3u_channels_with_stats(black_box(content.clone()));
                black_box(result.channels.len())
            });
        },
    );
    group.finish();
}

criterion_group!(benches, bench_m3u_parser);
criterion_main!(benches);
```

- [ ] **Step 2: Confirm the benchmark compiles and runs**

Run: `cd packages/m3u_parser/rust && cargo bench --bench m3u_parser -- --test`
Expected: exits 0 (`--test` mode runs each benchmark body once for
correctness instead of the full timing loop — fast, and enough to prove
the fork compiles and executes against the real ~2.8 MB iptv-org fixture,
without spending minutes on a full Criterion run).

- [ ] **Step 3: Write the package README**

```markdown
# m3u_parser

M3U/M3U8 playlist parser for Flutter. Rust-accelerated on Android, iOS, and
macOS; falls back to an identical pure-Dart implementation on web or
whenever the native bridge is unavailable.

## Usage

```dart
import 'package:m3u_parser/m3u_parser.dart';

// Synchronous, pure-Dart — works everywhere, including web.
final playlist = parseM3u(m3uContent);

// Rust-preferred with automatic fallback. Prefer this when you don't need
// a guaranteed-synchronous call.
final playlist = await parseM3uAsync(m3uContent);

// Aggregate-only stats (no playlist content), for progress/telemetry.
final result = await parseM3uWithStatsAsync(m3uContent);
print('${result.stats.parsedCount} parsed, ${result.stats.skippedCount} skipped');

// Validated, normalized, deduplicated channel records.
final channels = await parseM3uChannelsWithStatsAsync(m3uContent);
```

## Threading

**This package spawns no isolates internally.** Every function here is a
plain, synchronous-under-the-hood call (the `*Async` variants are async
only because they may cross the FFI boundary, not because they do their
own off-main dispatch). If you're parsing a playlist larger than roughly
50 KB, wrap the call in your own isolate/worker boundary — don't call these
functions directly from a UI-thread hot path. This is a deliberate
constraint, not an oversight: a package with an opinion about isolates
inside it would fight whatever concurrency model its host app already has.

## Scope

This package parses M3U text into structured channel entries. It does not
fetch playlists over HTTP, cache responses, manage multiple playlist
sources, or deduplicate/rank channels across sources — those are
application concerns. If you need HTTP fetching with ETag caching and
BYOC-style source management, that layer is straightforward to build on
top of this package's `parseM3u`/`parseM3uAsync`.

## Platform support

| Platform | Parser used |
|---|---|
| Android, iOS, macOS | Rust (native), Dart fallback if the bridge fails to load |
| Web | Pure Dart (no native bridge exists on web) |
| Linux, Windows | Rust (native), Dart fallback if the bridge fails to load |

## License

MIT
```

- [ ] **Step 4: Aika Stream regression check**

Run: `grep -rln "m3u_parser" app/pubspec*.yaml app/lib packages/core_native packages/platform_playlist_import 2>/dev/null`
Expected: no output — still true at the end of package construction.

- [ ] **Step 5: Commit**

```bash
git add packages/m3u_parser/rust/benches packages/m3u_parser/README.md
git commit -m "docs(m3u_parser): fork the benchmark and write the package README

Benchmark drops the file-based groups (no file API in this package's
scope) but keeps reading the real ~2.8 MB iptv-org fixture — a dev-only
bench never shipped as part of the published Dart package, so reaching
into the monorepo's shared fixture is fine. README documents the
no-internal-isolates constraint explicitly, per CLAUDE.md's off-main
parsing rule, so external consumers don't hit a web isolate crash by
calling this from a UI-thread hot path.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 7: Whole-workspace regression verification

**Files:** none created or modified — this task only runs checks.

**Interfaces:** none — this is a verification-only task, the final gate
before calling the extraction done.

- [ ] **Step 1: Full workspace bootstrap**

Run: `melos bootstrap`
Expected: succeeds with no errors, `packages/m3u_parser` listed among the
resolved packages.

- [ ] **Step 2: Analyze the whole workspace**

Run: `melos run analyze` (or, if that script doesn't exist in this
checkout, `melos exec -- flutter analyze` — check `pubspec.yaml`'s `melos`
scripts section first)
Expected: no new issues anywhere outside `packages/m3u_parser` — this
package's own analyzer pass already happened in Task 4 Step 4.

- [ ] **Step 3: Confirm the existing M3U-adjacent test suites still pass unmodified**

Run: `cd packages/core_native && flutter test`
Run: `cd packages/platform_playlist_import && flutter test`
Expected: both PASS, same test counts as before this plan started (54 for
`platform_playlist_import`, per the prior session's verification) — proves
nothing in the existing M3U code path was touched.

- [ ] **Step 4: Rebuild and reload Aika Stream on web, same manual check as the prior session**

```bash
cd app
cp pubspec_tv.yaml pubspec.yaml
flutter pub get
```

Run: `flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8236 -t lib/main_tv.dart --dart-define=APP_VARIANT=tv --dart-define=APP_PLATFORM=androidTv` in
the background (per this repo's convention for a long-lived dev server;
poll the log for `is being served at` rather than blocking on it).

Once serving, open it in the Browser tool, add
`https://iptv-org.github.io/iptv/index.m3u` as a playlist source (same
steps as the prior session's live verification), and confirm the channel
guide populates exactly as before — this proves the standalone package's
existence in the workspace has zero effect on the shipping app, since nothing
in `app/`'s dependency graph reaches it yet.

Then clean up:

```bash
git checkout -- pubspec.yaml pubspec.lock \
  linux/flutter/generated_plugin_registrant.cc \
  linux/flutter/generated_plugins.cmake \
  macos/Flutter/GeneratedPluginRegistrant.swift \
  windows/flutter/generated_plugin_registrant.cc \
  windows/flutter/generated_plugins.cmake
```

Run: `git status --short` from the repo root
Expected: clean except for this plan's own new files under
`packages/m3u_parser/`, `flutter_rust_bridge_m3u_parser.yaml`, and
`scripts/regenerate-m3u-parser-frb.sh` — the pubspec swap used for the web
check leaves no trace.

- [ ] **Step 5: Final commit**

```bash
git add -A
git status --short
```

Confirm the staged diff is exactly what Tasks 1–6 already committed plus
nothing else, then:

```bash
git commit --allow-empty -m "chore(m3u_parser): confirm workspace-wide regression check is clean

melos bootstrap, workspace analyze, core_native + platform_playlist_import
test suites, and a live Aika Stream web rebuild against
https://iptv-org.github.io/iptv/index.m3u all pass unchanged — the new
package exists in the workspace but nothing in app/'s dependency graph
reaches it yet, so this extraction (up to but not including #1502, Airo's
own consumption of the package) had zero effect on the shipping app.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

(Use `--allow-empty` only if Step 4's cleanup left literally nothing new
to stage beyond what Tasks 1–6 already committed; if `git status --short`
in Step 4 shows anything unexpected, stage and describe that instead of
using an empty commit.)

---

## What this plan deliberately does not do

- **Does not wire Airo to consume the package.** `core_native` and
  `platform_playlist_import` keep their own copies of the parser
  untouched. That's issue #1502, and it's a separate plan — swapping a
  live dependency in is a different risk profile than adding an unused
  sibling package, and deserves its own regression pass once this package
  has proven itself.
- **Does not publish to pub.dev.** `publish_to: none` stays until #1501
  (publishing pipeline) exists.
- **Does not add a Linux/Windows CI job or an on-device Android/iOS build
  verification.** Task 7 verifies what's checkable in this environment
  (host `cargo test`/`cargo bench`, Melos-wide resolution, Dart test
  suites, a web rebuild). A real device build is a natural follow-up once
  something actually depends on this package, matching this repo's own
  documented gap for `core_native` itself (no iOS CI, #1704).
