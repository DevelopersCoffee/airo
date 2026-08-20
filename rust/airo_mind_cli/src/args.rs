//! Plain flag parsing for the dev CLI — no `clap` dependency (Constitution §6).

use std::env;
use std::path::PathBuf;

#[derive(Clone, Debug)]
pub struct CliArgs {
    pub audio: PathBuf,
    pub models_dir: Option<PathBuf>,
    pub out: Option<PathBuf>,
    pub skip_eval: bool,
    pub asr_only: bool,
    pub language: Option<String>,
    pub meeting_id: String,
    pub golden_transcript: Option<PathBuf>,
    pub golden_ir: Option<PathBuf>,
    pub golden_mom: Option<PathBuf>,
    pub help: bool,
}

fn manifest_dir() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
}

fn flag(args: &[String], name: &str) -> Option<PathBuf> {
    args.iter()
        .position(|a| a == name)
        .and_then(|i| args.get(i + 1))
        .map(PathBuf::from)
}

fn has_flag(args: &[String], name: &str) -> bool {
    args.iter().any(|a| a == name)
}

fn flag_string(args: &[String], name: &str) -> Option<String> {
    args.iter()
        .position(|a| a == name)
        .and_then(|i| args.get(i + 1))
        .cloned()
}

/// First positional argument that is not a flag or a flag's value.
fn positional_audio(args: &[String]) -> Option<PathBuf> {
    let mut skip_next = false;
    for arg in args.iter().skip(1) {
        if skip_next {
            skip_next = false;
            continue;
        }
        if arg.starts_with('-') {
            if arg == "--models-dir"
                || arg == "--out"
                || arg == "--meeting-id"
                || arg == "--language"
                || arg == "--golden-meeting"
                || arg == "--golden-transcript"
                || arg == "--golden-ir"
                || arg == "--golden-mom"
            {
                skip_next = true;
            }
            continue;
        }
        return Some(PathBuf::from(arg));
    }
    None
}

fn default_audio_for_golden_meeting(meeting_id: &str) -> Option<PathBuf> {
    if meeting_id == "meeting_001" {
        let path = manifest_dir().join("../fixtures/meeting_001.m4a");
        if path.exists() {
            return Some(path);
        }
    }
    None
}

pub fn parse() -> CliArgs {
    let args: Vec<String> = env::args().collect();
    let golden_meeting = flag_string(&args, "--golden-meeting");

    let audio = env::var("AIRO_MIND_CLI_AUDIO")
        .map(PathBuf::from)
        .ok()
        .or_else(|| positional_audio(&args))
        .or_else(|| {
            golden_meeting
                .as_deref()
                .and_then(default_audio_for_golden_meeting)
        })
        .unwrap_or_else(|| manifest_dir().join("../fixtures/speech.m4a"));

    let meeting_fixtures = manifest_dir().join("../airo_mind_meeting/tests/fixtures");
    let eval_manifest = manifest_dir().join("../airo_mind_eval");
    let own_golden_dir = eval_manifest.join("golden/reference_meeting");

    let golden_from_meeting = golden_meeting
        .as_deref()
        .map(|id| airo_mind_eval::golden::paths_for_meeting(&eval_manifest, id));

    CliArgs {
        audio,
        models_dir: flag(&args, "--models-dir"),
        out: flag(&args, "--out"),
        skip_eval: has_flag(&args, "--skip-eval"),
        asr_only: has_flag(&args, "--asr-only"),
        language: flag_string(&args, "--language"),
        meeting_id: flag(&args, "--meeting-id")
            .and_then(|p| p.into_os_string().into_string().ok())
            .or(golden_meeting)
            .unwrap_or_else(|| "cli-run".to_string()),
        golden_transcript: flag(&args, "--golden-transcript").or_else(|| {
            golden_from_meeting
                .as_ref()
                .map(|p| p.transcript.clone())
                .or_else(|| Some(own_golden_dir.join("transcript.json")))
        }),
        golden_ir: flag(&args, "--golden-ir").or_else(|| {
            golden_from_meeting
                .as_ref()
                .map(|p| p.golden_ir.clone())
                .or_else(|| Some(meeting_fixtures.join("golden_ir.json")))
        }),
        golden_mom: flag(&args, "--golden-mom").or_else(|| {
            golden_from_meeting
                .as_ref()
                .map(|p| p.golden_mom.clone())
                .or_else(|| Some(meeting_fixtures.join("golden_mom.md")))
        }),
        help: has_flag(&args, "--help") || has_flag(&args, "-h"),
    }
}

pub fn print_help() {
    println!(
        "\
airo_mind_cli — local dev loop for Airo Mind speech + generation

USAGE:
    cargo run -p airo_mind_cli -- [OPTIONS] [AUDIO]

ARGS:
    AUDIO    Input .m4a or .wav (default: rust/fixtures/speech.m4a)

OPTIONS:
    -h, --help                 Print this help
    --models-dir DIR           Directory with whisper .bin and llama .gguf models
    --out DIR                  Run full POC-2 pipeline and write artifacts here
    --skip-eval                With --out, skip eval gates (artifacts only)
    --asr-only                 Transcribe only; skip LLM summary (legacy mode)
    --language CODE            Pin whisper language (e.g. en, hi); default auto
    --meeting-id ID            Meeting id for transcript/IR (default: cli-run)
    --golden-meeting ID        Load eval goldens from airo_mind_eval/golden/ID/
    --golden-transcript PATH   Golden transcript.json for eval
    --golden-ir PATH           Golden IR JSON for eval
    --golden-mom PATH          Golden MoM markdown for eval

ENV (used when --models-dir is absent):
    AIRO_MIND_CLI_AUDIO        Default audio path
    AIRO_MIND_WHISPER_MODEL    Whisper ggml model path
    AIRO_MIND_LLAMA_MODEL      Llama gguf model path

MODES:
    Without --out: legacy summarize smoke test (ASR → one-line LLM summary).
    With --out:    preprocess → whisper → transcript::process → extract →
                   validate → generate_mom → eval gates (unless --skip-eval).

EXAMPLE (POC-2):
    cargo run -p airo_mind_cli -- rust/fixtures/speech.m4a \\
      --models-dir rust/airo_mind_whisper/models \\
      --out ./out/

EXAMPLE (user recording, meeting_001 goldens):
    ln -sf /path/to/your/recording.m4a rust/fixtures/meeting_001.m4a
    cargo run -p airo_mind_cli -- \\
      --models-dir models --out ./out/meeting_001/ \\
      --golden-meeting meeting_001
"
    );
}

pub fn resolve_whisper_model(models_dir: Option<&PathBuf>) -> PathBuf {
    if let Some(dir) = models_dir {
        for name in [
            "ggml-small.bin",
            "ggml-small.en.bin",
            "ggml-tiny.bin",
            "ggml-tiny.en.bin",
        ] {
            let path = dir.join(name);
            if path.exists() {
                return path;
            }
        }
        if let Ok(entries) = std::fs::read_dir(dir) {
            for entry in entries.flatten() {
                let path = entry.path();
                if path.extension().is_some_and(|e| e == "bin") {
                    return path;
                }
            }
        }
        return dir.join("ggml-tiny.bin");
    }
    env::var("AIRO_MIND_WHISPER_MODEL")
        .map(PathBuf::from)
        .unwrap_or_else(|_| manifest_dir().join("../airo_mind_whisper/models/ggml-tiny.bin"))
}

pub fn resolve_llama_model(models_dir: Option<&PathBuf>) -> PathBuf {
    if let Some(dir) = models_dir {
        let qwen = dir.join("qwen2.5-0.5b-instruct-q4_k_m.gguf");
        if qwen.exists() {
            return qwen;
        }
        if let Ok(entries) = std::fs::read_dir(dir) {
            for entry in entries.flatten() {
                let path = entry.path();
                if path.extension().is_some_and(|e| e == "gguf") {
                    return path;
                }
            }
        }
        return qwen;
    }
    env::var("AIRO_MIND_LLAMA_MODEL")
        .map(PathBuf::from)
        .unwrap_or_else(|_| {
            manifest_dir().join("../airo_mind_llama/models/qwen2.5-0.5b-instruct-q4_k_m.gguf")
        })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn positional_audio_skips_flags_and_values() {
        let args = vec![
            "airo_mind_cli".into(),
            "--out".into(),
            "./out".into(),
            "speech.m4a".into(),
        ];
        assert_eq!(
            positional_audio(&args).map(|p| p.to_string_lossy().into_owned()),
            Some("speech.m4a".into())
        );
    }

    #[test]
    fn default_audio_for_meeting_001_when_fixture_present() {
        let path = default_audio_for_golden_meeting("meeting_001");
        if manifest_dir().join("../fixtures/meeting_001.m4a").exists() {
            assert!(path.is_some());
            assert!(path.unwrap().ends_with("meeting_001.m4a"));
        }
    }
}
