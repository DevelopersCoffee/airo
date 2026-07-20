use std::collections::HashMap;

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

fn parse_m3u_playlist_str(content: &str) -> M3uPlaylist {
    let bytes = content.as_bytes();
    let mut playlist = M3uPlaylist::default();
    let mut pending: Option<PendingExtInf> = None;
    let mut offset = 0;

    while offset <= bytes.len() {
        let remaining = &bytes[offset..];
        let Some(newline_index) = memchr(b'\n', remaining) else {
            parse_line(&content[offset..], &mut pending, &mut playlist);
            break;
        };

        parse_line(
            &content[offset..offset + newline_index],
            &mut pending,
            &mut playlist,
        );
        offset += newline_index + 1;
    }

    playlist
}

fn parse_line(line: &str, pending: &mut Option<PendingExtInf>, playlist: &mut M3uPlaylist) {
    let line = line.trim();
    if line.starts_with("#EXTINF:") {
        *pending = parse_extinf(line);
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
}
