//! Rust-backed Mind operation log + vault-encrypted speaker enrollment (#1213, #504).

use std::fs::File;
use std::io::{BufRead, BufReader};
use std::path::{Path, PathBuf};
use std::sync::{Arc, LazyLock, Mutex};

use airo_mind::{
    generate_mnemonic, seed_from_mnemonic, ContextId, ContentId as VaultContentId,
    DeviceCertificate, DeviceId, DeviceKey, RevocationSubject, RootIdentity, SealedEnvelope,
    Vault,
};
use airo_mind_core::notes::{NotesCapability, NOTES_CAPABILITY};
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
const NOTES_KIND_CREATE: &str = "note.create";
const NOTES_KIND_EDIT: &str = "note.edit";
const NOTES_KIND_DELETE: &str = "note.delete";

pub(crate) struct VaultStateData {
    pub is_sealed: bool,
    pub key_count: u64,
    pub revoked_count: u64,
    pub revocation_epoch: u64,
    pub on_disk_bytes: u64,
}

pub(crate) struct MindDeviceData {
    pub name: String,
    pub fingerprint_a: String,
    pub fingerprint_b: String,
    pub fingerprint_c: String,
    pub is_this_device: bool,
    pub revoked_at_ms: u64,
}

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
    base_dir: PathBuf,
    runtime: Runtime,
    vault: Mutex<Vault>,
    envelope_dir: PathBuf,
    speaker_context: ContextId,
    root_identity: RootIdentity,
    local_device_id: String,
    device_names: Mutex<std::collections::BTreeMap<String, String>>,
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
            let existing =
                std::fs::read_to_string(&mnemonic_path).map_err(|e| e.to_string())?;
            if seed_from_mnemonic(existing.trim()).is_ok() {
                existing
            } else {
                // A truncated or hand-edited file bricks first launch with
                // "invalid recovery mnemonic". Regenerate rather than fail
                // permanently — the vault has no recoverable state yet.
                let generated = generate_mnemonic().map_err(|e| e.to_string())?;
                std::fs::write(&mnemonic_path, generated.as_str())
                    .map_err(|e| e.to_string())?;
                generated.to_string()
            }
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

        let mut device_names = Self::load_device_names(&vault_dir)?;
        let local_device_id = Self::bootstrap_local_device(
            &vault_dir,
            &mut vault,
            &identity,
            &mut device_names,
        )?;

        let state = Self {
            base_dir,
            runtime,
            vault: Mutex::new(vault),
            envelope_dir,
            speaker_context,
            root_identity: identity,
            local_device_id,
            device_names: Mutex::new(device_names),
        };

        state.migrate_legacy_mind_ops_jsonl(&state.base_dir.join("mind_ops.jsonl"))?;
        state.migrate_legacy_speaker_enrollment(&state.base_dir.join("speaker_enrollment"))?;
        state.migrate_legacy_notes_log(&state.base_dir.join("notes.log"))?;
        state.sync_speaker_enrollment_runtime()?;

        Ok(state)
    }

    fn load_device_names(
        vault_dir: &Path,
    ) -> Result<std::collections::BTreeMap<String, String>, String> {
        let path = vault_dir.join("device_names.json");
        if !path.exists() {
            return Ok(std::collections::BTreeMap::new());
        }
        let raw = std::fs::read_to_string(path).map_err(|e| e.to_string())?;
        serde_json::from_str(&raw).map_err(|e| e.to_string())
    }

    fn save_device_names(&self, vault_dir: &Path) -> Result<(), String> {
        let path = vault_dir.join("device_names.json");
        let names = self.device_names.lock().map_err(|e| e.to_string())?;
        let snapshot = names.clone();
        let json = serde_json::to_string_pretty(&snapshot).map_err(|e| e.to_string())?;
        std::fs::write(path, json).map_err(|e| e.to_string())?;
        Ok(())
    }

    fn bootstrap_local_device(
        vault_dir: &Path,
        vault: &mut Vault,
        root_identity: &RootIdentity,
        device_names: &mut std::collections::BTreeMap<String, String>,
    ) -> Result<String, String> {
        let local_path = vault_dir.join("local_device.json");
        let mut local_device_id = String::new();
        if local_path.exists() {
            let raw = std::fs::read_to_string(&local_path).map_err(|e| e.to_string())?;
            let parsed: serde_json::Value =
                serde_json::from_str(&raw).map_err(|e| e.to_string())?;
            local_device_id = parsed
                .get("device_id")
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_string();
        }
        if local_device_id.is_empty() {
            let device_key = DeviceKey::generate().map_err(|e| e.to_string())?;
            local_device_id = device_key.device_id();
            let now = std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .map(|d| d.as_millis() as u64)
                .unwrap_or(0);
            let certificate = DeviceCertificate::issue(root_identity, &device_key, now)
                .map_err(|e| e.to_string())?;
            vault.trust_device(certificate).map_err(|e| e.to_string())?;
            let meta = json!({ "device_id": local_device_id });
            std::fs::write(local_path, meta.to_string()).map_err(|e| e.to_string())?;
            device_names.insert(local_device_id.clone(), "This device".to_string());
            let json = serde_json::to_string_pretty(&device_names).map_err(|e| e.to_string())?;
            std::fs::write(vault_dir.join("device_names.json"), json).map_err(|e| e.to_string())?;
        }
        Ok(local_device_id)
    }

    fn migrate_legacy_notes_log(&self, path: &Path) -> Result<(), String> {
        if !path.exists() {
            return Ok(());
        }
        if self
            .runtime
            .replay()
            .map_err(|e| e.to_string())?
            .iter()
            .any(|op| op.capability == NOTES_CAPABILITY)
        {
            return Ok(());
        }
        let file = File::open(path).map_err(|e| e.to_string())?;
        let reader = BufReader::new(file);
        let notes = NotesCapability::new(&self.runtime);
        for line in reader.lines() {
            let line = line.map_err(|e| e.to_string())?;
            if line.trim().is_empty() {
                continue;
            }
            let record: LegacyNotesOpRecord =
                serde_json::from_str(&line).map_err(|e| e.to_string())?;
            let kind = match record.kind.as_str() {
                "create" => NOTES_KIND_CREATE,
                "edit" => NOTES_KIND_EDIT,
                "delete" => NOTES_KIND_DELETE,
                _ => continue,
            };
            match kind {
                NOTES_KIND_CREATE => {
                    notes
                        .create_note(
                            &record.id,
                            &record.title,
                            &record.body,
                            record.recorded_at_ms,
                        )
                        .map_err(|e| e.to_string())?;
                }
                NOTES_KIND_EDIT => {
                    notes
                        .edit_note(
                            &record.id,
                            &record.title,
                            &record.body,
                            record.recorded_at_ms,
                        )
                        .map_err(|e| e.to_string())?;
                }
                NOTES_KIND_DELETE => {
                    notes
                        .delete_note(&record.id, record.recorded_at_ms)
                        .map_err(|e| e.to_string())?;
                }
                _ => {}
            }
        }
        Ok(())
    }

    fn vault_state(&self) -> Result<VaultStateData, String> {
        let vault = self.vault.lock().map_err(|e| e.to_string())?;
        let revoked_count = vault.revocations().all_revoked().len() as u64;
        let on_disk_bytes = dir_size(&self.base_dir).unwrap_or(0);
        let key_count = vault.trusted_devices().len() as u64 + 1;
        Ok(VaultStateData {
            is_sealed: true,
            key_count,
            revoked_count,
            revocation_epoch: vault.revocations().head_epoch(),
            on_disk_bytes,
        })
    }

    fn vault_devices(&self) -> Result<Vec<MindDeviceData>, String> {
        let vault = self.vault.lock().map_err(|e| e.to_string())?;
        let names = self.device_names.lock().map_err(|e| e.to_string())?;
        let local_id = &self.local_device_id;
        let mut out = Vec::new();
        for cert in vault.trusted_devices() {
            let device_id = cert.device_id();
            let (a, b, c) = fingerprint_groups(device_id);
            let subject = RevocationSubject::Device(device_id.to_string());
            let revoked = vault.revocations().is_revoked(&subject);
            let name = names
                .get(device_id)
                .cloned()
                .unwrap_or_else(|| short_device_name(device_id));
            out.push(MindDeviceData {
                name,
                fingerprint_a: a,
                fingerprint_b: b,
                fingerprint_c: c,
                is_this_device: device_id == local_id,
                revoked_at_ms: if revoked {
                    vault.revocations().head_epoch()
                } else {
                    0
                },
            });
        }
        Ok(out)
    }

    fn revoke_vault_device(
        &self,
        fingerprint_a: &str,
        fingerprint_b: &str,
        fingerprint_c: &str,
    ) -> Result<(), String> {
        let prefix = format!(
            "{}{}{}",
            fingerprint_a.to_uppercase(),
            fingerprint_b.to_uppercase(),
            fingerprint_c.to_uppercase()
        );
        let vault_guard = self.vault.lock().map_err(|e| e.to_string())?;
        let device_id = vault_guard
            .trusted_devices()
            .iter()
            .map(|cert| cert.device_id())
            .find(|id| id.to_uppercase().starts_with(&prefix))
            .map(|s| s.to_string());
        let device_id = device_id.ok_or_else(|| "device not found".to_string())?;
        let mut vault = self.vault.lock().map_err(|e| e.to_string())?;
        let device_id = DeviceId::new(&device_id).map_err(|e| e.to_string())?;
        vault.revoke_device(&device_id).map_err(|e| e.to_string())?;
        Ok(())
    }

    fn replay_from(&self, sequence: u64) -> Result<Vec<f64>, String> {
        let ops = self.runtime.replay().map_err(|e| e.to_string())?;
        let tail: Vec<&Operation> = ops.iter().filter(|op| op.seq >= sequence).collect();
        if tail.is_empty() {
            return Ok(vec![1.0]);
        }
        let total = tail.len();
        let mut progress = Vec::with_capacity(total + 1);
        for (index, _) in tail.iter().enumerate() {
            progress.push(index as f64 / total as f64);
        }
        progress.push(1.0);
        Ok(progress)
    }

    fn notes_json(&self) -> Result<String, String> {
        let notes = NotesCapability::new(&self.runtime);
        let projection = notes.notes().map_err(|e| e.to_string())?;
        let wire: Vec<serde_json::Value> = projection
            .all()
            .into_iter()
            .map(|note| {
                json!({
                    "id": note.id,
                    "title": note.title,
                    "body": note.body,
                    "updatedAtMs": note.updated_at_ms,
                })
            })
            .collect();
        serde_json::to_string(&wire).map_err(|e| e.to_string())
    }

    fn create_note(
        &self,
        id: &str,
        title: &str,
        body: &str,
        recorded_at_ms: u64,
    ) -> Result<(), String> {
        NotesCapability::new(&self.runtime)
            .create_note(id, title, body, recorded_at_ms)
            .map_err(|e| e.to_string())?;
        Ok(())
    }

    fn edit_note(
        &self,
        id: &str,
        title: &str,
        body: &str,
        recorded_at_ms: u64,
    ) -> Result<(), String> {
        NotesCapability::new(&self.runtime)
            .edit_note(id, title, body, recorded_at_ms)
            .map_err(|e| e.to_string())?;
        Ok(())
    }

    fn delete_note(&self, id: &str, recorded_at_ms: u64) -> Result<(), String> {
        NotesCapability::new(&self.runtime)
            .delete_note(id, recorded_at_ms)
            .map_err(|e| e.to_string())?;
        Ok(())
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

#[derive(Deserialize)]
struct LegacyNotesOpRecord {
    kind: String,
    id: String,
    #[serde(default)]
    title: String,
    #[serde(default)]
    body: String,
    #[serde(rename = "recordedAtMs")]
    recorded_at_ms: u64,
}

fn fingerprint_groups(device_id: &str) -> (String, String, String) {
    let upper = device_id.to_uppercase();
    (
        upper.chars().take(4).collect(),
        upper.chars().skip(4).take(4).collect(),
        upper.chars().skip(8).take(4).collect(),
    )
}

fn short_device_name(device_id: &str) -> String {
    let (a, b, c) = fingerprint_groups(device_id);
    format!("{} · {} · {}", a, b, c)
}

fn dir_size(path: &Path) -> Result<u64, std::io::Error> {
    let mut total = 0u64;
    if path.is_file() {
        return Ok(path.metadata()?.len());
    }
    for entry in std::fs::read_dir(path)? {
        let entry = entry?;
        let meta = entry.metadata()?;
        if meta.is_dir() {
            total += dir_size(&entry.path())?;
        } else {
            total += meta.len();
        }
    }
    Ok(total)
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

pub fn vault_state() -> Result<VaultStateData, String> {
    let state = runtime_state()?;
    state.vault_state()
}

pub fn vault_devices() -> Result<Vec<MindDeviceData>, String> {
    let state = runtime_state()?;
    state.vault_devices()
}

pub fn revoke_vault_device(
    fingerprint_a: String,
    fingerprint_b: String,
    fingerprint_c: String,
) -> Result<(), String> {
    let state = runtime_state()?;
    state.revoke_vault_device(&fingerprint_a, &fingerprint_b, &fingerprint_c)
}

pub fn replay_from(sequence: u64) -> Result<Vec<f64>, String> {
    let state = runtime_state()?;
    state.replay_from(sequence)
}

pub fn notes_json() -> Result<String, String> {
    let state = runtime_state()?;
    state.notes_json()
}

pub fn create_note(
    id: String,
    title: String,
    body: String,
    recorded_at_ms: u64,
) -> Result<(), String> {
    let state = runtime_state()?;
    state.create_note(&id, &title, &body, recorded_at_ms)
}

pub fn edit_note(
    id: String,
    title: String,
    body: String,
    recorded_at_ms: u64,
) -> Result<(), String> {
    let state = runtime_state()?;
    state.edit_note(&id, &title, &body, recorded_at_ms)
}

pub fn delete_note(id: String, recorded_at_ms: u64) -> Result<(), String> {
    let state = runtime_state()?;
    state.delete_note(&id, recorded_at_ms)
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

#[cfg(test)]
mod e2e_tests {
    use super::*;
    use std::io::Write;

    fn temp_mind_dir(name: &str) -> PathBuf {
        let dir = std::env::temp_dir().join(format!(
            "airo_mind_runtime_e2e_{}_{}",
            name,
            std::process::id()
        ));
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir_all(&dir).expect("temp dir");
        dir
    }

    fn write_legacy_notes_log(path: &Path) {
        let file = File::create(path).expect("notes.log");
        let mut file = file;
        writeln!(
            file,
            r#"{{"seq":0,"kind":"create","id":"note-1","title":"Hello","body":"World","recordedAtMs":1000}}"#
        )
        .expect("write");
        writeln!(
            file,
            r#"{{"seq":1,"kind":"edit","id":"note-1","title":"Hello","body":"Updated","recordedAtMs":2000}}"#
        )
        .expect("write");
        file.flush().expect("flush");
    }

    #[test]
    fn open_regenerates_invalid_recovery_mnemonic() {
        let base = temp_mind_dir("invalid-mnemonic");
        let vault_dir = base.join("vault");
        std::fs::create_dir_all(&vault_dir).expect("vault dir");
        std::fs::write(vault_dir.join("recovery.mnemonic"), "not a valid mnemonic")
            .expect("write bad mnemonic");

        open_mind_runtime(base.to_str().expect("utf8 path")).expect("open");

        let mnemonic =
            std::fs::read_to_string(vault_dir.join("recovery.mnemonic")).expect("read mnemonic");
        assert_ne!(mnemonic.trim(), "not a valid mnemonic");
        let vault = vault_state().expect("vault state");
        assert!(vault.is_sealed);
    }

    #[test]
    fn mind_runtime_vault_notes_replay_end_to_end() {
        let base = temp_mind_dir("core");
        write_legacy_notes_log(&base.join("notes.log"));

        open_mind_runtime(base.to_str().expect("utf8 path")).expect("open");

        let vault = vault_state().expect("vault state");
        assert!(vault.is_sealed);
        assert!(vault.key_count >= 1);

        let devices = vault_devices().expect("devices");
        assert!(!devices.is_empty());
        assert!(devices.iter().any(|d| d.is_this_device));

        let notes_raw = notes_json().expect("notes json");
        assert!(notes_raw.contains("note-1"));
        assert!(notes_raw.contains("Updated"));

        create_note(
            "note-2".to_string(),
            "Second".to_string(),
            "Body".to_string(),
            3000,
        )
        .expect("create note");
        let after_create = notes_json().expect("notes after create");
        assert!(after_create.contains("note-2"));

        let seq1 = append_scribe_op(
            "inference".to_string(),
            "First".to_string(),
            "ctx-1".to_string(),
            "detail-a".to_string(),
        )
        .expect("append 1");
        let seq2 = append_scribe_op(
            "inference".to_string(),
            "Second".to_string(),
            "ctx-2".to_string(),
            "detail-b".to_string(),
        )
        .expect("append 2");
        assert_eq!(scribe_op_count().expect("count"), 2);

        let replay_tail = replay_from(seq2).expect("replay from seq2");
        assert!(!replay_tail.is_empty());
        assert_eq!(replay_tail.last().copied(), Some(1.0));

        let replay_mid = replay_from(seq1).expect("replay from seq1");
        assert!(replay_mid.len() >= 2);
        assert_eq!(replay_mid.last().copied(), Some(1.0));
    }
}
