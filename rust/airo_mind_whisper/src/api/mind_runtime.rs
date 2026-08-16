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

fn map_op(op: mind_runtime_state::MindOpWire) -> MindOpWire {
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
