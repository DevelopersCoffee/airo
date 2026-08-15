//! Shared generation-engine state for the llama cdylib's Flutter-facing API.
//!
//! `minutes` and `meeting_intelligence` both drive the same `Supervisor` slot;
//! splitting the statics would let one module cancel or unload what the other
//! loaded.

use std::sync::Mutex;

use airo_mind_core::{CancelToken, Supervisor};

pub(crate) static ENGINE: Mutex<Option<Supervisor>> = Mutex::new(None);
pub(crate) static CANCEL: Mutex<Option<CancelToken>> = Mutex::new(None);
pub(crate) static MODEL_ID: Mutex<Option<String>> = Mutex::new(None);

pub(crate) fn lock<T>(mutex: &'static Mutex<T>) -> std::sync::MutexGuard<'static, T> {
    mutex.lock().unwrap_or_else(|e| e.into_inner())
}

pub(crate) fn begin_job() -> CancelToken {
    let cancel = CancelToken::new();
    *lock(&CANCEL) = Some(cancel.clone());
    cancel
}

pub(crate) fn with_supervisor<R>(
    f: impl FnOnce(&Supervisor) -> Result<R, String>,
) -> Result<R, String> {
    let engine = lock(&ENGINE);
    let supervisor = engine.as_ref().ok_or("Airo Mind is not initialised")?;
    f(supervisor)
}

#[allow(dead_code)]
pub(crate) fn with_supervisor_mut<R>(
    f: impl FnOnce(&mut Supervisor) -> Result<R, String>,
) -> Result<R, String> {
    let mut engine = lock(&ENGINE);
    let supervisor = engine.as_mut().ok_or("Airo Mind is not initialised")?;
    f(supervisor)
}
