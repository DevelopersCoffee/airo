//! How native inference engines (llama.cpp, whisper.cpp) talk to the console.
//!
//! Those libraries default to a CLI habit: INFO Metal/allocator chatter on
//! stderr. A macOS app does not: debug and info stay out of the user's
//! terminal unless they opt in (`log stream`, Console.app). We follow that
//! here — quiet by default, full dump only when `AIRO_MIND_ENGINE_LOGS` is
//! set. Failures still return as `EngineError` to Flutter; a ggml assert
//! still aborts the process with its own message.

/// Whether llama.cpp / whisper.cpp should print their INFO/DEBUG dump.
///
/// Off by default, including Flutter debug runs. Set `AIRO_MIND_ENGINE_LOGS=1`
/// (or `true` / `yes`) to see Metal buffer sizes, KV-cache layout, and the
/// rest of the engine's CLI chatter.
pub fn engine_native_logs_verbose() -> bool {
    match std::env::var("AIRO_MIND_ENGINE_LOGS") {
        Ok(value) => {
            let value = value.trim();
            value == "1" || value.eq_ignore_ascii_case("true") || value.eq_ignore_ascii_case("yes")
        }
        Err(_) => false,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn defaults_off_when_unset() {
        if std::env::var("AIRO_MIND_ENGINE_LOGS").is_err() {
            assert!(!engine_native_logs_verbose());
        }
    }
}
