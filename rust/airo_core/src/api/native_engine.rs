use std::collections::{BTreeMap, HashSet};

const MAX_SUBTITLE_BYTES: usize = 2 * 1024 * 1024;

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct RecommendationCandidate {
    pub id: String,
    pub title: String,
    pub genre_affinity: i64,
    pub provider_affinity: i64,
    pub language_affinity: i64,
    pub completion_permille: Option<u16>,
    pub last_watched_age_days: Option<u32>,
    pub preferred_time: bool,
    pub device_fit: bool,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct RecommendationScore {
    pub id: String,
    pub score: i64,
    pub genre_points: i64,
    pub provider_points: i64,
    pub language_points: i64,
    pub completion_points: i64,
    pub recency_points: i64,
    pub time_bucket_points: i64,
    pub device_fit_points: i64,
}

pub fn rank_recommendations(candidates: Vec<RecommendationCandidate>) -> Vec<RecommendationScore> {
    let titles: BTreeMap<String, String> = candidates
        .iter()
        .map(|candidate| (candidate.id.clone(), candidate.title.to_lowercase()))
        .collect();
    let mut scores: Vec<RecommendationScore> = candidates
        .into_iter()
        .map(|candidate| {
            let genre_points = candidate.genre_affinity.saturating_mul(3);
            let provider_points = candidate.provider_affinity.saturating_mul(2);
            let language_points = candidate.language_affinity.saturating_mul(2);
            let completion_points = match candidate.completion_permille {
                Some(value) if value >= 900 => -5000,
                Some(value) if value >= 50 => 150,
                _ => 0,
            };
            let recency_points = match candidate.last_watched_age_days {
                Some(value) if value <= 7 => 40,
                Some(value) if value <= 30 => 15,
                _ => 0,
            };
            let time_bucket_points = if candidate.preferred_time { 50 } else { 0 };
            let device_fit_points = if candidate.device_fit { 25 } else { 0 };
            RecommendationScore {
                id: candidate.id,
                score: genre_points
                    .saturating_add(provider_points)
                    .saturating_add(language_points)
                    .saturating_add(completion_points)
                    .saturating_add(recency_points)
                    .saturating_add(time_bucket_points)
                    .saturating_add(device_fit_points),
                genre_points,
                provider_points,
                language_points,
                completion_points,
                recency_points,
                time_bucket_points,
                device_fit_points,
            }
        })
        .collect();
    scores.sort_by(|left, right| {
        right
            .score
            .cmp(&left.score)
            .then_with(|| {
                titles
                    .get(&left.id)
                    .map(String::as_str)
                    .unwrap_or("")
                    .cmp(titles.get(&right.id).map(String::as_str).unwrap_or(""))
            })
            .then_with(|| left.id.cmp(&right.id))
    });
    scores
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct VectorClockCounter {
    pub node_id: String,
    pub counter: u64,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum VectorClockRelation {
    Equal,
    LeftDominates,
    RightDominates,
    Concurrent,
}

pub fn compare_vector_clocks(
    left: Vec<VectorClockCounter>,
    right: Vec<VectorClockCounter>,
) -> VectorClockRelation {
    let left = normalized_clock(left);
    let right = normalized_clock(right);
    let nodes: HashSet<&str> = left
        .keys()
        .chain(right.keys())
        .map(String::as_str)
        .collect();
    let mut left_greater = false;
    let mut right_greater = false;
    for node in nodes {
        let left_value = left.get(node).copied().unwrap_or_default();
        let right_value = right.get(node).copied().unwrap_or_default();
        left_greater |= left_value > right_value;
        right_greater |= right_value > left_value;
    }
    match (left_greater, right_greater) {
        (false, false) => VectorClockRelation::Equal,
        (true, false) => VectorClockRelation::LeftDominates,
        (false, true) => VectorClockRelation::RightDominates,
        (true, true) => VectorClockRelation::Concurrent,
    }
}

fn normalized_clock(entries: Vec<VectorClockCounter>) -> BTreeMap<String, u64> {
    let mut result = BTreeMap::new();
    for entry in entries {
        result
            .entry(entry.node_id)
            .and_modify(|value: &mut u64| *value = (*value).max(entry.counter))
            .or_insert(entry.counter);
    }
    result
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum SubtitleFormat {
    Srt,
    WebVtt,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct SubtitleCue {
    pub start_millis: u64,
    pub end_millis: u64,
    pub text: String,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct SubtitleParseResult {
    pub cues: Vec<SubtitleCue>,
    pub malformed_cue_count: u32,
    pub truncated: bool,
}

pub fn parse_subtitles(content: String, format: SubtitleFormat) -> SubtitleParseResult {
    if content.len() > MAX_SUBTITLE_BYTES {
        return SubtitleParseResult {
            cues: Vec::new(),
            malformed_cue_count: 0,
            truncated: true,
        };
    }
    let normalized = content.replace("\r\n", "\n").replace('\r', "\n");
    let mut cues = Vec::new();
    let mut malformed_cue_count = 0_u32;
    for block in normalized.split("\n\n") {
        let mut lines = block.lines().filter(|line| !line.trim().is_empty());
        let first = match lines.next() {
            Some(line) => line.trim(),
            None => continue,
        };
        if format == SubtitleFormat::WebVtt && first.eq_ignore_ascii_case("WEBVTT") {
            continue;
        }
        let timing = if first.contains("-->") {
            first
        } else {
            match lines.next() {
                Some(line) if line.contains("-->") => line.trim(),
                _ => {
                    malformed_cue_count = malformed_cue_count.saturating_add(1);
                    continue;
                }
            }
        };
        let text = lines.collect::<Vec<_>>().join("\n").trim().to_string();
        let Some((start, end)) = parse_timing_line(timing, format) else {
            malformed_cue_count = malformed_cue_count.saturating_add(1);
            continue;
        };
        if text.is_empty() || end <= start {
            malformed_cue_count = malformed_cue_count.saturating_add(1);
            continue;
        }
        cues.push(SubtitleCue {
            start_millis: start,
            end_millis: end,
            text,
        });
    }
    cues.sort_by(|left, right| {
        left.start_millis
            .cmp(&right.start_millis)
            .then_with(|| left.end_millis.cmp(&right.end_millis))
            .then_with(|| left.text.cmp(&right.text))
    });
    SubtitleParseResult {
        cues,
        malformed_cue_count,
        truncated: false,
    }
}

fn parse_timing_line(line: &str, format: SubtitleFormat) -> Option<(u64, u64)> {
    let (start, rest) = line.split_once("-->")?;
    let end = rest.split_whitespace().next()?;
    Some((
        parse_timestamp(start.trim(), format)?,
        parse_timestamp(end.trim(), format)?,
    ))
}

fn parse_timestamp(value: &str, format: SubtitleFormat) -> Option<u64> {
    let normalized = match format {
        SubtitleFormat::Srt => value.replace(',', "."),
        SubtitleFormat::WebVtt => value.to_string(),
    };
    let segments: Vec<&str> = normalized.split(':').collect();
    let (hours, minutes, seconds) = match segments.as_slice() {
        [hours, minutes, seconds] => (
            hours.parse::<u64>().ok()?,
            minutes.parse::<u64>().ok()?,
            *seconds,
        ),
        [minutes, seconds] if format == SubtitleFormat::WebVtt => {
            (0, minutes.parse::<u64>().ok()?, *seconds)
        }
        _ => return None,
    };
    if minutes >= 60 {
        return None;
    }
    let (whole_seconds, millis) = seconds.split_once('.')?;
    let whole_seconds = whole_seconds.parse::<u64>().ok()?;
    if whole_seconds >= 60 || millis.len() != 3 {
        return None;
    }
    let millis = millis.parse::<u64>().ok()?;
    Some(
        hours
            .saturating_mul(3_600_000)
            .saturating_add(minutes.saturating_mul(60_000))
            .saturating_add(whole_seconds.saturating_mul(1_000))
            .saturating_add(millis),
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    fn candidate(id: &str, title: &str) -> RecommendationCandidate {
        RecommendationCandidate {
            id: id.to_string(),
            title: title.to_string(),
            genre_affinity: 0,
            provider_affinity: 0,
            language_affinity: 0,
            completion_permille: None,
            last_watched_age_days: None,
            preferred_time: false,
            device_fit: false,
        }
    }

    #[test]
    fn ranking_matches_reference_weights_and_ties() {
        let mut unfinished = candidate("unfinished", "Zed");
        unfinished.genre_affinity = 500;
        unfinished.provider_affinity = 500;
        unfinished.language_affinity = 500;
        unfinished.completion_permille = Some(500);
        unfinished.last_watched_age_days = Some(2);
        unfinished.preferred_time = true;
        unfinished.device_fit = true;
        let mut finished = candidate("finished", "Alpha");
        finished.genre_affinity = 950;
        finished.provider_affinity = 950;
        finished.language_affinity = 950;
        finished.completion_permille = Some(950);

        let ranked = rank_recommendations(vec![finished, unfinished]);

        assert_eq!(ranked[0].id, "unfinished");
        assert_eq!(ranked[0].completion_points, 150);
        assert_eq!(ranked[0].recency_points, 40);
        assert_eq!(ranked[0].time_bucket_points, 50);
        assert_eq!(ranked[0].device_fit_points, 25);
    }

    #[test]
    fn vector_clock_relations_cover_missing_nodes_and_concurrency() {
        let clock = |values: &[(&str, u64)]| {
            values
                .iter()
                .map(|(node_id, counter)| VectorClockCounter {
                    node_id: (*node_id).to_string(),
                    counter: *counter,
                })
                .collect()
        };
        assert_eq!(
            compare_vector_clocks(clock(&[("a", 1)]), clock(&[("a", 1)])),
            VectorClockRelation::Equal
        );
        assert_eq!(
            compare_vector_clocks(clock(&[("a", 2), ("b", 1)]), clock(&[("a", 1)])),
            VectorClockRelation::LeftDominates
        );
        assert_eq!(
            compare_vector_clocks(clock(&[("a", 2)]), clock(&[("a", 1), ("b", 1)])),
            VectorClockRelation::Concurrent
        );
    }

    #[test]
    fn parses_srt_and_webvtt_without_panicking_on_malformed_cues() {
        let srt = parse_subtitles(
            "1\n00:00:01,000 --> 00:00:02,500\nHello\nworld\n\nbad".to_string(),
            SubtitleFormat::Srt,
        );
        assert_eq!(srt.cues.len(), 1);
        assert_eq!(srt.cues[0].text, "Hello\nworld");
        assert_eq!(srt.malformed_cue_count, 1);

        let vtt = parse_subtitles(
            "WEBVTT\n\n00:01.000 --> 00:02.000 align:start\nHello".to_string(),
            SubtitleFormat::WebVtt,
        );
        assert_eq!(vtt.cues.len(), 1);
        assert_eq!(vtt.cues[0].start_millis, 1_000);
    }

    #[test]
    fn oversized_subtitle_input_fails_closed() {
        let result = parse_subtitles("x".repeat(MAX_SUBTITLE_BYTES + 1), SubtitleFormat::Srt);
        assert!(result.truncated);
        assert!(result.cues.is_empty());
    }
}
