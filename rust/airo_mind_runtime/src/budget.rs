//! Resource budgets.
//!
//! `C6`: the Supervisor *"owns memory, CPU and I/O budgets. An engine that
//! exceeds its budget is throttled or cancelled, not permitted to starve the
//! UI"*, and *"an engine exceeding its memory budget is stopped before the
//! process OOMs"*.
//!
//! Admission control, not accounting. An engine declares what it needs before
//! it runs; the Supervisor refuses the job if the device cannot afford it.
//! Refusing to start is the only point at which a 4 GB model on a 2 GB budget
//! can be handled gracefully — after the allocation it is an OOM kill, and on
//! Android that takes the whole app.

/// What an engine needs in order to run.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct ResourceRequest {
    pub memory_mb: u32,
}

impl ResourceRequest {
    pub fn new(memory_mb: u32) -> Self {
        Self { memory_mb }
    }
}

/// What the device is willing to spend.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct ResourceBudget {
    pub memory_mb: u32,
}

impl ResourceBudget {
    pub fn new(memory_mb: u32) -> Self {
        Self { memory_mb }
    }

    /// Whether this request fits. Compared before the engine allocates.
    pub fn admits(&self, request: ResourceRequest) -> bool {
        request.memory_mb <= self.memory_mb
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_request_within_budget_is_admitted() {
        assert!(ResourceBudget::new(2048).admits(ResourceRequest::new(512)));
        assert!(ResourceBudget::new(512).admits(ResourceRequest::new(512)));
    }

    #[test]
    fn a_request_over_budget_is_refused() {
        assert!(
            !ResourceBudget::new(512).admits(ResourceRequest::new(4096)),
            "a 4 GB model on a 512 MB budget must be refused before it allocates"
        );
    }
}
