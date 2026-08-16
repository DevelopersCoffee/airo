//! Rust-backed operation log + speaker enrollment persistence (#1213, #504).

use flutter_rust_bridge::frb;

use crate::mind_runtime_state;

/// One scribe timeline operation mirrored from the Rust operation log.
#[frb]
pub struct MindOpWire {
    pub sequence: u64,
    pub kind: String,
    pub title: String,
    pub context_id: String,
    pub device_name: String,
    pub recorded_at_ms: u64,
    pub detail: String,
}

#[frb]
pub struct VaultStateWire {
    pub is_sealed: bool,
    pub key_count: u64,
    pub revoked_count: u64,
    pub revocation_epoch: u64,
    pub on_disk_bytes: u64,
}

#[frb]
pub struct MindDeviceWire {
    pub name: String,
    pub fingerprint_a: String,
    pub fingerprint_b: String,
    pub fingerprint_c: String,
    pub is_this_device: bool,
    pub revoked_at_ms: u64,
}

fn map_op(op: mind_runtime_state::ScribeOpWire) -> MindOpWire {
    MindOpWire {
        sequence: op.sequence,
        kind: op.kind,
        title: op.title,
        context_id: op.context_id,
        device_name: op.device_name,
        recorded_at_ms: op.recorded_at_ms,
        detail: op.detail,
    }
}

fn map_vault_state(state: mind_runtime_state::VaultStateData) -> VaultStateWire {
    VaultStateWire {
        is_sealed: state.is_sealed,
        key_count: state.key_count,
        revoked_count: state.revoked_count,
        revocation_epoch: state.revocation_epoch,
        on_disk_bytes: state.on_disk_bytes,
    }
}

fn map_device(device: mind_runtime_state::MindDeviceData) -> MindDeviceWire {
    MindDeviceWire {
        name: device.name,
        fingerprint_a: device.fingerprint_a,
        fingerprint_b: device.fingerprint_b,
        fingerprint_c: device.fingerprint_c,
        is_this_device: device.is_this_device,
        revoked_at_ms: device.revoked_at_ms,
    }
}

/// Boots the Rust operation log + vault-backed speaker enrollment store.
#[frb(sync)]
pub fn mind_runtime_initialize(base_dir: String) -> Result<(), String> {
    mind_runtime_state::open_mind_runtime(&base_dir)
}

/// Appends one scribe-visible operation to the Rust log.
#[frb(sync)]
pub fn mind_runtime_append_scribe_op(
    kind: String,
    title: String,
    context_id: String,
    detail: String,
) -> Result<u64, String> {
    mind_runtime_state::append_scribe_op(kind, title, context_id, detail)
}

#[frb(sync)]
pub fn mind_runtime_scribe_op_count() -> Result<u64, String> {
    mind_runtime_state::scribe_op_count()
}

#[frb(sync)]
pub fn mind_runtime_scribe_ops_recent(
    offset: u64,
    limit: u64,
) -> Result<Vec<MindOpWire>, String> {
    mind_runtime_state::scribe_ops_recent(offset, limit)
        .map(|ops| ops.into_iter().map(map_op).collect())
}

/// Enrolls a speaker profile into the vault-encrypted Rust log.
#[frb(sync)]
pub fn mind_runtime_enroll_speaker(
    id: String,
    display_name: String,
    embedding: Vec<f32>,
) -> Result<(), String> {
    mind_runtime_state::enroll_speaker(id, display_name, embedding)
}

/// JSON array of enrolled speaker profiles rebuilt from the Rust log.
#[frb(sync)]
pub fn mind_runtime_speaker_profiles_json() -> Result<String, String> {
    mind_runtime_state::speaker_profiles_json()
}

#[frb(sync)]
pub fn mind_runtime_vault_state() -> Result<VaultStateWire, String> {
    mind_runtime_state::vault_state().map(map_vault_state)
}

#[frb(sync)]
pub fn mind_runtime_vault_devices() -> Result<Vec<MindDeviceWire>, String> {
    mind_runtime_state::vault_devices()
        .map(|devices| devices.into_iter().map(map_device).collect())
}

#[frb(sync)]
pub fn mind_runtime_revoke_vault_device(
    fingerprint_a: String,
    fingerprint_b: String,
    fingerprint_c: String,
) -> Result<(), String> {
    mind_runtime_state::revoke_vault_device(fingerprint_a, fingerprint_b, fingerprint_c)
}

#[frb(sync)]
pub fn mind_runtime_replay_from(sequence: u64) -> Result<Vec<f64>, String> {
    mind_runtime_state::replay_from(sequence)
}

#[frb(sync)]
pub fn mind_runtime_notes_json() -> Result<String, String> {
    mind_runtime_state::notes_json()
}

#[frb(sync)]
pub fn mind_runtime_create_note(
    id: String,
    title: String,
    body: String,
    recorded_at_ms: u64,
) -> Result<(), String> {
    mind_runtime_state::create_note(id, title, body, recorded_at_ms)
}

#[frb(sync)]
pub fn mind_runtime_edit_note(
    id: String,
    title: String,
    body: String,
    recorded_at_ms: u64,
) -> Result<(), String> {
    mind_runtime_state::edit_note(id, title, body, recorded_at_ms)
}

#[frb(sync)]
pub fn mind_runtime_delete_note(id: String, recorded_at_ms: u64) -> Result<(), String> {
    mind_runtime_state::delete_note(id, recorded_at_ms)
}
