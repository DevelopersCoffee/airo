// Streaming XMLTV / EPG parser (#768)
//
// Parses XMLTV programme data using quick-xml's pull-based reader.
// Constant-memory: processes XML events one at a time without building a DOM.
//
// XMLTV datetime format: "YYYYMMDDHHmmss +HHMM" or "YYYYMMDDHHmmss"
// Example: "20260715120000 +0530"

use quick_xml::events::Event;
use quick_xml::Reader;

/// A single programme entry from an XMLTV feed.
#[derive(Debug, Clone, PartialEq)]
pub struct EpgEntry {
    /// Channel ID as declared in the XMLTV <programme channel="..."> attribute.
    pub channel_id: String,
    /// Programme start time as a Unix epoch (seconds).
    pub start_epoch: i64,
    /// Programme end time as a Unix epoch (seconds).
    pub end_epoch: i64,
    /// Programme title (from the first <title> child element).
    pub title: String,
    /// Programme category (from the first <category> child element), if any.
    pub category: Option<String>,
}

/// Parse an XMLTV document from raw bytes and return all programme entries.
///
/// Uses a streaming pull parser (quick-xml) to avoid building the full DOM
/// in memory. This is important for large EPG files (50-200 MB is common
/// for national-scale XMLTV feeds).
///
/// # Arguments
/// * `xml` - Raw XMLTV bytes (UTF-8).
///
/// # Returns
/// A `Vec<EpgEntry>` with one entry per `<programme>` element found.
/// Programmes missing a `start` attribute or `<title>` child are skipped.
pub fn parse_xmltv(xml: &[u8]) -> Vec<EpgEntry> {
    let mut reader = Reader::from_reader(xml);
    reader.config_mut().trim_text(true);

    let mut entries = Vec::new();
    let mut buf = Vec::new();

    // State for the programme we are currently inside, if any.
    let mut current: Option<PartialEntry> = None;
    // Which child element we are reading text from.
    let mut reading_child = ChildElement::None;

    loop {
        match reader.read_event_into(&mut buf) {
            Ok(Event::Start(ref e)) => {
                match e.name().as_ref() {
                    b"programme" => {
                        let mut channel = String::new();
                        let mut start_str = String::new();
                        let mut stop_str = String::new();

                        for attr in e.attributes().flatten() {
                            match attr.key.as_ref() {
                                b"channel" => {
                                    channel = String::from_utf8_lossy(&attr.value)
                                        .into_owned();
                                }
                                b"start" => {
                                    start_str = String::from_utf8_lossy(&attr.value)
                                        .into_owned();
                                }
                                b"stop" => {
                                    stop_str = String::from_utf8_lossy(&attr.value)
                                        .into_owned();
                                }
                                _ => {}
                            }
                        }

                        let start_epoch = parse_xmltv_datetime(&start_str);
                        let stop_epoch = parse_xmltv_datetime(&stop_str);

                        // Skip programmes without a valid start time.
                        if let Some(start) = start_epoch {
                            current = Some(PartialEntry {
                                channel_id: channel,
                                start_epoch: start,
                                end_epoch: stop_epoch.unwrap_or(0),
                                title: String::new(),
                                category: None,
                            });
                        }
                    }
                    b"title" if current.is_some() => {
                        reading_child = ChildElement::Title;
                    }
                    b"category" if current.is_some() => {
                        reading_child = ChildElement::Category;
                    }
                    _ => {}
                }
            }
            Ok(Event::Text(ref e)) => {
                if let Some(ref mut entry) = current {
                    let text = e.unescape().unwrap_or_default();
                    match reading_child {
                        ChildElement::Title if entry.title.is_empty() => {
                            entry.title = text.into_owned();
                        }
                        ChildElement::Category if entry.category.is_none() => {
                            entry.category = Some(text.into_owned());
                        }
                        _ => {}
                    }
                }
            }
            Ok(Event::End(ref e)) => {
                match e.name().as_ref() {
                    b"title" | b"category" => {
                        reading_child = ChildElement::None;
                    }
                    b"programme" => {
                        if let Some(entry) = current.take() {
                            // Only emit entries that have a title.
                            if !entry.title.is_empty() {
                                entries.push(EpgEntry {
                                    channel_id: entry.channel_id,
                                    start_epoch: entry.start_epoch,
                                    end_epoch: entry.end_epoch,
                                    title: entry.title,
                                    category: entry.category,
                                });
                            }
                        }
                    }
                    _ => {}
                }
            }
            Ok(Event::Eof) => break,
            Err(_) => break,
            _ => {}
        }
        buf.clear();
    }

    entries
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

/// Tracks which child element's text we are currently collecting.
#[derive(Debug, Clone, Copy, PartialEq)]
enum ChildElement {
    None,
    Title,
    Category,
}

/// Accumulates data for a `<programme>` while we parse its children.
struct PartialEntry {
    channel_id: String,
    start_epoch: i64,
    end_epoch: i64,
    title: String,
    category: Option<String>,
}

/// Parse an XMLTV datetime string into a Unix epoch (seconds).
///
/// Accepted formats:
///   - `"YYYYMMDDHHmmss +HHMM"` (with timezone offset)
///   - `"YYYYMMDDHHmmss -HHMM"`
///   - `"YYYYMMDDHHmmss"`        (assumed UTC)
///
/// Returns `None` if the string is empty or cannot be parsed.
fn parse_xmltv_datetime(s: &str) -> Option<i64> {
    let s = s.trim();
    if s.len() < 14 {
        return None;
    }

    let date_part = &s[..14];

    let year: i64 = date_part[0..4].parse().ok()?;
    let month: i64 = date_part[4..6].parse().ok()?;
    let day: i64 = date_part[6..8].parse().ok()?;
    let hour: i64 = date_part[8..10].parse().ok()?;
    let min: i64 = date_part[10..12].parse().ok()?;
    let sec: i64 = date_part[12..14].parse().ok()?;

    // Convert to Unix epoch using a simplified calendar calculation.
    // This avoids pulling in chrono just for this one conversion.
    let epoch = datetime_to_epoch(year, month, day, hour, min, sec);

    // Parse optional timezone offset (e.g. " +0530" or " -0100").
    let remainder = s[14..].trim();
    if remainder.len() >= 5 {
        let sign = match remainder.as_bytes()[0] {
            b'+' => -1i64, // positive offset means UTC is behind local
            b'-' => 1i64,
            _ => return Some(epoch),
        };
        let tz_hours: i64 = remainder[1..3].parse().ok()?;
        let tz_mins: i64 = remainder[3..5].parse().ok()?;
        let offset_secs = sign * (tz_hours * 3600 + tz_mins * 60);
        Some(epoch + offset_secs)
    } else {
        Some(epoch)
    }
}

/// Convert a date-time to Unix epoch seconds (UTC).
///
/// Uses the well-known algorithm for converting a Gregorian date to a day
/// count, then adds the time-of-day offset. Accurate for dates from
/// 1970-01-01 onwards.
fn datetime_to_epoch(year: i64, month: i64, day: i64, hour: i64, min: i64, sec: i64) -> i64 {
    // Adjust so March = month 1 (simplifies leap year handling).
    let (y, m) = if month <= 2 {
        (year - 1, month + 9)
    } else {
        (year, month - 3)
    };

    // Days from epoch 0000-03-01 to the start of the given date.
    let days = 365 * y + y / 4 - y / 100 + y / 400 + (m * 306 + 5) / 10 + (day - 1);

    // Offset to Unix epoch (1970-01-01).
    // 719468 is the number of days from 0000-03-01 to 1970-01-01.
    let unix_days = days - 719468;

    unix_days * 86400 + hour * 3600 + min * 60 + sec
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    /// Minimal valid XMLTV fixture with two programmes.
    const FIXTURE: &[u8] = br#"<?xml version="1.0" encoding="UTF-8"?>
<tv generator-info-name="test">
  <channel id="bbc1.uk">
    <display-name>BBC One</display-name>
  </channel>
  <programme start="20260715120000 +0530" stop="20260715130000 +0530" channel="bbc1.uk">
    <title lang="en">World News</title>
    <category lang="en">News</category>
  </programme>
  <programme start="20260715130000 +0530" stop="20260715143000 +0530" channel="bbc1.uk">
    <title lang="en">Cricket Live</title>
    <category lang="en">Sports</category>
  </programme>
</tv>"#;

    #[test]
    fn parses_two_programmes() {
        let entries = parse_xmltv(FIXTURE);
        assert_eq!(entries.len(), 2);
    }

    #[test]
    fn first_programme_fields() {
        let entries = parse_xmltv(FIXTURE);
        let e = &entries[0];
        assert_eq!(e.channel_id, "bbc1.uk");
        assert_eq!(e.title, "World News");
        assert_eq!(e.category.as_deref(), Some("News"));
        // 2026-07-15 12:00:00 +0530 = 2026-07-15 06:30:00 UTC
        assert_eq!(e.start_epoch, 1784097000);
        // 2026-07-15 13:00:00 +0530 = 2026-07-15 07:30:00 UTC
        assert_eq!(e.end_epoch, 1784100600);
    }

    #[test]
    fn second_programme_fields() {
        let entries = parse_xmltv(FIXTURE);
        let e = &entries[1];
        assert_eq!(e.channel_id, "bbc1.uk");
        assert_eq!(e.title, "Cricket Live");
        assert_eq!(e.category.as_deref(), Some("Sports"));
    }

    #[test]
    fn skips_programme_without_title() {
        let xml = br#"<tv>
  <programme start="20260715120000" stop="20260715130000" channel="ch1">
  </programme>
</tv>"#;
        let entries = parse_xmltv(xml);
        assert!(entries.is_empty());
    }

    #[test]
    fn handles_no_timezone() {
        let xml = br#"<tv>
  <programme start="20260715120000" stop="20260715130000" channel="ch1">
    <title>Test</title>
  </programme>
</tv>"#;
        let entries = parse_xmltv(xml);
        assert_eq!(entries.len(), 1);
        // No offset means UTC: 2026-07-15 12:00:00 UTC
        assert_eq!(entries[0].start_epoch, 1784116800);
    }

    #[test]
    fn handles_negative_timezone() {
        let xml = br#"<tv>
  <programme start="20260715120000 -0500" stop="20260715130000 -0500" channel="ch1">
    <title>Eastern</title>
  </programme>
</tv>"#;
        let entries = parse_xmltv(xml);
        // 12:00 EST = 17:00 UTC = epoch for 2026-07-15 17:00:00 UTC
        assert_eq!(entries[0].start_epoch, 1784134800);
    }

    #[test]
    fn category_is_optional() {
        let xml = br#"<tv>
  <programme start="20260715120000" stop="20260715130000" channel="ch1">
    <title>No Category Show</title>
  </programme>
</tv>"#;
        let entries = parse_xmltv(xml);
        assert_eq!(entries.len(), 1);
        assert_eq!(entries[0].category, None);
    }

    #[test]
    fn empty_input() {
        let entries = parse_xmltv(b"");
        assert!(entries.is_empty());
    }

    #[test]
    fn xmltv_datetime_known_values() {
        // 2026-07-15 12:00:00 +0530 -> UTC 06:30:00 -> epoch
        assert_eq!(parse_xmltv_datetime("20260715120000 +0530"), Some(1784097000));
        // 2026-01-01 00:00:00 UTC
        assert_eq!(parse_xmltv_datetime("20260101000000"), Some(1767225600));
        // Too short
        assert_eq!(parse_xmltv_datetime("2026"), None);
        // Empty
        assert_eq!(parse_xmltv_datetime(""), None);
    }
}
