//! Research library — previous jobs compound. Not a sidecar database.
//!
//! Incremental research = prior sources + freshness + delta. The durable
//! form is an operation-log record (`I2`).

use super::search::canonicalize_url;

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ResearchLibraryEntry {
    pub topic_key: String,
    pub question: String,
    pub retrieved_at: String,
    pub source_urls: Vec<String>,
    pub findings: Vec<String>,
}

impl ResearchLibraryEntry {
    pub fn new(
        question: impl Into<String>,
        retrieved_at: impl Into<String>,
        source_urls: Vec<String>,
        findings: Vec<String>,
    ) -> Self {
        let question = question.into();
        Self {
            topic_key: topic_key(&question),
            question,
            retrieved_at: retrieved_at.into(),
            source_urls: source_urls
                .into_iter()
                .map(|url| canonicalize_url(&url))
                .collect(),
            findings,
        }
    }

    pub fn to_record(&self) -> String {
        format!(
            "v1\u{1f}{}\u{1f}{}\u{1f}{}\u{1f}{}\u{1f}{}",
            self.topic_key.replace('\u{1f}', " "),
            self.question.replace('\u{1f}', " "),
            self.retrieved_at,
            self.source_urls.join(","),
            self.findings.join("||"),
        )
    }

    pub fn from_record(record: &str) -> Option<Self> {
        let parts: Vec<&str> = record.split('\u{1f}').collect();
        if parts.len() != 6 || parts[0] != "v1" {
            return None;
        }
        Some(Self {
            topic_key: parts[1].to_string(),
            question: parts[2].to_string(),
            retrieved_at: parts[3].to_string(),
            source_urls: if parts[4].is_empty() {
                Vec::new()
            } else {
                parts[4].split(',').map(str::to_string).collect()
            },
            findings: if parts[5].is_empty() {
                Vec::new()
            } else {
                parts[5].split("||").map(str::to_string).collect()
            },
        })
    }
}

pub fn topic_key(question: &str) -> String {
    question
        .trim()
        .to_ascii_lowercase()
        .split_whitespace()
        .collect::<Vec<_>>()
        .join(" ")
}

/// URLs that a follow-up job can skip. Hits whose canonical URL is new are
/// the delta — search snippets are still not evidence.
pub fn delta_urls(previous: &[String], candidates: &[String]) -> Vec<String> {
    let known: std::collections::BTreeSet<String> =
        previous.iter().map(|url| canonicalize_url(url)).collect();
    candidates
        .iter()
        .map(|url| canonicalize_url(url))
        .filter(|url| !known.contains(url))
        .collect()
}

#[derive(Default)]
pub struct InMemoryResearchLibrary {
    entries: Vec<ResearchLibraryEntry>,
}

impl InMemoryResearchLibrary {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn put(&mut self, entry: ResearchLibraryEntry) {
        self.entries.push(entry);
    }

    pub fn find_by_topic(&self, question: &str) -> Option<&ResearchLibraryEntry> {
        let key = topic_key(question);
        self.entries
            .iter()
            .rev()
            .find(|entry| entry.topic_key == key)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn library_roundtrip_preserves_sources_and_findings() {
        let entry = ResearchLibraryEntry::new(
            "What is Qwen?",
            "2026-08-22T00:00:00Z",
            vec!["https://en.wikipedia.org/wiki/Qwen?utm_source=x".into()],
            vec!["Qwen is a family of large language models.".into()],
        );
        let restored = ResearchLibraryEntry::from_record(&entry.to_record()).unwrap();
        assert_eq!(restored.topic_key, "what is qwen?");
        assert_eq!(
            restored.source_urls,
            vec!["https://en.wikipedia.org/wiki/Qwen"]
        );
        assert_eq!(
            restored.findings,
            vec!["Qwen is a family of large language models."]
        );
    }

    #[test]
    fn follow_up_research_skips_known_urls_and_keeps_the_delta() {
        let previous = ["https://en.wikipedia.org/wiki/Qwen".to_string()];
        let candidates = [
            "https://www.en.wikipedia.org/wiki/Qwen?utm_source=x".to_string(),
            "https://arxiv.org/abs/2401.12345".to_string(),
        ];
        let delta = delta_urls(&previous, &candidates);
        assert_eq!(delta, vec!["https://arxiv.org/abs/2401.12345"]);
    }

    #[test]
    fn same_topic_reuses_the_latest_library_entry() {
        let mut library = InMemoryResearchLibrary::new();
        library.put(ResearchLibraryEntry::new(
            "What is Qwen?",
            "2026-01-01T00:00:00Z",
            vec!["https://en.wikipedia.org/wiki/Qwen".into()],
            vec!["old".into()],
        ));
        library.put(ResearchLibraryEntry::new(
            "what is qwen?",
            "2026-08-22T00:00:00Z",
            vec!["https://arxiv.org/abs/2401.12345".into()],
            vec!["new".into()],
        ));
        let found = library.find_by_topic("WHAT IS QWEN?").unwrap();
        assert_eq!(found.findings, vec!["new"]);
        assert_eq!(found.retrieved_at, "2026-08-22T00:00:00Z");
    }
}
