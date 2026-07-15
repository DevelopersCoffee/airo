/// M3U playlist parser — extracts channel entries from M3U/M3U8 content.
///
/// Parses `#EXTINF` attribute lines and the URL line that follows each one.
/// Returns a flat Vec of [`M3UEntry`] structs ready for the Dart side to map
/// into `IPTVChannel` objects.
///
/// Design constraints (see `mod.rs` header):
///   - No panics.  Malformed lines are silently skipped.
///   - Payload kept small: only the fields the Dart model needs.
///   - Pure-Dart fallback exists in `m3u_parser_service.dart`.

/// A single parsed M3U channel entry.
#[derive(Debug, Clone, PartialEq)]
pub struct M3UEntry {
    pub name: String,
    pub url: String,
    pub group_title: String,
    pub tvg_logo: String,
    pub tvg_id: String,
    pub tvg_name: String,
    pub tvg_language: String,
    pub tvg_country: String,
}

/// Parse M3U content into a list of channel entries.
///
/// Handles the standard `#EXTINF:-1 key="value",...,Channel Name` format
/// followed by a URL line. Lines that don't match are skipped.
///
/// # Examples
/// ```
/// use airo_core::api::m3u::parse_m3u;
///
/// let content = concat!(
///     "#EXTM3U\n",
///     "#EXTINF:-1 tvg-id=\"bbc1\" tvg-name=\"BBC One\" ",
///     "tvg-logo=\"http://logo.png\" group-title=\"News\",BBC News\n",
///     "http://stream.example.com/bbc1\n",
/// );
/// let entries = parse_m3u(content.to_string());
/// assert_eq!(entries.len(), 1);
/// assert_eq!(entries[0].name, "BBC News");
/// ```
pub fn parse_m3u(content: String) -> Vec<M3UEntry> {
    let mut entries = Vec::new();
    let mut pending: Option<PendingEntry> = None;

    for raw_line in content.lines() {
        let line = raw_line.trim();

        if line.starts_with("#EXTINF:") {
            pending = Some(parse_extinf(line));
        } else if !line.is_empty() && !line.starts_with('#') {
            // URL line — only accept http(s) URLs.
            if let Some(entry) = pending.take() {
                if line.starts_with("http://") || line.starts_with("https://") {
                    entries.push(M3UEntry {
                        name: entry.name,
                        url: line.to_string(),
                        group_title: entry.group_title,
                        tvg_logo: entry.tvg_logo,
                        tvg_id: entry.tvg_id,
                        tvg_name: entry.tvg_name,
                        tvg_language: entry.tvg_language,
                        tvg_country: entry.tvg_country,
                    });
                }
            }
            // If no pending EXTINF, skip the line (bare URL without metadata).
        }
    }

    entries
}

// ── Internal helpers ──────────────────────────────────────────────────

/// Intermediate struct holding parsed EXTINF attributes before the URL arrives.
struct PendingEntry {
    name: String,
    group_title: String,
    tvg_logo: String,
    tvg_id: String,
    tvg_name: String,
    tvg_language: String,
    tvg_country: String,
}

/// Parse a single `#EXTINF:` line into a `PendingEntry`.
///
/// Format: `#EXTINF:-1 key="value" key="value"...,Channel Name`
///
/// The channel name is everything after the last comma that is *outside*
/// any quoted attribute value.  Attribute values are extracted with a simple
/// state machine that handles quoted strings.
fn parse_extinf(line: &str) -> PendingEntry {
    // Find the last comma that is outside quotes to split name from attrs.
    let split_idx = find_last_unquoted_comma(line);
    let (attr_part, name) = match split_idx {
        Some(idx) => (&line[..idx], line[idx + 1..].trim().to_string()),
        None => (line, String::new()),
    };

    let attrs = extract_attributes(attr_part);

    PendingEntry {
        name,
        group_title: find_attr(&attrs, "group-title"),
        tvg_logo: find_attr(&attrs, "tvg-logo"),
        tvg_id: find_attr(&attrs, "tvg-id"),
        tvg_name: find_attr(&attrs, "tvg-name"),
        tvg_language: find_attr(&attrs, "tvg-language"),
        tvg_country: find_attr(&attrs, "tvg-country"),
    }
}

/// Find an attribute value by key, returning empty string if not found.
fn find_attr(attrs: &[(String, String)], key: &str) -> String {
    attrs
        .iter()
        .find(|(k, _)| k == key)
        .map(|(_, v)| v.clone())
        .unwrap_or_default()
}

/// Find the last comma in `s` that is not inside a quoted attribute value.
fn find_last_unquoted_comma(s: &str) -> Option<usize> {
    let mut in_quotes = false;
    let mut last_comma = None;

    for (i, c) in s.char_indices() {
        match c {
            '"' => in_quotes = !in_quotes,
            ',' if !in_quotes => last_comma = Some(i),
            _ => {}
        }
    }

    last_comma
}

/// Extract `key="value"` pairs from the attribute portion of an EXTINF line.
///
/// Returns a Vec of (key, value) tuples.  Keys are lowercased for
/// case-insensitive matching; values are returned as-is.
fn extract_attributes(s: &str) -> Vec<(String, String)> {
    let mut attrs = Vec::new();
    let bytes = s.as_bytes();
    let len = bytes.len();
    let mut i = 0;

    while i < len {
        // Skip to the start of a potential key (letter or hyphen).
        if !bytes[i].is_ascii_alphanumeric() && bytes[i] != b'-' {
            i += 1;
            continue;
        }

        // Read the key.
        let key_start = i;
        while i < len && (bytes[i].is_ascii_alphanumeric() || bytes[i] == b'-') {
            i += 1;
        }
        let key = &s[key_start..i];

        // Expect '=' followed by '"'.
        if i >= len || bytes[i] != b'=' {
            continue;
        }
        i += 1; // skip '='
        if i >= len || bytes[i] != b'"' {
            continue;
        }
        i += 1; // skip opening '"'

        // Read the value until the closing '"'.
        let val_start = i;
        while i < len && bytes[i] != b'"' {
            i += 1;
        }
        let val = &s[val_start..i];

        if i < len {
            i += 1; // skip closing '"'
        }

        attrs.push((key.to_ascii_lowercase(), val.to_string()));
    }

    attrs
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_basic_m3u() {
        let content = concat!(
            "#EXTM3U\n",
            "#EXTINF:-1 tvg-id=\"bbc1\" tvg-name=\"BBC One\" ",
            "tvg-logo=\"http://logo.png\" group-title=\"News\" ",
            "tvg-language=\"English\" tvg-country=\"UK\",BBC News\n",
            "http://stream.example.com/bbc1\n",
        );
        let entries = parse_m3u(content.to_string());
        assert_eq!(entries.len(), 1);

        let e = &entries[0];
        assert_eq!(e.name, "BBC News");
        assert_eq!(e.url, "http://stream.example.com/bbc1");
        assert_eq!(e.group_title, "News");
        assert_eq!(e.tvg_logo, "http://logo.png");
        assert_eq!(e.tvg_id, "bbc1");
        assert_eq!(e.tvg_name, "BBC One");
        assert_eq!(e.tvg_language, "English");
        assert_eq!(e.tvg_country, "UK");
    }

    #[test]
    fn parse_multiple_entries() {
        let content = concat!(
            "#EXTM3U\n",
            "#EXTINF:-1 group-title=\"News\",Channel A\n",
            "http://example.com/a\n",
            "#EXTINF:-1 group-title=\"Sports\",Channel B\n",
            "https://example.com/b\n",
        );
        let entries = parse_m3u(content.to_string());
        assert_eq!(entries.len(), 2);
        assert_eq!(entries[0].name, "Channel A");
        assert_eq!(entries[0].group_title, "News");
        assert_eq!(entries[1].name, "Channel B");
        assert_eq!(entries[1].group_title, "Sports");
    }

    #[test]
    fn missing_attributes_default_to_empty() {
        let content = concat!("#EXTINF:-1,Bare Channel\n", "http://example.com/bare\n",);
        let entries = parse_m3u(content.to_string());
        assert_eq!(entries.len(), 1);

        let e = &entries[0];
        assert_eq!(e.name, "Bare Channel");
        assert_eq!(e.group_title, "");
        assert_eq!(e.tvg_logo, "");
        assert_eq!(e.tvg_id, "");
        assert_eq!(e.tvg_name, "");
        assert_eq!(e.tvg_language, "");
        assert_eq!(e.tvg_country, "");
    }

    #[test]
    fn empty_input() {
        let entries = parse_m3u(String::new());
        assert!(entries.is_empty());
    }

    #[test]
    fn whitespace_only_input() {
        let entries = parse_m3u("   \n\n  \n".to_string());
        assert!(entries.is_empty());
    }

    #[test]
    fn malformed_extinf_without_url() {
        let content = concat!(
            "#EXTINF:-1 group-title=\"News\",Orphan Channel\n",
            "# This is a comment\n",
            "#EXTINF:-1 group-title=\"Music\",Valid Channel\n",
            "http://example.com/valid\n",
        );
        let entries = parse_m3u(content.to_string());
        // The orphan EXTINF is replaced by the next EXTINF before a URL appears.
        assert_eq!(entries.len(), 1);
        assert_eq!(entries[0].name, "Valid Channel");
    }

    #[test]
    fn non_http_url_skipped() {
        let content = concat!(
            "#EXTINF:-1,FTP Channel\n",
            "ftp://example.com/stream\n",
        );
        let entries = parse_m3u(content.to_string());
        assert!(entries.is_empty());
    }

    #[test]
    fn url_without_extinf_skipped() {
        let content = "http://example.com/orphan-url\n";
        let entries = parse_m3u(content.to_string());
        assert!(entries.is_empty());
    }

    #[test]
    fn handles_windows_line_endings() {
        let content =
            "#EXTM3U\r\n#EXTINF:-1,Win Channel\r\nhttp://example.com/win\r\n";
        let entries = parse_m3u(content.to_string());
        assert_eq!(entries.len(), 1);
        assert_eq!(entries[0].name, "Win Channel");
        assert_eq!(entries[0].url, "http://example.com/win");
    }

    #[test]
    fn attributes_are_case_insensitive() {
        let content = concat!(
            "#EXTINF:-1 TVG-ID=\"id1\" Tvg-Name=\"Name1\" GROUP-TITLE=\"G\",Ch\n",
            "http://example.com/ch\n",
        );
        let entries = parse_m3u(content.to_string());
        assert_eq!(entries.len(), 1);
        assert_eq!(entries[0].tvg_id, "id1");
        assert_eq!(entries[0].tvg_name, "Name1");
        assert_eq!(entries[0].group_title, "G");
    }

    #[test]
    fn empty_attribute_values() {
        let content = concat!(
            "#EXTINF:-1 tvg-id=\"\" group-title=\"\",No Attrs\n",
            "http://example.com/noattrs\n",
        );
        let entries = parse_m3u(content.to_string());
        assert_eq!(entries.len(), 1);
        assert_eq!(entries[0].tvg_id, "");
        assert_eq!(entries[0].group_title, "");
    }

    #[test]
    fn commas_in_attribute_values() {
        // The channel name is everything after the last *unquoted* comma.
        let content = concat!(
            "#EXTINF:-1 group-title=\"News, Weather\",BBC News\n",
            "http://example.com/bbc\n",
        );
        let entries = parse_m3u(content.to_string());
        assert_eq!(entries.len(), 1);
        assert_eq!(entries[0].group_title, "News, Weather");
        assert_eq!(entries[0].name, "BBC News");
    }
}
