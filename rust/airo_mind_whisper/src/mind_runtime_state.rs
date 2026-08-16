//! Rust-backed Mind operation log + vault-encrypted speaker enrollment (#1213, #504).

use std::fs::File;
use std::io::{BufRead, BufReader};
use std::path::{Path, PathBuf};
use std::sync::{Arc, LazyLock, Mutex};

use airo_mind::{
    generate_mnemonic, seed_from_mnemonic, ContextId, ContentId as VaultContentId,
    RootIdentity, SealedEnvelope, Vault,
};
use airo_mind_core::runtime::{Operation, OperationRequest, Runtime};
use airo_mind_core::ResourceBudget;
use airo_mind_diarize::SpeakerEnrollmentStore;
use serde::Deserialize;
use serde_json::json;

const SPEAKER_CAPABILITY: &str = "speaker";
const SCRIBE_CAPABILITY: &str = "scribe";
const SPEAKER_CONTEXT: &str = "speaker-enrollment";
const SPEAKER_ENROLL_KIND: &str = "speaker.enroll";
const SPEAKER_REMOVE_KIND: &str = "speaker.remove";

static MIND_RUNTIME: LazyLock<Mutex<Option<Arc<MindRuntimeState>>>> =
    LazyLock::new(|| Mutex::new(None));

pub struct ScribeOpWire {
    pub sequence: u64,
    pub kind: String,
    pub title: String,
    pub context_id: String,
    pub device_name: String,
    pub recorded_at_ms: u64,
    pub detail: String,
}

struct MindRuntimeState {
    runtime: Runtime,
    vault: Mutex<Vault>,
    envelope_dir: PathBuf,
    speaker_context: ContextId,
}

impl MindRuntimeState {
    fn open(base_dir: &Path) -> Result<Self, String> {
        let base_dir = base_dir.to_path_buf();
        std::fs::create_dir_all(&base_dir).map_err(|e| e.to_string())?;

        let log_path = base_dir.join("operations.log");
        let runtime = Runtime::boot(ResourceBudget::new(4096), &log_path)
            .map_err(|e| e.to_string())?;

        let vault_dir = base_dir.join("vault");
        std::fs::create_dir_all(&vault_dir).map_err(|e| e.to_string())?;
        let mnemonic_path = vault_dir.join("recovery.mnemonic");
        let mnemonic = if mnemonic_path.exists() {
            std::fs::read_to_string(&mnemonic_path).map_err(|e| e.to_string())?
        } else {
            let generated = generate_mnemonic().map_err(|e| e.to_string())?;
            std::fs::write(&mnemonic_path, generated.as_str()).map_err(|e| e.to_string())?;
            generated.to_string()
        };
        let seed = seed_from_mnemonic(mnemonic.trim()).map_err(|e| e.to_string())?;
        let identity = RootIdentity::from_seed(&seed).map_err(|e| e.to_string())?;
        let mut vault = Vault::new(identity.public_key());

        let speaker_context = ContextId::new(SPEAKER_CONTEXT).map_err(|e| e.to_string())?;
        vault
            .add_context(&speaker_context)
            .map_err(|e| e.to_string())?;

        let envelope_dir = base_dir.join("speaker_enrollment").join("envelopes");
        std::fs::create_dir_all(&envelope_dir).map_err(|e| e.to_string())?;

        let state = Self {
            runtime,
            vault: Mutex::new(vault),
            envelope_dir,
            speaker_context,
        };

        state.migrate_legacy_mind_ops_jsonl(&base_dir.join("mind_ops.jsonl"))?;
        state.migrate_legacy_speaker_enrollment(&base_dir.join("speaker_enrollment"))?;
        state.sync_speaker_enrollment_runtime()?;

        Ok(state)
    }

    fn migrate_legacy_mind_ops_jsonl(&self, path: &Path) -> Result<(), String> {
        if !path.exists() {
            return Ok(());
        }
        if self.runtime.replay().map_err(|e| e.to_string())?
            .iter()
            .any(|op| op.capability == SCRIBE_CAPABILITY)
        {
            return Ok(());
        }
        let file = File::open(path).map_err(|e| e.to_string())?;
        let reader = BufReader::new(file);
        for line in reader.lines() {
            let line = line.map_err(|e| e.to_string())?;
            if line.trim().is_empty() {
                continue;
            }
            let record: LegacyMindOpRecord =
                serde_json::from_str(&line).map_err(|e| e.to_string())?;
            let payload = json!({
                "title": record.title,
                "detail": record.detail,
            });
            self.runtime
                .emit_operation_ex(OperationRequest {
                    capability: SCRIBE_CAPABILITY,
                    kind: &record.kind,
                    payload: payload.to_string().as_bytes(),
                    recorded_at_ms: record.recorded_at_ms,
                    entity_id: &record.context_id,
                    parent_operation_id: None,
                    context_ids: &[],
                    schema_id: "",
                    content: None,
                })
                .map_err(|e| e.to_string())?;
        }
        Ok(())
    }

    fn migrate_legacy_speaker_enrollment(&self, root: &Path) -> Result<(), String> {
        let ops_path = root.join("ops.jsonl");
        if !ops_path.exists() {
            return Ok(());
        }
        if self
            .runtime
            .replay()
            .map_err(|e| e.to_string())?
            .iter()
            .any(|op| op.capability == SPEAKER_CAPABILITY)
        {
            return Ok(());
        }
        let content_dir = root.join("content");
        let file = File::open(&ops_path).map_err(|e| e.to_string())?;
        let reader = BufReader::new(file);
        for line in reader.lines() {
            let line = line.map_err(|e| e.to_string())?;
            if line.trim().is_empty() {
                continue;
            }
            let record: LegacySpeakerOpRecord =
                serde_json::from_str(&line).map_err(|e| e.to_string())?;
            match record.kind.as_str() {
                "enroll" => {
                    let bin_path = content_dir.join(format!("{}.bin", record.id));
                    if !bin_path.exists() {
                        continue;
                    }
                    let raw = std::fs::read(&bin_path).map_err(|e| e.to_string())?;
                    let embedding = bytes_to_f32_vec(&raw)?;
                    self.enroll_speaker(&record.id, &record.display_name, &embedding)?;
                }
                "remove" => self.remove_speaker(&record.id)?,
                _ => {}
            }
        }
        Ok(())
    }

    fn enroll_speaker(
        &self,
        id: &str,
        display_name: &str,
        embedding: &[f32],
    ) -> Result<(), String> {
        if id.is_empty() || display_name.trim().is_empty() || embedding.is_empty() {
            return Ok(());
        }
        let vault_content_id = VaultContentId::new(id).map_err(|e| e.to_string())?;
        let mut vault = self.vault.lock().map_err(|e| e.to_string())?;
        let (content_key, envelope) = vault
            .add_content(&vault_content_id, &[&self.speaker_context])
            .map_err(|e| e.to_string())?;
        let plaintext = f32_vec_to_bytes(embedding);
        let sealed = content_key.seal(&plaintext).map_err(|e| e.to_string())?;
        let sealed_envelope = vault.seal_envelope(&envelope).map_err(|e| e.to_string())?;
        self.write_envelope(id, &sealed_envelope)?;

        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_millis() as u64)
            .unwrap_or(0);
        self.runtime
            .emit_operation_ex(OperationRequest {
                capability: SPEAKER_CAPABILITY,
                kind: SPEAKER_ENROLL_KIND,
                payload: display_name.trim().as_bytes(),
                recorded_at_ms: now,
                entity_id: id,
                parent_operation_id: None,
                context_ids: &[SPEAKER_CONTEXT],
                schema_id: "",
                content: Some(&sealed),
            })
            .map_err(|e| e.to_string())?;
        Ok(())
    }

    fn remove_speaker(&self, id: &str) -> Result<(), String> {
        if id.is_empty() {
            return Ok(());
        }
        let envelope_path = self.envelope_path(id);
        if envelope_path.exists() {
            let _ = std::fs::remove_file(envelope_path);
        }
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_millis() as u64)
            .unwrap_or(0);
        self.runtime
            .emit_operation_ex(OperationRequest {
                capability: SPEAKER_CAPABILITY,
                kind: SPEAKER_REMOVE_KIND,
                payload: &[],
                recorded_at_ms: now,
                entity_id: id,
                parent_operation_id: None,
                context_ids: &[],
                schema_id: "",
                content: None,
            })
            .map_err(|e| e.to_string())?;
        Ok(())
    }

    fn write_envelope(&self, entity_id: &str, sealed: &SealedEnvelope) -> Result<(), String> {
        let path = self.envelope_path(entity_id);
        let json = serde_json::to_vec(sealed).map_err(|e| e.to_string())?;
        std::fs::write(path, json).map_err(|e| e.to_string())?;
        Ok(())
    }

    fn read_envelope(&self, entity_id: &str) -> Result<Option<SealedEnvelope>, String> {
        let path = self.envelope_path(entity_id);
        if !path.exists() {
            return Ok(None);
        }
        let bytes = std::fs::read(path).map_err(|e| e.to_string())?;
        Ok(Some(SealedEnvelope::from_bytes(bytes)))
    }

    fn envelope_path(&self, entity_id: &str) -> PathBuf {
        self.envelope_dir.join(format!("{}.envelope.json", entity_id))
    }

    fn sync_speaker_enrollment_runtime(&self) -> Result<(), String> {
        let profiles = self.build_speaker_profiles()?;
        let mut store = SpeakerEnrollmentStore::new();
        for profile in profiles {
            store.replace_or_insert(
                profile.id,
                profile.display_name,
                profile.embedding,
            );
        }
        crate::api::meetings::replace_speaker_enrollment_store(store);
        Ok(())
    }

    fn build_speaker_profiles(&self) -> Result<Vec<SpeakerProfileWire>, String> {
        let ops = self.runtime.replay().map_err(|e| e.to_string())?;
        let mut by_id: std::collections::BTreeMap<String, SpeakerProfileWire> =
            std::collections::BTreeMap::new();
        for op in ops {
            if op.capability != SPEAKER_CAPABILITY {
                continue;
            }
            match op.kind.as_str() {
                SPEAKER_ENROLL_KIND => {
                    let embedding = self.decrypt_enrollment_op(&op)?;
                    if embedding.is_empty() {
                        continue;
                    }
                    by_id.insert(
                        op.entity_id.clone(),
                        SpeakerProfileWire {
                            id: op.entity_id.clone(),
                            display_name: String::from_utf8_lossy(&op.payload).trim().to_string(),
                            embedding,
                        },
                    );
                }
                SPEAKER_REMOVE_KIND => {
                    by_id.remove(&op.entity_id);
                }
                _ => {}
            }
        }
        Ok(by_id.values().cloned().collect())
    }

    fn decrypt_enrollment_op(&self, op: &Operation) -> Result<Vec<f32>, String> {
        let stored_id = op
            .content_id
            .as_ref()
            .ok_or_else(|| "missing content id".to_string())?;
        let sealed_blob = self
            .runtime
            .read_content(stored_id)
            .map_err(|e| e.to_string())?
            .ok_or_else(|| "missing enrollment blob".to_string())?;
        let sealed_envelope = self
            .read_envelope(&op.entity_id)?
            .ok_or_else(|| "missing enrollment envelope".to_string())?;
        let envelope = self
            .vault
            .lock()
            .map_err(|e| e.to_string())?
            .open_envelope(&sealed_envelope)
            .map_err(|e| e.to_string())?;
        let plaintext = self
            .vault
            .lock()
            .map_err(|e| e.to_string())?
            .open_enveloped_content(&envelope, &self.speaker_context, &sealed_blob)
            .map_err(|e| e.to_string())?;
        bytes_to_f32_vec(plaintext.as_slice())
    }

    fn append_scribe_op(
        &self,
        kind: &str,
        title: &str,
        context_id: &str,
        detail: &str,
    ) -> Result<u64, String> {
        let payload = json!({ "title": title, "detail": detail });
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_millis() as u64)
            .unwrap_or(0);
        let op = self
            .runtime
            .emit_operation_ex(OperationRequest {
                capability: SCRIBE_CAPABILITY,
                kind,
                payload: payload.to_string().as_bytes(),
                recorded_at_ms: now,
                entity_id: context_id,
                parent_operation_id: None,
                context_ids: &[],
                schema_id: "",
                content: None,
            })
            .map_err(|e| e.to_string())?;
        Ok(op.seq)
    }

    fn scribe_op_count(&self) -> Result<u64, String> {
        Ok(self
            .runtime
            .replay()
            .map_err(|e| e.to_string())?
            .iter()
            .filter(|op| op.capability == SCRIBE_CAPABILITY)
            .count() as u64)
    }

    fn scribe_ops_recent(&self, offset: u64, limit: u64) -> Result<Vec<ScribeOpWire>, String> {
        let replayed = self.runtime.replay().map_err(|e| e.to_string())?;
        let mut ops: Vec<&Operation> = replayed
            .iter()
            .filter(|op| op.capability == SCRIBE_CAPABILITY)
            .collect();
        ops.sort_by(|a, b| b.seq.cmp(&a.seq));
        let slice = ops
            .into_iter()
            .skip(offset as usize)
            .take(limit as usize)
            .collect::<Vec<_>>();
        Ok(slice
            .into_iter()
            .map(|op| decode_scribe_op(op))
            .collect())
    }

    pub fn speaker_profiles_json(&self) -> Result<String, String> {
        let profiles = self.build_speaker_profiles()?;
        serde_json::to_string(&profiles).map_err(|e| e.to_string())
    }
}

#[derive(Clone, serde::Serialize)]
#[serde(rename_all = "camelCase")]
struct SpeakerProfileWire {
    id: String,
    display_name: String,
    embedding: Vec<f32>,
}

#[derive(Deserialize)]
struct LegacyMindOpRecord {
    kind: String,
    title: String,
    context_id: String,
    recorded_at_ms: u64,
    detail: String,
}

#[derive(Deserialize)]
struct LegacySpeakerOpRecord {
    kind: String,
    id: String,
    display_name: String,
}

fn decode_scribe_op(op: &Operation) -> ScribeOpWire {
    let mut title = String::new();
    let mut detail = String::new();
    if let Ok(value) = serde_json::from_slice::<serde_json::Value>(&op.payload) {
        title = value
            .get("title")
            .and_then(|v| v.as_str())
            .unwrap_or("")
            .to_string();
        detail = value
            .get("detail")
            .and_then(|v| v.as_str())
            .unwrap_or("")
            .to_string();
    }
    ScribeOpWire {
        sequence: op.seq,
        kind: op.kind.clone(),
        title,
        context_id: op.entity_id.clone(),
        device_name: op.device_id.clone(),
        recorded_at_ms: op.recorded_at_ms,
        detail,
    }
}

fn f32_vec_to_bytes(values: &[f32]) -> Vec<u8> {
    let mut out = Vec::with_capacity(values.len() * 4);
    for value in values {
        out.extend_from_slice(&value.to_le_bytes());
    }
    out
}

fn bytes_to_f32_vec(bytes: &[u8]) -> Result<Vec<f32>, String> {
    if bytes.len() % 4 != 0 {
        return Err("invalid float32 payload length".into());
    }
    Ok(bytes
        .chunks_exact(4)
        .map(|chunk| f32::from_le_bytes(chunk.try_into().unwrap()))
        .collect())
}

pub fn open_mind_runtime(base_dir: &str) -> Result<(), String> {
    let state = MindRuntimeState::open(Path::new(base_dir))?;
    *lock_runtime() = Some(Arc::new(state));
    Ok(())
}

pub fn append_scribe_op(
    kind: String,
    title: String,
    context_id: String,
    detail: String,
) -> Result<u64, String> {
    let state = runtime_state()?;
    state.append_scribe_op(&kind, &title, &context_id, &detail)
}

pub fn scribe_op_count() -> Result<u64, String> {
    let state = runtime_state()?;
    state.scribe_op_count()
}

pub fn scribe_ops_recent(offset: u64, limit: u64) -> Result<Vec<ScribeOpWire>, String> {
    let state = runtime_state()?;
    state.scribe_ops_recent(offset, limit)
}

pub fn enroll_speaker(
    id: String,
    display_name: String,
    embedding: Vec<f32>,
) -> Result<(), String> {
    let state = runtime_state()?;
    state.enroll_speaker(&id, &display_name, &embedding)?;
    state.sync_speaker_enrollment_runtime()?;
    Ok(())
}

pub fn speaker_profiles_json() -> Result<String, String> {
    let state = runtime_state()?;
    state.speaker_profiles_json()
}

fn runtime_state() -> Result<Arc<MindRuntimeState>, String> {
    let guard = lock_runtime();
    guard
        .as_ref()
        .cloned()
        .ok_or_else(|| "Mind runtime is not initialised".to_string())
}

fn lock_runtime() -> std::sync::MutexGuard<'static, Option<Arc<MindRuntimeState>>> {
    MIND_RUNTIME.lock().unwrap_or_else(|e| e.into_inner())
}
