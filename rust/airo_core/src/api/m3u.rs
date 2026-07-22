use std::collections::HashMap;
use std::fs::File;
use std::io::{BufRead, BufReader};
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
/// devices. Stream/logo URL validation intentionally mirrors
/// `AiroPlaylistUrlPolicy` on the Dart side.
pub fn parse_m3u_channels_with_stats(content: String) -> M3uChannelParseResult {
    channels_from_parse_result(parse_m3u_playlist_str_with_stats(&content))
}

/// Parse an M3U playlist from a file path while retaining only safe aggregate
/// counters for large-playlist import progress reporting.
pub fn parse_m3u_file_with_stats(path: String) -> Result<M3uParseResult, String> {
    let file = File::open(&path)
        .map_err(|error| format!("failed to open M3U playlist file `{path}`: {error}"))?;
    let reader = BufReader::with_capacity(1024 * 1024, file);
    parse_m3u_playlist_reader_with_stats(reader).map_err(|error| error.to_string())
}

/// Parse, validate, normalize, and deduplicate M3U channels from a file path in
/// Rust, avoiding a full raw playlist `String` allocation in Dart first.
pub fn parse_m3u_file_channels_with_stats(path: String) -> Result<M3uChannelParseResult, String> {
    let file = File::open(&path)
        .map_err(|error| format!("failed to open M3U playlist file `{path}`: {error}"))?;
    let reader = BufReader::with_capacity(1024 * 1024, file);
    let result = parse_m3u_playlist_reader_with_stats(reader).map_err(|error| error.to_string())?;
    Ok(channels_from_parse_result(result))
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

fn parse_m3u_playlist_reader_with_stats<R: BufRead>(
    mut reader: R,
) -> std::io::Result<M3uParseResult> {
    let started_at = Instant::now();
    let mut playlist = M3uPlaylist::default();
    let mut pending: Option<PendingExtInf> = None;
    let mut stats = M3uParseStats::default();
    let mut line = String::new();

    loop {
        line.clear();
        let bytes_read = reader.read_line(&mut line)?;
        if bytes_read == 0 {
            break;
        }
        parse_line(&line, &mut pending, &mut playlist, &mut stats);
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

    Ok(M3uParseResult { playlist, stats })
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

fn channels_from_parse_result(result: M3uParseResult) -> M3uChannelParseResult {
    let mut channels = Vec::<M3uChannel>::new();
    let mut seen_channels = HashMap::<String, usize>::new();

    for entry in result.playlist.entries {
        let Some(stream_url) = normalize_stream_url(&entry.url) else {
            continue;
        };

        let normalized_name = normalize_channel_name(&entry.name);
        let logo = entry.logo.as_deref().and_then(normalize_logo_url);
        let channel = M3uChannel {
            name: format_channel_name(&entry.name),
            url: stream_url,
            logo,
            group: entry.group,
            tvg_id: entry.tvg_id,
            tvg_name: entry.tvg_name,
            language: entry.language,
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
        // Known attributes are not duplicated into extras.
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
    fn parses_playlist_from_file_with_stats() {
        let path = std::env::temp_dir().join(format!(
            "airo-core-m3u-file-{}-{}.m3u",
            std::process::id(),
            "reader"
        ));
        std::fs::write(
            &path,
            r#"#EXTM3U x-tvg-url="https://provider.example/guide.xml"
#EXTINF:-1 tvg-id="file.news" group-title="News",File News
https://cdn.example.com/file-news.m3u8
"#,
        )
        .expect("write M3U fixture");

        let result =
            parse_m3u_file_with_stats(path.to_string_lossy().to_string()).expect("valid M3U file");
        let _ = std::fs::remove_file(path);

        assert_eq!(result.playlist.entries.len(), 1);
        assert_eq!(result.playlist.entries[0].name, "File News");
        assert_eq!(
            result.playlist.headers.get("x-tvg-url").map(String::as_str),
            Some("https://provider.example/guide.xml")
        );
        assert_eq!(result.stats.parsed_count, 1);
        assert_eq!(result.stats.skipped_count, 0);
        assert_eq!(result.stats.malformed_count, 0);
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

    #[test]
    fn parses_shaped_channels_from_file_with_stats() {
        let path = std::env::temp_dir().join(format!(
            "airo-core-m3u-file-{}-{}.m3u",
            std::process::id(),
            "channels"
        ));
        std::fs::write(
            &path,
            r#"#EXTM3U
#EXTINF:-1 group-title="News",File Channel
https://cdn.example.com/file-channel.m3u8
"#,
        )
        .expect("write M3U fixture");

        let result = parse_m3u_file_channels_with_stats(path.to_string_lossy().to_string())
            .expect("valid M3U file");
        let _ = std::fs::remove_file(path);

        assert_eq!(result.channels.len(), 1);
        assert_eq!(result.channels[0].name, "File Channel");
        assert_eq!(
            result.channels[0].url,
            "https://cdn.example.com/file-channel.m3u8"
        );
        assert_eq!(result.stats.parsed_count, 1);
    }
}
