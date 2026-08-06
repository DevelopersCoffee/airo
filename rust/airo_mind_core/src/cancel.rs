//! Cooperative cancellation.
//!
//! `C6`: *"work started from the UI is cancellable when the user navigates away
//! or the app backgrounds"*, and a long job *"cancelled mid-flight leaves no
//! torn state"*.
//!
//! Cooperative rather than pre-emptive: an engine holding a partially decoded
//! model cannot be killed safely, so it is asked to stop at a segment boundary
//! and reports that it did.

use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;

/// A cancellation signal shared with a running job.
///
/// Cloning shares the signal — cancelling any handle cancels the job.
#[derive(Clone, Debug, Default)]
pub struct CancelToken(Arc<AtomicBool>);

impl CancelToken {
    pub fn new() -> Self {
        Self::default()
    }

    /// Asks the job to stop. Idempotent.
    pub fn cancel(&self) {
        self.0.store(true, Ordering::SeqCst);
    }

    /// Engines check this between segments. Checking more often than that
    /// costs an atomic load per token; checking less often makes cancellation
    /// feel broken to a user who has already navigated away.
    pub fn is_cancelled(&self) -> bool {
        self.0.load(Ordering::SeqCst)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_clone_shares_the_signal() {
        let a = CancelToken::new();
        let b = a.clone();
        assert!(!b.is_cancelled());
        a.cancel();
        assert!(
            b.is_cancelled(),
            "cancelling one handle must cancel the job"
        );
    }

    #[test]
    fn cancellation_is_idempotent() {
        let t = CancelToken::new();
        t.cancel();
        t.cancel();
        assert!(t.is_cancelled());
    }
}
