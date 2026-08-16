//! Full offline meeting-intelligence pipeline for the CLI.

use std::path::{Path, PathBuf};
use std::time::Instant;

use airo_mind_audio::preprocess_path;
use airo_mind_core::{
    CancelToken, EngineError, GenerationChunk, GenerationEngine, GenerationRequest,
    ResourceRequest, RuntimeError, RuntimeStats, Supervisor, TranscriptSegment,
};
use airo_mind_diarize::diarize_single_speaker;
use airo_mind_llama::{LlamaGenerationEngine, ResourceBudget, Supervisor as LlamaSupervisor};
use airo_mind_meeting::{
    extract, generate_mom, validate, ExtractionConfig, MeetingInput, MeetingIr, MomError,
};
use airo_mind_transcript::{process, Chunk, ChunkConfig, ProcessedTranscript, Segment};
use airo_mind_whisper::{
    AudioInput, CancelToken as WhisperCancelToken, ResourceBudget as WhisperBudget,
    Supervisor as WhisperSupervisor, TranscriptionOptions, WhisperSpeechEngine,
};
use serde::Serialize;

use crate::args::CliArgs;

#[derive(Debug)]
pub struct PipelineOutput {
    pub processed: ProcessedTranscript,
    pub hypothesis_text: String,
    pub ir: MeetingIr,
    pub mom: String,
    pub whisper_model: PathBuf,
    #[allow(dead_code)]
    pub llama_model: PathBuf,
    pub processing_ms: u64,
    pub speaker_labels: std::collections::HashMap<String, String>,
}

#[derive(Serialize)]
struct StoredSegmentArtifact {
    id: String,
    start_ms: u64,
    end_ms: u64,
    raw: String,
    normalized: String,
    speaker_label: Option<String>,
}

#[derive(Serialize)]
struct TranscriptArtifact {
    meeting_id: String,
    audio_path: String,
    model_version: String,
    raw: String,
    normalized: String,
    segments: Vec<StoredSegmentArtifact>,
}

#[derive(Serialize)]
struct ChunkArtifact {
    id: String,
    start_ms: u64,
    end_ms: u64,
    segment_ids: Vec<String>,
    text: String,
}

fn segments_with_ids(raw: &[TranscriptSegment]) -> Vec<Segment> {
    raw.iter()
        .enumerate()
        .map(|(i, s)| Segment {
            id: format!("s{i}"),
            start_ms: s.start_ms,
            end_ms: s.end_ms,
            text: s.text.trim().to_string(),
        })
        .collect()
}

fn hypothesis_text(segments: &[Segment]) -> String {
    segments
        .iter()
        .map(|s| s.text.as_str())
        .collect::<Vec<_>>()
        .join(" ")
}

fn chunk_artifacts(chunks: &[Chunk]) -> Vec<ChunkArtifact> {
    chunks
        .iter()
        .map(|c| ChunkArtifact {
            id: c.id.clone(),
            start_ms: c.start_ms,
            end_ms: c.end_ms,
            segment_ids: c.segment_ids.clone(),
            text: c.text.clone(),
        })
        .collect()
}

struct SupervisorGenerationEngine<'a> {
    supervisor: &'a Supervisor,
}

impl GenerationEngine for SupervisorGenerationEngine<'_> {
    fn resource_request(&self) -> ResourceRequest {
        ResourceRequest::new(0)
    }

    fn stats(&self) -> RuntimeStats {
        self.supervisor.generation_stats().unwrap_or_default()
    }

    fn generate(
        &self,
        request: &GenerationRequest,
        cancel: &CancelToken,
        sink: &mut dyn FnMut(GenerationChunk) -> Result<(), EngineError>,
    ) -> Result<(), EngineError> {
        self.supervisor
            .run_generation(request, cancel, sink)
            .map_err(runtime_to_engine)
    }
}

fn runtime_to_engine(error: RuntimeError) -> EngineError {
    match error {
        RuntimeError::Engine(e) => e,
        other => EngineError::Backend(other.to_string()),
    }
}

fn mom_to_string(error: MomError) -> String {
    match error {
        MomError::Cancelled => "cancelled".into(),
        MomError::Engine(message) => message,
    }
}

pub fn run_poc2(args: &CliArgs, whisper_model: &Path, llama_model: &Path) -> PipelineOutput {
    let start = Instant::now();

    let pcm = preprocess_path(&args.audio).expect("audio preprocess succeeds");

    let speech_engine = WhisperSpeechEngine::load(whisper_model, 512).expect("whisper loads");
    let mut whisper_supervisor = WhisperSupervisor::new(WhisperBudget::new(2048));
    whisper_supervisor.register_speech(Box::new(speech_engine));

    // Multilingual auto-detect — same default as product (`language: None`).
    let asr_options = TranscriptionOptions { language: None };

    let mut raw_segments: Vec<TranscriptSegment> = Vec::new();
    whisper_supervisor
        .run_speech(
            AudioInput {
                samples: &pcm.samples,
                sample_rate_hz: pcm.sample_rate_hz,
                channels: pcm.channels,
            },
            &asr_options,
            &WhisperCancelToken::new(),
            &mut |segment| {
                raw_segments.push(segment);
                Ok(())
            },
        )
        .expect("transcription succeeds");

    let segments = segments_with_ids(&raw_segments);
    let hypothesis = hypothesis_text(&segments);
    if hypothesis.trim().is_empty() {
        panic!("whisper produced no text");
    }

    let diarized = diarize_single_speaker(&segments).expect("diarization succeeds");
    let speaker_by_id: std::collections::HashMap<String, String> = diarized
        .segments
        .iter()
        .map(|s| (s.id.clone(), s.speaker.label()))
        .collect();

    let processed = process(&segments, &ChunkConfig::default());

    let generation_engine =
        LlamaGenerationEngine::load(llama_model, 1024, 2048).expect("llama loads");
    let mut llama_supervisor = LlamaSupervisor::new(ResourceBudget::new(4096));
    llama_supervisor.register_generation(Box::new(generation_engine));

    let cancel = CancelToken::new();
    let model_id = format!(
        "cli@{}",
        llama_model
            .file_stem()
            .and_then(|s| s.to_str())
            .unwrap_or("llama")
    );

    let extraction = {
        let engine = SupervisorGenerationEngine {
            supervisor: &llama_supervisor,
        };
        extract(
            &engine,
            &processed,
            &MeetingInput {
                id: args.meeting_id.clone(),
                title: None,
                model_id: Some(model_id),
            },
            &ExtractionConfig::default(),
            &cancel,
        )
        .expect("extraction succeeds")
    };

    let (validated_ir, _report) = validate(&extraction.ir, &segments);

    let mom = {
        let engine = SupervisorGenerationEngine {
            supervisor: &llama_supervisor,
        };
        generate_mom(&engine, &validated_ir, &cancel)
            .map_err(mom_to_string)
            .expect("mom succeeds")
    };

    PipelineOutput {
        processed,
        hypothesis_text: hypothesis,
        ir: validated_ir,
        mom,
        whisper_model: whisper_model.to_path_buf(),
        llama_model: llama_model.to_path_buf(),
        processing_ms: start.elapsed().as_millis() as u64,
        speaker_labels: speaker_by_id,
    }
}

pub fn write_artifacts(out_dir: &Path, args: &CliArgs, output: &PipelineOutput) {
    std::fs::create_dir_all(out_dir).expect("out dir created");

    let transcript_path = out_dir.join("transcript.json");
    let artifact = TranscriptArtifact {
        meeting_id: args.meeting_id.clone(),
        audio_path: args.audio.display().to_string(),
        model_version: format!(
            "whisper@{}",
            output
                .whisper_model
                .file_stem()
                .and_then(|s| s.to_str())
                .unwrap_or("model")
        ),
        raw: output.processed.raw.clone(),
        normalized: output.processed.normalized.clone(),
        segments: output
            .processed
            .segments
            .iter()
            .map(|s| StoredSegmentArtifact {
                id: s.id.clone(),
                start_ms: s.start_ms,
                end_ms: s.end_ms,
                raw: s.raw.clone(),
                normalized: s.normalized.clone(),
                speaker_label: output.speaker_labels.get(&s.id).cloned(),
            })
            .collect(),
    };
    std::fs::write(
        &transcript_path,
        serde_json::to_string_pretty(&artifact).expect("transcript serializes"),
    )
    .expect("transcript.json written");

    let chunks_path = out_dir.join("chunks.json");
    std::fs::write(
        &chunks_path,
        serde_json::to_string_pretty(&chunk_artifacts(&output.processed.chunks))
            .expect("chunks serializes"),
    )
    .expect("chunks.json written");

    let ir_json = serde_json::to_string_pretty(&output.ir).expect("ir serializes");

    std::fs::write(out_dir.join("meeting_ir.json"), &ir_json).expect("meeting_ir.json written");
    std::fs::write(out_dir.join("predicted_ir.json"), &ir_json).expect("predicted_ir.json written");

    let mom_path = out_dir.join("mom.md");
    std::fs::write(&mom_path, &output.mom).expect("mom.md written");

    let hypothesis_path = out_dir.join("hypothesis_transcript.txt");
    std::fs::write(&hypothesis_path, &output.hypothesis_text)
        .expect("hypothesis_transcript.txt written");
}
