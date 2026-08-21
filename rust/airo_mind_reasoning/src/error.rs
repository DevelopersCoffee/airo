use airo_mind_core::EngineError;

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ReasoningError {
    InferenceUnavailable,
    ModelNotLoaded,
    ContextLimitExceeded,
    InvalidModelOutput,
    Cancelled,
    UnsupportedCapability,
    Backend(String),
}

impl ReasoningError {
    pub fn user_message(&self) -> &'static str {
        match self {
            Self::InferenceUnavailable | Self::ModelNotLoaded => {
                "On-device generation is not available right now."
            }
            Self::ContextLimitExceeded => "This request is too large for the current device.",
            Self::InvalidModelOutput => "The model returned an answer that could not be used.",
            Self::Cancelled => "Stopped.",
            Self::UnsupportedCapability => "This device cannot run that kind of reasoning.",
            Self::Backend(_) => "Generation failed. Try again.",
        }
    }
}

impl From<EngineError> for ReasoningError {
    fn from(value: EngineError) -> Self {
        match value {
            EngineError::Cancelled => Self::Cancelled,
            EngineError::ModelUnavailable => Self::ModelNotLoaded,
            EngineError::InvalidInput(_) => Self::InvalidModelOutput,
            EngineError::Backend(msg) => Self::Backend(msg),
        }
    }
}

impl std::fmt::Display for ReasoningError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(self.user_message())
    }
}

impl std::error::Error for ReasoningError {}
