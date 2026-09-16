# VibeSync Daemon Skeleton Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create `DevelopersCoffee/vibesync` and land a two-process daemon: CLI/Flutter send `VibeSyncCommand` over NDJSON IPC, `vibesyncd` runs a typed pipeline with a fixture engine, and the daemon stays up if a client dies.

**Architecture:** Rust workspace with `airo_desktop` (OS traits, all `Unsupported`), `vibesync_core` (config, commands, events, registry, pipeline, IPC codec), `vibesyncd` (socket server), `vibesync_cli` (client). Flutter is an event client only. No llama.cpp, no real clipboard, no Airo worktree.

**Tech Stack:** Rust 2021, tokio, serde/serde_json/serde_yaml, Flutter desktop (macOS/Windows/Linux) for the control-plane client. Spec: `docs/superpowers/specs/2026-09-12-vibesync-daemon-skeleton-design.md` (copy into the new repo as `docs/architecture/2026-09-12-vibesync-daemon-skeleton-design.md`).

---

## File map

Create these in `/Users/udaychauhan/workspace/vibesync` (new clone, not an Airo worktree):

| Path | Responsibility |
|---|---|
| `Cargo.toml` | Workspace members + shared package metadata |
| `LICENSE` | MIT |
| `crates/airo_desktop/src/lib.rs` | Re-exports |
| `crates/airo_desktop/src/capabilities.rs` | `PlatformCapabilities` |
| `crates/airo_desktop/src/unsupported.rs` | All traits + `Unsupported*` impls |
| `crates/vibesync_core/src/config.rs` | YAML → typed `VibeSyncConfig` |
| `crates/vibesync_core/src/command.rs` | `VibeSyncCommand` |
| `crates/vibesync_core/src/event.rs` | `VibeSyncEvent`, `ErrorCode` |
| `crates/vibesync_core/src/operation.rs` | `InteractionMode`, `ExecutionMode`, `TextOperation`, `OperationRegistry` |
| `crates/vibesync_core/src/context.rs` | `SelectionContext`, `FixtureSelectionSource` |
| `crates/vibesync_core/src/engine.rs` | `InferenceEngine`, `FixtureEngine` |
| `crates/vibesync_core/src/validator.rs` | Output validator |
| `crates/vibesync_core/src/pipeline.rs` | Command bus → events |
| `crates/vibesync_core/src/ipc.rs` | NDJSON encode/decode |
| `crates/vibesyncd/src/main.rs` | Bind socket, serve clients, run pipeline |
| `crates/vibesync_cli/src/main.rs` | Connect, send one command, print events |
| `app/lib/ipc_client.dart` | Flutter unix-socket / named-pipe client |
| `app/lib/main.dart` | Event log + Shutdown button |

Do not create files under `/Users/udaychauhan/workspace/airo` except the Airo GitHub issues in Task 13.

---

### Task 1: Create the GitHub repo and Cargo workspace

**Files:**
- Create: `/Users/udaychauhan/workspace/vibesync/` (new repo)
- Create: `LICENSE`, `README.md`, `.gitignore`, `Cargo.toml`
- Create: `docs/architecture/2026-09-12-vibesync-daemon-skeleton-design.md` (copy from Airo spec)
- Create: `docs/superpowers/plans/2026-09-12-vibesync-daemon-skeleton.md` (copy this plan)

- [ ] **Step 1: Create the empty GitHub repo**

```bash
gh repo create DevelopersCoffee/vibesync --public --description "VibeSync — local AI command layer for text and desktop workflows" --clone=false
mkdir -p /Users/udaychauhan/workspace/vibesync
cd /Users/udaychauhan/workspace/vibesync
git init
git remote add origin git@github.com:DevelopersCoffee/vibesync.git
```

Expected: `git remote -v` shows `DevelopersCoffee/vibesync`.

- [ ] **Step 2: Write MIT LICENSE**

Use the same MIT license text as `https://github.com/DevelopersCoffee/airo_core` (Copyright 2026 DevelopersCoffee).

- [ ] **Step 3: Write `.gitignore`**

```
/target
**/*.rs.bk
.DS_Store
app/.dart_tool/
app/build/
app/.flutter-plugins
app/.flutter-plugins-dependencies
```

- [ ] **Step 4: Write workspace `Cargo.toml`**

```toml
[workspace]
resolver = "2"
members = [
  "crates/airo_desktop",
  "crates/vibesync_core",
  "crates/vibesyncd",
  "crates/vibesync_cli",
]

[workspace.package]
version = "0.1.0"
edition = "2021"
license = "MIT"
repository = "https://github.com/DevelopersCoffee/vibesync"
```

- [ ] **Step 5: Copy spec and this plan into the new repo, write a short README**

Copy:

- `/Users/udaychauhan/workspace/airo/docs/superpowers/specs/2026-09-12-vibesync-daemon-skeleton-design.md`
  → `docs/architecture/2026-09-12-vibesync-daemon-skeleton-design.md`
- `/Users/udaychauhan/workspace/airo/docs/superpowers/plans/2026-09-12-vibesync-daemon-skeleton.md`
  → `docs/superpowers/plans/2026-09-12-vibesync-daemon-skeleton.md`

README body:

```markdown
# VibeSync

Local AI command layer for text and desktop workflows.

Slice 1 is the Rust daemon skeleton. Flutter is a control plane. Inference is a fixture. See `docs/architecture/2026-09-12-vibesync-daemon-skeleton-design.md`.
```

- [ ] **Step 6: Commit and push**

```bash
cd /Users/udaychauhan/workspace/vibesync
git add LICENSE README.md .gitignore Cargo.toml docs
git commit -m "$(cat <<'EOF'
chore: bootstrap VibeSync workspace and architecture spec

EOF
)"
git push -u origin HEAD:main
```

---

### Task 2: `airo_desktop` traits and Unsupported impls

**Files:**
- Create: `crates/airo_desktop/Cargo.toml`
- Create: `crates/airo_desktop/src/lib.rs`
- Create: `crates/airo_desktop/src/capabilities.rs`
- Create: `crates/airo_desktop/src/unsupported.rs`
- Test: `crates/airo_desktop/src/unsupported.rs` (inline `#[cfg(test)]`)

- [ ] **Step 1: Add the crate manifest**

```toml
[package]
name = "airo_desktop"
version.workspace = true
edition.workspace = true
license.workspace = true
description = "OS integration traits for desktop utilities (hotkey, clipboard, input, display, tray, permissions)"
publish = false

[dependencies]
```

- [ ] **Step 2: Write the failing test**

In `crates/airo_desktop/src/unsupported.rs` (create the module first with just the test if needed — or put the test in `lib.rs`):

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn unsupported_hotkey_is_not_granted() {
        let hotkey = UnsupportedHotkey;
        assert!(!hotkey.is_supported());
    }

    #[test]
    fn capabilities_are_all_false_on_stub() {
        let caps = PlatformCapabilities::unsupported();
        assert!(!caps.global_hotkey);
        assert!(!caps.input_simulation);
        assert!(!caps.clipboard);
        assert!(!caps.overlay);
        assert!(!caps.tray);
    }
}
```

- [ ] **Step 3: Run test to verify it fails**

```bash
cd /Users/udaychauhan/workspace/vibesync
cargo test -p airo_desktop
```

Expected: FAIL compiling (`UnsupportedHotkey` / `PlatformCapabilities` not found).

- [ ] **Step 4: Write the implementation**

`crates/airo_desktop/src/capabilities.rs`:

```rust
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct PlatformCapabilities {
    pub global_hotkey: bool,
    pub input_simulation: bool,
    pub clipboard: bool,
    pub overlay: bool,
    pub tray: bool,
}

impl PlatformCapabilities {
    pub fn unsupported() -> Self {
        Self {
            global_hotkey: false,
            input_simulation: false,
            clipboard: false,
            overlay: false,
            tray: false,
        }
    }
}
```

`crates/airo_desktop/src/unsupported.rs`:

```rust
use crate::capabilities::PlatformCapabilities;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Display {
    pub id: u32,
    pub name: String,
}

pub trait Hotkey {
    fn is_supported(&self) -> bool;
}

pub trait Clipboard {
    fn is_supported(&self) -> bool;
}

pub trait Input {
    fn is_supported(&self) -> bool;
}

pub trait DisplayManager {
    fn primary_display(&self) -> Option<Display>;
    fn displays(&self) -> Vec<Display>;
    fn display_at_cursor(&self) -> Option<Display>;
    fn display_for_active_app(&self) -> Option<Display>;
}

pub trait Tray {
    fn is_supported(&self) -> bool;
}

pub trait Permissions {
    fn is_supported(&self) -> bool;
}

pub struct UnsupportedHotkey;
impl Hotkey for UnsupportedHotkey {
    fn is_supported(&self) -> bool {
        false
    }
}

pub struct UnsupportedClipboard;
impl Clipboard for UnsupportedClipboard {
    fn is_supported(&self) -> bool {
        false
    }
}

pub struct UnsupportedInput;
impl Input for UnsupportedInput {
    fn is_supported(&self) -> bool {
        false
    }
}

pub struct UnsupportedDisplayManager;
impl DisplayManager for UnsupportedDisplayManager {
    fn primary_display(&self) -> Option<Display> {
        None
    }
    fn displays(&self) -> Vec<Display> {
        Vec::new()
    }
    fn display_at_cursor(&self) -> Option<Display> {
        None
    }
    fn display_for_active_app(&self) -> Option<Display> {
        None
    }
}

pub struct UnsupportedTray;
impl Tray for UnsupportedTray {
    fn is_supported(&self) -> bool {
        false
    }
}

pub struct UnsupportedPermissions;
impl Permissions for UnsupportedPermissions {
    fn is_supported(&self) -> bool {
        false
    }
}

pub fn capabilities() -> PlatformCapabilities {
    PlatformCapabilities::unsupported()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::capabilities::PlatformCapabilities;

    #[test]
    fn unsupported_hotkey_is_not_granted() {
        let hotkey = UnsupportedHotkey;
        assert!(!hotkey.is_supported());
    }

    #[test]
    fn capabilities_are_all_false_on_stub() {
        let caps = PlatformCapabilities::unsupported();
        assert!(!caps.global_hotkey);
        assert!(!caps.input_simulation);
        assert!(!caps.clipboard);
        assert!(!caps.overlay);
        assert!(!caps.tray);
    }
}
```

`Display.name: String` cannot live in a `Copy` struct — `Display` is `Clone` only (already not Copy). Good.

`crates/airo_desktop/src/lib.rs`:

```rust
pub mod capabilities;
pub mod unsupported;

pub use capabilities::PlatformCapabilities;
pub use unsupported::{
    Clipboard, Display, DisplayManager, Hotkey, Input, Permissions, Tray, UnsupportedClipboard,
    UnsupportedDisplayManager, UnsupportedHotkey, UnsupportedInput, UnsupportedPermissions,
    UnsupportedTray, capabilities,
};
```

- [ ] **Step 5: Run tests**

```bash
cargo test -p airo_desktop
```

Expected: PASS, 2 tests.

- [ ] **Step 6: Commit**

```bash
git add crates/airo_desktop
git commit -m "$(cat <<'EOF'
feat(airo_desktop): add OS traits with unsupported stubs

EOF
)"
```

---

### Task 3: Typed YAML config

**Files:**
- Create: `crates/vibesync_core/Cargo.toml`
- Create: `crates/vibesync_core/src/lib.rs`
- Create: `crates/vibesync_core/src/config.rs`

- [ ] **Step 1: Manifest**

```toml
[package]
name = "vibesync_core"
version.workspace = true
edition.workspace = true
license.workspace = true
description = "VibeSync daemon runtime: config, commands, events, pipeline, IPC"
publish = false

[dependencies]
serde = { version = "1", features = ["derive"] }
serde_json = "1"
serde_yaml = "0.9"
thiserror = "2"

[dev-dependencies]
tempfile = "3"
```

- [ ] **Step 2: Write the failing tests in `config.rs`**

```rust
#[cfg(test)]
mod tests {
    use super::*;

    const SAMPLE: &str = r#"
app:
  start_on_login: false
  show_overlay: true
shortcut:
  key: "Alt+Space"
  interaction: zero_click
correction:
  preserve_meaning: true
  preserve_tone: true
  preserve_formatting: true
  spelling: true
  grammar: true
  punctuation: true
engine:
  provider: fixture
  model: grammar-default
  context_size: 1024
  temperature: 0.0
clipboard:
  restore_previous: true
operations:
  correct_grammar:
    mode: inplace
"#;

    #[test]
    fn parses_sample_yaml() {
        let cfg = VibeSyncConfig::from_yaml(SAMPLE).unwrap();
        assert_eq!(cfg.shortcut.key, "Alt+Space");
        assert_eq!(cfg.engine.provider, "fixture");
        assert_eq!(cfg.operations["correct_grammar"].mode, ExecutionMode::InPlace);
    }

    #[test]
    fn unknown_key_is_error() {
        let err = VibeSyncConfig::from_yaml("app:\n  nope: 1\n").unwrap_err();
        assert!(matches!(err, ConfigError::Parse(_)));
    }
}
```

`ExecutionMode` is defined in Task 4. To keep this task compiling independently, put a local `ExecutionMode` in `config.rs` as the operation mode field, then re-export the same enum from `operation.rs` in Task 4 **using this exact definition** (do not create a second enum):

```rust
#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum ExecutionMode {
    InPlace,
    Clipboard,
    Overlay,
}
```

Move it to `operation.rs` in Task 4 and have `config.rs` `use crate::operation::ExecutionMode`. For Task 3, define `ExecutionMode` in `config.rs` and in Task 4 **cut-paste** it to `operation.rs` (delete the config.rs copy, add `use crate::operation::ExecutionMode`).

- [ ] **Step 3: Run to verify fail**

```bash
cargo test -p vibesync_core --lib config
```

Expected: FAIL (`VibeSyncConfig` missing).

- [ ] **Step 4: Implement `config.rs`**

```rust
use std::collections::BTreeMap;
use std::fs;
use std::path::Path;

use serde::{Deserialize, Serialize};

use crate::operation::ExecutionMode;

#[derive(Debug, thiserror::Error)]
pub enum ConfigError {
    #[error("config parse error: {0}")]
    Parse(String),
    #[error("config io error: {0}")]
    Io(#[from] std::io::Error),
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct VibeSyncConfig {
    pub app: AppConfig,
    pub shortcut: ShortcutConfig,
    pub correction: CorrectionConfig,
    pub engine: EngineConfig,
    pub clipboard: ClipboardConfig,
    pub operations: BTreeMap<String, OperationConfig>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct AppConfig {
    pub start_on_login: bool,
    pub show_overlay: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ShortcutConfig {
    pub key: String,
    pub interaction: InteractionMode,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum InteractionMode {
    ZeroClick,
    Interactive,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct CorrectionConfig {
    pub preserve_meaning: bool,
    pub preserve_tone: bool,
    pub preserve_formatting: bool,
    pub spelling: bool,
    pub grammar: bool,
    pub punctuation: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct EngineConfig {
    pub provider: String,
    pub model: String,
    pub context_size: u32,
    pub temperature: f32,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ClipboardConfig {
    pub restore_previous: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct OperationConfig {
    pub mode: ExecutionMode,
}

impl VibeSyncConfig {
    pub fn from_yaml(text: &str) -> Result<Self, ConfigError> {
        serde_yaml::from_str(text).map_err(|e| ConfigError::Parse(e.to_string()))
    }

    pub fn load_or_init(path: &Path) -> Result<Self, ConfigError> {
        if path.exists() {
            let text = fs::read_to_string(path)?;
            return Self::from_yaml(&text);
        }
        let cfg = Self::default_skeleton();
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent)?;
        }
        fs::write(path, serde_yaml::to_string(&cfg).map_err(|e| ConfigError::Parse(e.to_string()))?)?;
        Ok(cfg)
    }

    pub fn default_skeleton() -> Self {
        let yaml = r#"
app:
  start_on_login: false
  show_overlay: true
shortcut:
  key: "Alt+Space"
  interaction: zero_click
correction:
  preserve_meaning: true
  preserve_tone: true
  preserve_formatting: true
  spelling: true
  grammar: true
  punctuation: true
engine:
  provider: fixture
  model: grammar-default
  context_size: 1024
  temperature: 0.0
clipboard:
  restore_previous: true
operations:
  correct_grammar:
    mode: inplace
"#;
        Self::from_yaml(yaml).expect("default skeleton yaml is valid")
    }
}
```

For Task 3 to compile before Task 4, create a stub `crates/vibesync_core/src/operation.rs`:

```rust
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum ExecutionMode {
    InPlace,
    Clipboard,
    Overlay,
}
```

`lib.rs`:

```rust
pub mod config;
pub mod operation;
```

- [ ] **Step 5: Run tests**

```bash
cargo test -p vibesync_core --lib config
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add crates/vibesync_core
git commit -m "$(cat <<'EOF'
feat(vibesync_core): parse deny-unknown-fields YAML config

EOF
)"
```

---

### Task 4: Commands, events, operations registry

**Files:**
- Create: `crates/vibesync_core/src/command.rs`
- Create: `crates/vibesync_core/src/event.rs`
- Modify: `crates/vibesync_core/src/operation.rs`
- Modify: `crates/vibesync_core/src/lib.rs`

- [ ] **Step 1: Write failing tests at the bottom of `operation.rs`**

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn default_registry_has_correct_grammar_only() {
        let reg = OperationRegistry::default_slice1();
        let op = reg.get("correct_grammar").expect("registered");
        assert_eq!(op.interaction, InteractionMode::ZeroClick);
        assert_eq!(op.execution, ExecutionMode::InPlace);
        assert!(reg.get("rewrite").is_none());
    }
}
```

Also add to `command.rs` tests:

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn process_selection_round_trips_json() {
        let cmd = VibeSyncCommand::ProcessSelection {
            operation_id: "correct_grammar".into(),
        };
        let json = serde_json::to_string(&cmd).unwrap();
        let back: VibeSyncCommand = serde_json::from_str(&json).unwrap();
        assert_eq!(cmd, back);
    }
}
```

- [ ] **Step 2: Run to verify fail**

```bash
cargo test -p vibesync_core
```

Expected: FAIL (`OperationRegistry` / `VibeSyncCommand` missing).

- [ ] **Step 3: Implement**

`command.rs`:

```rust
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum VibeSyncCommand {
    ProcessSelection { operation_id: String },
    ReloadConfiguration,
    ShowOverlay,
    HideOverlay,
    Shutdown,
}
```

`event.rs`:

```rust
use serde::{Deserialize, Serialize};

use crate::operation::ExecutionMode;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum VibeSyncEvent {
    Ready,
    HotkeyTriggered,
    CommandReceived { command: String },
    SelectionCaptured { text_len: usize, text_hash: String },
    InferenceStarted,
    InferenceCompleted,
    ValidationPassed,
    ValidationFailed { reason: String },
    DeliveryRecorded { mode: ExecutionMode },
    Completed,
    Error { code: ErrorCode },
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ErrorCode {
    UnknownOperation,
    BindInUse,
    InvalidConfig,
    EnginePanic,
}
```

Replace `operation.rs` with:

```rust
use serde::{Deserialize, Serialize};

use crate::config::InteractionMode;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum ExecutionMode {
    InPlace,
    Clipboard,
    Overlay,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TextOperation {
    pub id: String,
    pub interaction: InteractionMode,
    pub execution: ExecutionMode,
    pub prompt_template: String,
}

#[derive(Debug, Clone, Default)]
pub struct OperationRegistry {
    ops: std::collections::BTreeMap<String, TextOperation>,
}

impl OperationRegistry {
    pub fn default_slice1() -> Self {
        let mut reg = Self::default();
        reg.ops.insert(
            "correct_grammar".into(),
            TextOperation {
                id: "correct_grammar".into(),
                interaction: InteractionMode::ZeroClick,
                execution: ExecutionMode::InPlace,
                prompt_template: "Correct grammar only.".into(),
            },
        );
        reg
    }

    pub fn get(&self, id: &str) -> Option<&TextOperation> {
        self.ops.get(id)
    }
}
```

`lib.rs` adds `pub mod command; pub mod event;` and re-exports `InteractionMode` from config.

Do **not** add `rewrite` as a registered operation. Reserved names live only in the spec.

- [ ] **Step 4: Run tests**

```bash
cargo test -p vibesync_core
```

Expected: PASS (config + registry + json round-trip).

- [ ] **Step 5: Commit**

```bash
git add crates/vibesync_core
git commit -m "$(cat <<'EOF'
feat(vibesync_core): add commands, events, and slice-1 operation registry

EOF
)"
```

---

### Task 5: Fixture engine, selection source, validator

**Files:**
- Create: `crates/vibesync_core/src/context.rs`
- Create: `crates/vibesync_core/src/engine.rs`
- Create: `crates/vibesync_core/src/validator.rs`

- [ ] **Step 1: Write failing tests**

`engine.rs`:

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn fixture_engine_is_deterministic() {
        let engine = FixtureEngine;
        let a = engine.infer("pls send tommorow").unwrap();
        let b = engine.infer("pls send tommorow").unwrap();
        assert_eq!(a, b);
        assert_ne!(a, "pls send tommorow");
    }
}
```

`validator.rs`:

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn empty_output_fails() {
        let v = OutputValidator { max_chars: 32 * 1024 };
        assert!(v.check("hello", "").is_err());
    }

    #[test]
    fn identical_output_is_ok() {
        let v = OutputValidator { max_chars: 32 * 1024 };
        assert!(v.check("hello", "hello").is_ok());
    }

    #[test]
    fn over_cap_fails() {
        let v = OutputValidator { max_chars: 4 };
        assert!(v.check("hi", "hello").is_err());
    }
}
```

- [ ] **Step 2: Run to verify fail**

```bash
cargo test -p vibesync_core --lib engine
```

Expected: FAIL (`FixtureEngine` missing).

- [ ] **Step 3: Implement**

`context.rs`:

```rust
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ActiveApplication {
    pub name: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SelectionContext {
    pub text: String,
    pub application: ActiveApplication,
    pub captured_at_unix_ms: u64,
}

pub struct FixtureSelectionSource {
    pub text: String,
}

impl FixtureSelectionSource {
    pub fn capture(&self) -> SelectionContext {
        SelectionContext {
            text: self.text.clone(),
            application: ActiveApplication {
                name: "fixture".into(),
            },
            captured_at_unix_ms: 0,
        }
    }
}

pub fn hash_text(text: &str) -> String {
    use std::hash::{Hash, Hasher};
    let mut hasher = std::collections::hash_map::DefaultHasher::new();
    text.hash(&mut hasher);
    format!("{:x}", hasher.finish())
}
```

`engine.rs`:

```rust
#[derive(Debug, thiserror::Error)]
pub enum EngineError {
    #[error("engine panic: {0}")]
    Panic(String),
}

pub trait InferenceEngine {
    fn infer(&self, input: &str) -> Result<String, EngineError>;
}

pub struct FixtureEngine;

impl InferenceEngine for FixtureEngine {
    fn infer(&self, input: &str) -> Result<String, EngineError> {
        Ok(input.replace("tommorow", "tomorrow").replace("pls ", "Please "))
    }
}
```

`validator.rs`:

```rust
#[derive(Debug, thiserror::Error)]
pub enum ValidationError {
    #[error("empty output")]
    Empty,
    #[error("output exceeds {0} characters")]
    TooLong(usize),
}

pub struct OutputValidator {
    pub max_chars: usize,
}

impl OutputValidator {
    pub fn check(&self, _input: &str, output: &str) -> Result<(), ValidationError> {
        if output.is_empty() {
            return Err(ValidationError::Empty);
        }
        if output.chars().count() > self.max_chars {
            return Err(ValidationError::TooLong(self.max_chars));
        }
        Ok(())
    }
}
```

Wire modules in `lib.rs`.

- [ ] **Step 4: Run tests**

```bash
cargo test -p vibesync_core
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add crates/vibesync_core
git commit -m "$(cat <<'EOF'
feat(vibesync_core): add fixture engine and output validator

EOF
)"
```

---

### Task 6: Pipeline + in-memory event bus

**Files:**
- Create: `crates/vibesync_core/src/pipeline.rs`

- [ ] **Step 1: Write the failing integration-style unit test**

```rust
#[cfg(test)]
mod tests {
    use super::*;
    use crate::command::VibeSyncCommand;
    use crate::event::VibeSyncEvent;
    use crate::operation::ExecutionMode;

    #[test]
    fn process_selection_emits_success_sequence() {
        let mut rt = Pipeline::new_slice1("pls send tommorow");
        let events = rt.handle(VibeSyncCommand::ProcessSelection {
            operation_id: "correct_grammar".into(),
        });
        let types: Vec<_> = events.iter().map(|e| std::mem::discriminant(e)).collect();
        assert_eq!(events[0], VibeSyncEvent::CommandReceived { command: "process_selection".into() });
        assert!(matches!(events[1], VibeSyncEvent::SelectionCaptured { .. }));
        assert_eq!(events[2], VibeSyncEvent::InferenceStarted);
        assert_eq!(events[3], VibeSyncEvent::InferenceCompleted);
        assert_eq!(events[4], VibeSyncEvent::ValidationPassed);
        assert_eq!(
            events[5],
            VibeSyncEvent::DeliveryRecorded {
                mode: ExecutionMode::InPlace
            }
        );
        assert_eq!(events[6], VibeSyncEvent::Completed);
        let _ = types;
    }

    #[test]
    fn unknown_operation_is_error() {
        let mut rt = Pipeline::new_slice1("hi");
        let events = rt.handle(VibeSyncCommand::ProcessSelection {
            operation_id: "nope".into(),
        });
        assert!(matches!(
            events.last(),
            Some(VibeSyncEvent::Error {
                code: crate::event::ErrorCode::UnknownOperation
            })
        ));
    }
}
```

Remove the unused `types` binding in the real file — do not leave `_ = types`. Drop that line when implementing.

- [ ] **Step 2: Run to verify fail**

```bash
cargo test -p vibesync_core --lib pipeline
```

Expected: FAIL (`Pipeline` missing).

- [ ] **Step 3: Implement `pipeline.rs`**

```rust
use crate::command::VibeSyncCommand;
use crate::context::{hash_text, FixtureSelectionSource};
use crate::engine::{FixtureEngine, InferenceEngine};
use crate::event::{ErrorCode, VibeSyncEvent};
use crate::operation::OperationRegistry;
use crate::validator::OutputValidator;

pub struct Pipeline {
    registry: OperationRegistry,
    selection: FixtureSelectionSource,
    engine: FixtureEngine,
    validator: OutputValidator,
}

impl Pipeline {
    pub fn new_slice1(fixture_text: impl Into<String>) -> Self {
        Self {
            registry: OperationRegistry::default_slice1(),
            selection: FixtureSelectionSource {
                text: fixture_text.into(),
            },
            engine: FixtureEngine,
            validator: OutputValidator {
                max_chars: 32 * 1024,
            },
        }
    }

    pub fn handle(&mut self, command: VibeSyncCommand) -> Vec<VibeSyncEvent> {
        match command {
            VibeSyncCommand::ProcessSelection { operation_id } => {
                self.process_selection(&operation_id)
            }
            VibeSyncCommand::Shutdown => vec![VibeSyncEvent::Completed],
            VibeSyncCommand::ReloadConfiguration
            | VibeSyncCommand::ShowOverlay
            | VibeSyncCommand::HideOverlay => vec![VibeSyncEvent::CommandReceived {
                command: "ok".into(),
            }],
        }
    }

    fn process_selection(&mut self, operation_id: &str) -> Vec<VibeSyncEvent> {
        let mut events = vec![VibeSyncEvent::CommandReceived {
            command: "process_selection".into(),
        }];
        let Some(op) = self.registry.get(operation_id) else {
            events.push(VibeSyncEvent::Error {
                code: ErrorCode::UnknownOperation,
            });
            return events;
        };
        let execution = op.execution;
        let ctx = self.selection.capture();
        events.push(VibeSyncEvent::SelectionCaptured {
            text_len: ctx.text.len(),
            text_hash: hash_text(&ctx.text),
        });
        events.push(VibeSyncEvent::InferenceStarted);
        let output = match self.engine.infer(&ctx.text) {
            Ok(o) => o,
            Err(_) => {
                events.push(VibeSyncEvent::Error {
                    code: ErrorCode::EnginePanic,
                });
                return events;
            }
        };
        events.push(VibeSyncEvent::InferenceCompleted);
        match self.validator.check(&ctx.text, &output) {
            Ok(()) => events.push(VibeSyncEvent::ValidationPassed),
            Err(e) => {
                events.push(VibeSyncEvent::ValidationFailed {
                    reason: e.to_string(),
                });
                return events;
            }
        }
        events.push(VibeSyncEvent::DeliveryRecorded { mode: execution });
        events.push(VibeSyncEvent::Completed);
        events
    }
}
```

Empty fixture text: validator will fail on empty engine output too — `new_slice1("")` then `infer` returns `""` which fails validation. That is correct.

- [ ] **Step 4: Run tests**

```bash
cargo test -p vibesync_core
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add crates/vibesync_core
git commit -m "$(cat <<'EOF'
feat(vibesync_core): run ProcessSelection through fixture pipeline

EOF
)"
```

---

### Task 7: NDJSON IPC codec

**Files:**
- Create: `crates/vibesync_core/src/ipc.rs`

- [ ] **Step 1: Write failing tests**

```rust
#[cfg(test)]
mod tests {
    use super::*;
    use crate::command::VibeSyncCommand;
    use crate::event::VibeSyncEvent;

    #[test]
    fn encodes_command_with_trailing_newline() {
        let cmd = VibeSyncCommand::Shutdown;
        let line = encode_command(&cmd).unwrap();
        assert!(line.ends_with('\n'));
        assert!(!line[..line.len() - 1].contains('\n'));
        assert_eq!(decode_command(&line).unwrap(), cmd);
    }

    #[test]
    fn encodes_event_with_trailing_newline() {
        let ev = VibeSyncEvent::Ready;
        let line = encode_event(&ev).unwrap();
        assert_eq!(decode_event(&line).unwrap(), ev);
    }
}
```

- [ ] **Step 2: Run to verify fail**

```bash
cargo test -p vibesync_core --lib ipc
```

Expected: FAIL (`encode_command` missing).

- [ ] **Step 3: Implement**

```rust
use crate::command::VibeSyncCommand;
use crate::event::VibeSyncEvent;

#[derive(Debug, thiserror::Error)]
pub enum IpcError {
    #[error("json: {0}")]
    Json(#[from] serde_json::Error),
}

pub fn encode_command(cmd: &VibeSyncCommand) -> Result<String, IpcError> {
    Ok(format!("{}\n", serde_json::to_string(cmd)?))
}

pub fn decode_command(line: &str) -> Result<VibeSyncCommand, IpcError> {
    Ok(serde_json::from_str(line.trim_end())?)
}

pub fn encode_event(ev: &VibeSyncEvent) -> Result<String, IpcError> {
    Ok(format!("{}\n", serde_json::to_string(ev)?))
}

pub fn decode_event(line: &str) -> Result<VibeSyncEvent, IpcError> {
    Ok(serde_json::from_str(line.trim_end())?)
}

pub fn default_socket_path() -> std::path::PathBuf {
    #[cfg(windows)]
    {
        std::path::PathBuf::from(r"\\.\pipe\vibesync")
    }
    #[cfg(not(windows))]
    {
        std::env::temp_dir().join("vibesync.sock")
    }
}
```

- [ ] **Step 4: Run tests**

```bash
cargo test -p vibesync_core
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add crates/vibesync_core
git commit -m "$(cat <<'EOF'
feat(vibesync_core): add newline-delimited JSON IPC codec

EOF
)"
```

---

### Task 8: `vibesyncd` unix socket server

**Files:**
- Create: `crates/vibesyncd/Cargo.toml`
- Create: `crates/vibesyncd/src/main.rs`
- Create: `crates/vibesyncd/tests/process_selection.rs`

- [ ] **Step 1: Manifest**

```toml
[package]
name = "vibesyncd"
version.workspace = true
edition.workspace = true
license.workspace = true
publish = false

[dependencies]
vibesync_core = { path = "../vibesync_core" }
tokio = { version = "1", features = ["macros", "rt-multi-thread", "net", "io-util", "sync", "time"] }
serde_json = "1"
```

- [ ] **Step 2: Write the failing integration test**

`crates/vibesyncd/tests/process_selection.rs`:

```rust
use std::time::Duration;

use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::net::UnixStream;
use tokio::process::Command;

#[cfg(unix)]
#[tokio::test]
async fn cli_process_selection_event_order() {
    let dir = tempfile::tempdir().unwrap();
    let sock = dir.path().join("vibesync.sock");
    let cfg = dir.path().join("config.yaml");
    let mut child = Command::new(env!("CARGO_BIN_EXE_vibesyncd"))
        .env("VIBESYNC_SOCK", &sock)
        .env("VIBESYNC_CONFIG", &cfg)
        .env("VIBESYNC_FIXTURE_TEXT", "pls send tommorow")
        .kill_on_drop(true)
        .spawn()
        .unwrap();

    let stream = wait_connect(&sock).await;
    let (reader, mut writer) = stream.into_split();
    let mut lines = BufReader::new(reader).lines();
    let ready = lines.next_line().await.unwrap().unwrap();
    assert!(ready.contains("ready"));
    writer
        .write_all(
            br#"{"type":"process_selection","operation_id":"correct_grammar"}
"#,
        )
        .await
        .unwrap();
    let mut joined = String::new();
    loop {
        let line = tokio::time::timeout(Duration::from_secs(2), lines.next_line())
            .await
            .unwrap()
            .unwrap()
            .unwrap();
        joined.push_str(&line);
        joined.push('\n');
        if line.contains("completed") {
            break;
        }
    }
    assert!(joined.contains("command_received"));
    assert!(joined.contains("selection_captured"));
    assert!(joined.contains("inference_started"));
    assert!(joined.contains("inference_completed"));
    assert!(joined.contains("validation_passed"));
    assert!(joined.contains("delivery_recorded"));
    child.kill().await.ok();
}

async fn wait_connect(sock: &std::path::Path) -> UnixStream {
    for _ in 0..50 {
        if let Ok(s) = UnixStream::connect(sock).await {
            return s;
        }
        tokio::time::sleep(Duration::from_millis(50)).await;
    }
    panic!("daemon did not bind {sock:?}");
}
```

Add to `vibesyncd` `[dev-dependencies]`: `tempfile = "3"` and `tokio` with features `macros`, `rt-multi-thread`, `net`, `io-util`, `process`, `time`. Add `[dependencies]` `dirs-next = "2"`. Each connection receives `Ready` once (not broadcast). Pipeline events are `broadcast` so CLI and Flutter both see them without duplicates: the command handler only `tx.send`s; the connection writes events from `rx.recv`.

- [ ] **Step 3: Run to verify fail**

```bash
cargo test -p vibesyncd --test process_selection
```

Expected: FAIL (package/bin missing or connection refused).

- [ ] **Step 4: Implement `main.rs`**

```rust
use std::path::PathBuf;
use std::sync::Arc;

use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::net::{UnixListener, UnixStream};
use tokio::sync::{broadcast, Mutex};
use vibesync_core::config::VibeSyncConfig;
use vibesync_core::event::VibeSyncEvent;
use vibesync_core::ipc::{decode_command, default_socket_path, encode_event};
use vibesync_core::pipeline::Pipeline;

fn default_config_path() -> PathBuf {
    dirs_next::config_dir()
        .unwrap_or_else(|| PathBuf::from("."))
        .join("vibesync")
        .join("config.yaml")
}

#[tokio::main]
async fn main() {
    let sock = std::env::var("VIBESYNC_SOCK")
        .map(PathBuf::from)
        .unwrap_or_else(|_| default_socket_path());
    let cfg_path = std::env::var("VIBESYNC_CONFIG")
        .map(PathBuf::from)
        .unwrap_or_else(|_| default_config_path());
    if let Err(e) = VibeSyncConfig::load_or_init(&cfg_path) {
        eprintln!("invalid config: {e}");
        std::process::exit(1);
    }
    let fixture =
        std::env::var("VIBESYNC_FIXTURE_TEXT").unwrap_or_else(|_| "pls send tommorow".into());
    let pipeline = Arc::new(Mutex::new(Pipeline::new_slice1(fixture)));
    let _ = std::fs::remove_file(&sock);
    let listener = match UnixListener::bind(&sock) {
        Ok(l) => l,
        Err(e) if e.kind() == std::io::ErrorKind::AddrInUse => {
            eprintln!("bind in use: {sock:?}");
            std::process::exit(1);
        }
        Err(e) => {
            eprintln!("{e}");
            std::process::exit(1);
        }
    };
    let (tx, _) = broadcast::channel::<String>(64);
    loop {
        let Ok((stream, _)) = listener.accept().await else {
            continue;
        };
        let pipeline = Arc::clone(&pipeline);
        let tx = tx.clone();
        tokio::spawn(async move {
            if let Err(e) = handle_client(stream, pipeline, tx).await {
                eprintln!("client: {e}");
            }
        });
    }
}

async fn handle_client(
    stream: UnixStream,
    pipeline: Arc<Mutex<Pipeline>>,
    tx: broadcast::Sender<String>,
) -> std::io::Result<()> {
    let mut rx = tx.subscribe();
    let (reader, mut writer) = stream.into_split();
    let ready = encode_event(&VibeSyncEvent::Ready).unwrap();
    writer.write_all(ready.as_bytes()).await?;
    let mut lines = BufReader::new(reader).lines();
    loop {
        tokio::select! {
            line = lines.next_line() => {
                let Some(line) = line? else { break; };
                if line.trim().is_empty() {
                    continue;
                }
                let Ok(cmd) = decode_command(&line) else { continue; };
                let shutdown = matches!(cmd, vibesync_core::command::VibeSyncCommand::Shutdown);
                let events = pipeline.lock().await.handle(cmd);
                for ev in events {
                    let encoded = encode_event(&ev).unwrap();
                    let _ = tx.send(encoded);
                }
                if shutdown {
                    break;
                }
            }
            Ok(encoded) = rx.recv() => {
                writer.write_all(encoded.as_bytes()).await?;
            }
        }
    }
    Ok(())
}
```

`Ready` is per-connection and not broadcast. Pipeline events are broadcast once via `tx`.

- [ ] **Step 5: Run tests**

```bash
cargo test -p vibesyncd
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add crates/vibesyncd Cargo.lock
git commit -m "$(cat <<'EOF'
feat(vibesyncd): serve ProcessSelection over a unix socket

EOF
)"
```

---

### Task 9: `vibesync_cli` + client-kill isolation test

**Files:**
- Create: `crates/vibesync_cli/Cargo.toml`
- Create: `crates/vibesync_cli/src/main.rs`
- Create: `crates/vibesyncd/tests/client_kill.rs`

- [ ] **Step 1: CLI manifest**

```toml
[package]
name = "vibesync_cli"
version.workspace = true
edition.workspace = true
license.workspace = true
publish = false

[dependencies]
vibesync_core = { path = "../vibesync_core" }
tokio = { version = "1", features = ["macros", "rt-multi-thread", "net", "io-util"] }
```

- [ ] **Step 2: Write failing CLI smoke: binary missing**

Implement `main.rs` immediately after the isolation test exists. Isolation test first:

`crates/vibesyncd/tests/client_kill.rs`:

```rust
use std::time::Duration;

use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::net::UnixStream;
use tokio::process::Command;

#[tokio::test]
async fn daemon_survives_client_disconnect() {
    let dir = tempfile::tempdir().unwrap();
    let sock = dir.path().join("vibesync.sock");
    let cfg = dir.path().join("config.yaml");
    let mut child = Command::new(env!("CARGO_BIN_EXE_vibesyncd"))
        .env("VIBESYNC_SOCK", &sock)
        .env("VIBESYNC_CONFIG", &cfg)
        .kill_on_drop(true)
        .spawn()
        .unwrap();

    let stream = wait_connect(&sock).await;
    drop(stream);

    let stream = wait_connect(&sock).await;
    let (reader, mut writer) = stream.into_split();
    let mut lines = BufReader::new(reader).lines();
    let _ready = lines.next_line().await.unwrap();
    writer
        .write_all(br#"{"type":"process_selection","operation_id":"correct_grammar"}
"#)
        .await
        .unwrap();
    let mut saw_completed = false;
    for _ in 0..20 {
        let line = tokio::time::timeout(Duration::from_secs(2), lines.next_line())
            .await
            .unwrap()
            .unwrap()
            .unwrap();
        if line.contains("completed") {
            saw_completed = true;
            break;
        }
    }
    assert!(saw_completed);
    child.kill().await.ok();
}

async fn wait_connect(sock: &std::path::Path) -> UnixStream {
    for _ in 0..50 {
        if let Ok(s) = UnixStream::connect(sock).await {
            return s;
        }
        tokio::time::sleep(Duration::from_millis(50)).await;
    }
    panic!("daemon did not bind {sock:?}");
}
```

- [ ] **Step 3: Run isolation test (should pass once Task 8 daemon exists)**

```bash
cargo test -p vibesyncd --test client_kill
```

Expected: PASS.

- [ ] **Step 4: Implement CLI**

```rust
use std::path::PathBuf;

use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::net::UnixStream;
use vibesync_core::command::VibeSyncCommand;
use vibesync_core::ipc::{default_socket_path, encode_command};

#[tokio::main]
async fn main() -> std::io::Result<()> {
    let sock = std::env::var("VIBESYNC_SOCK")
        .map(PathBuf::from)
        .unwrap_or_else(|_| default_socket_path());
    let operation = std::env::args()
        .nth(1)
        .unwrap_or_else(|| "correct_grammar".into());
    let stream = UnixStream::connect(&sock).await?;
    let (reader, mut writer) = stream.into_split();
    let cmd = VibeSyncCommand::ProcessSelection {
        operation_id: operation,
    };
    writer
        .write_all(encode_command(&cmd).unwrap().as_bytes())
        .await?;
    let mut lines = BufReader::new(reader).lines();
    while let Some(line) = lines.next_line().await? {
        println!("{line}");
        if line.contains("completed") || line.contains("error") {
            break;
        }
    }
    Ok(())
}
```

CLI must read `Ready` first, then send the command (same as the integration test). Update `main` to skip/print the first line then write:

```rust
    let mut lines = BufReader::new(reader).lines();
    let _ready = lines.next_line().await?;
    writer
        .write_all(encode_command(&cmd).unwrap().as_bytes())
        .await?;
    while let Some(line) = lines.next_line().await? {
        println!("{line}");
        if line.contains("\"type\":\"completed\"") || line.contains("\"type\":\"error\"") {
            break;
        }
    }
```

Because `into_split` happened before reading, create the stream, split, spawn the write after ready — the code order must be: split → BufReader on reader → read ready → write command → read until completed.

- [ ] **Step 5: Manual smoke (optional if integration tests pass)**

```bash
VIBESYNC_SOCK=/tmp/vibesync-dev.sock VIBESYNC_CONFIG=/tmp/vibesync-dev.yaml cargo run -p vibesyncd
# other terminal:
VIBESYNC_SOCK=/tmp/vibesync-dev.sock cargo run -p vibesync_cli -- correct_grammar
```

Expected: JSON events ending in `completed`.

- [ ] **Step 6: Invalid YAML refuses start**

`crates/vibesyncd/tests/bad_config.rs`:

```rust
#[test]
fn invalid_yaml_exits_nonzero() {
    let dir = tempfile::tempdir().unwrap();
    let cfg = dir.path().join("config.yaml");
    std::fs::write(&cfg, "app:\n  nope: 1\n").unwrap();
    let out = std::process::Command::new(env!("CARGO_BIN_EXE_vibesyncd"))
        .env("VIBESYNC_CONFIG", &cfg)
        .env("VIBESYNC_SOCK", dir.path().join("s.sock"))
        .output()
        .unwrap();
    assert!(!out.status.success());
}
```

This test is synchronous and will hang if the daemon starts. Invalid YAML must exit before bind. Task 8 `main` already exits on `load_or_init` error — but `load_or_init` **writes defaults if missing**; for an existing invalid file `from_yaml` errors. Good.

Run:

```bash
cargo test -p vibesyncd
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add crates/vibesync_cli crates/vibesyncd
git commit -m "$(cat <<'EOF'
feat: add CLI client and prove daemon survives client drop

EOF
)"
```

---

### Task 10: Flutter control-plane event client

**Files:**
- Create: `app/` via `flutter create`
- Create: `app/lib/ipc_client.dart`
- Modify: `app/lib/main.dart`

- [ ] **Step 1: Create the Flutter desktop app**

```bash
cd /Users/udaychauhan/workspace/vibesync
flutter create --org io.vibesync --project-name vibesync_app --platforms=macos,windows,linux app
```

- [ ] **Step 2: Write `app/lib/ipc_client.dart`**

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

class VibeSyncIpcClient {
  VibeSyncIpcClient({required this.socketPath});

  final String socketPath;
  Socket? _socket;
  final _events = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get events => _events.stream;

  Future<void> connect() async {
    final address = InternetAddress(socketPath, type: InternetAddressType.unix);
    _socket = await Socket.connect(address, 0);
    _socket!.listen((data) {
      for (final line in utf8.decode(data).split('\n')) {
        if (line.trim().isEmpty) continue;
        _events.add(jsonDecode(line) as Map<String, dynamic>);
      }
    }, onDone: _events.close);
  }

  Future<void> processSelection(String operationId) async {
    _socket!.add(utf8.encode(jsonEncode({
      'type': 'process_selection',
      'operation_id': operationId,
    }) + '\n'));
  }

  Future<void> shutdown() async {
    _socket!.add(utf8.encode(jsonEncode({'type': 'shutdown'}) + '\n'));
  }

  Future<void> close() async {
    await _socket?.close();
  }
}
```

- [ ] **Step 3: Replace `app/lib/main.dart` with an event log**

```dart
import 'dart:io';

import 'package:flutter/material.dart';

import 'ipc_client.dart';

void main() {
  runApp(const VibeSyncApp());
}

class VibeSyncApp extends StatefulWidget {
  const VibeSyncApp({super.key});

  @override
  State<VibeSyncApp> createState() => _VibeSyncAppState();
}

class _VibeSyncAppState extends State<VibeSyncApp> {
  final _lines = <String>[];
  VibeSyncIpcClient? _client;

  @override
  void initState() {
    super.initState();
    final path = Platform.environment['VIBESYNC_SOCK'] ?? '/tmp/vibesync.sock';
    _client = VibeSyncIpcClient(socketPath: path);
    _client!.connect().then((_) {
      _client!.events.listen((event) {
        setState(() => _lines.add(event.toString()));
      });
    }).catchError((Object e) {
      setState(() => _lines.add('connect failed: $e'));
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('VibeSync')),
        body: ListView(children: [for (final l in _lines) ListTile(title: Text(l))]),
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton(
              heroTag: 'run',
              onPressed: () => _client?.processSelection('correct_grammar'),
              child: const Icon(Icons.play_arrow),
            ),
            const SizedBox(height: 12),
            FloatingActionButton(
              heroTag: 'stop',
              onPressed: () => _client?.shutdown(),
              child: const Icon(Icons.stop),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Add a Dart test that encodes the same JSON as Rust**

`app/test/ipc_json_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('process_selection json matches daemon codec', () {
    final encoded = jsonEncode({
      'type': 'process_selection',
      'operation_id': 'correct_grammar',
    });
    expect(encoded, contains('"type":"process_selection"'));
    expect(encoded, contains('"operation_id":"correct_grammar"'));
  });
}
```

Run:

```bash
cd /Users/udaychauhan/workspace/vibesync/app && flutter test
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app
git commit -m "$(cat <<'EOF'
feat(app): add Flutter event-log control plane client

EOF
)"
```

---

### Task 11: Docs + Airo tracking issues (no Airo code)

**Files:**
- Create: `docs/platform/capabilities.md`
- Create: `docs/security/ipc.md`
- GitHub issues on `DevelopersCoffee/airo` and `DevelopersCoffee/airo_core` / `airo_mind` as specified

- [ ] **Step 1: Write `docs/platform/capabilities.md`**

```markdown
# Platform capabilities (slice 1)

All `airo_desktop` traits return unsupported. Real macOS/Windows/Linux
backends land in later slices. Callers must read `PlatformCapabilities`.
```

- [ ] **Step 2: Write `docs/security/ipc.md`**

```markdown
# IPC

Local unix socket (named pipe on Windows). Not TCP. Events log
`text_len` and `text_hash`, never the selection body.
```

- [ ] **Step 3: File Airo issues with `gh`**

```bash
gh issue create --repo DevelopersCoffee/airo --title "VibeSync: do not add desktop OS APIs to airo_core" --body "$(cat <<'EOF'
VibeSync (DevelopersCoffee/vibesync) is a separate desktop daemon. OS integration (hotkey, clipboard, input, display) lives in its `airo_desktop` crate.

Do not extend `airo_core` (M3U/XMLTV/search) with desktop automation. This is a tracking issue so later agents do not merge those concerns.

Slice 1 of VibeSync does not consume Airo path packages.
EOF
)"

gh issue create --repo DevelopersCoffee/airo --title "enhancement: extract GenerationEngine from airo_mind_llama for VibeSync" --body "$(cat <<'EOF'
VibeSync will need a local llama.cpp worker in a later slice. `airo_mind_llama` is welded to Mind (meeting crates, ggml link constraints).

Ask: a standalone generation crate without whisper/meeting deps that VibeSync can consume. Not blocking VibeSync slice 1 (fixture engine).
EOF
)"
```

If `airo_core` is a separate repo, also:

```bash
gh issue create --repo DevelopersCoffee/airo_core --title "Keep parser crate free of desktop OS integration" --body "$(cat <<'EOF'
Desktop hotkeys/clipboard belong in VibeSync's airo_desktop crate, not this M3U/XMLTV engine.
EOF
)"
```

- [ ] **Step 4: Commit docs in vibesync**

```bash
cd /Users/udaychauhan/workspace/vibesync
git add docs
git commit -m "$(cat <<'EOF'
docs: record IPC privacy and unsupported platform capabilities

EOF
)"
git push origin main
```

---

## Self-review

**Spec coverage**

| Spec section | Task |
|---|---|
| New GitHub repo, not Airo flavor | 1 |
| `airo_desktop` traits, all Unsupported | 2 |
| Typed YAML, deny unknown keys, default write, invalid refuse start | 3, 9 |
| Commands, events, `correct_grammar` only | 4 |
| Fixture engine + validator (empty / cap / identical-ok) | 5 |
| Pipeline event sequence | 6, 8 |
| NDJSON IPC, unix socket | 7, 8 |
| Daemon survives client drop | 9 |
| Flutter event client, Shutdown | 10 |
| Logs hash not body | 4 (`SelectionCaptured`), 11 |
| Airo issues, no airo_core desktop APIs | 11 |
| No llama.cpp / FRB / airo_protocol | all tasks omit them |

**Not in this plan (later slices):** real hotkey/clipboard, llama.cpp, Dynamic Notch polish, crates.io extract.

**Type names used everywhere:** `VibeSyncCommand`, `VibeSyncEvent`, `ErrorCode`, `InteractionMode`, `ExecutionMode`, `TextOperation`, `OperationRegistry`, `SelectionContext`, `InferenceEngine`, `FixtureEngine`, `OutputValidator`, `Pipeline`, `PlatformCapabilities`.
