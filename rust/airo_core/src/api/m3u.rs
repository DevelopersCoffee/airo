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
}

pub fn parse_m3u_entries(content: String) -> Vec<M3uEntry> {
    parse_m3u_entries_str(&content)
}

fn parse_m3u_entries_str(content: &str) -> Vec<M3uEntry> {
    let bytes = content.as_bytes();
    let mut entries = Vec::new();
    let mut pending: Option<PendingExtInf> = None;
    let mut offset = 0;

    while offset <= bytes.len() {
        let remaining = &bytes[offset..];
        let Some(newline_index) = memchr(b'\n', remaining) else {
            parse_line(&content[offset..], &mut pending, &mut entries);
            break;
        };

        parse_line(
            &content[offset..offset + newline_index],
            &mut pending,
            &mut entries,
        );
        offset += newline_index + 1;
    }

    entries
}

fn parse_line(line: &str, pending: &mut Option<PendingExtInf>, entries: &mut Vec<M3uEntry>) {
    let line = line.trim();
    if line.starts_with("#EXTINF:") {
        *pending = parse_extinf(line);
        return;
    }

    if line.is_empty() || line.starts_with('#') {
        return;
    }

    if let Some(info) = pending.take() {
        entries.push(M3uEntry {
            name: info.name,
            url: line.to_string(),
            logo: info.logo,
            group: info.group,
            tvg_id: info.tvg_id,
            tvg_name: info.tvg_name,
            language: info.language,
        });
    }
}

fn parse_extinf(line: &str) -> Option<PendingExtInf> {
    let comma_index = line.rfind(',')?;
    let name = line[comma_index + 1..].trim().to_string();
    let mut info = PendingExtInf {
        name,
        ..PendingExtInf::default()
    };

    for (key, value) in AttributeIter::new(&line[..comma_index]) {
        match key {
            "tvg-logo" => info.logo = Some(value.to_string()),
            "group-title" => info.group = Some(value.to_string()),
            "tvg-id" => info.tvg_id = Some(value.to_string()),
            "tvg-name" => info.tvg_name = Some(value.to_string()),
            "tvg-language" => info.language = Some(value.to_string()),
            _ => {}
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

    #[test]
    fn parses_extinf_entry_with_attributes() {
        let entries = parse_m3u_entries_str(
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
        let entries = parse_m3u_entries_str(
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
        let entries = parse_m3u_entries_str(
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
}
