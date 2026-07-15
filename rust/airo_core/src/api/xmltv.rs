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
struct PendingProgramme {
    channel_id: Option<String>,
    start: Option<String>,
    stop: Option<String>,
    title: Option<String>,
}

pub fn parse_xmltv_programmes(
    content: String,
    max_programmes: u32,
) -> Result<XmltvParseResult, String> {
    parse_xmltv_programmes_str(&content, max_programmes as usize).map_err(|error| error.to_string())
}

fn parse_xmltv_programmes_str(
    content: &str,
    max_programmes: usize,
) -> quick_xml::Result<XmltvParseResult> {
    let mut reader = Reader::from_str(content);

    let mut result = XmltvParseResult::default();
    let mut pending: Option<PendingProgramme> = None;
    let mut inside_title = false;

    loop {
        match reader.read_event()? {
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
    }

    Ok(result)
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
}
