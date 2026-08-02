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
            if parts.len() != 6 {
                return Err(StoreError::Corrupt(format!(
                    "expected 6 fields, found {}",
                    parts.len()
                )));
            }
            let recorded_at = parts[2]
                .parse::<u64>()
                .map_err(|e| StoreError::Corrupt(format!("recorded_at: {e}")))?;
            let meeting = Meeting {
                id: unescape(parts[0]),
                title: unescape(parts[1]),
                recorded_at,
                model: unescape(parts[3]),
                transcript: unescape(parts[4]),
                minutes: unescape(parts[5]),
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
        }
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
}
