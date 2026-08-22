//! Meeting content: persist a transcript and its minutes, reopen them. `#1399`.
//!
//! # What this is, and what it will be
//!
//! `I1` says only the operation log and the encrypted content store are
//! durable, and `I2` says no capability owns storage. **The operation log does
//! not exist yet** — the Vault is `v1.0.0-alpha` as a specification, and
//! `rust/airo_mind` holds no code.
//!
//! So this is an append-only file store with the *shape* the log will take:
//! records are appended, never rewritten; a read replays them in order; the
//! latest record for an id wins. When the log lands, this module's contents
//! become operations and the file becomes the log — the call sites do not
//! change.
//!
//! Recording that plainly rather than calling it a content store: the honest
//! statement is that Milestone 2 needs somewhere to put a transcript, and this
//! is that, built so it does not have to be unpicked.
//!
//! Minutes are **Content**, not a projection. `C2` requires replay to produce
//! byte-identical state on every device; a local LLM does not. So the minutes
//! are stored, and the record carries the model that produced them — replay
//! reproduces the *reference*, never the inference.

use std::collections::BTreeMap;
use std::fs::{File, OpenOptions};
use std::io::{BufRead, BufReader, Write};
use std::path::{Path, PathBuf};

/// A stored meeting.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Meeting {
    pub id: String,
    pub title: String,
    /// Seconds since the Unix epoch. Supplied by the caller, never read from a
    /// clock here — `C2` forbids wall-clock on a replay path.
    pub recorded_at: u64,
    pub transcript: String,
    pub minutes: String,
    /// Which model produced the minutes. `ADR-0018`: an LLM is not
    /// deterministic across versions, so what produced a summary is recorded
    /// with it rather than inferred later.
    pub model: String,
    /// `ADR-0022 §1`: the Meeting IR's decisions, hand-mirrored from
    /// `airo_mind_meeting::ir::Decision` rather than imported — this crate
    /// takes no dependency on `airo_mind_meeting` (`ADR-0022`'s explicit
    /// boundary decision, matching `airo_mind_transcript::segment::Segment`'s
    /// own "local mirror, not a re-export" precedent).
    pub decisions: Vec<MeetingDecision>,
    pub action_items: Vec<MeetingActionItem>,
    pub metrics: Vec<MeetingMetric>,
}

/// What a decision was, at the last point the transcript mentioned it.
/// Mirrors `airo_mind_meeting::ir::DecisionStatus` field-for-field.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub enum DecisionStatus {
    /// Raised, not settled. The default: silence is not agreement.
    #[default]
    Proposed,
    Agreed,
    Rejected,
    Deferred,
}

/// Where an action item stood at the last point the transcript mentioned it.
/// Mirrors `airo_mind_meeting::ir::ActionStatus` field-for-field.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub enum ActionStatus {
    #[default]
    Open,
    InProgress,
    Done,
    Blocked,
}

/// Something the meeting settled (or explicitly did not). Mirrors
/// `airo_mind_meeting::ir::Decision`; `evidence_segment_ids` is that type's
/// `evidence` field, renamed here to say plainly what it holds — segment ids
/// into the meeting's `transcript.json`, resolved per `ADR-0022 §4`.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct MeetingDecision {
    pub id: String,
    pub statement: String,
    pub status: DecisionStatus,
    pub evidence_segment_ids: Vec<String>,
}

/// Work someone is expected to do after the meeting. Mirrors
/// `airo_mind_meeting::ir::ActionItem`. `owner` is `None` when the transcript
/// named nobody — Pass 1 never infers one, and this type does not either.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct MeetingActionItem {
    pub id: String,
    pub task: String,
    pub owner: Option<String>,
    pub due: Option<String>,
    pub status: ActionStatus,
    pub evidence_segment_ids: Vec<String>,
}

/// A number the meeting quoted. Mirrors `airo_mind_meeting::ir::Metric`;
/// `value` stays a string for the same reason the source type's does — "about
/// 500,000" is a real answer and not an `f64`.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct MeetingMetric {
    pub id: String,
    pub name: String,
    pub value: String,
    pub evidence_segment_ids: Vec<String>,
}

#[derive(Debug)]
pub enum StoreError {
    Io(String),
    Corrupt(String),
}

impl std::fmt::Display for StoreError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Io(m) => write!(f, "store io: {m}"),
            Self::Corrupt(m) => write!(f, "store record is corrupt: {m}"),
        }
    }
}

impl std::error::Error for StoreError {}

/// Append-only meeting store.
pub struct MeetingStore {
    path: PathBuf,
}

/// Field separator. Chosen because it cannot occur in the escaped forms below,
/// so a record can be split without a parser.
const SEP: char = '\u{1f}';

fn escape(s: &str) -> String {
    s.replace('\\', "\\\\")
        .replace('\n', "\\n")
        .replace(SEP, "\\u")
}

fn unescape(s: &str) -> String {
    let mut out = String::with_capacity(s.len());
    let mut chars = s.chars();
    while let Some(c) = chars.next() {
        if c != '\\' {
            out.push(c);
            continue;
        }
        match chars.next() {
            Some('n') => out.push('\n'),
            Some('u') => out.push(SEP),
            Some('\\') => out.push('\\'),
            Some(other) => out.push(other),
            None => out.push('\\'),
        }
    }
    out
}

// ---------------------------------------------------------------------------
// IR field encoding
//
// `airo_mind_core` carries zero dependencies (see the crate root doc comment)
// so the three new `Meeting` fields cannot lean on serde. This is the same
// hand-rolled, length-prefixed discipline `notes.rs`'s `NoteOp::encode` /
// `decode` already use for its operation payloads: every string is written as
// its byte length, a `:`, then the bytes themselves, so no delimiter
// collision is possible regardless of what the transcript said. The result is
// one `String`, which then rides through `escape`/`unescape` like any other
// field -- a decision statement containing `SEP` or a backslash is escaped
// exactly as a transcript containing one already is.
// ---------------------------------------------------------------------------

fn push_len_str(out: &mut String, s: &str) {
    out.push_str(&s.len().to_string());
    out.push(':');
    out.push_str(s);
}

fn pop_len_str(s: &str, pos: &mut usize) -> Option<String> {
    let rest = s.get(*pos..)?;
    let colon = rest.find(':')?;
    let len: usize = rest[..colon].parse().ok()?;
    let start = *pos + colon + 1;
    let end = start.checked_add(len)?;
    let val = s.get(start..end)?.to_string();
    *pos = end;
    Some(val)
}

fn push_opt_str(out: &mut String, s: &Option<String>) {
    match s {
        Some(v) => {
            out.push('1');
            push_len_str(out, v);
        }
        None => out.push('0'),
    }
}

fn pop_opt_str(s: &str, pos: &mut usize) -> Option<Option<String>> {
    let flag = s.get(*pos..*pos + 1)?;
    *pos += 1;
    match flag {
        "1" => Some(Some(pop_len_str(s, pos)?)),
        "0" => Some(None),
        _ => None,
    }
}

fn push_str_vec(out: &mut String, items: &[String]) {
    out.push_str(&items.len().to_string());
    out.push(';');
    for item in items {
        push_len_str(out, item);
    }
}

fn pop_str_vec(s: &str, pos: &mut usize) -> Option<Vec<String>> {
    let rest = s.get(*pos..)?;
    let semi = rest.find(';')?;
    let count: usize = rest[..semi].parse().ok()?;
    *pos += semi + 1;
    let mut out = Vec::with_capacity(count);
    for _ in 0..count {
        out.push(pop_len_str(s, pos)?);
    }
    Some(out)
}

fn decision_status_digit(status: DecisionStatus) -> char {
    match status {
        DecisionStatus::Proposed => '0',
        DecisionStatus::Agreed => '1',
        DecisionStatus::Rejected => '2',
        DecisionStatus::Deferred => '3',
    }
}

fn decision_status_from_digit(c: char) -> Option<DecisionStatus> {
    match c {
        '0' => Some(DecisionStatus::Proposed),
        '1' => Some(DecisionStatus::Agreed),
        '2' => Some(DecisionStatus::Rejected),
        '3' => Some(DecisionStatus::Deferred),
        _ => None,
    }
}

fn action_status_digit(status: ActionStatus) -> char {
    match status {
        ActionStatus::Open => '0',
        ActionStatus::InProgress => '1',
        ActionStatus::Done => '2',
        ActionStatus::Blocked => '3',
    }
}

fn action_status_from_digit(c: char) -> Option<ActionStatus> {
    match c {
        '0' => Some(ActionStatus::Open),
        '1' => Some(ActionStatus::InProgress),
        '2' => Some(ActionStatus::Done),
        '3' => Some(ActionStatus::Blocked),
        _ => None,
    }
}

fn encode_decisions(items: &[MeetingDecision]) -> String {
    let mut out = String::new();
    out.push_str(&items.len().to_string());
    out.push(';');
    for item in items {
        push_len_str(&mut out, &item.id);
        push_len_str(&mut out, &item.statement);
        out.push(decision_status_digit(item.status));
        push_str_vec(&mut out, &item.evidence_segment_ids);
    }
    out
}

fn decode_decisions(s: &str) -> Option<Vec<MeetingDecision>> {
    let mut pos = 0usize;
    let semi = s.get(pos..)?.find(';')?;
    let count: usize = s[pos..pos + semi].parse().ok()?;
    pos += semi + 1;
    let mut out = Vec::with_capacity(count);
    for _ in 0..count {
        let id = pop_len_str(s, &mut pos)?;
        let statement = pop_len_str(s, &mut pos)?;
        let status = decision_status_from_digit(s.get(pos..pos + 1)?.chars().next()?)?;
        pos += 1;
        let evidence_segment_ids = pop_str_vec(s, &mut pos)?;
        out.push(MeetingDecision {
            id,
            statement,
            status,
            evidence_segment_ids,
        });
    }
    Some(out)
}

fn encode_action_items(items: &[MeetingActionItem]) -> String {
    let mut out = String::new();
    out.push_str(&items.len().to_string());
    out.push(';');
    for item in items {
        push_len_str(&mut out, &item.id);
        push_len_str(&mut out, &item.task);
        push_opt_str(&mut out, &item.owner);
        push_opt_str(&mut out, &item.due);
        out.push(action_status_digit(item.status));
        push_str_vec(&mut out, &item.evidence_segment_ids);
    }
    out
}

fn decode_action_items(s: &str) -> Option<Vec<MeetingActionItem>> {
    let mut pos = 0usize;
    let semi = s.get(pos..)?.find(';')?;
    let count: usize = s[pos..pos + semi].parse().ok()?;
    pos += semi + 1;
    let mut out = Vec::with_capacity(count);
    for _ in 0..count {
        let id = pop_len_str(s, &mut pos)?;
        let task = pop_len_str(s, &mut pos)?;
        let owner = pop_opt_str(s, &mut pos)?;
        let due = pop_opt_str(s, &mut pos)?;
        let status = action_status_from_digit(s.get(pos..pos + 1)?.chars().next()?)?;
        pos += 1;
        let evidence_segment_ids = pop_str_vec(s, &mut pos)?;
        out.push(MeetingActionItem {
            id,
            task,
            owner,
            due,
            status,
            evidence_segment_ids,
        });
    }
    Some(out)
}

fn encode_metrics(items: &[MeetingMetric]) -> String {
    let mut out = String::new();
    out.push_str(&items.len().to_string());
    out.push(';');
    for item in items {
        push_len_str(&mut out, &item.id);
        push_len_str(&mut out, &item.name);
        push_len_str(&mut out, &item.value);
        push_str_vec(&mut out, &item.evidence_segment_ids);
    }
    out
}

fn decode_metrics(s: &str) -> Option<Vec<MeetingMetric>> {
    let mut pos = 0usize;
    let semi = s.get(pos..)?.find(';')?;
    let count: usize = s[pos..pos + semi].parse().ok()?;
    pos += semi + 1;
    let mut out = Vec::with_capacity(count);
    for _ in 0..count {
        let id = pop_len_str(s, &mut pos)?;
        let name = pop_len_str(s, &mut pos)?;
        let value = pop_len_str(s, &mut pos)?;
        let evidence_segment_ids = pop_str_vec(s, &mut pos)?;
        out.push(MeetingMetric {
            id,
            name,
            value,
            evidence_segment_ids,
        });
    }
    Some(out)
}

impl MeetingStore {
    pub fn open(path: impl Into<PathBuf>) -> Self {
        Self { path: path.into() }
    }

    pub fn path(&self) -> &Path {
        &self.path
    }

    /// Appends a meeting. Re-saving the same id appends a new record; the
    /// latest wins on read. Nothing is rewritten in place, which is what makes
    /// this the log's shape rather than a database's.
    pub fn save(&self, meeting: &Meeting) -> Result<(), StoreError> {
        if let Some(parent) = self.path.parent() {
            std::fs::create_dir_all(parent).map_err(|e| StoreError::Io(e.to_string()))?;
        }
        let mut file = OpenOptions::new()
            .create(true)
            .append(true)
            .open(&self.path)
            .map_err(|e| StoreError::Io(e.to_string()))?;

        let line = [
            escape(&meeting.id),
            escape(&meeting.title),
            meeting.recorded_at.to_string(),
            escape(&meeting.model),
            escape(&meeting.transcript),
            escape(&meeting.minutes),
            escape(&encode_decisions(&meeting.decisions)),
            escape(&encode_action_items(&meeting.action_items)),
            escape(&encode_metrics(&meeting.metrics)),
        ]
        .join(&SEP.to_string());

        writeln!(file, "{line}").map_err(|e| StoreError::Io(e.to_string()))?;
        // Durability point. A meeting the user was told was saved must survive
        // the app being killed, which on Android happens without warning.
        file.sync_data()
            .map_err(|e| StoreError::Io(e.to_string()))?;
        Ok(())
    }

    /// Every meeting, newest record per id, ordered by `recorded_at` descending.
    pub fn all(&self) -> Result<Vec<Meeting>, StoreError> {
        let file = match File::open(&self.path) {
            Ok(f) => f,
            // No file yet is an empty store, not an error.
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => return Ok(Vec::new()),
            Err(e) => return Err(StoreError::Io(e.to_string())),
        };

        let mut latest: BTreeMap<String, Meeting> = BTreeMap::new();
        for line in BufReader::new(file).lines() {
            let line = line.map_err(|e| StoreError::Io(e.to_string()))?;
            if line.trim().is_empty() {
                continue;
            }
            let parts: Vec<&str> = line.split(SEP).collect();
            // 6 fields is a pre-`ADR-0022` record, written before the IR
            // fields existed -- it must still deserialize, defaulting the
            // new fields to empty rather than being treated as corrupt. 9 is
            // the current shape. Anything else is genuinely malformed.
            if parts.len() != 6 && parts.len() != 9 {
                return Err(StoreError::Corrupt(format!(
                    "expected 6 or 9 fields, found {}",
                    parts.len()
                )));
            }
            let recorded_at = parts[2]
                .parse::<u64>()
                .map_err(|e| StoreError::Corrupt(format!("recorded_at: {e}")))?;
            let (decisions, action_items, metrics) = if parts.len() == 9 {
                let decisions = decode_decisions(&unescape(parts[6]))
                    .ok_or_else(|| StoreError::Corrupt("decisions: malformed".into()))?;
                let action_items = decode_action_items(&unescape(parts[7]))
                    .ok_or_else(|| StoreError::Corrupt("action_items: malformed".into()))?;
                let metrics = decode_metrics(&unescape(parts[8]))
                    .ok_or_else(|| StoreError::Corrupt("metrics: malformed".into()))?;
                (decisions, action_items, metrics)
            } else {
                (Vec::new(), Vec::new(), Vec::new())
            };
            let meeting = Meeting {
                id: unescape(parts[0]),
                title: unescape(parts[1]),
                recorded_at,
                model: unescape(parts[3]),
                transcript: unescape(parts[4]),
                minutes: unescape(parts[5]),
                decisions,
                action_items,
                metrics,
            };
            latest.insert(meeting.id.clone(), meeting);
        }

        let mut out: Vec<Meeting> = latest.into_values().collect();
        out.sort_by(|a, b| b.recorded_at.cmp(&a.recorded_at).then(a.id.cmp(&b.id)));
        Ok(out)
    }

    /// Reopens one meeting.
    pub fn get(&self, id: &str) -> Result<Option<Meeting>, StoreError> {
        Ok(self.all()?.into_iter().find(|m| m.id == id))
    }

    /// Drops [id] by rewriting the log with the remaining latest records.
    /// Returns whether a meeting with that id was present.
    pub fn delete(&self, id: &str) -> Result<bool, StoreError> {
        let all = self.all()?;
        let existed = all.iter().any(|meeting| meeting.id == id);
        if !existed {
            return Ok(false);
        }
        let remaining: Vec<Meeting> = all.into_iter().filter(|meeting| meeting.id != id).collect();
        OpenOptions::new()
            .create(true)
            .write(true)
            .truncate(true)
            .open(&self.path)
            .map_err(|e| StoreError::Io(e.to_string()))?;
        for meeting in remaining {
            self.save(&meeting)?;
        }
        Ok(true)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn temp(name: &str) -> PathBuf {
        std::env::temp_dir().join(format!("airo_mind_store_{name}_{}.log", std::process::id()))
    }

    fn meeting(id: &str, at: u64) -> Meeting {
        Meeting {
            id: id.into(),
            title: format!("Standup {id}"),
            recorded_at: at,
            transcript: "Kafka consumer lag is the bottleneck.".into(),
            minutes: "- Add three pods\n- Raj owns rollout".into(),
            model: "qwen2.5-0.5b-instruct-q4_k_m".into(),
            decisions: Vec::new(),
            action_items: Vec::new(),
            metrics: Vec::new(),
        }
    }

    fn meeting_with_ir(id: &str, at: u64) -> Meeting {
        let mut m = meeting(id, at);
        m.decisions = vec![MeetingDecision {
            id: "d0".into(),
            statement: "Ship the rollout on Friday".into(),
            status: DecisionStatus::Agreed,
            evidence_segment_ids: vec!["s3".into(), "s4".into()],
        }];
        m.action_items = vec![MeetingActionItem {
            id: "a0".into(),
            task: "Add three pods before Friday".into(),
            owner: Some("Raj".into()),
            due: Some("Friday".into()),
            status: ActionStatus::Open,
            evidence_segment_ids: vec!["s5".into()],
        }];
        m.metrics = vec![MeetingMetric {
            id: "me0".into(),
            name: "consumer lag".into(),
            value: "about 500,000".into(),
            evidence_segment_ids: vec!["s1".into()],
        }];
        m
    }

    /// `#1399` exit criterion: a meeting reopens.
    #[test]
    fn a_saved_meeting_reopens_with_transcript_and_minutes() {
        let path = temp("reopen");
        let _ = std::fs::remove_file(&path);
        let store = MeetingStore::open(&path);

        let m = meeting("m1", 1_700_000_000);
        store.save(&m).unwrap();

        // A NEW handle, as a restarted app would have.
        let reopened = MeetingStore::open(&path).get("m1").unwrap().unwrap();
        assert_eq!(reopened, m);
        assert!(reopened.minutes.contains("Raj owns rollout"));
        let _ = std::fs::remove_file(&path);
    }

    #[test]
    fn delete_drops_one_meeting_and_keeps_the_others() {
        let path = temp("delete");
        let _ = std::fs::remove_file(&path);
        let store = MeetingStore::open(&path);
        store.save(&meeting("m1", 1)).unwrap();
        store.save(&meeting("m2", 2)).unwrap();

        assert!(store.delete("m1").unwrap());
        assert!(!store.delete("m1").unwrap());
        let remaining = store.all().unwrap();
        assert_eq!(remaining.len(), 1);
        assert_eq!(remaining[0].id, "m2");
        let _ = std::fs::remove_file(&path);
    }

    #[test]
    fn multiline_transcripts_survive_the_round_trip() {
        let path = temp("multiline");
        let _ = std::fs::remove_file(&path);
        let store = MeetingStore::open(&path);

        let mut m = meeting("m2", 1);
        m.transcript = "line one\nline two\nline three".into();
        m.minutes = "### Decisions\n- one\n- two".into();
        store.save(&m).unwrap();

        assert_eq!(store.get("m2").unwrap().unwrap(), m);
        let _ = std::fs::remove_file(&path);
    }

    #[test]
    fn re_saving_appends_and_the_latest_wins() {
        let path = temp("append");
        let _ = std::fs::remove_file(&path);
        let store = MeetingStore::open(&path);

        store.save(&meeting("m3", 1)).unwrap();
        let mut edited = meeting("m3", 1);
        edited.minutes = "corrected minutes".into();
        store.save(&edited).unwrap();

        assert_eq!(store.all().unwrap().len(), 1, "one meeting, not two");
        assert_eq!(
            store.get("m3").unwrap().unwrap().minutes,
            "corrected minutes"
        );

        // The earlier record is still on disk -- append-only, nothing rewritten.
        let raw = std::fs::read_to_string(&path).unwrap();
        assert_eq!(raw.lines().count(), 2);
        let _ = std::fs::remove_file(&path);
    }

    #[test]
    fn an_absent_store_is_empty_not_an_error() {
        let store = MeetingStore::open(temp("absent"));
        assert!(store.all().unwrap().is_empty());
        assert!(store.get("nope").unwrap().is_none());
    }

    #[test]
    fn meetings_come_back_newest_first() {
        let path = temp("order");
        let _ = std::fs::remove_file(&path);
        let store = MeetingStore::open(&path);
        store.save(&meeting("old", 100)).unwrap();
        store.save(&meeting("new", 900)).unwrap();

        let all = store.all().unwrap();
        assert_eq!(all[0].id, "new");
        assert_eq!(all[1].id, "old");
        let _ = std::fs::remove_file(&path);
    }

    /// `ADR-0022 §1`: decisions/action-items/metrics round-trip through the
    /// same append-only file, evidence ids included.
    #[test]
    fn decisions_action_items_and_metrics_round_trip() {
        let path = temp("ir_round_trip");
        let _ = std::fs::remove_file(&path);
        let store = MeetingStore::open(&path);

        let m = meeting_with_ir("m4", 1);
        store.save(&m).unwrap();

        let reopened = MeetingStore::open(&path).get("m4").unwrap().unwrap();
        assert_eq!(reopened, m);
        assert_eq!(
            reopened.decisions[0].statement,
            "Ship the rollout on Friday"
        );
        assert_eq!(reopened.decisions[0].status, DecisionStatus::Agreed);
        assert_eq!(
            reopened.decisions[0].evidence_segment_ids,
            vec!["s3".to_string(), "s4".to_string()]
        );
        assert_eq!(reopened.action_items[0].owner.as_deref(), Some("Raj"));
        assert_eq!(reopened.action_items[0].due.as_deref(), Some("Friday"));
        assert_eq!(reopened.action_items[0].status, ActionStatus::Open);
        assert_eq!(reopened.metrics[0].value, "about 500,000");
        let _ = std::fs::remove_file(&path);
    }

    /// An action item with no owner or due date -- the transcript named
    /// nobody -- must round-trip `None`, not an empty string that a reader
    /// could mistake for "named, but blank".
    #[test]
    fn an_action_item_with_no_owner_round_trips_as_none() {
        let path = temp("no_owner");
        let _ = std::fs::remove_file(&path);
        let store = MeetingStore::open(&path);

        let mut m = meeting_with_ir("m5", 1);
        m.action_items[0].owner = None;
        m.action_items[0].due = None;
        store.save(&m).unwrap();

        let reopened = MeetingStore::open(&path).get("m5").unwrap().unwrap();
        assert_eq!(reopened.action_items[0].owner, None);
        assert_eq!(reopened.action_items[0].due, None);
        let _ = std::fs::remove_file(&path);
    }

    /// Decision/action-item text can itself contain the field separator,
    /// newlines, and backslashes -- the same characters a transcript can
    /// already contain. The length-prefixed inner encoding plus the outer
    /// `escape`/`unescape` pass must survive it unchanged.
    #[test]
    fn ir_text_containing_separators_and_newlines_survives_the_round_trip() {
        let path = temp("ir_escaping");
        let _ = std::fs::remove_file(&path);
        let store = MeetingStore::open(&path);

        let mut m = meeting_with_ir("m6", 1);
        m.decisions[0].statement = format!("Line one\nLine two{SEP}with a unit separator\\done");
        store.save(&m).unwrap();

        let reopened = MeetingStore::open(&path).get("m6").unwrap().unwrap();
        assert_eq!(reopened.decisions[0].statement, m.decisions[0].statement);
        let _ = std::fs::remove_file(&path);
    }

    /// Backward compatibility: a record written before `ADR-0022` (six
    /// fields, no IR) must still deserialize, with the new fields defaulting
    /// to empty rather than the store treating the line as corrupt.
    #[test]
    fn a_pre_ir_six_field_record_still_deserializes() {
        let path = temp("legacy_six_field");
        let _ = std::fs::remove_file(&path);
        std::fs::create_dir_all(path.parent().unwrap()).unwrap();
        let legacy_line = [
            escape("legacy-1"),
            escape("Legacy Standup"),
            "42".to_string(),
            escape("qwen2.5-0.5b"),
            escape("Old transcript."),
            escape("Old minutes."),
        ]
        .join(&SEP.to_string());
        std::fs::write(&path, format!("{legacy_line}\n")).unwrap();

        let store = MeetingStore::open(&path);
        let reopened = store.get("legacy-1").unwrap().unwrap();
        assert_eq!(reopened.transcript, "Old transcript.");
        assert!(reopened.decisions.is_empty());
        assert!(reopened.action_items.is_empty());
        assert!(reopened.metrics.is_empty());
        let _ = std::fs::remove_file(&path);
    }

    /// A line with a field count that is neither the legacy 6 nor the
    /// current 9 is genuinely malformed, not a third schema to guess at.
    #[test]
    fn a_line_with_an_unrecognised_field_count_is_corrupt() {
        let path = temp("bad_field_count");
        let _ = std::fs::remove_file(&path);
        let bad_line = ["a", "b", "0", "c", "d", "e", "f"].join(&SEP.to_string());
        std::fs::create_dir_all(path.parent().unwrap()).unwrap();
        std::fs::write(&path, format!("{bad_line}\n")).unwrap();

        let store = MeetingStore::open(&path);
        assert!(matches!(store.all(), Err(StoreError::Corrupt(_))));
        let _ = std::fs::remove_file(&path);
    }
}
