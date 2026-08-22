//! In-process ResearchService. SearchEngine/Fetcher are injected; this crate
//! never opens a socket.
//!
//! Flutter talks to this API (`start` / `status` / `pause` / `resume` /
//! `cancel` / `report`). HTTP adapters stay outside `airo_mind_core`.

use std::collections::BTreeMap;

use super::document::{classify_url, extract_document};
use super::interpreter::{interpret, InterpretedGoal, ResearchIntent};
use super::planner::{PlanNodeKind, ResearchPlan};
use super::query::queries_for;
use super::request::{ResearchRequest, SearchPolicy};
use super::search::{SearchEngine, SearchHit, SearchRequest};
use super::state::{
    InMemoryResearchService, ResearchCheckpoint, ResearchCommand, ResearchJobState,
    ResearchStateError,
};
use super::stopping::{EvidenceSufficiencyPolicy, ResearchProgress, StopDecision, StoppingPolicy};

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ResearchEventKind {
    JobAdmitted,
    PlanningStarted,
    IntentClassified,
    PlanCreated,
    SearchStarted,
    SearchCompleted,
    SourceDiscovered,
    SourceFetched,
    SourceRejected,
    DocumentParsed,
    AnalyzingStarted,
    ClaimCreated,
    GapDetected,
    CounterResearchStarted,
    ConflictDetected,
    SynthesisStarted,
    Completed,
    Failed,
    Paused,
    Cancelled,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ResearchEvent {
    pub kind: ResearchEventKind,
    pub job_id: String,
    pub label: String,
    pub detail: String,
}

/// Fetch is I/O. Implementations live outside this crate (Dart today, a
/// future search cdylib later). The engine only consumes page text.
pub trait SourceFetcher: Send + Sync {
    fn fetch(&self, url: &str) -> Result<String, String>;
}

/// Owns the research loop. Not a prompt.
pub struct ResearchEngine {
    engines: Vec<Box<dyn SearchEngine>>,
    fetcher: Box<dyn SourceFetcher>,
    service: InMemoryResearchService,
    reports: BTreeMap<String, String>,
}

impl ResearchEngine {
    pub fn new(engines: Vec<Box<dyn SearchEngine>>, fetcher: Box<dyn SourceFetcher>) -> Self {
        Self {
            engines,
            fetcher,
            service: InMemoryResearchService::new(),
            reports: BTreeMap::new(),
        }
    }

    pub fn start(&mut self, request: ResearchRequest) -> String {
        self.service.start(request)
    }

    pub fn status(&self, job_id: &str) -> Option<ResearchJobState> {
        self.service.status(job_id)
    }

    pub fn pause(&mut self, job_id: &str) -> Result<(), ResearchStateError> {
        self.service.pause(job_id)
    }

    pub fn resume(&mut self, job_id: &str) -> Result<(), ResearchStateError> {
        self.service.resume(job_id)
    }

    pub fn cancel(&mut self, job_id: &str) -> Result<(), ResearchStateError> {
        self.service.cancel(job_id)
    }

    pub fn report(&self, job_id: &str) -> Option<&str> {
        self.reports.get(job_id).map(String::as_str)
    }

    pub fn checkpoint(&self, job_id: &str) -> Option<ResearchCheckpoint> {
        self.service.checkpoint(job_id)
    }

    pub fn restore(&mut self, checkpoint: ResearchCheckpoint) -> Result<(), ResearchStateError> {
        self.service.restore(checkpoint)
    }

    pub fn run(
        &mut self,
        job_id: &str,
        known_source_urls: &[String],
    ) -> Result<Vec<ResearchEvent>, ResearchStateError> {
        let checkpoint = self
            .service
            .checkpoint(job_id)
            .ok_or(ResearchStateError::UnknownJob)?;
        let mut events = vec![event(
            ResearchEventKind::JobAdmitted,
            job_id,
            "Research admitted",
            job_id,
        )];
        match checkpoint.state {
            ResearchJobState::Cancelled => {
                events.push(event(
                    ResearchEventKind::Cancelled,
                    job_id,
                    "Research cancelled",
                    "",
                ));
                return Ok(events);
            }
            ResearchJobState::Paused => {
                events.push(event(
                    ResearchEventKind::Paused,
                    job_id,
                    "Research paused",
                    "",
                ));
                return Ok(events);
            }
            ResearchJobState::Completed | ResearchJobState::Failed => {
                return Ok(events);
            }
            _ => {}
        }

        let request = self
            .service
            .job(job_id)
            .ok_or(ResearchStateError::UnknownJob)?
            .request
            .clone();
        let question = request.question.trim().to_string();
        if question.is_empty() {
            self.service.apply(job_id, ResearchCommand::Fail)?;
            events.push(event(
                ResearchEventKind::Failed,
                job_id,
                "Research failed",
                "A research question is required.",
            ));
            return Ok(events);
        }

        self.service.apply(job_id, ResearchCommand::StartPlanning)?;
        events.push(event(
            ResearchEventKind::PlanningStarted,
            job_id,
            "Understanding question",
            "",
        ));
        let goal = interpret(&request);
        events.push(event(
            ResearchEventKind::IntentClassified,
            job_id,
            "Understanding question",
            goal.intent.as_str(),
        ));
        let plan = ResearchPlan::from_request(&request);
        events.push(event(
            ResearchEventKind::PlanCreated,
            job_id,
            "Creating research plan",
            format!(
                "strategy={}\n{}",
                plan.strategy_id,
                plan.nodes
                    .iter()
                    .map(|node| format!("- {}", node.question))
                    .collect::<Vec<_>>()
                    .join("\n")
            ),
        ));
        self.service.apply(job_id, ResearchCommand::PlanReady)?;

        events.push(event(
            ResearchEventKind::SearchStarted,
            job_id,
            "Searching sources",
            "",
        ));
        let routed: Vec<&dyn SearchEngine> = self
            .engines
            .iter()
            .map(|engine| engine.as_ref())
            .filter(|engine| engine_allowed(request.policy, engine.id()))
            .collect();
        let budget = request.budget();
        let mut searches_used = 0u32;
        let mut hits = Vec::new();
        let breadth: Vec<_> = plan
            .nodes
            .iter()
            .filter(|node| node.kind == PlanNodeKind::Breadth)
            .collect();
        let depth: Vec<_> = plan
            .nodes
            .iter()
            .filter(|node| node.kind == PlanNodeKind::Depth)
            .collect();
        search_nodes(
            &routed,
            &breadth,
            budget.max_searches,
            &mut searches_used,
            &mut hits,
        );
        let mut unique =
            filter_known_hits(super::search::dedupe_hits(hits.clone()), known_source_urls);
        let progress = ResearchProgress {
            searches_used,
            max_searches: budget.max_searches,
            sources: unique.len() as u32,
            uncovered_nodes: depth.len(),
            iterations_used: 1,
            max_iterations: budget.max_iterations,
            cost_used: super::metrics::ResearchCostModel::default().estimate(
                searches_used,
                unique.len() as u32,
                0,
            ),
            max_cost: budget.max_cost_micros,
        };
        if !depth.is_empty()
            && EvidenceSufficiencyPolicy.should_stop(&progress) == StopDecision::Continue
        {
            events.push(event(
                ResearchEventKind::GapDetected,
                job_id,
                "Finding missing evidence",
                "Depth facets were not covered by the first search wave.",
            ));
            search_nodes(
                &routed,
                &depth,
                budget.max_searches,
                &mut searches_used,
                &mut hits,
            );
            unique = filter_known_hits(super::search::dedupe_hits(hits), known_source_urls);
        }
        if goal.decision_required && searches_used < budget.max_searches {
            events.push(event(
                ResearchEventKind::CounterResearchStarted,
                job_id,
                "Finding missing evidence",
                queries_for(&goal.topic).counterargument,
            ));
        }
        self.service
            .apply(job_id, ResearchCommand::SearchFinished)?;
        events.push(event(
            ResearchEventKind::SearchCompleted,
            job_id,
            "Searching sources",
            "",
        ));
        for hit in &unique {
            events.push(event(
                ResearchEventKind::SourceDiscovered,
                job_id,
                "Reading documents",
                format!("{} — {}", hit.title, hit.url),
            ));
        }
        let mut rejected = 0u32;
        let mut documents = Vec::new();
        for hit in &unique {
            match self.fetcher.fetch(&hit.url) {
                Ok(raw) => {
                    let extracted = extract_document(&raw, Some(&hit.url));
                    if extracted.evidence_text().trim().is_empty() {
                        rejected = rejected.saturating_add(1);
                        events.push(event(
                            ResearchEventKind::SourceRejected,
                            job_id,
                            "Reading documents",
                            "empty document",
                        ));
                        continue;
                    }
                    events.push(event(
                        ResearchEventKind::SourceFetched,
                        job_id,
                        "Reading documents",
                        hit.url.clone(),
                    ));
                    let class = classify_url(&hit.url);
                    events.push(event(
                        ResearchEventKind::DocumentParsed,
                        job_id,
                        "Reading documents",
                        format!("{} ({:?}/{:?})", extracted.title, class.kind, class.class),
                    ));
                    documents.push(Acquired {
                        url: super::search::canonicalize_url(&hit.url),
                        title: if extracted.title.is_empty() {
                            hit.title.clone()
                        } else {
                            extracted.title
                        },
                        paragraphs: extracted.paragraphs,
                        tables: extracted.tables,
                        class,
                    });
                }
                Err(reason) => {
                    rejected = rejected.saturating_add(1);
                    events.push(event(
                        ResearchEventKind::SourceRejected,
                        job_id,
                        "Reading documents",
                        reason,
                    ))
                }
            }
        }
        self.service
            .apply(job_id, ResearchCommand::CollectionFinished)?;

        events.push(event(
            ResearchEventKind::AnalyzingStarted,
            job_id,
            "Comparing evidence",
            "",
        ));
        let mut claims = Vec::new();
        for document in &documents {
            for text in document.paragraphs.iter().chain(document.tables.iter()) {
                let text = text.trim();
                if text.len() < 12 {
                    continue;
                }
                claims.push((text.to_string(), document.url.clone()));
                events.push(event(
                    ResearchEventKind::ClaimCreated,
                    job_id,
                    "Comparing evidence",
                    format!("supported: {text}"),
                ));
            }
        }
        self.service
            .apply(job_id, ResearchCommand::AnalysisFinished)?;
        let mut conflicts = 0u32;
        for i in 0..claims.len() {
            for j in (i + 1)..claims.len() {
                let reasons = super::evidence::contradiction_reasons(&claims[i].0, &claims[j].0);
                if reasons.is_empty() {
                    continue;
                }
                conflicts += 1;
                events.push(event(
                    ResearchEventKind::ConflictDetected,
                    job_id,
                    "Comparing evidence",
                    format!(
                        "{} vs {} ({})",
                        claims[i].0,
                        claims[j].0,
                        reasons.join(", ")
                    ),
                ));
            }
        }
        self.service
            .apply(job_id, ResearchCommand::VerificationFinished)?;
        self.service.apply(job_id, ResearchCommand::GapsResolved)?;
        events.push(event(
            ResearchEventKind::SynthesisStarted,
            job_id,
            "Writing report",
            "",
        ));
        let metrics = super::metrics::ResearchMetrics {
            duration_ms: 0,
            searches: searches_used,
            sources_used: documents.len() as u32,
            sources_rejected: rejected,
            claims: claims.len() as u32,
            contradictions: conflicts,
            tokens: 0,
            cost_micros: 0,
        }
        .with_cost(super::metrics::ResearchCostModel::default());
        let report = compose_report(
            &request,
            &plan,
            &goal,
            &documents,
            &claims,
            conflicts as usize,
            metrics,
        );
        self.service
            .apply(job_id, ResearchCommand::SynthesisFinished)?;
        self.service
            .apply(job_id, ResearchCommand::ValidationPassed)?;
        self.reports.insert(job_id.to_string(), report.clone());
        events.push(event(
            ResearchEventKind::Completed,
            job_id,
            "Research completed",
            report,
        ));
        Ok(events)
    }
}

struct Acquired {
    url: String,
    title: String,
    paragraphs: Vec<String>,
    tables: Vec<String>,
    class: super::document::SourceClassification,
}

fn filter_known_hits(mut hits: Vec<SearchHit>, known_source_urls: &[String]) -> Vec<SearchHit> {
    if known_source_urls.is_empty() {
        return hits;
    }
    let skip: std::collections::BTreeSet<String> = known_source_urls
        .iter()
        .map(|url| super::search::canonicalize_url(url))
        .collect();
    hits.retain(|hit| !skip.contains(&super::search::canonicalize_url(&hit.url)));
    hits
}

fn event(
    kind: ResearchEventKind,
    job_id: impl Into<String>,
    label: impl Into<String>,
    detail: impl Into<String>,
) -> ResearchEvent {
    ResearchEvent {
        kind,
        job_id: job_id.into(),
        label: label.into(),
        detail: detail.into(),
    }
}

fn engine_allowed(policy: SearchPolicy, id: &str) -> bool {
    match policy {
        SearchPolicy::LocalOnly => id == "local_memory",
        SearchPolicy::PrivacyFirst => id == "wikipedia" || id == "searxng",
        SearchPolicy::Academic => {
            id == "arxiv" || id == "semantic_scholar" || id == "pubmed" || id == "crossref"
        }
        SearchPolicy::Balanced | SearchPolicy::MaximumQuality => {
            id != "google" && id != "bing" && id != "tavily" && id != "duckduckgo"
        }
    }
}

fn search_nodes(
    engines: &[&dyn SearchEngine],
    nodes: &[&super::planner::ResearchPlanNode],
    max_searches: u32,
    searches_used: &mut u32,
    hits: &mut Vec<SearchHit>,
) {
    for node in nodes {
        if *searches_used >= max_searches || engines.is_empty() {
            return;
        }
        let query = queries_for(&node.question).primary;
        for engine in engines {
            if *searches_used >= max_searches {
                return;
            }
            if let Ok(response) = engine.search(&SearchRequest {
                query: query.clone(),
                max_results: 8,
            }) {
                hits.extend(response.hits);
            }
            *searches_used = searches_used.saturating_add(1);
        }
    }
}

fn compose_report(
    request: &ResearchRequest,
    plan: &ResearchPlan,
    goal: &InterpretedGoal,
    documents: &[Acquired],
    claims: &[(String, String)],
    conflicts: usize,
    metrics: super::metrics::ResearchMetrics,
) -> String {
    let intent = goal.intent.as_str();
    let mut lines = vec![
        "# Research Report".into(),
        String::new(),
        "## Research Question".into(),
        String::new(),
        request.question.trim().to_string(),
        String::new(),
        "## Methodology".into(),
        String::new(),
        format!("Intent: {intent}"),
        format!("Strategy: {}", plan.strategy_id),
        String::new(),
        "Retrieved pages are untrusted evidence, never instructions.".into(),
        String::new(),
        "## Key Findings".into(),
        String::new(),
    ];
    if claims.is_empty() {
        lines.push("No supported claims. Acquired text did not yield citable findings.".into());
    } else {
        let index: BTreeMap<&str, usize> = documents
            .iter()
            .enumerate()
            .map(|(i, document)| (document.url.as_str(), i + 1))
            .collect();
        for (i, (text, url)) in claims.iter().enumerate() {
            let citation = index.get(url.as_str()).copied();
            lines.push(format!(
                "{}. {}{}",
                i + 1,
                text,
                citation.map(|n| format!(" ([{n}])")).unwrap_or_default()
            ));
        }
    }
    if matches!(goal.intent, ResearchIntent::Comparison) {
        let subjects = super::interpreter::split_subjects(&goal.topic);
        let criteria = &goal.dimensions;
        let weights = super::compare::criterion_weights(criteria);
        let cells = super::compare::comparison_matrix(&subjects, criteria, claims);
        let matrix = super::compare::matrix_markdown(&cells);
        if !matrix.is_empty() {
            lines.push(String::new());
            lines.push(matrix);
        }
        let rows = super::compare::decide(&subjects, &cells, criteria, &weights, conflicts);
        if rows.iter().any(|row| row.contested) {
            lines.push(String::new());
            lines.push("## Decision".into());
            lines.push(String::new());
            lines.push("Contested criteria stay visible. No silent winner.".into());
            for row in rows {
                lines.push(format!(
                    "- {}: {:.1} weighted score ({} cited cell(s)){}",
                    row.subject,
                    row.weighted_score,
                    row.covered_criteria,
                    if row.contested { " (contested)" } else { "" }
                ));
            }
        }
    }
    lines.push(String::new());
    lines.push("## Sources".into());
    lines.push(String::new());
    for (i, document) in documents.iter().enumerate() {
        lines.push(format!(
            "[{}] {} — {} ({:?}/{:?})",
            i + 1,
            document.title,
            document.url,
            document.class.class,
            document.class.kind
        ));
    }
    lines.push(String::new());
    lines.push(metrics.markdown());
    lines.join("\n")
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::research::request::ResearchMode;
    use crate::research::search::{SearchError, SearchResponse};

    struct FakeSearch {
        id: &'static str,
        url: &'static str,
        snippet: &'static str,
    }

    impl SearchEngine for FakeSearch {
        fn id(&self) -> &'static str {
            self.id
        }

        fn search(&self, request: &SearchRequest) -> Result<SearchResponse, SearchError> {
            if request.query.trim().is_empty() {
                return Err(SearchError::InvalidQuery);
            }
            Ok(SearchResponse {
                engine_id: self.id.to_string(),
                hits: vec![SearchHit {
                    url: self.url.to_string(),
                    title: "Qwen".into(),
                    snippet: self.snippet.to_string(),
                }],
            })
        }
    }

    struct FakeFetch {
        body: &'static str,
    }

    impl SourceFetcher for FakeFetch {
        fn fetch(&self, _url: &str) -> Result<String, String> {
            Ok(self.body.to_string())
        }
    }

    const PAGE: &str =
        "<article><h1>Qwen</h1><p>Qwen is a family of large language models.</p></article>";

    fn quick(question: &str) -> ResearchRequest {
        let mut request = ResearchRequest::new(question);
        request.mode = ResearchMode::Quick;
        request.policy = SearchPolicy::Balanced;
        request
    }

    #[test]
    fn empty_question_fails_instead_of_inventing_a_report() {
        let search = FakeSearch {
            id: "wikipedia",
            url: "https://en.wikipedia.org/wiki/Qwen",
            snippet: "SEARCH SNIPPET ONLY",
        };
        let fetch = FakeFetch { body: PAGE };
        let mut engine = ResearchEngine::new(vec![Box::new(search)], Box::new(fetch));
        let job_id = engine.start(quick("   "));
        let events = engine
            .run(&job_id, &[])
            .expect("empty questions still admit");
        assert_eq!(
            events.last().map(|e| e.kind),
            Some(ResearchEventKind::Failed)
        );
        assert!(engine.report(&job_id).is_none());
    }

    #[test]
    fn report_cites_acquired_text_not_search_snippets() {
        let search = FakeSearch {
            id: "wikipedia",
            url: "https://en.wikipedia.org/wiki/Qwen",
            snippet: "SEARCH SNIPPET ONLY",
        };
        let fetch = FakeFetch { body: PAGE };
        let mut engine = ResearchEngine::new(vec![Box::new(search)], Box::new(fetch));
        let job_id = engine.start(quick("What is Qwen?"));
        assert_eq!(engine.status(&job_id), Some(ResearchJobState::Created));
        let events = engine.run(&job_id, &[]).expect("run");
        assert_eq!(
            events.last().map(|e| e.kind),
            Some(ResearchEventKind::Completed)
        );
        let report = engine.report(&job_id).unwrap();
        assert!(report.contains("Qwen is a family"));
        assert!(report.contains("[1]"));
        assert!(report.contains("https://en.wikipedia.org/wiki/Qwen"));
        assert!(!report.contains("SEARCH SNIPPET ONLY"));
        assert!(report.contains("## Observability"));
        assert!(report.contains("Searches:"));
        assert!(report.contains("Cost:"));
        assert!(events
            .iter()
            .any(|e| e.kind == ResearchEventKind::JobAdmitted));
        assert!(events
            .iter()
            .any(|e| e.kind == ResearchEventKind::DocumentParsed));
        assert!(events.iter().all(|e| e.job_id == job_id));
    }

    #[test]
    fn cancel_does_not_write_a_completed_report() {
        let search = FakeSearch {
            id: "wikipedia",
            url: "https://en.wikipedia.org/wiki/Qwen",
            snippet: "SEARCH SNIPPET ONLY",
        };
        let fetch = FakeFetch { body: PAGE };
        let mut engine = ResearchEngine::new(vec![Box::new(search)], Box::new(fetch));
        let job_id = engine.start(quick("What is Qwen?"));
        engine.cancel(&job_id).unwrap();
        let events = engine
            .run(&job_id, &[])
            .expect("cancelled jobs still run to a terminal event");
        assert!(events
            .iter()
            .any(|e| e.kind == ResearchEventKind::Cancelled));
        assert!(!events
            .iter()
            .any(|e| e.kind == ResearchEventKind::Completed));
        assert!(engine.report(&job_id).is_none());
        assert_eq!(engine.status(&job_id), Some(ResearchJobState::Cancelled));
    }

    #[test]
    fn pause_then_resume_still_produces_a_cited_report() {
        let search = FakeSearch {
            id: "wikipedia",
            url: "https://en.wikipedia.org/wiki/Qwen",
            snippet: "SEARCH SNIPPET ONLY",
        };
        let fetch = FakeFetch { body: PAGE };
        let mut engine = ResearchEngine::new(vec![Box::new(search)], Box::new(fetch));
        let job_id = engine.start(quick("What is Qwen?"));
        engine.pause(&job_id).unwrap();
        let paused = engine.run(&job_id, &[]).unwrap();
        assert!(paused.iter().any(|e| e.kind == ResearchEventKind::Paused));
        assert!(!paused
            .iter()
            .any(|e| e.kind == ResearchEventKind::Completed));
        engine.resume(&job_id).unwrap();
        let events = engine.run(&job_id, &[]).unwrap();
        assert_eq!(
            events.last().map(|e| e.kind),
            Some(ResearchEventKind::Completed)
        );
        assert!(engine.report(&job_id).unwrap().contains("[1]"));
    }

    #[test]
    fn local_only_allows_research_library_memory() {
        assert!(engine_allowed(SearchPolicy::LocalOnly, "local_memory"));
        assert!(!engine_allowed(SearchPolicy::LocalOnly, "wikipedia"));
    }

    #[test]
    fn known_library_urls_skip_re_fetch() {
        let search = FakeSearch {
            id: "wikipedia",
            url: "https://en.wikipedia.org/wiki/Qwen",
            snippet: "SEARCH SNIPPET ONLY",
        };
        let fetch = FakeFetch { body: PAGE };
        let mut engine = ResearchEngine::new(vec![Box::new(search)], Box::new(fetch));
        let job_id = engine.start(quick("What is Qwen?"));
        let events = engine
            .run(&job_id, &["https://en.wikipedia.org/wiki/Qwen".to_string()])
            .expect("run");
        assert!(!events
            .iter()
            .any(|event| event.kind == ResearchEventKind::SourceFetched));
    }

    #[test]
    fn privacy_first_allows_searxng_and_never_google() {
        assert!(engine_allowed(SearchPolicy::PrivacyFirst, "wikipedia"));
        assert!(engine_allowed(SearchPolicy::PrivacyFirst, "searxng"));
        assert!(!engine_allowed(
            SearchPolicy::PrivacyFirst,
            "semantic_scholar"
        ));
        assert!(!engine_allowed(SearchPolicy::MaximumQuality, "google"));
        assert!(!engine_allowed(SearchPolicy::Balanced, "bing"));
    }
}
