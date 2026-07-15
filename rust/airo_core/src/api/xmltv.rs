use std::collections::HashMap;
use std::fs::File;
use std::io::{BufRead, BufReader, Cursor};

use quick_xml::encoding::Decoder;
use quick_xml::escape::{resolve_predefined_entity, unescape};
use quick_xml::events::{attributes::Attribute, BytesRef, BytesStart, Event};
use quick_xml::Reader;

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct XmltvProgramme {
    pub channel_id: String,
    pub start: String,
    pub stop: Option<String>,
    pub title: Option<String>,
}

#[derive(Clone, Debug, Default, Eq, PartialEq)]
pub struct XmltvParseStats {
    pub programme_count: u32,
    pub skipped_programme_count: u32,
    pub truncated: bool,
}

#[derive(Clone, Debug, Default, Eq, PartialEq)]
pub struct XmltvParseResult {
    pub programmes: Vec<XmltvProgramme>,
    pub stats: XmltvParseStats,
}

#[derive(Clone, Debug, Default, Eq, PartialEq)]
pub struct XmltvCurrentNextStats {
    pub programme_count: u32,
    pub skipped_programme_count: u32,
    pub invalid_timestamp_count: u32,
    pub matched_programme_count: u32,
    pub requested_channel_count: u32,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct XmltvCurrentNextEntry {
    pub channel_id: String,
    pub current: Option<XmltvProgramme>,
    pub next: Option<XmltvProgramme>,
}

#[derive(Clone, Debug, Default, Eq, PartialEq)]
pub struct XmltvCurrentNextResult {
    pub entries: Vec<XmltvCurrentNextEntry>,
    pub stats: XmltvCurrentNextStats,
}

#[flutter_rust_bridge::frb(ignore)]
#[derive(Clone, Debug, Default, Eq, PartialEq)]
struct PendingProgramme {
    channel_id: Option<String>,
    start: Option<String>,
    stop: Option<String>,
    title: Option<String>,
}

#[flutter_rust_bridge::frb(ignore)]
#[derive(Clone, Debug, Default, Eq, PartialEq)]
struct CurrentNextCandidate {
    current: Option<(i64, XmltvProgramme)>,
    next: Option<(i64, XmltvProgramme)>,
}

pub fn parse_xmltv_programmes(
    content: String,
    max_programmes: u32,
) -> Result<XmltvParseResult, String> {
    parse_xmltv_programmes_reader(Cursor::new(content.into_bytes()), max_programmes as usize)
        .map_err(|error| error.to_string())
}

pub fn parse_xmltv_programmes_file(
    path: String,
    max_programmes: u32,
) -> Result<XmltvParseResult, String> {
    let file = File::open(&path)
        .map_err(|error| format!("failed to open XMLTV file `{path}`: {error}"))?;
    let reader = BufReader::with_capacity(1024 * 1024, file);
    parse_xmltv_programmes_reader(reader, max_programmes as usize)
        .map_err(|error| error.to_string())
}

pub fn parse_xmltv_current_next_file(
    path: String,
    channel_ids: Vec<String>,
    now_epoch_seconds: i64,
    default_duration_seconds: u32,
) -> Result<XmltvCurrentNextResult, String> {
    let file = File::open(&path)
        .map_err(|error| format!("failed to open XMLTV file `{path}`: {error}"))?;
    let reader = BufReader::with_capacity(1024 * 1024, file);
    parse_xmltv_current_next_reader(
        reader,
        channel_ids,
        now_epoch_seconds,
        default_duration_seconds,
    )
    .map_err(|error| error.to_string())
}

pub fn parse_xmltv_programmes_reader<R: BufRead>(
    input: R,
    max_programmes: usize,
) -> quick_xml::Result<XmltvParseResult> {
    let mut reader = Reader::from_reader(input);
    let mut buffer = Vec::with_capacity(8192);
    let mut result = XmltvParseResult::default();
    let mut pending: Option<PendingProgramme> = None;
    let mut inside_title = false;

    loop {
        match reader.read_event_into(&mut buffer)? {
            Event::Start(element) if element.name().as_ref() == b"programme" => {
                pending = Some(pending_programme(&element, reader.decoder())?);
            }
            Event::Start(element) if pending.is_some() && element.name().as_ref() == b"title" => {
                inside_title = true;
            }
            Event::Text(text) if inside_title => {
                if let Some(programme) = pending.as_mut() {
                    let decoded = text.decode()?;
                    append_title(programme, &unescape(&decoded)?);
                }
            }
            Event::GeneralRef(reference) if inside_title => {
                if let Some(programme) = pending.as_mut() {
                    append_title(programme, &resolve_general_ref(&reference)?);
                }
            }
            Event::End(element) if element.name().as_ref() == b"title" => {
                inside_title = false;
            }
            Event::End(element) if element.name().as_ref() == b"programme" => {
                if let Some(programme) = pending.take() {
                    finish_programme(programme, max_programmes, &mut result);
                }
                inside_title = false;
            }
            Event::Eof => break,
            _ => {}
        }
        buffer.clear();
    }

    Ok(result)
}

pub fn parse_xmltv_current_next_reader<R: BufRead>(
    input: R,
    channel_ids: Vec<String>,
    now_epoch_seconds: i64,
    default_duration_seconds: u32,
) -> quick_xml::Result<XmltvCurrentNextResult> {
    let channel_index = channel_ids
        .iter()
        .enumerate()
        .map(|(index, channel_id)| (channel_id.clone(), index))
        .collect::<HashMap<_, _>>();
    let mut candidates = vec![CurrentNextCandidate::default(); channel_ids.len()];
    let mut reader = Reader::from_reader(input);
    let mut buffer = Vec::with_capacity(8192);
    let mut result = XmltvCurrentNextResult {
        stats: XmltvCurrentNextStats {
            requested_channel_count: channel_ids.len() as u32,
            ..XmltvCurrentNextStats::default()
        },
        ..XmltvCurrentNextResult::default()
    };
    let mut pending: Option<PendingProgramme> = None;
    let mut inside_title = false;

    loop {
        match reader.read_event_into(&mut buffer)? {
            Event::Start(element) if element.name().as_ref() == b"programme" => {
                pending = Some(pending_programme(&element, reader.decoder())?);
            }
            Event::Start(element) if pending.is_some() && element.name().as_ref() == b"title" => {
                inside_title = true;
            }
            Event::Text(text) if inside_title => {
                if let Some(programme) = pending.as_mut() {
                    let decoded = text.decode()?;
                    append_title(programme, &unescape(&decoded)?);
                }
            }
            Event::GeneralRef(reference) if inside_title => {
                if let Some(programme) = pending.as_mut() {
                    append_title(programme, &resolve_general_ref(&reference)?);
                }
            }
            Event::End(element) if element.name().as_ref() == b"title" => {
                inside_title = false;
            }
            Event::End(element) if element.name().as_ref() == b"programme" => {
                if let Some(programme) = pending.take() {
                    finish_current_next_programme(
                        programme,
                        &channel_index,
                        now_epoch_seconds,
                        default_duration_seconds,
                        &mut candidates,
                        &mut result.stats,
                    );
                }
                inside_title = false;
            }
            Event::Eof => break,
            _ => {}
        }
        buffer.clear();
    }

    result.entries = channel_ids
        .into_iter()
        .enumerate()
        .filter_map(|(index, channel_id)| {
            let candidate = &candidates[index];
            if candidate.current.is_none() && candidate.next.is_none() {
                return None;
            }
            Some(XmltvCurrentNextEntry {
                channel_id,
                current: candidate
                    .current
                    .as_ref()
                    .map(|(_, programme)| programme.clone()),
                next: candidate
                    .next
                    .as_ref()
                    .map(|(_, programme)| programme.clone()),
            })
        })
        .collect();

    Ok(result)
}

#[cfg(test)]
fn parse_xmltv_programmes_str(
    content: &str,
    max_programmes: usize,
) -> quick_xml::Result<XmltvParseResult> {
    parse_xmltv_programmes_reader(Cursor::new(content.as_bytes()), max_programmes)
}

#[cfg(test)]
fn parse_xmltv_current_next_str(
    content: &str,
    channel_ids: Vec<String>,
    now_epoch_seconds: i64,
    default_duration_seconds: u32,
) -> quick_xml::Result<XmltvCurrentNextResult> {
    parse_xmltv_current_next_reader(
        Cursor::new(content.as_bytes()),
        channel_ids,
        now_epoch_seconds,
        default_duration_seconds,
    )
}

fn pending_programme(
    element: &BytesStart<'_>,
    decoder: Decoder,
) -> quick_xml::Result<PendingProgramme> {
    let mut programme = PendingProgramme::default();

    for attribute in element.attributes() {
        let attribute = attribute?;
        match attribute.key.as_ref() {
            b"channel" => {
                programme.channel_id = Some(attribute_value(&attribute, decoder)?);
            }
            b"start" => {
                programme.start = Some(attribute_value(&attribute, decoder)?);
            }
            b"stop" => {
                programme.stop = Some(attribute_value(&attribute, decoder)?);
            }
            _ => {}
        }
    }

    Ok(programme)
}

fn attribute_value(attribute: &Attribute<'_>, decoder: Decoder) -> quick_xml::Result<String> {
    Ok(attribute.decode_and_unescape_value(decoder)?.into_owned())
}

fn append_title(programme: &mut PendingProgramme, chunk: &str) {
    programme
        .title
        .get_or_insert_with(String::new)
        .push_str(chunk);
}

fn resolve_general_ref(reference: &BytesRef<'_>) -> quick_xml::Result<String> {
    if let Some(character) = reference.resolve_char_ref()? {
        return Ok(character.to_string());
    }

    let entity = reference.decode()?;
    let Some(value) = resolve_predefined_entity(&entity) else {
        return Err(quick_xml::Error::Escape(
            quick_xml::escape::EscapeError::UnrecognizedEntity(0..entity.len(), entity.to_string()),
        ));
    };

    Ok(value.to_string())
}

fn finish_programme(
    programme: PendingProgramme,
    max_programmes: usize,
    result: &mut XmltvParseResult,
) {
    let (Some(channel_id), Some(start)) = (programme.channel_id, programme.start) else {
        result.stats.skipped_programme_count += 1;
        return;
    };

    result.stats.programme_count += 1;

    if result.programmes.len() >= max_programmes {
        result.stats.truncated = true;
        return;
    }

    result.programmes.push(XmltvProgramme {
        channel_id,
        start,
        stop: programme.stop,
        title: programme
            .title
            .map(|title| title.trim().to_string())
            .filter(|title| !title.is_empty()),
    });
}

fn finish_current_next_programme(
    programme: PendingProgramme,
    channel_index: &HashMap<String, usize>,
    now_epoch_seconds: i64,
    default_duration_seconds: u32,
    candidates: &mut [CurrentNextCandidate],
    stats: &mut XmltvCurrentNextStats,
) {
    let (Some(channel_id), Some(start)) = (programme.channel_id, programme.start) else {
        stats.skipped_programme_count += 1;
        return;
    };

    stats.programme_count += 1;

    let Some(index) = channel_index.get(&channel_id).copied() else {
        return;
    };

    let Some(start_epoch_seconds) = parse_xmltv_timestamp_epoch_seconds(&start) else {
        stats.invalid_timestamp_count += 1;
        return;
    };
    let stop_epoch_seconds = match programme.stop.as_deref() {
        Some(stop) => {
            let Some(stop_epoch_seconds) = parse_xmltv_timestamp_epoch_seconds(stop) else {
                stats.invalid_timestamp_count += 1;
                return;
            };
            stop_epoch_seconds
        }
        None => start_epoch_seconds + i64::from(default_duration_seconds),
    };
    if stop_epoch_seconds <= start_epoch_seconds {
        stats.invalid_timestamp_count += 1;
        return;
    }

    stats.matched_programme_count += 1;
    let compact_programme = XmltvProgramme {
        channel_id,
        start,
        stop: programme.stop,
        title: programme
            .title
            .map(|title| title.trim().to_string())
            .filter(|title| !title.is_empty()),
    };
    let candidate = &mut candidates[index];

    if start_epoch_seconds <= now_epoch_seconds && now_epoch_seconds < stop_epoch_seconds {
        let should_replace = candidate
            .current
            .as_ref()
            .map(|(existing_start, _)| start_epoch_seconds < *existing_start)
            .unwrap_or(true);
        if should_replace {
            candidate.current = Some((start_epoch_seconds, compact_programme));
        }
        return;
    }

    if start_epoch_seconds > now_epoch_seconds {
        let should_replace = candidate
            .next
            .as_ref()
            .map(|(existing_start, _)| start_epoch_seconds < *existing_start)
            .unwrap_or(true);
        if should_replace {
            candidate.next = Some((start_epoch_seconds, compact_programme));
        }
    }
}

fn parse_xmltv_timestamp_epoch_seconds(value: &str) -> Option<i64> {
    let value = value.trim();
    if value.len() < 14 {
        return None;
    }

    let year = value.get(0..4)?.parse::<i32>().ok()?;
    let month = value.get(4..6)?.parse::<u32>().ok()?;
    let day = value.get(6..8)?.parse::<u32>().ok()?;
    let hour = value.get(8..10)?.parse::<u32>().ok()?;
    let minute = value.get(10..12)?.parse::<u32>().ok()?;
    let second = value.get(12..14)?.parse::<u32>().ok()?;
    if !valid_datetime(year, month, day, hour, minute, second) {
        return None;
    }

    let mut epoch_seconds =
        days_from_civil(year, month, day) * 86_400 + i64::from(hour * 3600 + minute * 60 + second);
    let offset = value.get(14..).unwrap_or("").trim();
    if !offset.is_empty() {
        let sign = offset.as_bytes().first().copied()?;
        if sign != b'+' && sign != b'-' {
            return None;
        }
        if offset.len() < 5 {
            return None;
        }
        let offset_hours = offset.get(1..3)?.parse::<i64>().ok()?;
        let offset_minutes = offset.get(3..5)?.parse::<i64>().ok()?;
        if offset_hours > 23 || offset_minutes > 59 {
            return None;
        }
        let offset_seconds = offset_hours * 3600 + offset_minutes * 60;
        epoch_seconds = if sign == b'+' {
            epoch_seconds - offset_seconds
        } else {
            epoch_seconds + offset_seconds
        };
    }

    Some(epoch_seconds)
}

fn valid_datetime(year: i32, month: u32, day: u32, hour: u32, minute: u32, second: u32) -> bool {
    if !(1..=12).contains(&month) || hour > 23 || minute > 59 || second > 59 {
        return false;
    }
    let max_day = match month {
        1 | 3 | 5 | 7 | 8 | 10 | 12 => 31,
        4 | 6 | 9 | 11 => 30,
        2 if is_leap_year(year) => 29,
        2 => 28,
        _ => return false,
    };
    (1..=max_day).contains(&day)
}

fn is_leap_year(year: i32) -> bool {
    (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
}

fn days_from_civil(year: i32, month: u32, day: u32) -> i64 {
    let year = year - if month <= 2 { 1 } else { 0 };
    let era = if year >= 0 { year } else { year - 399 } / 400;
    let year_of_era = year - era * 400;
    let month = month as i32;
    let day = day as i32;
    let day_of_year = (153 * (month + if month > 2 { -3 } else { 9 }) + 2) / 5 + day - 1;
    let day_of_era = year_of_era * 365 + year_of_era / 4 - year_of_era / 100 + day_of_year;
    i64::from(era * 146_097 + day_of_era - 719_468)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_programmes_with_title_and_bounds() {
        let result = parse_xmltv_programmes_str(
            r#"<?xml version="1.0" encoding="UTF-8"?>
<tv>
  <programme channel="news.one" start="20260715090000 +0000" stop="20260715100000 +0000">
    <title lang="en">Morning News</title>
    <desc>Ignored for compact summary</desc>
  </programme>
  <programme channel="sports.one" start="20260715100000 +0000" stop="20260715110000 +0000">
    <title>Live Match</title>
  </programme>
</tv>"#,
            1,
        )
        .expect("valid XMLTV");

        assert_eq!(result.programmes.len(), 1);
        assert_eq!(result.programmes[0].channel_id, "news.one");
        assert_eq!(result.programmes[0].start, "20260715090000 +0000");
        assert_eq!(
            result.programmes[0].stop.as_deref(),
            Some("20260715100000 +0000")
        );
        assert_eq!(result.programmes[0].title.as_deref(), Some("Morning News"));
        assert_eq!(result.stats.programme_count, 2);
        assert_eq!(result.stats.skipped_programme_count, 0);
        assert!(result.stats.truncated);
    }

    #[test]
    fn skips_programmes_missing_required_attributes() {
        let result = parse_xmltv_programmes_str(
            r#"<tv>
  <programme channel="news.one"><title>No Start</title></programme>
  <programme start="20260715090000 +0000"><title>No Channel</title></programme>
  <programme channel="valid" start="20260715100000 +0000"></programme>
</tv>"#,
            10,
        )
        .expect("valid XMLTV");

        assert_eq!(result.programmes.len(), 1);
        assert_eq!(result.programmes[0].channel_id, "valid");
        assert_eq!(result.programmes[0].title, None);
        assert_eq!(result.stats.programme_count, 1);
        assert_eq!(result.stats.skipped_programme_count, 2);
        assert!(!result.stats.truncated);
    }

    #[test]
    fn rejects_malformed_xml() {
        assert!(parse_xmltv_programmes_str(
            r#"<tv><programme channel="news.one" start="20260715090000 +0000"></tv>"#,
            10,
        )
        .is_err());
    }

    #[test]
    fn zero_bound_counts_without_storing() {
        let result = parse_xmltv_programmes_str(
            r#"<tv>
  <programme channel="news.one" start="20260715090000 +0000"><title>Morning</title></programme>
</tv>"#,
            0,
        )
        .expect("valid XMLTV");

        assert!(result.programmes.is_empty());
        assert_eq!(result.stats.programme_count, 1);
        assert!(result.stats.truncated);
    }

    #[test]
    fn decodes_escaped_attributes_and_title() {
        let result = parse_xmltv_programmes_str(
            r#"<tv>
  <programme channel="news.&amp;.one" start="20260715090000 +0000" stop="20260715100000 +0000">
    <title>Morning &amp; Markets</title>
  </programme>
</tv>"#,
            10,
        )
        .expect("valid XMLTV");

        assert_eq!(result.programmes[0].channel_id, "news.&.one");
        assert_eq!(
            result.programmes[0].title.as_deref(),
            Some("Morning & Markets")
        );
    }

    #[test]
    fn parses_from_buffered_reader_without_string_ownership() {
        let input = Cursor::new(
            br#"<tv>
  <programme channel="reader.one" start="20260715090000 +0000">
    <title>Reader Path</title>
  </programme>
</tv>"#
                .as_slice(),
        );

        let result = parse_xmltv_programmes_reader(input, 10).expect("valid XMLTV");

        assert_eq!(result.programmes.len(), 1);
        assert_eq!(result.programmes[0].channel_id, "reader.one");
        assert_eq!(result.programmes[0].title.as_deref(), Some("Reader Path"));
    }

    #[test]
    fn parses_from_file_without_string_ownership() {
        let path = std::env::temp_dir().join(format!(
            "airo-core-xmltv-file-{}-{}.xml",
            std::process::id(),
            "reader"
        ));
        std::fs::write(
            &path,
            r#"<tv>
  <programme channel="file.one" start="20260715090000 +0000">
    <title>File Path</title>
  </programme>
</tv>"#,
        )
        .expect("write XMLTV fixture");

        let result =
            parse_xmltv_programmes_file(path.display().to_string(), 10).expect("valid XMLTV file");
        let _ = std::fs::remove_file(path);

        assert_eq!(result.programmes.len(), 1);
        assert_eq!(result.programmes[0].channel_id, "file.one");
        assert_eq!(result.programmes[0].title.as_deref(), Some("File Path"));
    }

    #[test]
    fn parses_current_next_for_requested_channels_only() {
        let now = parse_xmltv_timestamp_epoch_seconds("20260715093000 +0000").unwrap();
        let result = parse_xmltv_current_next_str(
            r#"<tv>
  <programme channel="ignored" start="20260715090000 +0000" stop="20260715100000 +0000"><title>Ignored</title></programme>
  <programme channel="news" start="20260715090000 +0000" stop="20260715100000 +0000"><title>Current</title></programme>
  <programme channel="news" start="20260715100000 +0000" stop="20260715103000 +0000"><title>Next</title></programme>
  <programme channel="sports" start="20260715110000 +0000" stop="20260715113000 +0000"><title>Later</title></programme>
</tv>"#,
            vec!["sports".to_string(), "news".to_string()],
            now,
            1800,
        )
        .expect("valid XMLTV");

        assert_eq!(result.entries.len(), 2);
        assert_eq!(result.entries[0].channel_id, "sports");
        assert_eq!(result.entries[0].current, None);
        assert_eq!(
            result.entries[0].next.as_ref().unwrap().title.as_deref(),
            Some("Later")
        );
        assert_eq!(result.entries[1].channel_id, "news");
        assert_eq!(
            result.entries[1].current.as_ref().unwrap().title.as_deref(),
            Some("Current")
        );
        assert_eq!(
            result.entries[1].next.as_ref().unwrap().title.as_deref(),
            Some("Next")
        );
        assert_eq!(result.stats.programme_count, 4);
        assert_eq!(result.stats.matched_programme_count, 3);
        assert_eq!(result.stats.requested_channel_count, 2);
    }

    #[test]
    fn current_next_uses_default_duration_and_timezone_offsets() {
        let now = parse_xmltv_timestamp_epoch_seconds("20260715090000 +0000").unwrap();
        let result = parse_xmltv_current_next_str(
            r#"<tv>
  <programme channel="news" start="20260715143000 +0530"><title>Current Offset</title></programme>
  <programme channel="news" start="20260715094000 +0000"><title>Next Missing Stop</title></programme>
</tv>"#,
            vec!["news".to_string()],
            now,
            1800,
        )
        .expect("valid XMLTV");

        let entry = &result.entries[0];
        assert_eq!(
            entry.current.as_ref().unwrap().title.as_deref(),
            Some("Current Offset")
        );
        assert_eq!(
            entry.next.as_ref().unwrap().title.as_deref(),
            Some("Next Missing Stop")
        );
    }

    #[test]
    fn current_next_rejects_invalid_timestamps() {
        let now = parse_xmltv_timestamp_epoch_seconds("20260715090000 +0000").unwrap();
        let result = parse_xmltv_current_next_str(
            r#"<tv>
  <programme channel="news" start="not-a-time"><title>Bad Start</title></programme>
  <programme channel="news" start="20260715090000 +0000" stop="20260715080000 +0000"><title>Bad Window</title></programme>
  <programme channel="news" start="20260715090000 +0000" stop="20260715100000 +0000"><title>Good</title></programme>
</tv>"#,
            vec!["news".to_string()],
            now,
            1800,
        )
        .expect("valid XMLTV");

        assert_eq!(result.entries.len(), 1);
        assert_eq!(
            result.entries[0].current.as_ref().unwrap().title.as_deref(),
            Some("Good")
        );
        assert_eq!(result.stats.invalid_timestamp_count, 2);
        assert_eq!(result.stats.matched_programme_count, 1);
    }
}
