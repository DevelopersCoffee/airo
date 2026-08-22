//! Deep Research FFI. Rust owns orchestration; Dart injects search/fetch I/O.
//!
//! `ResearchEngine` in `airo_mind_core` never opens sockets. This module bridges
//! Dart HTTP adapters through channels so the sync engine can call async Dart.

use std::sync::mpsc::{self, Receiver, Sender};
use std::sync::{Arc, Mutex};
use std::time::Duration;

use airo_mind_core::research::{
    ResearchCheckpoint, ResearchEngine, ResearchEvent as CoreEvent, ResearchEventKind as CoreKind,
    ResearchJobState as CoreJobState, ResearchMode, ResearchRequest as CoreRequest, SearchEngine,
    SearchError, SearchHit, SearchPolicy, SearchRequest, SearchResponse, SourceFetcher,
};
use flutter_rust_bridge::{frb, DartFnFuture};

use crate::frb_generated::StreamSink;

// ---------------------------------------------------------------------------
// Wire types — Dart-facing mirrors of the domain models.
// ---------------------------------------------------------------------------

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum FrbResearchMode {
    Quick,
    Standard,
    Deep,
    Exhaustive,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum FrbSearchPolicy {
    LocalOnly,
    PrivacyFirst,
    Balanced,
    MaximumQuality,
    Academic,
}

pub struct FrbResearchRequest {
    pub question: String,
    pub mode: FrbResearchMode,
    pub policy: FrbSearchPolicy,
    pub output_format: String,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum FrbResearchEventKind {
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

pub struct FrbResearchEvent {
    pub kind: FrbResearchEventKind,
    pub job_id: String,
    pub label: String,
    pub detail: String,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum FrbResearchJobState {
    Created,
    Planning,
    Searching,
    Collecting,
    Analyzing,
    Verifying,
    GapAnalysis,
    Synthesizing,
    Validating,
    Completed,
    Paused,
    Cancelled,
    Failed,
}

pub struct FrbSearchRequest {
    pub query: String,
    pub max_results: u32,
}

pub struct FrbSearchHit {
    pub url: String,
    pub title: String,
    pub snippet: String,
}

pub struct FrbSearchResponse {
    pub engine_id: String,
    pub hits: Vec<FrbSearchHit>,
}

// ---------------------------------------------------------------------------
// Channel-backed I/O adapters.
// ---------------------------------------------------------------------------

enum IoRequest {
    Search {
        engine_id: String,
        request: SearchRequest,
        respond_to: Sender<Result<SearchResponse, SearchError>>,
    },
    Fetch {
        url: String,
        respond_to: Sender<Result<String, String>>,
    },
}

struct ChannelSearchEngine {
    id: &'static str,
    io_tx: Sender<IoRequest>,
}

impl SearchEngine for ChannelSearchEngine {
    fn id(&self) -> &'static str {
        self.id
    }

    fn search(&self, request: &SearchRequest) -> Result<SearchResponse, SearchError> {
        let (tx, rx) = mpsc::channel();
        self.io_tx
            .send(IoRequest::Search {
                engine_id: self.id.to_string(),
                request: request.clone(),
                respond_to: tx,
            })
            .map_err(|_| SearchError::Unavailable(self.id))?;
        rx.recv().map_err(|_| SearchError::Unavailable(self.id))?
    }
}

struct ChannelFetcher {
    io_tx: Sender<IoRequest>,
}

impl SourceFetcher for ChannelFetcher {
    fn fetch(&self, url: &str) -> Result<String, String> {
        let (tx, rx) = mpsc::channel();
        self.io_tx
            .send(IoRequest::Fetch {
                url: url.to_string(),
                respond_to: tx,
            })
            .map_err(|_| "fetch bridge closed".to_string())?;
        rx.recv().map_err(|_| "fetch bridge closed".to_string())?
    }
}

fn leak_engine_id(id: String) -> &'static str {
    Box::leak(id.into_boxed_str())
}

// ---------------------------------------------------------------------------
// Handle
// ---------------------------------------------------------------------------

type SearchCallback =
    Arc<dyn Fn(String, FrbSearchRequest) -> DartFnFuture<FrbSearchResponse> + Send + Sync>;
type FetchCallback = Arc<dyn Fn(String) -> DartFnFuture<String> + Send + Sync>;

#[frb(opaque)]
pub struct ResearchServiceHandle {
    engine: Arc<Mutex<ResearchEngine>>,
    io_rx: Mutex<Receiver<IoRequest>>,
    search: SearchCallback,
    fetch: FetchCallback,
}

/// Create a research service with Dart-injected search/fetch adapters.
pub fn create_research_service(
    engine_ids: Vec<String>,
    search: impl Fn(String, FrbSearchRequest) -> DartFnFuture<FrbSearchResponse> + Send + Sync + 'static,
    fetch: impl Fn(String) -> DartFnFuture<String> + Send + Sync + 'static,
) -> ResearchServiceHandle {
    let (io_tx, io_rx) = mpsc::channel();
    let engines: Vec<Box<dyn SearchEngine>> = engine_ids
        .into_iter()
        .map(|id| {
            let leaked = leak_engine_id(id);
            Box::new(ChannelSearchEngine {
                id: leaked,
                io_tx: io_tx.clone(),
            }) as Box<dyn SearchEngine>
        })
        .collect();
    let engine = ResearchEngine::new(engines, Box::new(ChannelFetcher { io_tx }));
    ResearchServiceHandle {
        engine: Arc::new(Mutex::new(engine)),
        io_rx: Mutex::new(io_rx),
        search: Arc::new(search),
        fetch: Arc::new(fetch),
    }
}

#[frb(sync)]
pub fn research_start(handle: &ResearchServiceHandle, request: FrbResearchRequest) -> String {
    let mut engine = handle.engine.lock().expect("research engine lock");
    engine.start(request.into())
}

#[frb(sync)]
pub fn research_status(
    handle: &ResearchServiceHandle,
    job_id: String,
) -> Option<FrbResearchJobState> {
    let engine = handle.engine.lock().expect("research engine lock");
    engine.status(&job_id).map(Into::into)
}

#[frb(sync)]
pub fn research_pause(handle: &ResearchServiceHandle, job_id: String) -> Result<(), String> {
    handle
        .engine
        .lock()
        .expect("research engine lock")
        .pause(&job_id)
        .map_err(|error| error.to_string())
}

#[frb(sync)]
pub fn research_resume(handle: &ResearchServiceHandle, job_id: String) -> Result<(), String> {
    handle
        .engine
        .lock()
        .expect("research engine lock")
        .resume(&job_id)
        .map_err(|error| error.to_string())
}

#[frb(sync)]
pub fn research_cancel(handle: &ResearchServiceHandle, job_id: String) -> Result<(), String> {
    handle
        .engine
        .lock()
        .expect("research engine lock")
        .cancel(&job_id)
        .map_err(|error| error.to_string())
}

pub struct FrbResearchCheckpoint {
    pub record: String,
}

#[frb(sync)]
pub fn research_checkpoint(
    handle: &ResearchServiceHandle,
    job_id: String,
) -> Option<FrbResearchCheckpoint> {
    let engine = handle.engine.lock().expect("research engine lock");
    engine
        .checkpoint(&job_id)
        .map(|checkpoint| FrbResearchCheckpoint {
            record: checkpoint.to_record(),
        })
}

#[frb(sync)]
pub fn research_restore(
    handle: &ResearchServiceHandle,
    checkpoint: FrbResearchCheckpoint,
) -> Result<(), String> {
    let checkpoint =
        ResearchCheckpoint::from_record(&checkpoint.record).map_err(|error| error.to_string())?;
    handle
        .engine
        .lock()
        .expect("research engine lock")
        .restore(checkpoint)
        .map_err(|error| error.to_string())
}

#[frb(sync)]
pub fn research_report(handle: &ResearchServiceHandle, job_id: String) -> Option<String> {
    let engine = handle.engine.lock().expect("research engine lock");
    engine.report(&job_id).map(str::to_owned)
}

/// Run a admitted job to completion, streaming structured events.
pub async fn research_run(
    handle: &ResearchServiceHandle,
    job_id: String,
    known_source_urls: Vec<String>,
    sink: StreamSink<FrbResearchEvent>,
) -> Result<(), String> {
    let engine = Arc::clone(&handle.engine);
    let job_id_for_thread = job_id.clone();
    let (done_tx, done_rx) = mpsc::channel();

    std::thread::spawn(move || {
        let result = {
            let mut engine = engine.lock().expect("research engine lock");
            engine.run(&job_id_for_thread, &known_source_urls)
        };
        let _ = done_tx.send(result);
    });

    loop {
        let pending: Vec<IoRequest> = {
            let rx = handle.io_rx.lock().expect("io_rx lock");
            let mut batch = Vec::new();
            while let Ok(request) = rx.try_recv() {
                batch.push(request);
            }
            batch
        };

        for request in pending {
            match request {
                IoRequest::Search {
                    engine_id,
                    request,
                    respond_to,
                } => {
                    let frb_request = FrbSearchRequest {
                        query: request.query,
                        max_results: request.max_results,
                    };
                    let response = (handle.search)(engine_id, frb_request).await;
                    let mapped = Ok(response.into());
                    let _ = respond_to.send(mapped);
                }
                IoRequest::Fetch { url, respond_to } => {
                    let body = (handle.fetch)(url).await;
                    let _ = respond_to.send(Ok(body));
                }
            }
        }

        if let Ok(result) = done_rx.try_recv() {
            let events = result.map_err(|error| error.to_string())?;
            for event in events {
                sink.add(event.into()).map_err(|error| error.to_string())?;
            }
            return Ok(());
        }

        std::thread::sleep(Duration::from_millis(1));
    }
}

// ---------------------------------------------------------------------------
// Mapping
// ---------------------------------------------------------------------------

impl From<FrbResearchMode> for ResearchMode {
    fn from(value: FrbResearchMode) -> Self {
        match value {
            FrbResearchMode::Quick => Self::Quick,
            FrbResearchMode::Standard => Self::Standard,
            FrbResearchMode::Deep => Self::Deep,
            FrbResearchMode::Exhaustive => Self::Exhaustive,
        }
    }
}

impl From<FrbSearchPolicy> for SearchPolicy {
    fn from(value: FrbSearchPolicy) -> Self {
        match value {
            FrbSearchPolicy::LocalOnly => Self::LocalOnly,
            FrbSearchPolicy::PrivacyFirst => Self::PrivacyFirst,
            FrbSearchPolicy::Balanced => Self::Balanced,
            FrbSearchPolicy::MaximumQuality => Self::MaximumQuality,
            FrbSearchPolicy::Academic => Self::Academic,
        }
    }
}

impl From<FrbResearchRequest> for CoreRequest {
    fn from(value: FrbResearchRequest) -> Self {
        let mut request = CoreRequest::new(value.question);
        request.mode = value.mode.into();
        request.policy = value.policy.into();
        request.output_format = value.output_format;
        request
    }
}

impl From<CoreKind> for FrbResearchEventKind {
    fn from(value: CoreKind) -> Self {
        match value {
            CoreKind::JobAdmitted => Self::JobAdmitted,
            CoreKind::PlanningStarted => Self::PlanningStarted,
            CoreKind::IntentClassified => Self::IntentClassified,
            CoreKind::PlanCreated => Self::PlanCreated,
            CoreKind::SearchStarted => Self::SearchStarted,
            CoreKind::SearchCompleted => Self::SearchCompleted,
            CoreKind::SourceDiscovered => Self::SourceDiscovered,
            CoreKind::SourceFetched => Self::SourceFetched,
            CoreKind::SourceRejected => Self::SourceRejected,
            CoreKind::DocumentParsed => Self::DocumentParsed,
            CoreKind::AnalyzingStarted => Self::AnalyzingStarted,
            CoreKind::ClaimCreated => Self::ClaimCreated,
            CoreKind::GapDetected => Self::GapDetected,
            CoreKind::CounterResearchStarted => Self::CounterResearchStarted,
            CoreKind::ConflictDetected => Self::ConflictDetected,
            CoreKind::SynthesisStarted => Self::SynthesisStarted,
            CoreKind::Completed => Self::Completed,
            CoreKind::Failed => Self::Failed,
            CoreKind::Paused => Self::Paused,
            CoreKind::Cancelled => Self::Cancelled,
        }
    }
}

impl From<CoreEvent> for FrbResearchEvent {
    fn from(value: CoreEvent) -> Self {
        Self {
            kind: value.kind.into(),
            job_id: value.job_id,
            label: value.label,
            detail: value.detail,
        }
    }
}

impl From<CoreJobState> for FrbResearchJobState {
    fn from(value: CoreJobState) -> Self {
        match value {
            CoreJobState::Created => Self::Created,
            CoreJobState::Planning => Self::Planning,
            CoreJobState::Searching => Self::Searching,
            CoreJobState::Collecting => Self::Collecting,
            CoreJobState::Analyzing => Self::Analyzing,
            CoreJobState::Verifying => Self::Verifying,
            CoreJobState::GapAnalysis => Self::GapAnalysis,
            CoreJobState::Synthesizing => Self::Synthesizing,
            CoreJobState::Validating => Self::Validating,
            CoreJobState::Completed => Self::Completed,
            CoreJobState::Paused => Self::Paused,
            CoreJobState::Cancelled => Self::Cancelled,
            CoreJobState::Failed => Self::Failed,
        }
    }
}

impl From<FrbSearchResponse> for SearchResponse {
    fn from(value: FrbSearchResponse) -> Self {
        Self {
            engine_id: value.engine_id,
            hits: value.hits.into_iter().map(Into::into).collect(),
        }
    }
}

impl From<FrbSearchHit> for SearchHit {
    fn from(value: FrbSearchHit) -> Self {
        Self {
            url: value.url,
            title: value.title,
            snippet: value.snippet,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn request_mapping_preserves_mode_and_policy() {
        let request = FrbResearchRequest {
            question: "What is Qwen?".into(),
            mode: FrbResearchMode::Quick,
            policy: FrbSearchPolicy::PrivacyFirst,
            output_format: "technical_report".into(),
        };
        let core: CoreRequest = request.into();
        assert_eq!(core.mode, ResearchMode::Quick);
        assert_eq!(core.policy, SearchPolicy::PrivacyFirst);
    }

    #[test]
    fn event_kind_mapping_covers_terminal_states() {
        assert_eq!(
            FrbResearchEventKind::from(CoreKind::Completed),
            FrbResearchEventKind::Completed
        );
        assert_eq!(
            FrbResearchEventKind::from(CoreKind::Cancelled),
            FrbResearchEventKind::Cancelled
        );
        assert_eq!(
            FrbResearchEventKind::from(CoreKind::Failed),
            FrbResearchEventKind::Failed
        );
    }
}
